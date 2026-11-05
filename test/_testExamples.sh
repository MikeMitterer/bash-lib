#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testExamples.sh — examples/cli-demo.sh läuft und folgt dem CLI-Theme
#
# Ruft jeden Befehl des Beispiels mit src/ dieser Arbeitskopie auf und prüft
# Exit-Codes, Kernzeilen und Spalten; ohne Theme-Datei und in der Pipe ohne
# Farben. Am Pseudoterminal (python3) prüft er die Farben eines eigenen Themes
# und NO_COLOR. Eigener XDG_CONFIG_HOME, die echte Konfiguration bleibt außen vor.
#
#   ./test/_testExamples.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

DEMO="${ROOT}/examples/cli-demo.sh"
work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# Setzt rc, out (stdout) und err (stderr). Argumente gehen an cli-demo.sh.
runDemo() {
    rc=0
    env -i PATH="${PATH}" HOME="${work}" XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" \
        "${DEMO}" "$@" > "${work}/out" 2> "${work}/err" || rc=$?
    out="$(cat "${work}/out")"
    err="$(cat "${work}/err")"
}

# Spalte (ab 1), in der der Text nach der Beschriftung $1 beginnt
column() {
    awk -v label="$1" 'index($0, label) { rest = substr($0, index($0, label) + length(label)); match(rest, /[^ ]/); print index($0, label) + length(label) + RSTART - 1; exit }' <<< "${out}"
}

echo
echo "examples/cli-demo.sh"
echo

for args in "" "-h" "--help"; do
    # shellcheck disable=SC2086  # leeres Argument bewusst ohne Wort
    runDemo ${args}
    assertEquals "0" "${rc}" "Hilfe '${args}': Exit 0"
    assertContains "Aufruf: cli-demo.sh BEFEHL [ARGUMENT]" "${out}" "Hilfe '${args}': Aufrufzeile"
done
assertContains "Beispiele" "${out}" "Hilfe: Abschnitt Beispiele"
assertContains "Begrüßt NAME; ohne NAME ein Fehler mit Exit 2" "${out}" "Hilfe: Hervorhebung in der Pipe als reiner Text"
assertEquals "31" "$(column "info | -i")" "Hilfe: Beschreibung in Spalte 31 (classic ohne Theme-Datei)"
assertEquals "" "${err}" "Hilfe: stderr leer in der Pipe"

runDemo info
assertEquals "0" "${rc}" "info: Exit 0"
assertContains "${work}/config/cli-theme/classic.theme" "${out}" "info: Pfad der Theme-Datei"
assertContains "classic (Standard)" "${out}" "info: Theme mit Herkunft Standard"
# info zeigt, was colors.lib.sh geladen hat, auch mit dem Ersatznamen MAKE_THEME
out="$(env -i PATH="${PATH}" HOME="${work}" XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" MAKE_THEME=ocean "${DEMO}" info)"
assertContains "${work}/config/cli-theme/ocean.theme" "${out}" "info mit MAKE_THEME=ocean: Pfad von ocean"
assertEquals "ocean" "$(awk '$1 == "Theme" { print $2 }' <<< "${out}")" "info mit MAKE_THEME=ocean: Theme ocean"
assertContains "ocean (aus MAKE_THEME)" "${out}" "info mit MAKE_THEME=ocean: Herkunft MAKE_THEME"
assertContains "aus (keine Ausgabe an ein Terminal)" "${out}" "info: Farben aus in der Pipe"

runDemo hints
assertEquals "0" "${rc}" "hints: Exit 0"
assertContains $'\n       Jeder Befehl steht für sich' "${out}" "hints: Hinweistext mit I_HINT in der Pipe ohne Farben"
assertEquals "cli-theme install" "$(awk '/Themes anlegen/ { sub(/^ *Themes anlegen +/, ""); print }' <<< "${out}")" "hints: Befehl steht für sich"

runDemo status
assertEquals "0" "${rc}" "status: Exit 0"
assertContains "✓ Erfolg" "${out}" "status: Erfolg"
assertContains "! Warnung" "${out}" "status: Warnung"
assertContains "✗ Fehler" "${out}" "status: Fehler"

runDemo theme
assertEquals "0" "${rc}" "theme: Exit 0"
assertEquals "21" "$(awk '$1 == "W_KEY" { print $2 }' <<< "${out}")" "theme: Abstände von classic ohne Theme-Datei"

runDemo greet Mike
assertEquals "0" "${rc}" "greet Mike: Exit 0"
assertContains "✓ Hallo Mike" "${out}" "greet Mike: Begrüßung"

runDemo greet
assertEquals "2" "${rc}" "greet ohne NAME: Exit 2"
assertEquals "" "${out}" "greet ohne NAME: stdout leer"
assertContains "✗ Fehlende Angabe: NAME" "${err}" "greet ohne NAME: Meldung auf stderr"
assertEquals "cli-demo.sh greet NAME" "$(sed -n 2p <<< "${err}" | sed 's/^ *//')" "greet ohne NAME: nächster Schritt in eigener Zeile"

