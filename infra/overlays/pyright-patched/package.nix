# Patched pyright package with esbuild 0.25+ to fix Go stdlib CVEs
# CVE-2025-22871, CVE-2024-24790, CVE-2023-24531, and related vulnerabilities
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

  # Patch pyright-internal's package.json to use esbuild-loader 4.4.0
  # This pulls in esbuild 0.25+ which is built with Go 1.23.7+ (CVE fixes)
  patchedInternalPackageJSON = runCommand "pyright-internal-package.json" { } ''
    ${jq}/bin/jq '
      .devDependencies["esbuild-loader"] = "^4.4.0"
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
    # Updated hash for esbuild-loader 4.4.0 -> esbuild 0.25.12
    npmDepsHash = "sha256-79OIVzxstTneuk3Xh7rVlNCtfye0lNkgH2N6MiO2jds=";
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
    description = "Type checker for the Python language (patched with esbuild 0.25+ for CVE fixes)";
    homepage = "https://github.com/Microsoft/pyright";
    license = lib.licenses.mit;
    mainProgram = "pyright";
    maintainers = with lib.maintainers; [ kalekseev ];
  };
}
