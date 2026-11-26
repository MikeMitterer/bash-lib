#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testPython.sh — python.lib.sh: readRequiresPython liest die Mindestversion,
# findPython wählt den Interpreter aus dem PATH, ensurePythonVenv legt eine venv
# mit Mindestversion an und installiert Pakete
#
# Braucht ein Python ab 3.14 (Hausmindestversion, über findPython gesucht) und ein
# älteres für die Fälle „zu alt“; pip läuft nur offline (--no-index). findPython
# prüft der Test mit nachgebauten Interpretern in einem eigenen PATH.
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

# Führt die Funktion "$@" aus python.lib.sh in ${work} aus; setzt rc, out und err.
# Mit LIB_PATH gesetzt gilt dieser PATH in der Funktion (Bash über ihren Pfad).
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runLib() {
    rc=0
    out="$(cd "${work}" && NO_COLOR=1 BASH_LIBS="${ROOT}/src" \
        "${BASH}" -c '. "${BASH_LIBS}/python.lib.sh"; [[ -z ${LIB_PATH:-} ]] || PATH="${LIB_PATH}"; "$@"' _ "$@" \
        2>"${work}/err")" || rc=$?
    err="$(cat "${work}/err")"
}
runVenv() { runLib ensurePythonVenv "$@"; }

runLib findPython 3.14
CURRENT="${out}"
[[ ${rc} == 0 ]] || { echo "kein Python ab 3.14 im PATH" >&2; exit 1; }
OLD=""
for name in python3.9 python3.10 python3.11 python3.12 python3.13 python3; do
    candidate="$(command -v "${name}")" || continue
    if [[ "$("${candidate}" -c 'import sys; print(sys.version_info < (3, 14))' 2>/dev/null)" == True ]]; then
        OLD="${candidate}"
        break
    fi
done
[[ -n ${OLD} ]] || { echo "kein Python älter als 3.14 im PATH; die Fälle zu alt brauchen eins" >&2; exit 1; }

echo
echo "readRequiresPython"
echo

printf '[tool.other]\nrequires-python = ">=9.9"\n\n[project]\nname = "demo"\nrequires-python = ">= 3.12"  # Kommentar\n' \
    > "${work}/pyproject.toml"
runLib readRequiresPython pyproject.toml
assertEquals "0|3.12" "${rc}|${out}" "pyproject.toml: X.Y aus [project], nicht aus anderen Abschnitten"
printf "[project]\nrequires-python = '>=3.11'\n" > "${work}/single.toml"
runLib readRequiresPython single.toml
assertEquals "0|3.11" "${rc}|${out}" "pyproject.toml mit '…': X.Y"
printf 'Metadata-Version: 2.1\nName: demo\nRequires-Python: >=3.10\n\nRequires-Python: >=9.9\n' > "${work}/METADATA"
runLib readRequiresPython METADATA
assertEquals "0|3.10" "${rc}|${out}" "METADATA: X.Y aus dem Kopf"
for spec in ">=3.9,<4" "<3.13" ">=3.9.1" "~=3.9"; do
    printf '[project]\nrequires-python = "%s"\n' "${spec}" > "${work}/odd.toml"
    runLib readRequiresPython odd.toml
    assertEquals "1|" "${rc}|${out}" "unverständlich ${spec}: Exit 1, keine Ausgabe"
    assertContains "${spec}" "${err}" "unverständlich ${spec}: Meldung nennt die Angabe"
done
printf '[project]\nname = "demo"\n' > "${work}/none.toml"
runLib readRequiresPython none.toml
assertEquals "1" "${rc}" "ohne requires-python: Exit 1"
runLib readRequiresPython fehlt.toml
assertEquals "1" "${rc}" "Datei fehlt: Exit 1"
runLib readRequiresPython
assertEquals "2" "${rc}" "ohne DATEI: Aufruffehler Exit 2"
# Übliche Formatierungen, die TOML erlaubt: eingerückter Schlüssel, Kommentar und Leerzeichen
# im Kopf des Abschnitts, CRLF-Zeilenenden
printf '[project]\nname = "demo"\n    requires-python = ">=3.12"\n' > "${work}/indent.toml"
printf '[ project ] # Paket\nrequires-python = ">=3.12"\n' > "${work}/header.toml"
printf '[project]\r\nname = "demo"\r\nrequires-python = ">=3.12"\r\n' > "${work}/crlf.toml"
for file in indent.toml header.toml crlf.toml; do
    runLib readRequiresPython "${file}"
    assertEquals "0|3.12" "${rc}|${out}" "pyproject.toml ${file%.toml}: X.Y"
