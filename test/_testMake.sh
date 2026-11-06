#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testMake.sh — make.lib.sh: showMakeHelp und showMakeHints im CLI-Theme,
# dazu make help und make hints dieses Repos
#
# Übernimmt die Fälle aus CLITheme tests/test_make_help.py (make-help, rows).
# Bindet src/ dieser Arbeitskopie ein, nicht die Bibliotheken unter BASH_LIBS.
#
#   ./test/_testMake.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"
# Ein umgebendes make (make check) gibt sonst seine Flags weiter
unset MAKEFLAGS MAKELEVEL MFLAGS

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# Theme-Datei wie die classic-Vorlage von CLITheme; ohne sie gäbe es keine Farben
mkdir -p "${work}/config/cli-theme"
cat > "${work}/config/cli-theme/classic.theme" <<'EOF'
C_HEAD=bold+11
C_KEY=33
C_TEXT=10
C_VAL=10
C_HINT=dim
C_ACC=14
C_OK=10
C_WARN=208
C_ERR=bold+196
C_MARK=13
I_HEAD=2
I_ROW=7
I_HINT=7
W_KEY=21
GAP=2
WIDTH=120
SPACE=1
EOF

# Führt "$@" nach dem Einbinden von make.lib.sh aus; stdin bleibt erhalten.
# Setzt rc, out (stdout samt abschließender Leerzeilen) und err (stderr).
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runMake() {
    rc=0
    out="$(env -u NO_COLOR XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" \
        bash -c '. "${BASH_LIBS}/make.lib.sh"; "$@"; rc=$?; printf x; exit "${rc}"' _ "$@" 2>"${work}/err")" || rc=$?
    out="${out%x}"
    err="$(cat "${work}/err")"
}

# Wie runMake, aber mit einem Terminal als stdout (pty); stdout und stderr zusammen
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runInTerminal() {
    out="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" TERM=xterm-256color \
        python3 -c '
import errno, os, pty, subprocess, sys
master, slave = pty.openpty()
child = subprocess.Popen(sys.argv[1:], stdin=subprocess.DEVNULL, stdout=slave, stderr=slave)
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
' bash -c '. "${BASH_LIBS}/make.lib.sh"; "$@"' _ "$@" 2>&1)"
}

ESC=$'\033'

cat > "${work}/Makefile" <<'EOF'
##@ Setup
setup: .venv ## Bereit zum Entwickeln
install-from-working-copy: ## Länger als W_KEY
VERSION := 1.0 ## kein Target
NAME:= 1 ## auch kein Target
.PHONY: setup

##@ Release
tag-major: precheck ## Major-Release {major} — Maintainer
tag-minor: ## Minor-Release {minor}, {unknown} bleibt
EOF

echo
echo "showMakeHelp"
echo

runMake showMakeHelp --set "major=1.4.9 → 2.0.0" "${work}/Makefile"
assertEquals "0" "${rc}" "Exit 0"
assertEquals "" "${err}" "nichts auf stderr"
expected="
  Setup
       setup                  Bereit zum Entwickeln
       install-from-working-copy
                              Länger als W_KEY

  Release
       tag-major              Major-Release 1.4.9 → 2.0.0 [Maintainer]
       tag-minor              Minor-Release {minor}, {unknown} bleibt

"
assertEquals "${expected}" "${out}" \
    "Gruppen, Spalten nach W_KEY und GAP, langes Target auf eigener Zeile, [Maintainer], {major} gefüllt, Leerzeile am Ende"
assertNotContains "VERSION" "${out}" "Zuweisung NAME := … zählt nicht"
assertNotContains "NAME" "${out}" "Zuweisung NAME:= … zählt nicht"
assertNotContains ".PHONY" "${out}" ".PHONY zählt nicht"
assertNotContains "${ESC}" "${out}" "in einer Pipe keine Escape-Folgen"

