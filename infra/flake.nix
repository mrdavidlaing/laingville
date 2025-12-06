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

        # Common packages for all containers
        basePackages = with pkgs; [
          bashInteractive
          coreutils
          findutils
          gnugrep
          gnused
          gawk
          cacert           # TLS certificates
          tzdata           # Timezone data
          nix              # Nix package manager
          direnv
          nix-direnv
        ];

        # Additional packages for devcontainer
        devcontainerPackages = with pkgs; [
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

        # Create a non-root user for containers
        # This creates /etc/passwd, /etc/group, etc.
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
        nixConf = pkgs.writeTextDir "etc/nix/nix.conf" ''
          experimental-features = nix-command flakes
          accept-flake-config = true
        '';

        # direnv configuration
        direnvConf = pkgs.writeTextDir "etc/direnv/direnvrc" ''
          source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
        '';

        # vscode user for devcontainers
        vscodeUser = mkUser {
          name = "vscode";
          uid = 1000;
          gid = 1000;
          home = "/home/vscode";
        };

        # app user for runtime containers
        appUser = mkUser {
          name = "app";
          uid = 1000;
          gid = 1000;
          home = "/app";
        };

      in
      {
        # DevShells - composable development environments
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
            packages = with pkgs; [
              python312
              python312Packages.pip
              python312Packages.virtualenv
              uv
              ruff
              pyright
            ];
            shellHook = ''
              echo "Python devShell activated"
            '';
          };

          node = pkgs.mkShell {
            name = "node-dev";
            packages = with pkgs; [
              nodejs_22
              bun
              nodePackages.typescript
              nodePackages.typescript-language-server
              nodePackages.prettier
              nodePackages.eslint
            ];
            shellHook = ''
              echo "Node devShell activated"
            '';
          };
        };

        # Container images built with dockerTools
        packages = {
          # Base image: Nix + direnv (foundation for all other images)
          base = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/mrdavidlaing/laingville/base";
            tag = "latest";
            contents = basePackages ++ [ nixConf direnvConf ];
            config = {
              Env = [
                "PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "NIX_PATH=nixpkgs=channel:nixos-25.11-small"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              WorkingDir = "/workspace";
            };
            maxLayers = 100;
          };

          # DevContainer base: base + dev tools + vscode user
          devcontainer-base = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/mrdavidlaing/laingville/devcontainer-base";
            tag = "latest";
            contents = basePackages ++ devcontainerPackages ++ [
              nixConf
              direnvConf
              vscodeUser
              # bashrc with direnv hook
              (pkgs.writeTextDir "home/vscode/.bashrc" ''
                eval "$(direnv hook bash)"
              '')
              # direnv config for vscode user
              (pkgs.writeTextDir "home/vscode/.config/direnv/direnvrc" ''
                source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
              '')
              # nix config for vscode user
              (pkgs.writeTextDir "home/vscode/.config/nix/nix.conf" ''
                experimental-features = nix-command flakes
                accept-flake-config = true
              '')
            ];
            config = {
              Env = [
                "PATH=/home/vscode/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "NIX_PATH=nixpkgs=channel:nixos-25.11-small"
                "HOME=/home/vscode"
                "USER=vscode"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              User = "vscode";
              WorkingDir = "/workspace";
              Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
            };
            maxLayers = 100;
          };

          # Runtime Python: base + Python interpreter (for production)
          runtime-python = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/mrdavidlaing/laingville/runtime-python";
            tag = "latest";
            contents = [
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.cacert
              pkgs.python312
              appUser
            ];
            config = {
              Env = [
                "PATH=/app/.local/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "PYTHONUNBUFFERED=1"
                "HOME=/app"
                "USER=app"
              ];
              User = "app";
              WorkingDir = "/app";
            };
            maxLayers = 50;
          };

          # Runtime Node: base + Node.js (for production)
          runtime-node = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/mrdavidlaing/laingville/runtime-node";
            tag = "latest";
            contents = [
              pkgs.bashInteractive
              pkgs.coreutils
              pkgs.cacert
              pkgs.nodejs_22
              appUser
            ];
            config = {
              Env = [
                "PATH=/app/node_modules/.bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "NODE_ENV=production"
                "HOME=/app"
                "USER=app"
              ];
              User = "app";
              WorkingDir = "/app";
            };
            maxLayers = 50;
          };

          # Runtime minimal: just enough to run static binaries (Go, Rust, Bun-compiled)
          runtime-minimal = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/mrdavidlaing/laingville/runtime-minimal";
            tag = "latest";
            contents = [
              pkgs.cacert
              appUser
            ];
            config = {
              Env = [
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "HOME=/app"
                "USER=app"
              ];
              User = "app";
              WorkingDir = "/app";
            };
            maxLayers = 10;
          };
        };
      }
    );
}
