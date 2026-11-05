#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testToolsErrexit.sh — Helfer aus tools.lib.sh beenden aufrufende Skripte nicht
#
# Skripte laufen oft mit set -eo pipefail. scriptToDoc und repeat dürfen dort
# auch bei einem Fehlschlag im Inneren (grep ohne Treffer, seq mit ungültiger
# Anzahl) nicht das aufrufende Skript beenden.
#
#   ./test/_testToolsErrexit.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

printf '#!/usr/bin/env bash\necho ohne Doku-Zeilen\n' > "${work}/nodoc.sh"

# Führt $1 nach dem Einbinden von tools.lib.sh unter set -eo pipefail aus.
# Setzt rc und out (stdout und stderr).
runStrict() {
    rc=0
    out="$(BASH_LIBS="${ROOT}/src" bash -c 'set -eo pipefail; . "${BASH_LIBS}/tools.lib.sh" >/dev/null; '"$1" 2>&1)" || rc=$?
}

echo
echo "tools.lib.sh unter set -eo pipefail"
echo

runStrict "scriptToDoc '${work}/nodoc.sh' >/dev/null; echo weiter"
assertEquals "0" "${rc}" "scriptToDoc ohne Doku-Zeilen: Exit 0"
assertEquals "weiter" "${out}" "scriptToDoc ohne Doku-Zeilen: Skript läuft weiter"

# inherit_errexit gibt es ab Bash 4.4
if bash -c 'shopt -s inherit_errexit' 2>/dev/null; then
    runStrict "shopt -s inherit_errexit; doc=\"\$(scriptToDoc '${work}/nodoc.sh')\"; printf '%s|' \"\${doc}\"; echo weiter"
    assertEquals "0" "${rc}" "scriptToDoc mit inherit_errexit: Exit 0"
    assertEquals '\x1B[0m|weiter' "${out}" "scriptToDoc mit inherit_errexit: Ergebnis wie vorher"
else
    echo "  – inherit_errexit fehlt in dieser Bash, Fall übersprungen"
fi

runStrict "repeat x abc >/dev/null 2>&1; echo weiter"
assertEquals "0" "${rc}" "repeat mit ungültiger Anzahl: Exit 0"
assertEquals "weiter" "${out}" "repeat mit ungültiger Anzahl: Skript läuft weiter"

# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runStrict 'printf "[%s]" "$(repeat - 3)"'
assertEquals "[---]" "${out}" "repeat: gültiger Aufruf unverändert"

finishTests
