#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testMake.sh — make.lib.sh: showMakeHeader, showMakeTargets, printMakeHeading und
# printMakeValue im CLI-Theme, dazu make help, info und hints dieses Repos
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
# Ohne Versionsdatei im Arbeitsverzeichnis: showMakeTargets zeigt dann den Ersatz
cd "${work}" || exit 1

# Theme über das echte clitheme mit eigenem XDG_CONFIG_HOME und XDG_CACHE_HOME
export XDG_CONFIG_HOME="${work}/config" XDG_CACHE_HOME="${work}/cache"
if ! clitheme install >/dev/null 2>&1; then
    echo "clitheme fehlt oder scheitert: pipx install git+https://github.com/MikeMitterer/python-clitheme.git" >&2
    exit 1
fi

# Führt "$@" nach dem Einbinden von make.lib.sh aus; stdin bleibt erhalten.
# Setzt rc, out (stdout samt abschließender Leerzeilen) und err (stderr).
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runMake() {
    rc=0
    out="$(env -u NO_COLOR BASH_LIBS="${ROOT}/src" \
        bash -c '. "${BASH_LIBS}/make.lib.sh"; "$@"; rc=$?; printf x; exit "${rc}"' _ "$@" 2>"${work}/err")" || rc=$?
    out="${out%x}"
    err="$(cat "${work}/err")"
}

