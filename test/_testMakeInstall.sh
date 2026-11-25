#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testMakeInstall.sh — make install installiert die Arbeitskopie mit pipx
#
# Ruft make install mit einem nachgebauten pipx auf (hält nur die Argumente
# fest), dazu mit scheiterndem und fehlendem pipx. Echte pipx-Installationen
# bleiben unberührt.
#
#   ./test/_testMakeInstall.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"
# Ein umgebendes make (make check) gibt sonst seine Flags weiter
unset MAKEFLAGS MAKELEVEL MFLAGS
# Bash überspringt BASH_ENV, wenn stdin eine Netzverbindung ist und SHLVL unter 2 liegt
# (Erkennung von rshd/sshd). env -i leert SHLVL, und unter einem Agenten ist stdin oft
# ein Socket; dann fänden make info und make hints die Funktionen aus make.lib.sh nicht.
exec < /dev/null

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# Nachgebautes pipx: schreibt seine Argumente zeilenweise, scheitert mit FAKE_FAIL.
mkdir -p "${work}/bin"
cat > "${work}/bin/pipx" <<'EOF'
#!/usr/bin/env bash
# pipx list --short: die installierten Pakete aus FAKE_LIST
if [[ $1 == list ]]; then printf '%s\n' "${FAKE_LIST:-}"; exit 0; fi
printf '%s\n' "$@" > "${FAKE_LOG}"
[[ -z ${FAKE_FAIL:-} ]] || { echo "pipx kaputt"; exit 1; }
echo "  These apps are now available"
EOF
chmod +x "${work}/bin/pipx"

# Ohne ~/.local/bin, damit ein installiertes pipx nicht mitspielt.
# Die Bash 5 steht vor /bin (macOS: Bash 3.2), sonst bricht cli.lib.sh ab.
BASE_PATH="$(dirname "$(command -v bash)"):/usr/bin:/bin:$(dirname "$(command -v make)")"

