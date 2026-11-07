#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testBashVersion.sh — cli.lib.sh bricht unter Bash < 5 mit Meldung ab
#
# BashLib setzt Bash 5 voraus. Unter einer älteren Bash (macOS: /bin/bash 3.2)
# steht „✗ Bash 5 nötig, läuft mit Bash <Version>“ und darunter
# `brew install bash` auf stderr, das Skript endet mit Exit ungleich 0. Unter
# Bash 5 bleibt das Einbinden still.
#
#   ./test/_testBashVersion.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

# Bindet $2 unter der Bash $1 ein und gibt danach „weiter“ aus.
# Setzt rc, out (stdout) und err (stderr).
runLib() {
    local errFile
    errFile="$(mktemp)"
    rc=0
    # shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
    out="$(BASH_LIBS="${ROOT}/src" "$1" -c '. "${BASH_LIBS}/'"$2"'"; echo weiter' 2>"${errFile}")" || rc=$?
    err="$(<"${errFile}")"
    command rm -f -- "${errFile}"
}

echo
echo "cli.lib.sh unter Bash 5"
echo

runLib bash cli.lib.sh
assertEquals "0" "${rc}" "cli.lib.sh: Exit 0"
assertEquals "weiter" "${out}" "cli.lib.sh: Skript läuft weiter"
assertEquals "" "${err}" "cli.lib.sh: keine Ausgabe auf stderr"

runLib bash tools.lib.sh
assertEquals "" "${err}" "tools.lib.sh: keine Ausgabe auf stderr"

echo
echo "cli.lib.sh unter Bash < 5"
echo

# Eine ältere Bash gibt es etwa als /bin/bash unter macOS (3.2)
oldBash=""
# shellcheck disable=SC2016  # die Ausdrücke laufen erst in der inneren Bash
for candidate in /bin/bash /usr/bin/bash; do
    if [[ -x "${candidate}" ]] && (( $("${candidate}" -c 'echo "${BASH_VERSINFO[0]}"') < 5 )); then
        oldBash="${candidate}"
        break
    fi
done

if [[ -n "${oldBash}" ]]; then
    # shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
    oldVersion="$("${oldBash}" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"')"
    for lib in cli.lib.sh tools.lib.sh; do
        runLib "${oldBash}" "${lib}"
        assertEquals "1" "${rc}" "${lib} unter ${oldBash}: Exit 1, auch gesourct"
        assertEquals "" "${out}" "${lib} unter ${oldBash}: Skript endet vor dem nächsten Befehl"
        assertEquals "  ✗ Bash 5 nötig, läuft mit Bash ${oldVersion}"$'\n'"       brew install bash" "${err}" \
            "${lib} unter ${oldBash}: Meldung und Installationshinweis in eigener Zeile auf stderr"
    done
else
    echo "  – keine Bash < 5 gefunden, Fälle übersprungen"
fi

finishTests
