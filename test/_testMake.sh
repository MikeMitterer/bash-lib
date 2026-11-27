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
# showMakeHeader folgt der Sprache; englisch fest, die deutschen Fälle setzen sie je Aufruf
unset LANGUAGE LC_ALL LC_MESSAGES
export LANG=en_US.UTF-8

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
       tag-major              Major-Release 1.4.9 → 2.0.0 — Maintainer
       tag-minor              Minor-Release x.y.z → x.Y+1.0, {unknown} bleibt

"
assertEquals "${expected}" "${out}" \
    "Gruppen, Spalten nach W_KEY und GAP, langes Target auf eigener Zeile, — Maintainer als Text ohne Markierung, --set vor der Version, ohne Versionsdatei Ersatz, Leerzeile am Ende"
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

# Server-Targets: ##R schreibend, ##D destruktiv; Platzhalter und Text wie bei ##
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
       server-DANGER-restore  Backup einspielen — Maintainer
       local                  Lokal

"
assertEquals "${expected}" "${out}" "##R und ##D wie ##: Platzhalter, Text unverändert, ohne Farben schlicht"
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
# Die Kennzeichnung „— Maintainer“ ist abgeschafft (T-78): der Text bleibt, wie er dasteht
assertContains "2.0.0 — Maintainer" "$(sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g' <<< "${out}")" "im Terminal: — Maintainer als Text"
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
LANG=de_AT.UTF-8 runMake showMakeHeader "demo"
assertEquals $'\nVerwende `make <target>\', wobei <target> eines der folgenden ist\n\nProjekt: demo\n' "${out}" \
    "LANG=de_AT.UTF-8: beide Kopfzeilen deutsch"
LANG=C LC_MESSAGES=de_DE.UTF-8 runMake showMakeHeader "${hostile}"
assertContains "Projekt: ${hostile}" "${out}" "LC_MESSAGES=de_DE.UTF-8 vor LANG=C: deutsch, Name wörtlich"
LANG=de_AT.UTF-8 LANGUAGE=en runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "LANGUAGE=en vor LANG=de_AT.UTF-8: englisch"
LANG=de_AT.UTF-8 LC_ALL=C runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "LC_ALL=C vor LANG=de_AT.UTF-8: englisch"
LANG=C LANGUAGE=de runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "LANGUAGE=de bei LANG=C: englisch, wie gettext"
# Ohne Sprachvariablen gilt unter macOS die erste Systemsprache (defaults read -g
# AppleLanguages). Nachbauten von defaults unter /bin/sh (L-220); jeder Aufruf zählt.
for lang in de en fail; do
    mkdir -p "${work}/defaults-${lang}"
    { printf '#!/bin/sh\necho "$*" >> %q\n' "${work}/defaults-calls"
      case ${lang} in
          de)   printf 'cat <<EOF\n(\n    "de-AT",\n    de,\n    en\n)\nEOF\n' ;;
          en)   printf 'cat <<EOF\n(\n    "en-US",\n    de\n)\nEOF\n' ;;
          fail) printf 'echo "Domain does not exist" >&2\nexit 1\n' ;;
      esac
    } > "${work}/defaults-${lang}/defaults"
    chmod +x "${work}/defaults-${lang}/defaults"
done
: > "${work}/defaults-calls"
LANG='' PATH="${work}/defaults-de:${PATH}" runMake showMakeHeader "demo"
assertContains "Projekt: demo" "${out}" "ohne Sprache, Systemsprache de-AT: deutsch"
assertEquals "read -g AppleLanguages" "$(cat "${work}/defaults-calls")" "ohne Sprache: defaults read -g AppleLanguages einmal"
LANG='' PATH="${work}/defaults-en:${PATH}" runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "ohne Sprache, Systemsprache en-US: englisch"
LANG='' PATH="${work}/defaults-fail:${PATH}" runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "ohne Sprache, defaults scheitert: englisch"
assertEquals "" "${err}" "ohne Sprache, defaults scheitert: nichts auf stderr"
: > "${work}/defaults-calls"
LANG=en_US.UTF-8 PATH="${work}/defaults-de:${PATH}" runMake showMakeHeader "demo"
assertContains "Project: demo" "${out}" "LANG=en_US.UTF-8 bei Systemsprache de-AT: englisch"
assertEquals "" "$(cat "${work}/defaults-calls")" "mit LANG: defaults nicht aufgerufen"
LANG=de_AT.UTF-8 runInTerminal showMakeHeader "demo"
assertContains "Projekt: ${ESC}[1;38;5;11mdemo${ESC}[0m" "${out}" "Terminal deutsch: Projektname in der Gruppenfarbe"

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