# Wie runMake, aber mit einem Terminal als stdout (pty); stdout und stderr zusammen.
# NO_COLOR aus der Umgebung gilt nicht; $1 "plain" setzt es für diesen Aufruf.
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runInTerminal() {
    local -a color=(-u NO_COLOR)
    if [[ ${1} == plain ]]; then color=(NO_COLOR=1); shift; fi
    out="$(env "${color[@]}" BASH_LIBS="${ROOT}/src" TERM=xterm-256color \
        python3 -c '
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
echo "showMakeTargets"
echo

runMake showMakeTargets --set "major=1.4.9 → 2.0.0" "${work}/Makefile"
assertEquals "0" "${rc}" "Exit 0"
assertEquals "" "${err}" "nichts auf stderr"
expected="
  Setup
       setup                  Bereit zum Entwickeln
       install-from-working-copy
                              Länger als W_KEY

  Release
       tag-major              Major-Release 1.4.9 → 2.0.0 [Maintainer]
       tag-minor              Minor-Release x.y.z → x.Y+1.0, {unknown} bleibt

"
assertEquals "${expected}" "${out}" \
    "Gruppen, Spalten nach W_KEY und GAP, langes Target auf eigener Zeile, [Maintainer], --set vor der Version, ohne Versionsdatei Ersatz, Leerzeile am Ende"
assertNotContains "VERSION" "${out}" "Zuweisung NAME := … zählt nicht"
assertNotContains "NAME" "${out}" "Zuweisung NAME:= … zählt nicht"
assertNotContains ".PHONY" "${out}" ".PHONY zählt nicht"
assertNotContains "${ESC}" "${out}" "in einer Pipe keine Escape-Folgen"

# Versionsplatzhalter füllt showMakeTargets selbst aus der Versionsdatei im Arbeitsverzeichnis
project="${work}/project"
mkdir -p "${project}"
printf '[project]\nname = "demo"\nversion = "1.4.9"\n' > "${project}/pyproject.toml"
printf 'v: ## {version}\na: ## {major}\nb: ## {minor}\nc: ## {patch}\n' > "${project}/Makefile"
(cd "${project}" && runMake showMakeTargets Makefile && printf '%s' "${out}" > "${work}/version.out")
assertEquals "1.4.9 | 1.4.9 → 2.0.0 | 1.4.9 → 1.5.0 | 1.4.9 → 1.4.10" \
    "$(awk 'NF { sub(/^ +[a-z] +/, ""); printf "%s%s", sep, $0; sep = " | " }' "${work}/version.out")" \
    "{version}, {major}, {minor}, {patch} aus der Versionsdatei, ohne --set"
printf 'v: ## {version}\na: ## {major}\nb: ## {minor}\nc: ## {patch}\n' > "${work}/version.mk"
runMake showMakeTargets "${work}/version.mk"
assertEquals "x.y.z | x.y.z → X+1.0.0 | x.y.z → x.Y+1.0 | x.y.z → x.y.Z+1" \
    "$(awk 'NF { sub(/^ +[a-z] +/, ""); printf "%s%s", sep, $0; sep = " | " }' <<< "${out}")" \
    "ohne Versionsdatei lesbarer Ersatz"
assertEquals "" "${err}" "ohne Versionsdatei nichts auf stderr"

printf 'one: ## erstes\n' > "${work}/first.mk"
printf '##@ Extra\ntwo: ## zweites\n' > "${work}/second.mk"
runMake showMakeTargets "${work}/first.mk" "${work}/second.mk"
assertEquals "one Extra two" "$(awk 'NF { printf "%s%s", sep, $1; sep = " " }' <<< "${out}")" \
    "mehrere Dateien wie aus MAKEFILE_LIST: Einträge in der Reihenfolge der Dateien"

# Server-Targets: ##R schreibend, ##D destruktiv; Platzhalter und — Maintainer wie bei ##
cat > "${work}/server.mk" <<'EOF'
##@ Server
server-update: ##R Stack aktualisieren {major}
server-DANGER-restore: ##D Backup einspielen — Maintainer
local: ## Lokal
EOF
runMake showMakeTargets --set "major=1.4.9 → 2.0.0" "${work}/server.mk"
assertEquals "0" "${rc}" "##R und ##D: Exit 0"
expected="
  Server
       server-update          Stack aktualisieren 1.4.9 → 2.0.0
       server-DANGER-restore  Backup einspielen [Maintainer]
       local                  Lokal

"
assertEquals "${expected}" "${out}" "##R und ##D wie ##: Platzhalter, [Maintainer], ohne Farben schlicht"
# Farben des Themes, wie make.lib.sh sie setzt
# shellcheck disable=SC2016  # die Farben setzt erst make.lib.sh in der inneren Bash
runMake eval 'printf "%b|%b|%b" "${THEME_COLOR_TARGET}" "${THEME_COLOR_SERVER}" "${THEME_COLOR_DANGER}"'
IFS='|' read -r colorTarget colorServer colorDanger <<< "${out}"
# Gegenprobe: drei verschiedene, nicht leere Farben, sonst belegen die Prüfungen unten nichts
assertEquals "3" "$(printf '%s\n' "${colorTarget}" "${colorServer}" "${colorDanger}" | grep -c "${ESC}")" "Theme hat Target-, Server- und Danger-Farbe"
assertEquals "3" "$(printf '%s\n' "${colorTarget}" "${colorServer}" "${colorDanger}" | sort -u | grep -c .)" "die drei Farben unterscheiden sich"
runInTerminal showMakeTargets "${work}/server.mk"
assertContains "${colorServer}server-update" "${out}" "im Terminal: ##R-Target in der Server-Farbe"
assertContains "${colorDanger}server-DANGER-restore" "${out}" "im Terminal: ##D-Target in der Danger-Farbe"
assertContains "${colorTarget}local" "${out}" "im Terminal: ##-Target in der Target-Farbe"

runMake showMakeTargets --set major "${work}/Makefile"
assertEquals "2" "${rc}" "--set ohne =: Exit 2"
assertContains "NAME=WERT erwartet, war major" "${err}" "--set ohne =: Meldung"
runMake showMakeTargets
assertEquals "2" "${rc}" "ohne Datei: Exit 2"
runMake showMakeTargets "${work}/missing.mk"
assertEquals "1" "${rc}" "fehlende Datei: Exit 1"
assertContains "missing.mk" "${err}" "fehlende Datei: Name in der Meldung"
assertEquals "" "${out}" "fehlende Datei: keine halbe Hilfe"

hostile="\$(uname) \`uname\` it's & \\n %s"
printf 'x: ## Wert {v}\n' > "${work}/hostile.mk"
runMake showMakeTargets --set "v=${hostile}" "${work}/hostile.mk"
assertContains "Wert ${hostile}" "${out}" "Wert aus --set wörtlich, auch \$(…), Backtick, Apostroph, &, Backslash und %"

runInTerminal showMakeTargets --set "major=1.4.9 → 2.0.0" "${work}/Makefile"
assertContains "${ESC}[" "${out}" "im Terminal die Farben des Themes"
assertContains "[Maintainer]" "${out}" "im Terminal mit [Maintainer]"
printf 'x: ## %s\n' "$(printf 'Wort %.0s' {1..30})" > "${work}/long.mk"
COLUMNS=60 runInTerminal plain showMakeTargets "${work}/long.mk"
assertEquals "1" "$(grep -c . <<< "${out}")" "Terminal mit 60 Spalten: lange Beschreibung bleibt in einer Zeile (wie printThemeRow)"
runInTerminal plain showMakeTargets "${work}/Makefile"
assertNotContains "${ESC}" "${out}" "mit NO_COLOR keine Escape-Folgen"
assertContains "Bereit zum Entwickeln" "${out}" "mit NO_COLOR derselbe Text"

echo
echo "showMakeHeader"
echo

runMake showMakeHeader "demo"
assertEquals "0" "${rc}" "Exit 0"
assertEquals $'\nPlease use `make <target>\' where <target> is one of\n\nProject: demo\n' "${out}" \
    "Leerzeile, Aufrufzeile, Leerzeile, Projektzeile; in der Pipe ohne Escape-Folgen"
runMake showMakeHeader "${hostile}"
assertContains "Project: ${hostile}" "${out}" "Projektname mit \$(…), Backtick, Apostroph, &, Backslash und % wörtlich"
runMake showMakeHeader
assertEquals "2" "${rc}" "ohne Projektname: Aufruffehler Exit 2"
runInTerminal showMakeHeader "demo"
assertContains "<${ESC}[1;38;5;11mtarget${ESC}[0m>" "${out}" "Terminal: target in der Gruppenfarbe"
assertContains "Project: ${ESC}[1;38;5;11mdemo${ESC}[0m" "${out}" "Terminal: Projektname in der Gruppenfarbe"
runInTerminal plain showMakeHeader "demo"
assertNotContains "${ESC}" "${out}" "Terminal mit NO_COLOR: keine Escape-Folgen"

echo
echo "printMakeHeading und printMakeValue"
echo

runMake printMakeValue PROJECT_NAME demo
assertEquals "0" "${rc}" "Exit 0"
assertEquals $'       PROJECT_NAME           demo\n' "${out}" "eine Zeile in den Spalten des Themes, ohne Leerzeile danach"
runMake printMakeValue "Nur Beschriftung"
assertEquals "       Nur Beschriftung" "${out%"${out##*[! $'\n']}"}" "ohne Wert: nur die Beschriftung"
runMake printMakeValue WERT "${hostile}"
assertContains "${hostile}" "${out}" "Wert mit \$(…), Backtick, Apostroph, &, Backslash und % wörtlich"
runMake printMakeValue "${hostile}" x
assertContains "${hostile}" "${out}" "Beschriftung wörtlich"
runMake printMakeValue
assertEquals "2" "${rc}" "ohne Beschriftung: Aufruffehler Exit 2"
runMake printMakeValue a b c
assertEquals "2" "${rc}" "drei Argumente: Aufruffehler Exit 2"

runMake printMakeHeading "Werkzeuge"
assertEquals $'\n  Werkzeuge\n' "${out}" "Überschrift mit Abstand davor wie printThemeHeading"
runMake printMakeHeading "${hostile}"
assertContains "${hostile}" "${out}" "Überschrift wörtlich"
runMake printMakeHeading
assertEquals "2" "${rc}" "ohne Text: Aufruffehler Exit 2"

runMake printMakeValue "Größenänderung" umlaut
first="${out%%umlaut*}"
runMake printMakeValue "Groessenaenderung" ascii
second="${out%%ascii*}"
assertEquals "30" "${#first}" "Wert nach Umlaut-Beschriftung in Spalte 7 + 21 + 2"
assertEquals "30" "${#second}" "Wert nach ASCII-Beschriftung in derselben Spalte"
long="pipx install $(printf 'x%.0s' {1..200})"
runMake printMakeValue "Aus Git" "${long}"
assertEquals $'       Aus Git                '"${long}"$'\n' "${out}" "langer Wert bricht nicht um"
longValue="pipx install $(printf 'x%.0s' {1..100})"
COLUMNS=60 runInTerminal plain printMakeValue "Aus Git" "${longValue}"
assertContains "       Aus Git                ${longValue}" "${out}" "Terminal mit 60 Spalten: Wert bricht nie um"
runMake printMakeHeading Titel
assertNotContains "${ESC}" "${out}" "in einer Pipe keine Escape-Folgen"
runInTerminal printMakeValue Name Wert
assertContains "${ESC}[" "${out}" "im Terminal die Farben des Themes"

echo
echo "requireMakeSetup"
echo

# Wegwerf-Repo: setup legt .stamp an; die Prüfung läuft im Repo (git, make -q)
setup="${work}/setup"
mkdir -p "${setup}"
git init -q "${setup}"
printf '.stamp: input\n\ttouch .stamp\n' > "${setup}/Makefile"
touch "${setup}/input"
# Setzt rc, out und err für requireMakeSetup "$@", aufgerufen im Wegwerf-Repo
readSetup() {
    (cd "${setup}" && runMake requireMakeSetup "$@"
     printf '%s' "${rc}" > "${work}/setup.rc"; printf '%s' "${out}" > "${work}/setup.out"
     printf '%s' "${err}" > "${work}/setup.err")
    rc="$(cat "${work}/setup.rc")"; out="$(cat "${work}/setup.out")"; err="$(cat "${work}/setup.err")"
}

readSetup --hooks .githooks
assertEquals "1" "${rc}" "hooksPath fehlt: Rückgabe 1"
assertContains "Nicht eingerichtet" "${err}" "hooksPath fehlt: Meldung auf stderr"
assertContains $'\n       make setup' "${err}" "hooksPath fehlt: nächster Schritt in eigener Zeile"
assertEquals "" "${out}" "hooksPath fehlt: nichts auf stdout"
git -C "${setup}" config core.hooksPath .githooks
readSetup --hooks .githooks
assertEquals "0" "${rc}" "hooksPath gesetzt: Rückgabe 0"
assertEquals "" "${err}" "hooksPath gesetzt: keine Meldung"

readSetup --make make .stamp
assertEquals "1" "${rc}" "Stempel fehlt: Rückgabe 1"
assertContains "Nicht eingerichtet" "${err}" "Stempel fehlt: Meldung"
(cd "${setup}" && make -s .stamp)
readSetup --make make .stamp
assertEquals "0" "${rc}" "Stempel aktuell: Rückgabe 0"
sleep 1; touch "${setup}/input"
readSetup --hooks .githooks --make make .stamp
assertEquals "1" "${rc}" "Stempel veraltet: Rückgabe 1, auch wenn hooksPath stimmt"

readSetup .stamp
assertEquals "2" "${rc}" "Stempel ohne --make: Aufruffehler Exit 2"
readSetup
assertEquals "2" "${rc}" "ohne Prüfung: Aufruffehler Exit 2"
# Option ohne Wert am Ende (etwa aus einer leeren Make-Variable): Exit 2, keine Endlosschleife
for option in --hooks --make; do
    readSetup "${option}"
    assertEquals "2" "${rc}" "${option} ohne Wert: Aufruffehler Exit 2"
    assertContains "${option} " "${err}" "${option} ohne Wert: Meldung nennt die Option"
done
readSetup --hooks "" --make make .stamp
assertEquals "2" "${rc}" "--hooks mit leerem Wert: Aufruffehler Exit 2"

echo
echo "make help, info und hints dieses Repos"
echo

plain() { sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g'; }
help="$(make --no-print-directory -C "${ROOT}" help 2>&1 | plain)"
assertContains "  Setup" "${help}" "make help: Gruppe Setup"
assertContains "[Maintainer]" "$(grep -E '^ +tag-patch ' <<< "${help}")" "make help: tag-patch mit [Maintainer]"
assertNotContains "— Maintainer" "${help}" "make help: Endung durch [Maintainer] ersetzt"
assertNotContains "awk" "$(sed -n '/^help:/,/^$/p' "${ROOT}/Makefile")" "Makefile: help ohne awk"
assertNotContains "hint_row" "$(cat "${ROOT}/Makefile")" "Makefile: hints ohne hint_row"
assertNotContains "DEV_MAKE" "$(cat "${ROOT}/Makefile")" "Makefile: ohne MakeLib (DEV_MAKE)"
assertNotContains "clitheme export --make" "$(cat "${ROOT}/Makefile")" "Makefile: kein Theme-Include, die Farben kommen über make.lib.sh"
# Rezept eines Targets aus dem Makefile dieses Repos
recipe() { sed -n "/^${1}:/,/^\$/p" "${ROOT}/Makefile"; }
for target in help info hints; do
    assertNotContains "\\" "$(recipe "${target}")" "Makefile: ${target} ohne \\-Verkettung, eine Rezeptzeile je Ausgabezeile"
done
assertContains "showMakeHeader" "$(recipe help)" "Makefile: help mit showMakeHeader"
assertContains "showMakeTargets" "$(recipe help)" "Makefile: help mit showMakeTargets"
assertNotContains "--set" "$(recipe help)" "Makefile: help ohne --set, die Version füllt showMakeTargets"
assertContains "printMakeValue" "$(recipe info)" "Makefile: info über printMakeValue"
assertContains "printMakeHeading" "$(recipe hints)" "Makefile: hints über printMakeHeading"
assertNotContains "showMakeHints" "$(cat "${ROOT}/Makefile")" "Makefile: ohne showMakeHints"
# BASH_ENV nur für die Anzeige-Targets, als Verweis auf BASH_LIBS: Bash wertet den Wert aus
# shellcheck disable=SC2016  # Make-Text, wörtlich
assertEquals 'help info hints: export BASH_ENV := $${BASH_LIBS}/make.lib.sh' \
    "$(grep -E 'BASH_ENV' "${ROOT}/Makefile" | grep -v '^#')" "Makefile: BASH_ENV nur für help, info und hints, über \${BASH_LIBS}"
for name in showMakeHelp showMakeInfo showMakeHints; do
    rc=0; runMake type "${name}"
    assertEquals "1" "${rc}" "make.lib.sh: ${name} entfernt"
done
# Ohne clitheme im PATH: keine Farben, auch nicht in den Zeilen, die Make selbst ausgibt.
# Die Bash 5 steht vor /bin (macOS: Bash 3.2), sonst bricht cli.lib.sh ab.
nocolor="$(env PATH="$(dirname "$(command -v bash)"):/usr/bin:/bin" make --no-print-directory -C "${ROOT}" help 2>&1)"
assertNotContains "${ESC}" "${nocolor}" "make help ohne clitheme: keine Escape-Folgen"
assertContains "Project:" "${nocolor}" "make help ohne clitheme: läuft"
assertContains "→" "$(grep -E '^ +tag-minor ' <<< "${help}")" "make help: tag-minor mit Versionsvorschau"
# Andere Targets laden make.lib.sh nicht über BASH_ENV
# shellcheck disable=SC2016  # Make-Text, wörtlich
printf 'include %s\nshow-env:\n\t@printf "[%%s]" "$${BASH_ENV-}"\n' "${ROOT}/Makefile" > "${work}/env.mk"
assertEquals "[]" "$(make -s -C "${ROOT}" -f "${work}/env.mk" show-env 2>/dev/null)" "anderes Target: kein BASH_ENV"
info="$(make --no-print-directory -C "${ROOT}" info 2>&1 | plain)"
assertContains "BASH_LIBS              ${ROOT}/src" "${info}" "make info: Zeile BASH_LIBS"
assertContains "VERSION                $(cd "${ROOT}" && BASH_LIBS="${ROOT}/src" bash -c '. src/version.lib.sh; readProjectVersion')" "${info}" "make info: Zeile VERSION"
assertContains "PACKAGE                mmit-bashlib" "${info}" "make info: Zeile PACKAGE"
# Theme einmal je make-Lauf: make info ruft clitheme export --bash einmal auf, nicht je
# Rezeptzeile; ein anderes CLI_THEME gilt beim nächsten Lauf. Der Zähler läuft unter
# /bin/sh: Eine Bash läse über BASH_ENV make.lib.sh und riefe sich selbst auf.
mkdir -p "${work}/count-bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> %q\nexec %q "$@"\n' "${work}/calls" "$(command -v clitheme)" \
    > "${work}/count-bin/clitheme"
chmod +x "${work}/count-bin/clitheme"
for theme in mono classic; do
    : > "${work}/calls"
    info="$(env CLI_THEME="${theme}" PATH="${work}/count-bin:${PATH}" make --no-print-directory -C "${ROOT}" info 2>&1 | plain)"
    assertEquals "1" "$(grep -cx 'export --bash' "${work}/calls")" "make info mit ${theme}: clitheme export einmal je Lauf"
    assertContains "$(printf '%-23s%s' THEME "${theme}")" "${info}" "make info: Zeile THEME zeigt ${theme}"
done
assertContains "requireMakeSetup" "$(sed -n '/^require-setup:/,/^$/p' "${ROOT}/Makefile")" "Makefile: require-setup über requireMakeSetup"
hints="$(make --no-print-directory -C "${ROOT}" hints 2>&1 | plain)"
assertContains "Arbeitskopie" "${hints}" "make hints: Zeile Arbeitskopie"
assertContains "pipx install -e '${ROOT}'" "${hints}" "make hints: Arbeitskopie mit absolutem Pfad"
assertContains "  Links" "${hints}" "make hints: Überschrift Links"
assertContains "export BASH_LIBS=\$(bashlib-path)" "${hints}" "make hints: \$(…) im Wert wörtlich"
first="$(grep -E '^ +1\. Setup ' <<< "${hints}")"
second="$(grep -E '^ +2\. Prüfen ' <<< "${hints}")"
assertEquals "${#first}" "${#second}" "make hints: Umlaut-Beschriftung bündig"

echo
echo "Minimal-Makefile aus dem README in einem Ordner it's \$(uname)"
echo

folder="${work}/it's \$(uname)"
mkdir -p "${folder}"
awk '/^```makefile$/ { block = ""; inside = 1; next } inside && /^```$/ { inside = 0; if (block ~ /showMakeTargets/) print block; next } inside { block = block $0 "\n" }' \
    "${ROOT}/README.md" > "${folder}/Makefile"
assertContains "showMakeTargets" "$(cat "${folder}/Makefile")" "Beispiel aus der Doku gefunden"
rc=0
help="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" make -s -C "${folder}" help 2>"${work}/err")" || rc=$?
assertEquals "0" "${rc}" "Beispiel: make help Exit 0"
assertEquals "" "$(cat "${work}/err")" "Beispiel: make help ohne stderr"
assertContains "Show this help" "${help}" "Beispiel: help über showMakeTargets"
assertContains "Project: it's \$(uname)" "${help}" "Beispiel: Projektname aus dem Ordner, wörtlich"
: > "${work}/calls"
hints="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" PATH="${work}/count-bin:${PATH}" \
    make -s -C "${folder}" hints 2>&1)"
assertEquals "1" "$(grep -cx 'export --bash' "${work}/calls")" "Beispiel: make hints ruft clitheme export einmal auf"
# make -C liefert den physischen Pfad; WORKSPACE_SQ quotet den Apostroph als '\''
physical="$(cd "${folder}" && pwd -P)"
assertContains "pipx install -e '${physical//\'/\'\\\'\'}'" "${hints}" "Beispiel: Pfad mit Apostroph und \$(…) wörtlich"
# BASH_LIBS in einem Ordner mit $(…): BASH_ENV verweist nur auf die Variable, nichts läuft
libs="${work}/libs \$(touch ${work}/ausgefuehrt)"
mkdir -p "${libs}"
cp -R "${ROOT}/src/." "${libs}/"
rc=0
help="$(env XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${libs}" make -s -C "${folder}" help 2>&1)" || rc=$?
assertEquals "0" "${rc}" "Beispiel: BASH_LIBS mit \$(…) im Pfad, make help Exit 0"
assertContains "Show this help" "${help}" "Beispiel: BASH_LIBS mit \$(…) im Pfad, Hilfe da"
created=""
for entry in "${work}"/*; do
    case "${entry##*/}" in config|cache|err|setup|setup.*|project|version.out|count-bin|calls|"it's"*|"libs "*|*.mk|Makefile) ;; *) created+="${entry##*/} " ;; esac
done
assertEquals "" "${created}" "nichts aus dem Pfad ausgeführt"

finishTests
