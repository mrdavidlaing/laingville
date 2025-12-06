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
            shell = "${pkgs.bashInteractive}/bin/bash";
            uid = "1000";
            gid = "1000";
            home = "/home/${user}";
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages;
            # Create real files (not symlinks) using fakeRootCommands
            fakeRootCommands = ''
              # Create directories
              mkdir -p ./etc/sudoers.d ./etc/nix ./etc/direnv
              mkdir -p .${home}/.config/nix .${home}/.config/direnv
              mkdir -p ./root ./tmp
              chmod 1777 ./tmp

              # passwd - must be a real file, not symlink
              cat > ./etc/passwd <<EOF
root:x:0:0:root:/root:${shell}
${user}:x:${uid}:${gid}:${user}:${home}:${shell}
EOF

              # group
              cat > ./etc/group <<EOF
root:x:0:
wheel:x:10:${user}
${user}:x:${gid}:
EOF

              # shadow
              cat > ./etc/shadow <<EOF
root:!:1::::::
${user}:!:1::::::
EOF
              chmod 640 ./etc/shadow

              # sudoers
              echo "${user} ALL=(ALL) NOPASSWD:ALL" > ./etc/sudoers.d/${user}
              chmod 440 ./etc/sudoers.d/${user}

              # nix config
              cat > ./etc/nix/nix.conf <<EOF
experimental-features = nix-command flakes
accept-flake-config = true
EOF

              # direnv config
              cat > ./etc/direnv/direnvrc <<EOF
source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
EOF

              # user bashrc
              cat > .${home}/.bashrc <<'BASHRC'
eval "$(direnv hook bash)"
BASHRC

              # user nix config
              cat > .${home}/.config/nix/nix.conf <<EOF
experimental-features = nix-command flakes
accept-flake-config = true
EOF

              # user direnv config
              cat > .${home}/.config/direnv/direnvrc <<EOF
source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
EOF

              # Fix ownership
              chown -R ${uid}:${gid} .${home}
            '';
            config = {
              User = user;
              WorkingDir = "/workspace";
              Env = [
                "HOME=${home}"
                "USER=${user}"
                "PATH=${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "NIX_PATH=nixpkgs=channel:nixos-25.11-small"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              Cmd = [ shell ];
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
            shell = "${pkgs.bashInteractive}/bin/bash";
            uid = "1000";
            gid = "1000";
          in
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            contents = packages;
            # Create real files (not symlinks) using fakeRootCommands
            fakeRootCommands = ''
              # Create directories
              mkdir -p ./etc
              mkdir -p .${workdir}
              mkdir -p ./root ./tmp
              chmod 1777 ./tmp

              # passwd - must be a real file, not symlink
              cat > ./etc/passwd <<EOF
root:x:0:0:root:/root:${shell}
${user}:x:${uid}:${gid}:${user}:${workdir}:${shell}
EOF

              # group
              cat > ./etc/group <<EOF
root:x:0:
${user}:x:${gid}:
EOF

              # shadow
              cat > ./etc/shadow <<EOF
root:!:1::::::
${user}:!:1::::::
EOF
              chmod 640 ./etc/shadow

              # Fix ownership
              chown -R ${uid}:${gid} .${workdir}
            '';
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