# Wegwerf-Repo: setup legt .stamp an, setzt core.hooksPath und zählt seine Läufe in
# setup.count. SETUP_FAIL lässt setup scheitern, SETUP_SKIP lässt den Stempel aus.
setup="${work}/setup"
mkdir -p "${setup}"
git init -q "${setup}"
printf '%s\n' \
    '.stamp: input' \
    $'\t@test -n "$${SETUP_SKIP:-}" || touch .stamp' \
    'setup: .stamp' \
    $'\t@echo lief >> setup.count' \
    $'\t@test -z "$${SETUP_FAIL:-}"' \
    $'\t@git config core.hooksPath .githooks' > "${setup}/Makefile"
touch "${setup}/input"
# Setzt rc, out und err für requireMakeSetup "$@", aufgerufen im Wegwerf-Repo
readSetup() {
    (cd "${setup}" && runMake requireMakeSetup "$@"
     printf '%s' "${rc}" > "${work}/setup.rc"; printf '%s' "${out}" > "${work}/setup.out"
     printf '%s' "${err}" > "${work}/setup.err")
    rc="$(cat "${work}/setup.rc")"; out="$(cat "${work}/setup.out")"; err="$(cat "${work}/setup.err")"
}
# Anzahl der setup-Läufe seit dem letzten Aufruf; leert danach den Zähler
setupRuns() {
    touch "${setup}/setup.count"
    wc -l < "${setup}/setup.count" | tr -d ' '
    : > "${setup}/setup.count"
}

readSetup --hooks .githooks --make make .stamp
assertEquals "0" "${rc}" "nicht eingerichtet: make setup läuft, Rückgabe 0"
assertEquals "1" "$(setupRuns)" "nicht eingerichtet: genau ein make setup"
assertContains "Nicht eingerichtet oder veraltet, make setup läuft" "${err}" "nicht eingerichtet: Meldung auf stderr"
assertEquals ".githooks" "$(git -C "${setup}" config core.hooksPath)" "nach make setup: core.hooksPath gesetzt"
assertEquals "yes" "$([[ -e ${setup}/.stamp ]] && echo yes || echo no)" "nach make setup: Stempel da"

readSetup --hooks .githooks --make make .stamp
assertEquals "0" "${rc}" "eingerichtet: Rückgabe 0"
assertEquals "0" "$(setupRuns)" "eingerichtet: kein make setup"
assertEquals "" "${err}" "eingerichtet: keine Meldung"

sleep 1; touch "${setup}/input"
readSetup --make make .stamp
assertEquals "0" "${rc}" "Stempel veraltet: Rückgabe 0 nach make setup"
assertEquals "1" "$(setupRuns)" "Stempel veraltet: genau ein make setup"

git -C "${setup}" config --unset core.hooksPath
export SETUP_FAIL=1
readSetup --hooks .githooks --make make
unset SETUP_FAIL
assertEquals "1" "${rc}" "make setup scheitert: Rückgabe 1"
assertContains "make setup gescheitert" "${err}" "make setup scheitert: Meldung"
setupRuns >/dev/null

sleep 1; touch "${setup}/input"
export SETUP_SKIP=1
readSetup --hooks .githooks --make make .stamp
unset SETUP_SKIP
assertEquals "1" "${rc}" "Stempel fehlt nach make setup: Rückgabe 1"
assertContains "Nach make setup weiter nicht eingerichtet: core.hooksPath .githooks .stamp" "${err}" \
    "Stempel fehlt nach make setup: nennt Prüfungen"
setupRuns >/dev/null

