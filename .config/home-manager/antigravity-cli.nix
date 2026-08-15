# Google Antigravity CLI (`agy`) -- not in nixpkgs (only antigravity-ide-fhs,
# the full IDE, is). Upstream ships it as a closed-source prebuilt binary via
# a shell installer (https://antigravity.google/cli/install.sh), which
# queries a manifest server for a per-platform tarball URL + sha512, then
# copies the extracted `antigravity` binary to `~/.local/bin/agy`.
#
# This derivation replays that same download+verify step through fetchurl
# instead, pinned in pins.nix, so the binary lands in the Nix store like any
# other package rather than an unmanaged file the installer's own
# self-updater can silently overwrite.
{ pkgs, lib, ... }:
let
  pin = (import ./pins.nix).antigravity-cli;
in
pkgs.stdenv.mkDerivation {
  pname = "antigravity-cli";
  version = pin.version;

  src = pkgs.fetchurl {
    url = pin.url;
    sha512 = pin.sha512;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  # No extra buildInputs -- `ldd` against the extracted binary showed only
  # standard glibc libs (libc/libm/libpthread/libdl/librt/libresolv), which
  # stdenv's own glibc already satisfies.

  # The tarball's single entry is a bare file, not a directory, which trips
  # up stdenv's default unpackPhase ("unpacker appears to have produced no
  # directories"). Extract it directly instead.
  unpackPhase = ''
    tar -xzf $src antigravity
  '';

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out/bin
    # Upstream's own installer renames the archive's `antigravity` binary to
    # `agy` at install time -- match that so `agy ...` works the same way
    # the official docs describe.
    install -m755 antigravity $out/bin/agy
  '';

  meta = {
    description = "Google Antigravity CLI (agy) -- terminal agent harness";
    homepage = "https://antigravity.google/docs/cli";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
