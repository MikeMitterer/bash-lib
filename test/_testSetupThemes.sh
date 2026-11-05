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
assertEquals "0" "${status}" "vorhanden: Exit 0"
assertEquals "install" "$(cat "${work}/log")" "vorhanden: cli-theme install aufgerufen"
assertContains "✓ CLI-Themes in ${work}/config/cli-theme" "${output}" "vorhanden: Statuszeile nennt den Ordner"

runSetup "${work}/bin:${BASE_PATH}" FAKE_VERSION=0.0.1
assertEquals "0" "${status}" "zu alt: Exit 0"
assertContains "0.0.1 ist zu alt (verlangt ab ${MIN}): pipx install --force" "${output}" "zu alt: Hinweis mit pipx-Befehl"
assertEquals "install" "$(cat "${work}/log")" "zu alt: install trotzdem aufgerufen"

runSetup "${work}/bin:${BASE_PATH}" FAKE_VERSION="${MIN}" FAKE_FAIL=1
assertEquals "0" "${status}" "install scheitert: Exit 0"
assertContains "kaputt"$'\n'"  ✗ cli-theme install fehlgeschlagen" "${output}" "install scheitert: Ausgabe und Hinweis"

runSetup "${BASE_PATH}"
assertEquals "0" "${status}" "fehlt: Exit 0"
assertContains "CLITheme fehlt, Ausgabe ohne Farben: pipx install --force 'git+https://github.com/MikeMitterer/python-clitheme.git@v${MIN}+" "${output}" "fehlt: Hinweis mit pipx-Befehl"
assertEquals "" "$(cat "${work}/log")" "fehlt: kein install"

finishTests
