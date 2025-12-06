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
        # Uses runCommand to create real files (not symlinks) to avoid
        # "path escapes from parent" errors in Docker overlay filesystem
        mkUser = { name, uid, gid, home, shell ? "${pkgs.bashInteractive}/bin/bash" }:
          pkgs.runCommand "user-${name}" {} ''
            # Create directories
            mkdir -p $out/etc/sudoers.d
            mkdir -p $out${home}
            mkdir -p $out/root
            mkdir -p $out/tmp
            chmod 1777 $out/tmp

            # passwd file
            cat > $out/etc/passwd << 'PASSWD'
            root:x:0:0:root:/root:${shell}
            ${name}:x:${toString uid}:${toString gid}:${name}:${home}:${shell}
            PASSWD

            # group file
            cat > $out/etc/group << 'GROUP'
            root:x:0:
            wheel:x:10:${name}
            ${name}:x:${toString gid}:
            GROUP

            # shadow file
            cat > $out/etc/shadow << 'SHADOW'
            root:!:1::::::
            ${name}:!:1::::::
            SHADOW
            chmod 640 $out/etc/shadow

            # sudoers
            echo "${name} ALL=(ALL) NOPASSWD:ALL" > $out/etc/sudoers.d/${name}
            chmod 440 $out/etc/sudoers.d/${name}
          '';

        # Nix configuration - real file, not symlink
        mkNixConf = pkgs.runCommand "nix-conf" {} ''
          mkdir -p $out/etc/nix
          cat > $out/etc/nix/nix.conf << 'EOF'
          experimental-features = nix-command flakes
          accept-flake-config = true
          EOF
        '';

        # direnv configuration - real file, not symlink
        mkDirenvConf = pkgs.runCommand "direnv-conf" {} ''
          mkdir -p $out/etc/direnv
          cat > $out/etc/direnv/direnvrc << 'EOF'
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
          EOF
        '';

        # bashrc with direnv hook - real file
        mkBashrc = user: pkgs.runCommand "bashrc-${user}" {} ''
          mkdir -p $out/home/${user}
          cat > $out/home/${user}/.bashrc << 'EOF'
          eval "$(direnv hook bash)"
          EOF
        '';

        # User nix config - real file
        mkUserNixConf = user: pkgs.runCommand "user-nix-conf-${user}" {} ''
          mkdir -p $out/home/${user}/.config/nix
          cat > $out/home/${user}/.config/nix/nix.conf << 'EOF'
          experimental-features = nix-command flakes
          accept-flake-config = true
          EOF
        '';

        # User direnv config - real file
        mkUserDirenvConf = user: pkgs.runCommand "user-direnv-conf-${user}" {} ''
          mkdir -p $out/home/${user}/.config/direnv
          cat > $out/home/${user}/.config/direnv/direnvrc << 'EOF'
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
          EOF
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
