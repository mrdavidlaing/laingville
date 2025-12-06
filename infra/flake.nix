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

        # Packages - for container builds
        packages = {
          # Runtime closures for Layer 2
          pythonRuntime = pkgs.python312;
          nodeRuntime = pkgs.nodejs_22;
        };
      }
    );
}