printf 'one: ## erstes\n' > "${work}/first.mk"
printf '##@ Extra\ntwo: ## zweites\n' > "${work}/second.mk"
runMake showMakeHelp "${work}/first.mk" "${work}/second.mk"
assertEquals "one Extra two" "$(awk 'NF { printf "%s%s", sep, $1; sep = " " }' <<< "${out}")" \
    "mehrere Dateien wie aus MAKEFILE_LIST: Einträge in der Reihenfolge der Dateien"

runMake showMakeHelp --set major "${work}/Makefile"
assertEquals "2" "${rc}" "--set ohne =: Exit 2"
assertContains "NAME=WERT erwartet, war major" "${err}" "--set ohne =: Meldung"
runMake showMakeHelp
assertEquals "2" "${rc}" "ohne Datei: Exit 2"
runMake showMakeHelp "${work}/missing.mk"
assertEquals "1" "${rc}" "fehlende Datei: Exit 1"
assertContains "missing.mk" "${err}" "fehlende Datei: Name in der Meldung"
assertEquals "" "${out}" "fehlende Datei: keine halbe Hilfe"

hostile="\$(uname) \`uname\` it's & \\n %s"
printf 'x: ## Wert {v}\n' > "${work}/hostile.mk"
runMake showMakeHelp --set "v=${hostile}" "${work}/hostile.mk"
assertContains "Wert ${hostile}" "${out}" "Wert aus --set wörtlich, auch \$(…), Backtick, Apostroph, &, Backslash und %"

runInTerminal showMakeHelp --set "major=1.4.9 → 2.0.0" "${work}/Makefile"
assertContains "${ESC}[" "${out}" "im Terminal die Farben des Themes"
assertContains "[Maintainer]" "${out}" "im Terminal mit [Maintainer]"
NO_COLOR=1 runInTerminal showMakeHelp "${work}/Makefile"
assertNotContains "${ESC}" "${out}" "mit NO_COLOR keine Escape-Folgen"
assertContains "Bereit zum Entwickeln" "${out}" "mit NO_COLOR derselbe Text"

echo
echo "showMakeHints"
echo

long="pipx install $(printf 'x%.0s' {1..200})"
runMake showMakeHints <<EOF
## Werkzeuge
Größenänderung	umlaut
Groessenaenderung	ascii

