#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testHelpFormat.sh — printThemeOption und printThemeExample: Optionen mit
# reservierter Kurzform-Spalte, Metavariablen, Beispiele; usageLine bleibt
#
# Läuft mit dem echten clitheme in eigenem XDG_CONFIG_HOME und XDG_CACHE_HOME;
# die Farben prüft es an einem Pseudoterminal.
#
#   ./test/_testHelpFormat.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

export XDG_CONFIG_HOME="${work}/config" XDG_CACHE_HOME="${work}/cache"
if ! clitheme install >/dev/null 2>&1; then
    echo "clitheme fehlt oder scheitert: pipx install git+https://github.com/MikeMitterer/python-clitheme.git" >&2
    exit 1
fi

# Hilfe eines Beispiel-Skripts; ohne Terminal und ohne Farben
HELP='printThemeHeading "Optionen"
printThemeOption -i --info "" "Einstellungen anzeigen"
printThemeOption "" --restore DATEI "Sicherung zurückspielen"
printThemeOption -h --help "Diese Hilfe anzeigen"
printThemeOption -v "" "" "Nur die Kurzform"
printThemeOption "" --output-directory ORDNER "Lange Option, Beschreibung darunter"
printThemeHeading "Beispiele"
printThemeExample "demo --info" "Einstellungen anzeigen"
printThemeExample "demo --restore backup-2026-11-06.tar" "Sicherung vom 6. November zurückspielen"
usageLine "-x | --extra" "Alte Form bleibt gültig"
usageLine "" "eingerückt" yes'

# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
run() {
    env -u NO_COLOR BASH_LIBS="${ROOT}/src" bash -c '. "${BASH_LIBS}/tools.lib.sh"; eval "$1"' _ "$@"
}

# Wie run, aber mit einem Pseudoterminal als stdout; $1 "plain" setzt NO_COLOR
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runInTerminal() {
    local -a color=(-u NO_COLOR)
    if [[ ${1} == plain ]]; then color=(NO_COLOR=1); shift; fi
    env "${color[@]}" BASH_LIBS="${ROOT}/src" TERM=xterm-256color python3 -c '
import errno, os, pty, subprocess, sys
master, slave = pty.openpty()
child = subprocess.Popen(sys.argv[1:], stdout=slave, stderr=slave)
os.close(slave)
chunks = []
while True:
    try:
        chunk = os.read(master, 65536)
    except OSError as error:
        if error.errno != errno.EIO:
            raise
        break
    if not chunk:
        break
    chunks.append(chunk)
child.wait(timeout=10)
sys.stdout.write(b"".join(chunks).decode().replace("\r\n", "\n"))
' bash -c '. "${BASH_LIBS}/tools.lib.sh"; eval "$1"' _ "$@"
}

ESC=$'\033'

echo
echo "printThemeOption und printThemeExample"
echo

out="$(run "${HELP}")"
expected="
  Optionen
       -i | --info            Einstellungen anzeigen
            --restore DATEI   Sicherung zurückspielen
       -h | --help            Diese Hilfe anzeigen
       -v                     Nur die Kurzform
            --output-directory ORDNER
                              Lange Option, Beschreibung darunter

  Beispiele
       demo --info            Einstellungen anzeigen
       demo --restore backup-2026-11-06.tar
                              Sicherung vom 6. November zurückspielen
       -x | --extra           Alte Form bleibt gültig
                                  eingerückt"
# Leerzeichen am Zeilenende (Auffüllung vor leerer Beschreibung) zählen nicht
# shellcheck disable=SC2001  # sed je Zeile, nicht über die ganze Ausgabe
assertEquals "${expected}" "$(sed 's/ *$//' <<< "${out}")" \
    "Kurzform-Spalte reserviert, Langformen bündig, Beschreibung in Spalte 30, lange Einträge darunter, usageLine wie bisher"
assertNotContains "${ESC}" "${out}" "in einer Pipe keine Escape-Folgen"
assertEquals "30" "$(awk '/--info/ { print index($0, "Einstellungen") - 1; exit }' <<< "${out}")" \
    "Beschreibung beginnt nach 7 + 21 + 2 Zeichen"
assertEquals "$(awk '/-i \| --info/ { print index($0, "--info"); exit }' <<< "${out}")" \
    "$(awk '/--restore/ { print index($0, "--restore"); exit }' <<< "${out}")" "Langform ohne Kurzform in derselben Spalte"

colored="$(runInTerminal "${HELP}")"
assertContains "${ESC}[1;38;5;11mOptionen" "${colored}" "Terminal: Überschrift in C_HEAD"
assertContains "${ESC}[38;5;33m-i | --info" "${colored}" "Terminal: Option in C_KEY"
assertContains "--restore ${ESC}[38;5;14mDATEI${ESC}[0m${ESC}[38;5;33m" "${colored}" \
    "Terminal: Metavariable in C_ACC, danach wieder C_KEY"
assertContains "${ESC}[38;5;10mSicherung zurückspielen" "${colored}" "Terminal: Beschreibung in C_TEXT"
assertContains "${ESC}[38;5;33mdemo --info" "${colored}" "Terminal: Beispielaufruf in C_KEY"
plain="$(runInTerminal plain "${HELP}")"
assertNotContains "${ESC}" "${plain}" "Terminal mit NO_COLOR: keine Escape-Folgen"
assertContains "            --restore DATEI   Sicherung zurückspielen" "${plain}" "Terminal mit NO_COLOR: dieselben Spalten"

# Werte werden nur ausgegeben, nie ausgewertet
# shellcheck disable=SC2016  # der Text soll $(…) und Backticks wörtlich enthalten
out="$(run 'printThemeOption "" --name "\$(touch executed)" "Wert \`touch executed\`"')"
# shellcheck disable=SC2016  # gesucht wird der wörtliche Text
assertContains '$(touch executed)' "${out}" "Metavariable mit \$(…) wörtlich"
assertEquals "no" "$([[ -e executed ]] && echo yes || echo no)" "nichts ausgeführt"

finishTests
