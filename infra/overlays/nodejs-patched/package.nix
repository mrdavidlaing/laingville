# Patched nodejs package with npm 11.6.4 to fix glob CVE-2025-64756
# The upstream nodejs_22 bundles npm 10.9.4 with glob 10.4.5 (vulnerable)
# npm 11.6.4 includes glob 13.0.0 (fixed)
#
# This overlay wraps the original nodejs_22 and replaces its npm with 11.6.4.
# Used for container images where we need CVE-free npm but don't need nodePackages.
#
# Remove once nixpkgs updates nodejs with npm containing fixed glob.
# Track: https://github.com/npm/cli/releases - glob should be >= 10.5.0
{
  lib,
  stdenv,
  fetchurl,
  nodejs_22,
  makeWrapper,
}:

let
  # npm 11.6.4 tarball from npm registry
  npmTarball = fetchurl {
    url = "https://registry.npmjs.org/npm/-/npm-11.6.4.tgz";
    hash = "sha256-nAftyhKFPN2/T+1ONySFqmDAZPm/PkzRV6LbVRiheSs=";
  };

  # Extract npm to a derivation
  npmPackage = stdenv.mkDerivation {
    pname = "npm-standalone";
    version = "11.6.4";
    src = npmTarball;

    # npm tarball extracts to "package/" directory
    sourceRoot = "package";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/npm
      cp -r . $out/lib/node_modules/npm/
      runHook postInstall
    '';

    meta = {
      description = "npm package manager (standalone, version 11.6.4)";
      homepage = "https://www.npmjs.com/";
      license = lib.licenses.artistic2;
    };
  };

in
stdenv.mkDerivation {
  pname = "nodejs-patched";
  version = "${nodejs_22.version}-npm-11.6.4";

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/node_modules $out/share/man $out/include

    # Symlink node binary from original nodejs
    ln -s ${nodejs_22}/bin/node $out/bin/node

    # Symlink corepack if present
    if [ -e "${nodejs_22}/bin/corepack" ]; then
      ln -s ${nodejs_22}/bin/corepack $out/bin/corepack
    fi

    # Copy include directory if present
    cp -r ${nodejs_22}/include/* $out/include/ 2>/dev/null || true

    # Don't copy share/man from original nodejs as it contains symlinks to
    # the bundled npm which we're replacing. npm 11.6.4 doesn't include man pages.

    # Symlink corepack module from original
    if [ -d "${nodejs_22}/lib/node_modules/corepack" ]; then
      ln -s ${nodejs_22}/lib/node_modules/corepack $out/lib/node_modules/corepack
    fi

    # Use our patched npm instead of the bundled one
    cp -r ${npmPackage}/lib/node_modules/npm $out/lib/node_modules/npm

    # Create npm wrapper that uses our node
    makeWrapper $out/bin/node $out/bin/npm \
      --add-flags "$out/lib/node_modules/npm/bin/npm-cli.js"

    # Create npx wrapper
    makeWrapper $out/bin/node $out/bin/npx \
      --add-flags "$out/lib/node_modules/npm/bin/npx-cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Node.js ${nodejs_22.version} with patched npm 11.6.4 (CVE-2025-64756 fix)";
    homepage = "https://nodejs.org/";
    license = lib.licenses.mit;
    mainProgram = "node";
  };
}