Aus Git	${long}
Nur Beschriftung
EOF
assertEquals "0" "${rc}" "Exit 0"
mapfile -t lines < <(printf '%s' "${out}")
count="${#lines[@]}"
assertEquals "  Werkzeuge" "${lines[1]-}" "## Titel wird Überschrift"
lines+=("" "" "" "" "" "")
first="${lines[2]%%umlaut}"
second="${lines[3]%%ascii}"
assertEquals "30" "${#first}" "Wert nach Umlaut-Beschriftung in Spalte 7 + 21 + 2"
assertEquals "30" "${#second}" "Wert nach ASCII-Beschriftung in derselben Spalte"
assertEquals "       Aus Git                ${long}" "${lines[4]}" "langer Wert bricht nicht um"
assertEquals "       Nur Beschriftung" "${lines[5]%"${lines[5]##*[! ]}"}" "Zeile ohne TAB: Beschriftung ohne Wert"
assertEquals "7" "${count}" "leere Zeilen zählen nicht; am Ende eine Leerzeile"

runMake showMakeHints <<< "Wert	${hostile}"
assertContains "${hostile}" "${out}" "Wert von stdin wörtlich"
runMake showMakeHints <<< $'## Titel\nA\tB'
assertNotContains "${ESC}" "${out}" "in einer Pipe keine Escape-Folgen"

echo
echo "make help und make hints dieses Repos"
echo

plain() { sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g'; }
help="$(make --no-print-directory -C "${ROOT}" help 2>&1 | plain)"
assertContains "  Setup" "${help}" "make help: Gruppe Setup"
assertContains "[Maintainer]" "$(grep -E '^ +tag-patch ' <<< "${help}")" "make help: tag-patch mit [Maintainer]"
assertNotContains "— Maintainer" "${help}" "make help: Endung durch [Maintainer] ersetzt"
assertNotContains "awk" "$(sed -n '/^help:/,/^$/p' "${ROOT}/Makefile")" "Makefile: help ohne awk"
assertNotContains "hint_row" "$(cat "${ROOT}/Makefile")" "Makefile: hints ohne hint_row"
assertNotContains "DEV_MAKE" "$(cat "${ROOT}/Makefile")" "Makefile: ohne MakeLib (DEV_MAKE)"
assertContains "clitheme export --make" "$(cat "${ROOT}/Makefile")" "Makefile: Farben aus clitheme export"
# Ohne clitheme im PATH: keine Farben, auch nicht in den Zeilen, die Make selbst ausgibt
nocolor="$(env PATH="/usr/bin:/bin:$(dirname "$(command -v bash)")" make --no-print-directory -C "${ROOT}" help 2>&1)"
assertNotContains "${ESC}" "${nocolor}" "make help ohne clitheme: keine Escape-Folgen"
assertContains "Project:" "${nocolor}" "make help ohne clitheme: läuft"
info="$(make --no-print-directory -C "${ROOT}" info 2>&1 | plain)"
assertContains "BASH_LIBS              ${ROOT}/src" "${info}" "make info: Zeilen über showMakeHints"
hints="$(make --no-print-directory -C "${ROOT}" hints 2>&1 | plain)"
assertContains "Arbeitskopie" "${hints}" "make hints: Zeile Arbeitskopie"
assertContains "pipx install -e '${ROOT}'" "${hints}" "make hints: Arbeitskopie mit absolutem Pfad"
first="$(grep -E '^ +1\. Setup ' <<< "${hints}")"
second="$(grep -E '^ +2\. Prüfen ' <<< "${hints}")"
assertEquals "${#first}" "${#second}" "make hints: Umlaut-Beschriftung bündig"

echo
echo "Minimal-Makefile aus dem README in einem Ordner it's \$(uname)"
echo

folder="${work}/it's \$(uname)"
mkdir -p "${folder}"
awk '/^```makefile$/ { block = ""; inside = 1; next } inside && /^```$/ { inside = 0; if (block ~ /showMakeHelp/) print block; next } inside { block = block $0 "\n" }' \
    "${ROOT}/README.md" > "${folder}/Makefile"
assertContains "showMakeHelp" "$(cat "${folder}/Makefile")" "Beispiel aus der Doku gefunden"
rc=0
help="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" make -s -C "${folder}" help 2>"${work}/err")" || rc=$?
assertEquals "0" "${rc}" "Beispiel: make help Exit 0"
assertEquals "" "$(cat "${work}/err")" "Beispiel: make help ohne stderr"
assertContains "Hilfe anzeigen" "${help}" "Beispiel: help über showMakeHelp"
hints="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" make -s -C "${folder}" hints 2>&1)"
# make -C liefert den physischen Pfad; WORKSPACE_SQ quotet den Apostroph als '\''
physical="$(cd "${folder}" && pwd -P)"
assertContains "pipx install -e '${physical//\'/\'\\\'\'}'" "${hints}" "Beispiel: Pfad mit Apostroph und \$(…) wörtlich"
created=""
for entry in "${work}"/*; do
    case "${entry##*/}" in config|err|"it's"*|*.mk|Makefile) ;; *) created+="${entry##*/} " ;; esac
done
assertEquals "" "${created}" "nichts aus dem Pfad ausgeführt"
help="$(env BASH_LIBS="${work}/fehlt" make -s -C "${folder}" help 2>&1)"
assertContains "help: ## Hilfe anzeigen" "${help}" "Beispiel ohne BashLib: schlichte Liste"
hints="$(env BASH_LIBS="${work}/fehlt" make -s -C "${folder}" hints 2>&1)"
assertContains "pipx install -e" "${hints}" "Beispiel ohne BashLib: Hinweise schlicht"

finishTests