done
# METADATA: Der Kopf endet an der ersten Leerzeile, auch mit CRLF; die Beschreibung zählt nicht
printf 'Metadata-Version: 2.1\r\nName: demo\r\n\r\nBeispiel:\r\nRequires-Python: >=3.99\r\n' > "${work}/crlf-meta"
runLib readRequiresPython crlf-meta
assertEquals "1|" "${rc}|${out}" "METADATA mit CRLF, Angabe nur in der Beschreibung: Exit 1, keine Ausgabe"
printf 'Metadata-Version: 2.1\r\nRequires-Python: >=3.10\r\n\r\n' > "${work}/crlf-meta-ok"
runLib readRequiresPython crlf-meta-ok
assertEquals "0|3.10" "${rc}|${out}" "METADATA mit CRLF: X.Y aus dem Kopf"
# Führende Null: dezimal, wie Python sie liest
printf '[project]\nrequires-python = ">=3.09"\n' > "${work}/zero.toml"
runLib readRequiresPython zero.toml
assertEquals "0|3.9" "${rc}|${out}" "führende Null: dezimal 3.9"

echo
echo "findPython"
echo

# Nachgebaute Interpreter: geben ihre Version aus wie readPythonVersion sie abfragt
fake() {
    mkdir -p "$(dirname "${work}/$1")"
    printf '#!/bin/sh\n%s\n' "$2" > "${work}/$1"
    chmod +x "${work}/$1"
}
fake a/python3.20 'echo 3.20'
fake a/python3.8 'echo 3.8'
fake a/python3.7 'echo 2.7'
fake a/python3.25 'echo "SyntaxError: invalid syntax" >&2; exit 1'
fake a/python3-config 'echo 9.9'
ln -s "${work}/entfernt/python3.30" "${work}/a/python3.30"
fake b/python3.21 'echo 3.21'
fake c/python3 'echo 3.21'
LIB_PATH="${work}/a:${work}/b:${work}/c:/usr/bin:/bin" runLib findPython 3.20
assertEquals "0|${work}/b/python3.21" "${rc}|${out}" "mehrere Kandidaten: der neueste, auch weiter hinten im PATH"
assertEquals "" "${err}" "toter Link, zu alte und scheiternde Kandidaten: still übergangen"
LIB_PATH="${work}/a:${work}/b:${work}/c:/usr/bin:/bin" runLib findPython 3.8
assertEquals "${work}/b/python3.21" "${out}" "gleiche Version: der erste im PATH"
LIB_PATH="${work}/a:${work}/b:${work}/c:/usr/bin:/bin" runLib findPython 3.22
assertEquals "1|" "${rc}|${out}" "kein passender Interpreter: Exit 1, keine Ausgabe"
assertContains "kein Python ab 3.22" "${err}" "kein passender Interpreter: Meldung nennt die Mindestversion"
runLib findPython 3
assertEquals "2" "${rc}" "MIN ohne Minor: Aufruffehler Exit 2"
LIB_PATH="${work}/a:${work}/b:${work}/c:/usr/bin:/bin" runLib findPython 3.09
assertEquals "0|${work}/b/python3.21|" "${rc}|${out}|${err}" "MIN mit führender Null: dezimal, ohne Bash-Fehler"
if [[ $(uname -s) == Darwin && -x /usr/bin/python3 ]]; then
    # /usr/bin/python3 von macOS nur mit Command Line Tools (xcode-select -p)
    fake tools-fehlen/xcode-select 'exit 2'
    fake tools-da/xcode-select 'echo /Library/Developer/CommandLineTools'
    LIB_PATH="${work}/tools-fehlen:/usr/bin:/bin" runLib findPython 3.0
    assertEquals "1|" "${rc}|${out}" "macOS ohne Command Line Tools: /usr/bin/python3 nicht aufgerufen"
    LIB_PATH="${work}/tools-da:/usr/bin:/bin" runLib findPython 3.0
    assertEquals "0|/usr/bin/python3" "${rc}|${out}" "macOS mit Command Line Tools: /usr/bin/python3 zählt"
    # Derselbe Starter unter anderer Schreibweise oder über einen Link
    mkdir -p "${work}/link"
    ln -s /usr/bin/python3 "${work}/link/python3.9"
    LIB_PATH="${work}/tools-fehlen:/usr/bin/:${work}/link:/bin" runLib findPython 3.0
    assertEquals "1|" "${rc}|${out}" "macOS ohne Command Line Tools: auch /usr/bin/ und Link auf den Starter nicht aufgerufen"
fi

echo
echo "ensurePythonVenv"
echo

runVenv --venv found --min 3.14
assertEquals "0" "${rc}" "ohne --python: Rückgabe 0"
assertEquals "yes" "$("${work}/found/bin/python" -c 'import sys; print("yes" if sys.version_info >= (3, 14) else "no")')" \
    "ohne --python: venv mit dem Interpreter aus findPython"

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
runVenv --python "${CURRENT}" --venv .venv --min 3.14.0
assertEquals "2" "${rc}" "--min mit drei Stellen: Aufruffehler Exit 2 (verglichen werden X.Y)"
runVenv --venv .venv
assertEquals "2" "${rc}" "ohne --python und ohne --min: Aufruffehler Exit 2"
runVenv --min 3.14
assertEquals "2" "${rc}" "ohne --venv: Aufruffehler Exit 2"

finishTests
