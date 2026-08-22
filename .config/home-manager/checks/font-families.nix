# Fails the build if any font family named in wezterm/kitty/waybar config
# is not provided by an installed font package. Without this, fontconfig
# silently falls back to some other family and the mistake is invisible.
{ pkgs, lib, osConfig }:
let
  fontPackages =
    if osConfig == null then
      throw "checks/font-families.nix: osConfig is unavailable, so the font-family check cannot read fonts.packages. Remove the check or give it an explicit package list rather than letting it silently pass."
    else
      osConfig.fonts.packages;
in
pkgs.runCommand "check-font-families" { nativeBuildInputs = [ pkgs.fontconfig.bin ]; }
  ''
    dirs=""
    for d in ${lib.escapeShellArgs (map (p: "${p}/share/fonts") fontPackages)}; do
      [ -d "$d" ] && dirs="$dirs $d"
    done

    fc-scan --format '%{family}\n' $dirs 2>/dev/null \
      | tr ',' '\n' | sed 's/^[ "]*//; s/[ "]*$//' | grep -v '^$' | sort -u > installed

    wezterm_font=$(sed -n 's/^local font_family[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' ${../../wezterm/wezterm.lua})
    if [ -z "$wezterm_font" ]; then
      echo "" >&2
      echo 'error: could not find a `local font_family = "..."` line in wezterm.lua.' >&2
      echo "It was probably renamed or reformatted; update the sed in" >&2
      echo "checks/font-families.nix to match," >&2
      echo "otherwise this font check silently verifies nothing for wezterm." >&2
      exit 1
    fi

    {
      echo "$wezterm_font"
      sed -n 's/^font_family[[:space:]]\+//p' ${../../kitty/kitty.conf}
      sed -n 's/.*font-family:[[:space:]]*\([^;]*\);.*/\1/p' ${../../waybar/style.css}
    } | tr ',' '\n' | sed 's/^[ "]*//; s/[ "]*$//' | grep -v '^$' | sort -u > wanted

    missing=$(grep -Fxv -f installed wanted || true)
    if [ -n "$missing" ]; then
      echo "" >&2
      echo "error: these font families are referenced by config, but no installed" >&2
      echo "font package provides them (fontconfig would silently fall back):" >&2
      echo "" >&2
      echo "$missing" | while IFS= read -r fam; do
        echo "  - $fam" >&2
        key=$(printf '%s' "$fam" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        awk -v k="$key" \
          '{ n = tolower($0); gsub(/ /, "", n); if (index(n, k)) print "      did you mean: " $0 }' \
          installed >&2
      done
      echo "" >&2
      echo "($(wc -l < installed) families installed; run 'fc-list : family' to list them)" >&2
      exit 1
    fi

    mkdir -p "$out"
  ''
