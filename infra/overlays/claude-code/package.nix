# Claude Code CLI - Anthropic's official CLI for Claude
# Uses nodejs_22_patched to fix npm glob CVE-2025-64756
# All platform binaries (ripgrep, etc.) are included in the npm tarball
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22_patched,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.1.19";
  nodejs = nodejs_22_patched;

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';

  npmDepsHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";

  npmInstallFlags = [ "--ignore-scripts" ];

  dontNpmBuild = true;

  meta = {
    description = "Claude Code - Anthropic's official CLI for Claude AI assistant";
    homepage = "https://github.com/anthropics/anthropic-sdk-typescript";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
}