readSetup .stamp
assertEquals "2" "${rc}" "ohne --make: Aufruffehler Exit 2"
assertEquals "0" "$(setupRuns)" "ohne --make: kein make setup"
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
# Die Kennzeichnung „— Maintainer“ ist abgeschafft (T-78): die echte Hilfe trägt sie nicht mehr
assertNotContains "— Maintainer" "${help}" "make help: keine Endung — Maintainer"
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
# Ohne clitheme: keine Farben, auch nicht in den Zeilen, die Make selbst ausgibt. In einer
# Kopie ohne .tools/ (dort legt make setup clitheme ab, und das Makefile stellt es vor den
# PATH), mit einem PATH ohne clitheme (isolated-path.sh); make kommt aus /usr/bin.
. "${ROOT}/test/isolated-path.sh"
noThemeRepo="${work}/no-theme-repo"
mkdir -p "${noThemeRepo}"
cp "${ROOT}/Makefile" "${ROOT}/.dev-tools.conf.sh" "${ROOT}/pyproject.toml" "${noThemeRepo}/"
ln -s "${ROOT}/src" "${noThemeRepo}/src"
noThemePath="$(isolatedPath "${work}/no-theme-bin" clitheme bash)" || exit 1
requireMissing "${noThemeRepo}/.tools/bin:${noThemePath}" clitheme
nocolor="$(env PATH="${noThemePath}" make --no-print-directory -C "${noThemeRepo}" help 2>&1)"
assertNotContains "${ESC}" "${nocolor}" "make help ohne clitheme: keine Escape-Folgen"
assertContains "Project:" "${nocolor}" "make help ohne clitheme: läuft"
assertContains "→" "$(grep -E '^ +tag-minor ' <<< "${help}")" "make help: tag-minor mit Versionsvorschau"
# Andere Targets laden make.lib.sh nicht über BASH_ENV
# shellcheck disable=SC2016  # Make-Text, wörtlich
printf 'include %s\nshow-env:\n\t@printf "[%%s]" "$${BASH_ENV-}"\n' "${ROOT}/Makefile" > "${work}/env.mk"
assertEquals "[]" "$(make -s -C "${ROOT}" -f "${work}/env.mk" show-env 2>/dev/null)" "anderes Target: kein BASH_ENV"
# PYTHON aus der Umgebung (make test-package) erreicht die Rezepte unverändert; make build
# nimmt trotzdem das Python der .venv
# shellcheck disable=SC2016  # Make-Text, wörtlich
printf 'include %s\nshow-python:\n\t@printf "[%%s]" "$${PYTHON-}"\n' "${ROOT}/Makefile" > "${work}/python.mk"
assertEquals "[${work}/py/python3]" "$(PYTHON="${work}/py/python3" make -s -C "${ROOT}" -f "${work}/python.mk" show-python 2>/dev/null)" \
    "PYTHON aus der Umgebung: im Rezept unverändert"
build="$(PYTHON="${work}/py/python3" make -n --no-print-directory -C "${ROOT}" build 2>/dev/null)"
assertContains ".venv/bin/python -m build" "${build}" "PYTHON aus der Umgebung: make build nimmt das Python der .venv"
assertNotContains "${work}/py/python3" "${build}" "PYTHON aus der Umgebung: make build nimmt es nicht"
info="$(make --no-print-directory -C "${ROOT}" info 2>&1 | plain)"
assertContains "BASH_LIBS              ${ROOT}/src" "${info}" "make info: Zeile BASH_LIBS"
assertContains "VERSION                $(cd "${ROOT}" && BASH_LIBS="${ROOT}/src" bash -c '. src/version.lib.sh; readProjectVersion')" "${info}" "make info: Zeile VERSION"
assertContains "PACKAGE                mmit-bashlib" "${info}" "make info: Zeile PACKAGE"
# Theme einmal je make-Lauf, nicht je Rezeptzeile: make info (11 Zeilen) ruft clitheme
# export --bash höchstens zweimal auf (Make ab 4.4 lädt BASH_ENV auch in $(shell) des
# Merkers); ein anderes CLI_THEME gilt beim nächsten Lauf. Der Zähler läuft unter
# /bin/sh: Eine Bash läse über BASH_ENV make.lib.sh und riefe sich selbst auf. Das Makefile
# stellt .tools/bin des Checkouts vor den PATH; der Zähler liegt darum in .tools/bin einer
# Kopie mit Makefile, Werkzeug-Tags, pyproject.toml und src dieses Checkouts.
counted="${work}/counted"
mkdir -p "${counted}/.tools/bin"
cp "${ROOT}/Makefile" "${ROOT}/.dev-tools.conf.sh" "${ROOT}/pyproject.toml" "${counted}/"
ln -s "${ROOT}/src" "${counted}/src"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> %q\nexec %q "$@"\n' "${work}/calls" "$(command -v clitheme)" \
    > "${counted}/.tools/bin/clitheme"