# Setzt output (ohne Farbcodes) und status. $1 PATH, weitere Argumente: Umgebung für make
runInstall() {
    local path="$1"; shift
    : > "${work}/log"
    output="$(env -i HOME="${work}" PATH="${path}" FAKE_LOG="${work}/log" "$@" \
        make --no-print-directory -C "${ROOT}" install 2>&1)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}

echo
echo "installEditablePackage"
echo

# Setzt output (ohne Farbcodes und Einrückung des Themes) und status. $1 PATH, weitere
# Argumente: Umgebung, dann -- und die Argumente für installEditablePackage (FUNC: andere
# Funktion aus make.lib.sh)
runFunction() {
    local path="$1" func="${FUNC:-installEditablePackage}"; shift
    local -a envs=()
    while [[ $1 != -- ]]; do envs+=("$1"); shift; done
    shift
    : > "${work}/log"
    # shellcheck disable=SC2016  # $@ und BASH_LIBS wertet die innere Shell aus
    output="$(env -i HOME="${work}" PATH="${path}" FAKE_LOG="${work}/log" BASH_LIBS="${ROOT}/src" \
        ${envs[@]+"${envs[@]}"} bash -c '. "${BASH_LIBS}/make.lib.sh" && "$@"' _ "${func}" "$@" 2>&1)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g; s/^ *//')"
}

# Projekt mit eigenen Befehlen: Die Statuszeile liest DIR, nicht den aktuellen Ordner.
project="${work}/mein projekt"
mkdir -p "${project}"
printf '[project]\nname = "demo"\n\n[project.scripts]\ndemo = "demo:main"\ndemo-path = "demo:path"\n' \
    > "${project}/pyproject.toml"

runFunction "${work}/bin:${BASE_PATH}" -- "${project}"
assertEquals "0" "${status}" "Funktion, pipx vorhanden: Exit 0"
assertEquals $'install\n-e\n--force\n'"${project}" "$(cat "${work}/log")" "Funktion: pipx install -e --force DIR"
# Nur die Statuszeile, keine rohe pipx-Ausgabe
assertEquals "✓ demo, demo-path aus ${project}" "${output}" "Funktion: Statuszeile nennt Befehle aus DIR"

mkdir -p "${work}/ohne-befehle"
runFunction "${work}/bin:${BASE_PATH}" -- "${work}/ohne-befehle"
assertEquals "0" "${status}" "Funktion, ohne [project.scripts]: Exit 0"
assertEquals "✓ Paket aus ${work}/ohne-befehle" "${output}" "Funktion, ohne [project.scripts]: Statuszeile"

runFunction "${work}/bin:${BASE_PATH}" FAKE_FAIL=1 -- "${project}"
assertEquals "1" "${status}" "Funktion, pipx scheitert: Exit 1"
assertContains "pipx kaputt" "${output}" "Funktion, pipx scheitert: Ausgabe von pipx"
assertContains "✗ pipx install fehlgeschlagen" "${output}" "Funktion, pipx scheitert: Statuszeile"

runFunction "${BASE_PATH}" -- "${project}"
assertEquals "1" "${status}" "Funktion, pipx fehlt: Exit 1"
assertContains "✗ pipx fehlt" "${output}" "Funktion, pipx fehlt: Meldung"
assertContains "https://pipx.pypa.io" "${output}" "Funktion, pipx fehlt: Installationsweg"
assertEquals "" "$(cat "${work}/log")" "Funktion, pipx fehlt: kein Aufruf"

runFunction "${work}/bin:${BASE_PATH}" --
assertEquals "2" "${status}" "Funktion ohne DIR: Exit 2"
assertContains "installEditablePackage: DIR erwartet" "${output}" "Funktion ohne DIR: Meldung"
assertEquals "" "$(cat "${work}/log")" "Funktion ohne DIR: kein Aufruf"

echo
echo "uninstallPackage"
echo

FUNC=uninstallPackage
runFunction "${work}/bin:${BASE_PATH}" FAKE_LIST="demo 1.0" -- "${project}"
assertEquals "0" "${status}" "Funktion, installiert: Exit 0"
assertEquals $'uninstall\ndemo' "$(cat "${work}/log")" "Funktion: pipx uninstall mit dem Namen aus pyproject.toml"
assertEquals "✓ demo entfernt" "${output}" "Funktion: Statuszeile"

runFunction "${work}/bin:${BASE_PATH}" FAKE_LIST="demo-andere 1.0" -- "${project}"
assertEquals "0" "${status}" "Funktion, nicht installiert: Exit 0"
assertEquals "" "$(cat "${work}/log")" "Funktion, nicht installiert: kein pipx uninstall"
assertEquals "– demo nicht installiert" "${output}" "Funktion, nicht installiert: Statuszeile"

runFunction "${work}/bin:${BASE_PATH}" FAKE_LIST="demo 1.0" FAKE_FAIL=1 -- "${project}"
assertEquals "1" "${status}" "Funktion, pipx scheitert: Exit 1"
assertContains "pipx kaputt" "${output}" "Funktion, pipx scheitert: Ausgabe von pipx"
assertContains "✗ pipx uninstall fehlgeschlagen" "${output}" "Funktion, pipx scheitert: Statuszeile"

runFunction "${work}/bin:${BASE_PATH}" -- "${work}/ohne-befehle"
assertEquals "1" "${status}" "Funktion, ohne Paketname: Exit 1"
assertContains "✗ kein Paketname in ${work}/ohne-befehle/pyproject.toml" "${output}" "Funktion, ohne Paketname: Meldung"

runFunction "${BASE_PATH}" -- "${project}"
assertEquals "1" "${status}" "Funktion, pipx fehlt: Exit 1"
assertContains "✗ pipx fehlt" "${output}" "Funktion, pipx fehlt: Meldung"

runFunction "${work}/bin:${BASE_PATH}" --
assertEquals "2" "${status}" "Funktion ohne DIR: Exit 2"
assertContains "uninstallPackage: DIR erwartet" "${output}" "Funktion ohne DIR: Meldung"
unset FUNC

echo
echo "make install und uninstall"
echo

runInstall "${work}/bin:${BASE_PATH}"
assertEquals "0" "${status}" "pipx vorhanden: Exit 0"
assertEquals $'install\n-e\n--force\n'"${ROOT}" "$(cat "${work}/log")" "pipx install -e --force mit dem Pfad der Arbeitskopie"
assertContains "✓ bashlib, bashlib-path aus ${ROOT}" "${output}" "Statuszeile nennt Befehle und Arbeitskopie"
assertNotContains "These apps" "${output}" "keine rohe pipx-Ausgabe"

runInstall "${work}/bin:${BASE_PATH}" FAKE_FAIL=1
assertEquals "1" "$(( status != 0 ))" "pipx scheitert: Exit ungleich 0"
assertContains "pipx kaputt" "${output}" "pipx scheitert: Ausgabe von pipx sichtbar"
assertContains "✗ pipx install fehlgeschlagen" "${output}" "pipx scheitert: Statuszeile"

runInstall "${BASE_PATH}"
assertEquals "1" "$(( status != 0 ))" "pipx fehlt: Exit ungleich 0"
assertContains "✗ pipx fehlt" "${output}" "pipx fehlt: Meldung"
assertContains "https://pipx.pypa.io" "${output}" "pipx fehlt: Installationsweg"
assertEquals "" "$(cat "${work}/log")" "pipx fehlt: kein Aufruf"

# make uninstall: entfernt das Paket aus pyproject.toml dieser Arbeitskopie
: > "${work}/log"
output="$(env -i HOME="${work}" PATH="${work}/bin:${BASE_PATH}" FAKE_LOG="${work}/log" FAKE_LIST="mmit-bashlib 0.15.0" \
    make --no-print-directory -C "${ROOT}" uninstall 2>&1 | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
assertEquals $'uninstall\nmmit-bashlib' "$(cat "${work}/log")" "make uninstall: pipx uninstall mmit-bashlib"
assertContains "✓ mmit-bashlib entfernt" "${output}" "make uninstall: Statuszeile"

# Ohne den Starter devtools: require-tools nennt seinen Installationsbefehl, info und hints
# laufen ohne rohe Fehler.
runTarget() {
    output="$(env -i HOME="${work}" PATH="${BASE_PATH}" make --no-print-directory -C "${ROOT}" "$1" 2>&1 < /dev/null)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}
conf() { sed -n "s/^$1=//p" "${ROOT}/.dev-tools.conf.sh"; }
runTarget require-tools
assertEquals "1" "$(( status != 0 ))" "require-tools ohne devtools: Exit ungleich 0"
assertContains "✗ devtools fehlt" "${output}" "require-tools ohne devtools: Meldung"
assertContains "pipx install '$(conf DEVTOOLS_SOURCE)@$(conf DEVTOOLS_TAG)'" "${output}" \
    "require-tools ohne devtools: Installationsbefehl mit Quelle und Tag aus .dev-tools.conf.sh"
assertNotContains "command not found" "${output}" "require-tools ohne devtools: keine rohe Shell-Meldung"

# Mit einem devtools, dessen Prüfung scheitert: require-tools ruft einmal make setup auf und
# prüft danach erneut. Die Einrichtung der .venv muss dafür aktuell sein (make setup), sonst
# installierte setup hier über das Netz.
mkdir -p "${work}/devbin"
cat > "${work}/devbin/devtools" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DEVTOOLS_LOG}"
case "$*" in *" check "*) echo "ProjectTools fehlt (Ersatz)"; exit 1 ;; esac
exit 0
EOF
chmod +x "${work}/devbin/devtools"
assertEquals "0" "$(make --no-print-directory -C "${ROOT}" -q .venv/.installed .venv/bin/bashlib >/dev/null 2>&1; echo $?)" \
    "Voraussetzung: Einrichtung aktuell (make setup)"
