# Patched pyright package with esbuild 0.27.1 to fix Go stdlib CVEs
# esbuild 0.27.0+ is compiled with Go 1.25.4 which fixes:
# - CVE-2025-61729 (HIGH): HostnameError.Error() resource exhaustion
# - CVE-2025-58187 (HIGH): x509 name constraint checking DoS
# - CVE-2025-58186 (HIGH): HTTP cookie parsing memory exhaustion
# - CVE-2025-58183 (HIGH): archive/tar sparse map allocation
# - Plus ~20 additional medium severity Go stdlib CVEs
# Also uses nodejs_22_patched to fix glob CVE-2025-64756
# Remove this overlay once nixpkgs updates pyright with fixed esbuild
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  runCommand,
  jq,
  nodejs_22_patched,
}:

let
  version = "1.1.407";

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "pyright";
    tag = version;
    hash = "sha256-TQrmA65CzXar++79DLRWINaMsjoqNFdvNlwDzAcqOjM=";
  };

  patchedPackageJSON = runCommand "package.json" { } ''
    ${jq}/bin/jq '
      .devDependencies |= with_entries(select(.key == "glob" or .key == "jsonc-parser"))
      | .scripts =  {  }
      ' ${src}/package.json > $out
  '';

# Patch pyright-internal's package.json to use esbuild 0.27.1 (Go 1.25.4).
# NOTE: `esbuild-loader` pins `esbuild` to ^0.25.0 (0.25.x only), which pulls in
# a vulnerable Go stdlib via `@esbuild/*` gobinaries and gets flagged by container
# scanners even though we don't run the build pipeline in Nix (`dontNpmBuild=true`).
# We remove `esbuild-loader` entirely to keep the runtime closure CVE-free.
  patchedInternalPackageJSON = runCommand "pyright-internal-package.json" { } ''
    ${jq}/bin/jq '
      .devDependencies["esbuild"] = "0.27.1"
      | del(.devDependencies["esbuild-loader"])
      ' ${src}/packages/pyright-internal/package.json > $out
  '';

  pyright-root = buildNpmPackage {
    pname = "pyright-root";
    inherit version src;
    nodejs = nodejs_22_patched;  # Use patched nodejs with npm 11.6.4 (glob CVE fix)
    sourceRoot = "${src.name}"; # required for update.sh script
    npmDepsHash = "sha256-4DVWWoLnNXoJ6eWeQuOzAVjcvo75Y2nM/HwQvAEN4ME=";
    dontNpmBuild = true;
    postPatch = ''
      cp ${patchedPackageJSON} ./package.json
      cp ${./package-lock.json} ./package-lock.json
    '';
    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';
  };

  pyright-internal = buildNpmPackage {
    pname = "pyright-internal";
    inherit version src;
    nodejs = nodejs_22_patched;  # Use patched nodejs with npm 11.6.4 (glob CVE fix)
    sourceRoot = "${src.name}/packages/pyright-internal";
    # Updated hash after removing esbuild-loader (drops vulnerable Go gobinaries)
    npmDepsHash = "sha256-xx9GPRW46Q9w6x92kk3Wkyh2fzf1rTubUKOIqqrn30E=";
    dontNpmBuild = true;
    postPatch = ''
      cp ${patchedInternalPackageJSON} ./package.json
      cp ${./pyright-internal-package-lock.json} ./package-lock.json
    '';
    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';
  };
in
buildNpmPackage rec {
  pname = "pyright";
  inherit version src;
  nodejs = nodejs_22_patched;  # Use patched nodejs with npm 11.6.4 (glob CVE fix)

  sourceRoot = "${src.name}/packages/pyright";
  npmDepsHash = "sha256-NyZAvboojw9gTj52WrdNIL2Oyy2wtpVnb5JyxKLJqWM=";

  postPatch = ''
    chmod +w ../../
    ln -s ${pyright-root}/node_modules ../../node_modules
    chmod +w ../pyright-internal
    ln -s ${pyright-internal}/node_modules ../pyright-internal/node_modules
  '';

  dontNpmBuild = true;

  meta = {
    changelog = "https://github.com/Microsoft/pyright/releases/tag/${src.tag}";
    description = "Type checker for the Python language (patched with esbuild 0.27.1 for CVE fixes)";
    homepage = "https://github.com/Microsoft/pyright";
    license = lib.licenses.mit;
    mainProgram = "pyright";
    maintainers = with lib.maintainers; [ kalekseev ];
  };
}
