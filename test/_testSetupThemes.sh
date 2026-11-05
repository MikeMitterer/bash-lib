#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetupThemes.sh — make setup legt die CLI-Themes mit cli-theme install an
#
# Ruft make setup-themes (Teil von make setup) auf. Ein nachgebautes pipx spielt
# devtools (check clitheme: in Ordnung, zu alt, fehlt), ein nachgebautes
# cli-theme die Installation. setup-themes endet immer mit Exit 0, damit
# make setup ohne cli-theme oder pipx durchläuft.
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

INSTALL_CMD="pipx install --force git+https://github.com/MikeMitterer/python-clitheme.git@v0.4.0"

# Nachgebautes pipx: hält die Argumente fest und antwortet wie devtools check
# (FAKE_CHECK: ok, old, missing).
mkdir -p "${work}/pipx-bin" "${work}/theme-bin"
cat > "${work}/pipx-bin/pipx" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "\${FAKE_PIPX_LOG}"
case "\${FAKE_CHECK:-ok}" in
    ok) exit 0 ;;
    old) echo "  ✗ CLITheme 0.0.1 is too old (requires 0.4.0 or later): ${INSTALL_CMD}" >&2; exit 1 ;;
    missing) echo "  ✗ CLITheme is missing: ${INSTALL_CMD}" >&2; exit 1 ;;
esac
EOF
# Nachgebautes cli-theme: install scheitert mit FAKE_FAIL.
cat > "${work}/theme-bin/cli-theme" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    install) echo install >> "${FAKE_LOG}"; [[ -z ${FAKE_FAIL:-} ]] || { echo "kaputt"; exit 1; } ;;
    path) echo "${XDG_CONFIG_HOME}/cli-theme/classic.theme" ;;
esac
EOF
chmod +x "${work}/pipx-bin/pipx" "${work}/theme-bin/cli-theme"

# Ohne ~/.local/bin, damit installierte Werkzeuge nicht mitspielen.
BASE_PATH="/usr/bin:/bin:$(dirname "$(command -v make)"):$(dirname "$(command -v bash)")"
DEVTOOLS_TAG="$(sed -n 's/^DEVTOOLS_TAG=//p' "${ROOT}/.dev-tools.conf.sh")"

# Setzt output (ohne Farbcodes) und status. $1 PATH, weitere Argumente: Umgebung für make
runSetup() {
    local path="$1"; shift
    : > "${work}/log"
    : > "${work}/pipx"
    output="$(env -i HOME="${work}" PATH="${path}" XDG_CONFIG_HOME="${work}/config" \
        FAKE_LOG="${work}/log" FAKE_PIPX_LOG="${work}/pipx" "$@" \
        make --no-print-directory -C "${ROOT}" setup-themes 2>&1)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}

TOOLS="${work}/pipx-bin:${work}/theme-bin:${BASE_PATH}"

echo
echo "make setup-themes"
echo

runSetup "${TOOLS}" FAKE_CHECK=ok
assertEquals "0" "${status}" "vorhanden: Exit 0"
assertEquals "run --no-path-check --spec git+https://github.com/MikeMitterer/python-devtools.git@${DEVTOOLS_TAG} devtools check clitheme" \
    "$(cat "${work}/pipx")" "vorhanden: devtools prüft clitheme am Tag aus .dev-tools.conf.sh"
assertEquals "install" "$(cat "${work}/log")" "vorhanden: cli-theme install aufgerufen"
assertContains "✓ CLI-Themes in ${work}/config/cli-theme" "${output}" "vorhanden: Statuszeile nennt den Ordner"

runSetup "${TOOLS}" FAKE_CHECK=old
assertEquals "0" "${status}" "zu alt: Exit 0"
assertContains "too old (requires 0.4.0 or later): ${INSTALL_CMD}" "${output}" "zu alt: Meldung von devtools mit Installationsbefehl"
assertEquals "install" "$(cat "${work}/log")" "zu alt: install trotzdem aufgerufen"

runSetup "${TOOLS}" FAKE_CHECK=ok FAKE_FAIL=1
assertEquals "0" "${status}" "install scheitert: Exit 0"
assertContains "kaputt"$'\n'"  ✗ cli-theme install fehlgeschlagen" "${output}" "install scheitert: Ausgabe und Hinweis"

runSetup "${work}/pipx-bin:${BASE_PATH}" FAKE_CHECK=missing
assertEquals "0" "${status}" "fehlt: Exit 0"
assertContains "CLITheme is missing: ${INSTALL_CMD}" "${output}" "fehlt: Meldung von devtools mit Installationsbefehl"
assertEquals "" "$(cat "${work}/log")" "fehlt: kein install"

runSetup "${BASE_PATH}"
assertEquals "0" "${status}" "ohne pipx und cli-theme: Exit 0"
assertEquals "" "$(cat "${work}/log")" "ohne pipx und cli-theme: kein install"
assertContains "✗ pipx fehlt" "${output}" "ohne pipx: Meldung mit Installationsweg"
assertNotContains "command not found" "${output}" "ohne pipx: keine rohe Shell-Meldung"

finishTests
