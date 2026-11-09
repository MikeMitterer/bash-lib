#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testLibLayout.sh — Aufteilung der Bibliotheken: cli.lib.sh (Ausgabe im
# CLI-Theme), colors.lib.sh (Palette), tools.lib.sh (Allzweck-Helfer),
# make.lib.sh (Makefiles); ein Skript, das nur tools.lib.sh einbindet, findet
# alle bisherigen Funktionen außer denen aus make.lib.sh und net.lib.sh
#
#   ./test/_testLibLayout.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

# Fehlende Funktionen nach dem Einbinden von $1 (Leerzeichen-getrennte Liste)
missingAfter() {
    local -r lib="$1"; shift
    BASH_LIBS="${ROOT}/src" bash -c '. "${BASH_LIBS}/$1"; shift; for name; do declare -F "$name" >/dev/null || printf "%s " "$name"; done' \
        _ "${lib}" "$@" 2>/dev/null
}

# Datei, in der die Funktion $1 definiert ist
definedIn() {
    grep -lE "^$1\(\)" "${ROOT}"/src/*.lib.sh | xargs -n1 basename | tr '\n' ' ' | sed 's/ $//'
}

CLI=(themeLoad themeOwn themeNotice themeStyle themePlain themeNumber themeLine themeHeading
     themeInline themeAccent themeMark printThemeHeading printThemeRow printThemeValue
     printThemeOption printThemeExample printThemeHint printThemeStatus usageLine showMenu)
MAKE=(showProjectVersion showReleaseTags)
NET=(isLocalPortOpen)
TOOLS=(trim repeat scriptToDoc logFileStatus showModuleLinks)
PALETTE=(colorGreen colorError showScriptColors showAllColors showColorsInRange)

echo
echo "Aufteilung der Bibliotheken"
echo

for name in "${CLI[@]}"; do assertEquals "cli.lib.sh" "$(definedIn "${name}")" "${name} in cli.lib.sh"; done
for name in "${MAKE[@]}"; do assertEquals "make.lib.sh" "$(definedIn "${name}")" "${name} in make.lib.sh"; done
for name in "${NET[@]}"; do assertEquals "net.lib.sh" "$(definedIn "${name}")" "${name} in net.lib.sh"; done
for name in "${TOOLS[@]}"; do assertEquals "tools.lib.sh" "$(definedIn "${name}")" "${name} in tools.lib.sh"; done
for name in "${PALETTE[@]}"; do assertEquals "colors.lib.sh" "$(definedIn "${name}")" "${name} in colors.lib.sh"; done

assertEquals "" "$(missingAfter tools.lib.sh "${CLI[@]}" "${TOOLS[@]}" "${PALETTE[@]}")" \
    "nur tools.lib.sh eingebunden: Ausgabe, Allzweck-Helfer und Palette da"
assertEquals "${MAKE[*]} " "$(missingAfter tools.lib.sh "${MAKE[@]}")" \
    "nur tools.lib.sh eingebunden: Versionsanzeige nicht (make.lib.sh selbst einbinden)"
assertEquals "" "$(missingAfter make.lib.sh "${MAKE[@]}" "${CLI[@]}" "${TOOLS[@]}")" \
    "make.lib.sh eingebunden: Versionsanzeige, Ausgabe und Allzweck-Helfer da"
assertEquals "${NET[*]} " "$(missingAfter tools.lib.sh "${NET[@]}")" \
    "nur tools.lib.sh eingebunden: isLocalPortOpen nicht (net.lib.sh selbst einbinden)"
assertEquals "" "$(missingAfter net.lib.sh "${NET[@]}")" "net.lib.sh eingebunden: isLocalPortOpen da"
assertEquals "" "$(missingAfter cli.lib.sh "${CLI[@]}" "${PALETTE[@]}")" "nur cli.lib.sh eingebunden: Ausgabe und Palette da"
assertEquals "" "$(missingAfter colors.lib.sh "${PALETTE[@]}")" "nur colors.lib.sh eingebunden: Palette da"
assertEquals '\x1B[38;5;196m' "$(BASH_LIBS="${ROOT}/src" bash -c '. "${BASH_LIBS}/colors.lib.sh"; printf "%s" "${RED}"')" \
    "nur colors.lib.sh eingebunden: Farbwert RED"
assertEquals "       opt                    Text" \
    "$(NO_COLOR=1 BASH_LIBS="${ROOT}/src" bash -c '. "${BASH_LIBS}/cli.lib.sh"; printThemeRow opt Text' 2>/dev/null)" \
    "nur cli.lib.sh eingebunden: printThemeRow im Theme"
assertEquals "" "$(BASH_LIBS="${ROOT}/src" bash -c 'declare -a o=("- Eins | erste" "x Ende | raus"); . "${BASH_LIBS}/cli.lib.sh"; showMenu "Titel" o >/dev/null' 2>&1)" \
    "nur cli.lib.sh eingebunden: showMenu ohne Fehler (ohne trim/repeat aus tools.lib.sh)"

# Nach tools.lib.sh darf ein zweites Einbinden ohne Guard nicht abbrechen
assertEquals "weiter" "$(BASH_LIBS="${ROOT}/src" bash -c 'set -e; . "${BASH_LIBS}/tools.lib.sh"
    . "${BASH_LIBS}/cli.lib.sh"; . "${BASH_LIBS}/make.lib.sh"; . "${BASH_LIBS}/net.lib.sh"; echo weiter' 2>&1)" \
    "cli, make und net nach tools.lib.sh erneut eingebunden: Skript läuft weiter"

finishTests