runDemo --foo
assertEquals "2" "${rc}" "--foo: Exit 2"
assertContains "✗ Unbekannte Option: --foo" "${err}" "--foo: Meldung auf stderr"
assertEquals "cli-demo.sh --help" "$(sed -n 2p <<< "${err}" | sed 's/^ *//')" "--foo: nächster Schritt in eigener Zeile"

runDemo bla
assertEquals "2" "${rc}" "bla: Exit 2"
assertContains "✗ Unbekannter Befehl: bla" "${err}" "bla: Meldung auf stderr"

rc=0
err="$(env -i PATH="${PATH}" "${DEMO}" info 2>&1)" || rc=$?
assertEquals "1" "${rc}" "ohne BASH_LIBS: Exit 1"
assertContains "BASH_LIBS" "${err}" "ohne BASH_LIBS: Meldung nennt BASH_LIBS"

# Am Terminal: Farben und Abstände aus einem eigenen Theme, NO_COLOR schaltet ab.
mkdir -p "${work}/config/cli-theme"
cat > "${work}/config/cli-theme/probe.theme" <<'EOF'
C_HEAD=bold+5
C_KEY=6
C_TEXT=7
C_VAL=8
C_HINT=dim
C_ACC=9
C_OK=2
C_WARN=3
C_ERR=1
C_MARK=4
I_HEAD=1
I_ROW=3
I_HINT=3
W_KEY=14
GAP=3
WIDTH=80
SPACE=1
EOF
# Gibt die Ausgabe am Pseudoterminal zurück. $1 zusätzliche Umgebung (NAME=WERT …), dann Argumente
onTerminal() {
    local -r extra="$1"; shift
    python3 - "${extra}" "${DEMO}" "$@" <<'PY'
import os, pty, subprocess, sys
extra, command = sys.argv[1], sys.argv[2:]
env = {'PATH': os.environ['PATH'], 'HOME': os.environ['WORK'], 'XDG_CONFIG_HOME': os.environ['WORK'] + '/config',
       'BASH_LIBS': os.environ['LIBS'], 'TERM': 'xterm-256color'}
env.update(item.split('=', 1) for item in extra.split() if item)
master, slave = pty.openpty()
child = subprocess.Popen(command, env=env, stdout=slave, stderr=slave)
os.close(slave)
chunks = []
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError:
        break
    if not chunk:
        break
    chunks.append(chunk)
os.close(master)
child.wait(timeout=10)
sys.stdout.write(b''.join(chunks).decode().replace('\r\n', '\n'))
PY
}
export WORK="${work}" LIBS="${ROOT}/src"
colored="$(onTerminal "CLI_THEME=probe" status)"
assertContains $'\033[1;38;5;5mStatus\033[0m' "${colored}" "Terminal, Theme probe: Überschrift in C_HEAD"
assertContains $'\033[38;5;2m✓ Erfolg' "${colored}" "Terminal, Theme probe: Erfolg in C_OK"
assertContains $'\033[38;5;1m✗ Fehler' "${colored}" "Terminal, Theme probe: Fehler in C_ERR"
colored="$(onTerminal "CLI_THEME=probe" info)"
assertEquals "an" "$(sed $'s/\033\\[[0-9;]*m//g' <<< "${colored}" | sed -nE 's/^ +Farben {2,}//p')" "Terminal, Theme probe: info meldet Farben an"
colored="$(onTerminal "CLI_THEME=probe" hints)"
assertContains $'\n   \033[38;5;6mThemes anlegen\033[0m' "${colored}" "Terminal, Theme probe: Einrückung I_ROW=3 und C_KEY"
infoColored="$(onTerminal "CLI_THEME=probe" info)"
assertContains $'\033[38;5;8m1.0.0\033[0m' "${infoColored}" "Terminal, Theme probe: Wert in C_VAL"
assertContains $'\033[38;5;8mprobe \033[38;5;4m(aus CLI_THEME)\033[0m\033[38;5;8m' "${infoColored}" "Terminal, Theme probe: Herkunft in C_MARK, Reset, danach C_VAL"
assertContains $'\n   \033[2mFarben gibt es nur am Terminal' "${infoColored}" "Terminal, Theme probe: Hinweis mit I_HINT=3 in C_HINT"
helpColored="$(onTerminal "CLI_THEME=probe" --help)"
assertContains $'\033[38;5;7mBegrüßt \033[38;5;9mNAME\033[0m\033[38;5;7m; ohne ' "${helpColored}" "Terminal, Theme probe: Hervorhebung in C_ACC, Reset, danach wieder C_TEXT"
plain="$(onTerminal "CLI_THEME=probe NO_COLOR=1" hints)"
assertNotContains $'\033' "${plain}" "Terminal mit NO_COLOR: keine Farben"
assertContains $'\n   Themes anlegen   cli-theme install' "${plain}" "Terminal mit NO_COLOR: dieselben Spalten (W_KEY=14, GAP=3)"
missing="$(onTerminal "" status)"
assertNotContains $'\033' "${missing}" "Terminal ohne Theme-Datei: keine Farben"
assertContains "cli-theme install" "${missing}" "Terminal ohne Theme-Datei: Hinweis mit nächstem Schritt"

finishTests
