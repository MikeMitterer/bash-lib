#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetupThemes.sh — make setup legt die CLI-Themes mit cli-theme install an
#
# Ruft make setup-themes (Teil von make setup) mit einem nachgebauten cli-theme
# auf: vorhanden, zu alt, install scheitert, fehlt. setup-themes endet immer mit
# Exit 0, damit make setup ohne cli-theme durchläuft.
#
#   ./test/_testSetupThemes.sh
# ------------------------------------------------------------------------------
# shellcheck disable=SC2319  # check bekommt bewusst den Exit-Code der Bedingung davor
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Ein umgebendes make (make check) gibt sonst seine Flags weiter
unset MAKEFLAGS MAKELEVEL MFLAGS

tests_run=0
tests_failed=0
work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# $1 Exit-Code der Prüfung davor (0 = erfüllt), $2 Beschreibung, $3 Ausgabe für den Fehlerfall
check() {
    tests_run=$((tests_run + 1))
    if [[ $1 == 0 ]]; then
        echo "  ✓ $2"
    else
        tests_failed=$((tests_failed + 1))
        echo "  ✗ $2: $3"
    fi
}

# Nachgebautes cli-theme: Version aus FAKE_VERSION, install scheitert mit FAKE_FAIL.
mkdir -p "${work}/bin"
cat > "${work}/bin/cli-theme" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    --version) echo "cli-theme ${FAKE_VERSION}" ;;
    install) echo install >> "${FAKE_LOG}"; [[ -z ${FAKE_FAIL:-} ]] || { echo "kaputt"; exit 1; } ;;
    path) echo "${XDG_CONFIG_HOME}/cli-theme/classic.theme" ;;
esac
EOF
chmod +x "${work}/bin/cli-theme"

# Ohne ~/.local/bin, damit ein installiertes cli-theme nicht mitspielt.
BASE_PATH="/usr/bin:/bin:$(dirname "$(command -v make)"):$(dirname "$(command -v bash)")"
MIN="$(sed -n 's/^CLITHEME_TAG=v\([0-9.]*\)+.*/\1/p' "${ROOT}/.dev-tools.conf.sh")"

# Setzt output (ohne Farbcodes) und status. $1 PATH, weitere Argumente: Umgebung für make
runSetup() {
    local path="$1"; shift
    : > "${work}/log"
    output="$(env -i HOME="${work}" PATH="${path}" XDG_CONFIG_HOME="${work}/config" \
        FAKE_LOG="${work}/log" "$@" make --no-print-directory -C "${ROOT}" setup-themes 2>&1)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}

echo
echo "make setup-themes"
echo

runSetup "${work}/bin:${BASE_PATH}" FAKE_VERSION="${MIN}"
[[ ${status} == 0 ]]; check $? "vorhanden: Exit 0" "${status}"
[[ $(cat "${work}/log") == install ]]; check $? "vorhanden: cli-theme install aufgerufen" "$(cat "${work}/log")"
[[ ${output} == *"✓ CLI-Themes in ${work}/config/cli-theme"* ]]; check $? "vorhanden: Statuszeile nennt den Ordner" "${output}"

runSetup "${work}/bin:${BASE_PATH}" FAKE_VERSION=0.0.1
[[ ${status} == 0 ]]; check $? "zu alt: Exit 0" "${status}"
[[ ${output} == *"0.0.1 ist zu alt"*"pipx install --force"* ]]; check $? "zu alt: Hinweis mit pipx-Befehl" "${output}"
[[ $(cat "${work}/log") == install ]]; check $? "zu alt: install trotzdem aufgerufen" "$(cat "${work}/log")"

runSetup "${work}/bin:${BASE_PATH}" FAKE_VERSION="${MIN}" FAKE_FAIL=1
[[ ${status} == 0 ]]; check $? "install scheitert: Exit 0" "${status}"
[[ ${output} == *kaputt*"cli-theme install fehlgeschlagen"* ]]; check $? "install scheitert: Ausgabe und Hinweis" "${output}"

runSetup "${BASE_PATH}"
[[ ${status} == 0 ]]; check $? "fehlt: Exit 0" "${status}"
[[ ${output} == *"CLITheme fehlt"*"python-clitheme.git@v${MIN}+"* ]]; check $? "fehlt: Hinweis mit pipx-Befehl" "${output}"
[[ ! -s ${work}/log ]]; check $? "fehlt: kein install" "$(cat "${work}/log")"

echo
if (( tests_failed == 0 )); then
    echo "  ${tests_run} Tests, alle gruen"
else
    echo "  ${tests_failed} von ${tests_run} Tests fehlgeschlagen"
    exit 1
fi
