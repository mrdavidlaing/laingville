# OpenCode AI CLI - AI-powered coding assistant
# Uses nodejs_22_patched to fix npm glob CVE-2025-64756
# Platform-specific binaries are fetched from separate npm packages
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22_patched,
  stdenv,
}:

buildNpmPackage rec {
  pname = "opencode-ai";
  version = "1.1.34";
  nodejs = nodejs_22_patched;

  src = fetchurl {
    url = "https://registry.npmjs.org/opencode-ai/-/opencode-ai-${version}.tgz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  sourceRoot = "package";

  # Platform-specific binary package
  # The postinstall script expects to find these via require.resolve()
  opencodeBinary = fetchurl (
    if stdenv.hostPlatform.system == "x86_64-linux" then {
      url = "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${version}.tgz";
      hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
    } else if stdenv.hostPlatform.system == "aarch64-linux" then {
      url = "https://registry.npmjs.org/opencode-linux-arm64/-/opencode-linux-arm64-${version}.tgz";
      hash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
    } else throw "Unsupported platform: ${stdenv.hostPlatform.system}"
  );

  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';

  npmDepsHash = "sha256-DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=";

  npmInstallFlags = [ "--ignore-scripts" ];

  dontNpmBuild = true;

  postInstall = ''
    # Extract platform binary package to a temporary location
    mkdir -p $TMPDIR/opencode-binary
    tar -xzf ${opencodeBinary} -C $TMPDIR/opencode-binary
    
    # The postinstall script expects to find the binary via require.resolve()
    # which looks for opencode-${platform}-${arch}/package.json
    # We need to place the binary package in node_modules where it can be resolved
    platformPackage=${if stdenv.hostPlatform.system == "x86_64-linux" then "opencode-linux-x64" else "opencode-linux-arm64"}
    
    mkdir -p $out/lib/node_modules/$platformPackage
    cp -r $TMPDIR/opencode-binary/package/* $out/lib/node_modules/$platformPackage/
    
    # Make the binary executable
    chmod +x $out/lib/node_modules/$platformPackage/bin/opencode
    
    # Create the symlink that the postinstall script would have created
    # This mimics what postinstall.mjs does: symlink bin/opencode to the platform binary
    ln -sf $out/lib/node_modules/$platformPackage/bin/opencode $out/lib/node_modules/opencode-ai/bin/opencode
  '';

  meta = {
    description = "OpenCode AI - AI-powered coding assistant CLI";
    homepage = "https://github.com/opencode-ai/opencode";
    license = lib.licenses.unfree;
    mainProgram = "opencode";
  };
}
