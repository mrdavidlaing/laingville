{
  description = "Pensive Assistant - development tools for pensive";

  inputs = {
    infra.url = "github:mrdavidlaing/laingville?dir=infra";
    nixpkgs.follows = "infra/nixpkgs";  # Critical for layer sharing with laingville base image!
    beads = {
      url = "github:steveyegge/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, beads, infra, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          # Import nixpkgs with infra overlays to get nodejs_22_patched
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import "${infra}/overlays") ];
          };
          
          # Import overlay packages from infra (available in CI)
          opencodeAi = pkgs.callPackage "${infra}/overlays/opencode-ai/package.nix" { };
          claudeCode = pkgs.callPackage "${infra}/overlays/claude-code/package.nix" { };

          pensiveTools = [
            beads.packages.${system}.default
            pkgs.zellij
            pkgs.lazygit
            opencodeAi
            claudeCode
          ];

          pensiveEnv = pkgs.buildEnv {
            name = "pensive-assistant-tools";
            paths = pensiveTools;
            pathsToLink = [ "/bin" "/share" ];
          };

        in
        {
          default = pensiveEnv;

          tarball = pkgs.runCommand "pensive-tools-tarball" {
            nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
            exportReferencesGraph = [ "closure" pensiveEnv ];
          } ''
            mkdir -p $out

            # Get all store paths from the closure
            STORE_PATHS=$(cat closure | grep "^/nix/store")

            # Create tarball with all closure paths
            tar -cf - $STORE_PATHS | gzip > $out/pensive-tools.tar.gz

            # Write the env path for reference
            echo "${pensiveEnv}" > $out/env-path
          '';
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = self.packages.${system}.default.paths;
            shellHook = ''
              echo "Pensive assistant tools available: beads, zellij, lazygit"
            '';
          };
        });
    };
}