chmod +x "${counted}/.tools/bin/clitheme"
# Für das README-Beispiel ohne .tools/: derselbe Zähler über PATH
ln -s "${counted}/.tools/bin" "${work}/count-bin"
for theme in mono classic; do
    : > "${work}/calls"
    info="$(env CLI_THEME="${theme}" make --no-print-directory -C "${counted}" info 2>&1 | plain)"
    calls="$(grep -cx 'export --bash' "${work}/calls")"
    assertEquals "ja" "$( (( calls >= 1 && calls <= 2 )) && echo ja || echo "nein: ${calls}")" \
        "make info mit ${theme}: clitheme export einmal je Lauf, nicht je Zeile"
    assertContains "$(printf '%-23s%s' THEME "${theme}")" "${info}" "make info: Zeile THEME zeigt ${theme}"
done
assertContains "requireMakeSetup" "$(sed -n '/^require-setup:/,/^$/p' "${ROOT}/Makefile")" "Makefile: require-setup über requireMakeSetup"
# precheck meldet ein fehlendes BASH_LIBS auf stderr, stdout bleibt leer
rc=0
stdout="$(make --no-print-directory -C "${ROOT}" precheck BASH_LIBS="${work}/nirgends" 2>"${work}/precheck.err")" || rc=$?
assertEquals "2" "${rc}" "make precheck ohne BashLib: Exit 2 (Make-Fehler)"
assertEquals "" "${stdout}" "make precheck ohne BashLib: stdout leer"
assertContains "BASH_LIBS" "$(cat "${work}/precheck.err")" "make precheck ohne BashLib: Meldung auf stderr"
hints="$(make --no-print-directory -C "${ROOT}" hints 2>&1 | plain)"
assertContains "Arbeitskopie" "${hints}" "make hints: Zeile Arbeitskopie"
assertContains "pipx install -e '${ROOT}'" "${hints}" "make hints: Arbeitskopie mit absolutem Pfad"
assertContains "  Links" "${hints}" "make hints: Überschrift Links"
assertContains "export BASH_LIBS=\$(bashlib-path)" "${hints}" "make hints: \$(…) im Wert wörtlich"
first="$(grep -E '^ +1\. Setup ' <<< "${hints}")"
second="$(grep -E '^ +2\. Prüfen ' <<< "${hints}")"
assertEquals "${#first}" "${#second}" "make hints: Umlaut-Beschriftung bündig"

# Das Makefile dieses Repos in einem Ordner mit $(…) im Namen: Der Checkout-Pfad wird
# weder Make- noch Shell-Code, auch nicht in den erst bei Bedarf gelesenen PACKAGE_*.
hostile_dir="${work}/x\$(shell touch pwned) \$(uname)"
mkdir -p "${hostile_dir}"
( cd "${ROOT}" && git ls-files -z | tar --null -T - -cf - ) | tar -xf - -C "${hostile_dir}"
info="$(env XDG_CONFIG_HOME="${work}/config" make --no-print-directory -C "${hostile_dir}" info 2>&1 | plain)"
assertEquals "" "$(ls -d "${hostile_dir}/pwned" "${work}/pwned" 2>/dev/null)" "Ordner mit \$(shell touch …): nichts ausgeführt"
assertContains "PACKAGE                mmit-bashlib" "${info}" "Ordner mit \$(…): PACKAGE aus pyproject.toml gelesen"
hints="$(env XDG_CONFIG_HOME="${work}/config" make --no-print-directory -C "${hostile_dir}" hints 2>&1 | plain)"
assertContains "mmit-bashlib (Befehl bashlib)" "${hints}" "Ordner mit \$(…): make hints nennt Paket und Befehl"
assertEquals "" "$(ls -d "${hostile_dir}/pwned" "${work}/pwned" 2>/dev/null)" "Ordner mit \$(shell touch …): auch make hints führt nichts aus"

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
calls="$(grep -cx 'export --bash' "${work}/calls")"
assertEquals "ja" "$( (( calls >= 1 && calls <= 2 )) && echo ja || echo "nein: ${calls}")" \
    "Beispiel: make hints ruft clitheme export einmal je Lauf auf, nicht je Zeile"
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
    case "${entry##*/}" in config|cache|err|setup|setup.*|project|version.out|count-bin|no-theme-bin|no-theme-repo|counted|calls|defaults-*|precheck.err|"it's"*|"libs "*|"x\$(shell"*|*.mk|Makefile) ;; *) created+="${entry##*/} " ;; esac
done
assertEquals "" "${created}" "nichts aus dem Pfad ausgeführt"

finishTests
