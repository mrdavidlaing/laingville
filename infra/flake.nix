# infra/flake.nix
{
  description = "Nix container infrastructure for laingville";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = import ./overlays;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlays ];
          config.allowUnfree = false;
        };

        #############################################
        # Package Sets - composable building blocks
        #############################################
        packageSets = {
          # Foundation (always included)
          base = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
            gawk
            cacert           # TLS certificates
            tzdata           # Timezone data
          ];

          # Development tools (for devcontainers)
          devTools = with pkgs; [
            git
            curl
            jq
            ripgrep
            fd
            fzf
            bat
            shadow           # for user management
            sudo
          ];

          # Nix tooling (for containers that need nix develop)
          nixTools = with pkgs; [
            nix
            direnv
            nix-direnv
          ];

          # Language: Python
          python = with pkgs; [
            python312
          ];
          pythonDev = with pkgs; [
            python312Packages.pip
            python312Packages.virtualenv
            uv
            ruff
            pyright
          ];

          # Language: Node
          node = with pkgs; [
            nodejs_22
          ];
          nodeDev = with pkgs; [
            bun
            nodePackages.typescript
            nodePackages.typescript-language-server
            nodePackages.prettier
            nodePackages.eslint
          ];

          # Language: Go
          go = with pkgs; [
            go
          ];
          goDev = with pkgs; [
            gopls
            golangci-lint
          ];

          # Language: Rust
          rust = with pkgs; [
            rustc
            cargo
          ];
          rustDev = with pkgs; [
            rust-analyzer
            clippy
            rustfmt
          ];
        };

        #############################################
        # Helper functions for user/config creation
        #############################################

        # Create a non-root user for containers
        mkUser = { name, uid, gid, home, shell ? "${pkgs.bashInteractive}/bin/bash" }:
          pkgs.runCommand "user-${name}" {} ''
            mkdir -p $out/etc

            echo "root:x:0:0:root:/root:${shell}" > $out/etc/passwd
            echo "${name}:x:${toString uid}:${toString gid}:${name}:${home}:${shell}" >> $out/etc/passwd

            echo "root:x:0:" > $out/etc/group
            echo "wheel:x:10:${name}" >> $out/etc/group
            echo "${name}:x:${toString gid}:" >> $out/etc/group

            echo "root:!:1::::::" > $out/etc/shadow
            echo "${name}:!:1::::::" >> $out/etc/shadow

            mkdir -p $out${home}
            mkdir -p $out/root

            # sudoers
            mkdir -p $out/etc/sudoers.d
            echo "${name} ALL=(ALL) NOPASSWD:ALL" > $out/etc/sudoers.d/${name}
          '';

        # Nix configuration
        mkNixConf = pkgs.writeTextDir "etc/nix/nix.conf" ''
          experimental-features = nix-command flakes
          accept-flake-config = true
        '';

        # direnv configuration
        mkDirenvConf = pkgs.writeTextDir "etc/direnv/direnvrc" ''
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
        '';

        # bashrc with direnv hook
        mkBashrc = user: pkgs.writeTextDir "home/${user}/.bashrc" ''
          eval "$(direnv hook bash)"
        '';

        # User nix config
        mkUserNixConf = user: pkgs.writeTextDir "home/${user}/.config/nix/nix.conf" ''
          experimental-features = nix-command flakes
          accept-flake-config = true
        '';

        # User direnv config
        mkUserDirenvConf = user: pkgs.writeTextDir "home/${user}/.config/direnv/direnvrc" ''
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
        '';

        #############################################
        # Builder Functions
        #############################################

        # mkDevContainer: Creates a development container
        # - vscode user (uid 1000) by default
        # - sudo access
        # - direnv hook in bashrc
        # - Nix configured for flakes
        mkDevContainer = {
          packages,
          name ? "devcontainer",
          tag ? "latest",
          user ? "vscode",
          extraConfig ? {}
        }:
          let
            userSetup = mkUser {
              name = user;
              uid = 1000;
              gid = 1000;
              home = "/home/${user}";
            };
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages ++ [
              mkNixConf
              mkDirenvConf
              userSetup
              (mkBashrc user)
              (mkUserNixConf user)
              (mkUserDirenvConf user)
            ];
            config = {
              User = user;
              WorkingDir = "/workspace";
              Env = [
                "HOME=/home/${user}"
                "USER=${user}"
                "PATH=/home/${user}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "NIX_PATH=nixpkgs=channel:nixos-25.11-small"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
            } // extraConfig;
            maxLayers = 100;
          };

        # mkRuntime: Creates a minimal production container
        # - app user (uid 1000, non-root) by default
        # - No development tools
        # - No Nix (unless explicitly included in packages)
        mkRuntime = {
          packages,
          name ? "runtime",
          tag ? "latest",
          user ? "app",
          workdir ? "/app",
          extraConfig ? {}
        }:
          let
            userSetup = mkUser {
              name = user;
              uid = 1000;
              gid = 1000;
              home = workdir;
            };
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages ++ [ userSetup ];
            config = {
              User = user;
              WorkingDir = workdir;
              Env = [
                "HOME=${workdir}"
                "USER=${user}"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
            } // extraConfig;
            maxLayers = 50;
          };

      in
      {
        # Export package sets for projects to use
        inherit packageSets;

        # Export builder functions
        lib = {
          inherit mkDevContainer mkRuntime mkUser;
        };

        # DevShells - for local development without containers
        devShells = {
          default = pkgs.mkShell {
            name = "infra-dev";
            packages = with pkgs; [
              git
              direnv
              nix-direnv
            ];
          };

          python = pkgs.mkShell {
            name = "python-dev";
            packages = packageSets.base ++ packageSets.python ++ packageSets.pythonDev;
            shellHook = ''
              echo "Python devShell activated"
            '';
          };

          node = pkgs.mkShell {
            name = "node-dev";
            packages = packageSets.base ++ packageSets.node ++ packageSets.nodeDev;
            shellHook = ''
              echo "Node devShell activated"
            '';
          };
        };

        # Example container images (for testing/demo)
        # Projects should build their own using mkDevContainer/mkRuntime
        packages = {
          # Example devcontainer with Python
          example-python-devcontainer = mkDevContainer {
            name = "ghcr.io/mrdavidlaing/laingville/example-python-devcontainer";
            packages = packageSets.base ++ packageSets.nixTools ++ packageSets.devTools
                    ++ packageSets.python ++ packageSets.pythonDev;
          };

          # Example runtime with Python
          example-python-runtime = mkRuntime {
            name = "ghcr.io/mrdavidlaing/laingville/example-python-runtime";
            packages = packageSets.base ++ packageSets.python;
          };

          # Example devcontainer with Node
          example-node-devcontainer = mkDevContainer {
            name = "ghcr.io/mrdavidlaing/laingville/example-node-devcontainer";
            packages = packageSets.base ++ packageSets.nixTools ++ packageSets.devTools
                    ++ packageSets.node ++ packageSets.nodeDev;
          };

          # Example runtime with Node
          example-node-runtime = mkRuntime {
            name = "ghcr.io/mrdavidlaing/laingville/example-node-runtime";
            packages = packageSets.base ++ packageSets.node;
          };
        };
      }
    );
}