: > "${work}/devtools.log"
output="$(env -i HOME="${work}" PATH="${work}/devbin:${BASE_PATH}" FAKE_DEVTOOLS_LOG="${work}/devtools.log" \
    make --no-print-directory -C "${ROOT}" require-tools 2>&1 < /dev/null)"
status=$?
assertEquals "1" "$(( status != 0 ))" "require-tools, Prüfung scheitert: Exit ungleich 0"
assertEquals $'--project check projecttools\n--project install\n--project check projecttools' \
    "$(grep -v '^tstamp ' "${work}/devtools.log")" "require-tools: prüfen, einmal make setup, erneut prüfen"
assertContains "ProjectTools fehlt (Ersatz)" "${output}" "require-tools: nennt den Grund von devtools"

runTarget info
assertEquals "nicht abrufbar: devtools fehlt (make hints)" "$(sed -n 's/^ *Werkzeugstand  *//p' <<< "${output}")" \
    "info ohne devtools: Zeile Werkzeugstand mit Hinweis statt fehlender Zeilen"
runTarget hints
assertEquals "0" "${status}" "hints ohne devtools: Exit 0"
assertNotContains "nicht abrufbar" "${output}" "hints ohne devtools: keine Zeile ‚nicht abrufbar‘"
assertContains "pipx install '$(conf DEVTOOLS_SOURCE)@$(conf DEVTOOLS_TAG)'" "${output}" "hints nennt den Starter"

help="$(make --no-print-directory -C "${ROOT}" help 2>&1 | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
assertContains "install" "$(grep -E '^ +install ' <<< "${help}")" "make help nennt install"
# Sichtbare Zeichen, nicht Bytes (Umlaute)
longest="$(python3 -c 'import sys; print(max(len(l) for l in sys.stdin.read().splitlines()))' <<< "${help}")"
assertEquals "1" "$(( longest <= 100 ))" "make help: keine Zeile über 100 Zeichen (längste ${longest})"

finishTests
