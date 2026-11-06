#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testPython.sh — python.lib.sh: ensurePythonVenv legt eine venv mit
# Mindestversion an und installiert Pakete
#
# Braucht python3.14 (Hausmindestversion) und ein älteres python3 für die
# Fälle „zu alt“; pip läuft nur offline (--no-index).
#
#   ./test/_testPython.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

CURRENT="$(command -v python3.14)" || { echo "python3.14 fehlt" >&2; exit 1; }
OLD="$(command -v python3)"
if [[ "$("${OLD}" -c 'import sys; print(sys.version_info >= (3, 14))')" == True ]]; then
    echo "python3 ist nicht älter als 3.14; die Fälle zu alt brauchen ein älteres python3" >&2
    exit 1
fi

# Führt ensurePythonVenv "$@" in ${work} aus; setzt rc, out und err
runVenv() {
    rc=0
    out="$(cd "${work}" && NO_COLOR=1 BASH_LIBS="${ROOT}/src" \
        bash -c '. "${BASH_LIBS}/python.lib.sh"; ensurePythonVenv "$@"' _ "$@" 2>"${work}/err")" || rc=$?
    err="$(cat "${work}/err")"
}

echo
echo "ensurePythonVenv"
echo

runVenv --python "${work}/fehlt/python3" --venv .venv
assertEquals "1" "${rc}" "Interpreter fehlt: Rückgabe 1"
assertContains "fehlt" "${err}" "Interpreter fehlt: Meldung auf stderr"
assertEquals "no" "$([[ -e ${work}/.venv ]] && echo yes || echo no)" "Interpreter fehlt: keine venv"

runVenv --python "${OLD}" --venv .venv --min 3.14
assertEquals "1" "${rc}" "Interpreter zu alt: Rückgabe 1"
assertContains "verlangt ab 3.14" "${err}" "Interpreter zu alt: Meldung nennt die Mindestversion"
assertEquals "no" "$([[ -e ${work}/.venv ]] && echo yes || echo no)" "Interpreter zu alt: keine venv"

runVenv --python "${CURRENT}" --venv .venv --min 3.14
assertEquals "0" "${rc}" "venv anlegen: Rückgabe 0"
assertEquals "" "${out}${err}" "venv anlegen: keine Ausgabe"
assertEquals "yes" "$([[ -x ${work}/.venv/bin/python ]] && echo yes)" "venv angelegt"
stamp="$(stat -f %m "${work}/.venv/pyvenv.cfg" 2>/dev/null || stat -c %Y "${work}/.venv/pyvenv.cfg")"
sleep 1
runVenv --python "${CURRENT}" --venv .venv --min 3.14
assertEquals "0" "${rc}" "vorhandene venv: Rückgabe 0"
assertEquals "${stamp}" "$(stat -f %m "${work}/.venv/pyvenv.cfg" 2>/dev/null || stat -c %Y "${work}/.venv/pyvenv.cfg")" \
    "vorhandene venv bleibt unverändert"

runVenv --python "${CURRENT}" --venv .venv -- --no-index nicht-vorhandenes-paket-bashlib
assertEquals "1" "${rc}" "pip scheitert: Rückgabe 1"
assertContains "nicht-vorhandenes-paket-bashlib" "${err}" "pip scheitert: pip-Ausgabe auf stderr"
assertContains "pip install" "${err}" "pip scheitert: Meldung nennt pip install"

"${OLD}" -m venv "${work}/old"
runVenv --python "${CURRENT}" --venv old --min 3.14
assertEquals "1" "${rc}" "vorhandene venv zu alt: Rückgabe 1"
assertContains "old" "${err}" "vorhandene venv zu alt: Meldung nennt die venv"
assertContains "rm -rf" "${err}" "vorhandene venv zu alt: nächster Schritt"

for option in --python --venv --min; do
    runVenv --python "${CURRENT}" --venv .venv "${option}"
    assertEquals "2" "${rc}" "${option} ohne Wert: Aufruffehler Exit 2"
done
runVenv --python "${CURRENT}" --venv .venv --min drei
assertEquals "2" "${rc}" "--min keine Version: Aufruffehler Exit 2"
runVenv --venv .venv
assertEquals "2" "${rc}" "ohne --python: Aufruffehler Exit 2"

finishTests
