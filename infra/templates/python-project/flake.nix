# templates/python-project/flake.nix
{
  description = "Python project using laingville infrastructure";

  inputs = {
    infra.url = "github:mrdavidlaing/laingville?dir=infra";
    nixpkgs.follows = "infra/nixpkgs";
  };

  outputs = { self, infra, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      devShells.${system}.default = infra.devShells.${system}.python;
    };
}
