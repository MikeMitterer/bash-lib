#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetupThemes.sh — make setup legt die CLI-Themes mit clitheme install an
#
# Ruft make setup-themes (Teil von make setup) auf. Ein nachgebautes pipx spielt
# devtools (check clitheme: in Ordnung, zu alt, fehlt); die Themes legt das
# echte clitheme in einem eigenen XDG_CONFIG_HOME an. setup-themes endet immer mit Exit 0, damit
# make setup ohne clitheme oder pipx durchläuft.
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

INSTALL_CMD="pipx install --force git+https://github.com/MikeMitterer/python-clitheme.git@v0.5.0"

# Nachgebautes pipx: hält die Argumente fest und antwortet wie devtools check
# (FAKE_CHECK: ok, old, missing).
mkdir -p "${work}/pipx-bin" "${work}/theme-bin"
cat > "${work}/pipx-bin/pipx" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "\${FAKE_PIPX_LOG}"
case "\${FAKE_CHECK:-ok}" in
    ok) exit 0 ;;
    old) echo "  ✗ CLITheme 0.0.1 is too old (requires 0.5.0 or later): ${INSTALL_CMD}" >&2; exit 1 ;;
    missing) echo "  ✗ CLITheme is missing: ${INSTALL_CMD}" >&2; exit 1 ;;
esac
EOF
# Das echte clitheme, allein in einem eigenen bin; ohne clitheme schlägt der Test fehl.
clitheme="$(command -v clitheme)" || { echo "clitheme fehlt" >&2; exit 1; }
ln -s "${clitheme}" "${work}/theme-bin/clitheme"
chmod +x "${work}/pipx-bin/pipx"

# Ohne ~/.local/bin, damit installierte Werkzeuge nicht mitspielen.
# Die Bash 5 steht vor /bin (macOS: Bash 3.2), sonst bricht cli.lib.sh ab.
BASE_PATH="$(dirname "$(command -v bash)"):/usr/bin:/bin:$(dirname "$(command -v make)")"
DEVTOOLS_TAG="$(sed -n 's/^DEVTOOLS_TAG=//p' "${ROOT}/.dev-tools.conf.sh")"

# Setzt output (ohne Farbcodes) und status. $1 PATH, weitere Argumente: Umgebung für make
runSetup() {
    local path="$1"; shift
    command rm -rf -- "${work}/config"
    : > "${work}/pipx"
    output="$(env -i HOME="${work}" PATH="${path}" XDG_CONFIG_HOME="${work}/config" XDG_CACHE_HOME="${work}/cache" \
        FAKE_PIPX_LOG="${work}/pipx" "$@" \
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
assertEquals "yes" "$([[ -f ${work}/config/clitheme/classic.theme ]] && echo yes)" "vorhanden: clitheme install legt classic an"
assertContains "✓ CLI-Themes in ${work}/config/clitheme" "${output}" "vorhanden: Statuszeile nennt den Ordner"

runSetup "${TOOLS}" FAKE_CHECK=old
assertEquals "0" "${status}" "zu alt: Exit 0"
assertContains "too old (requires 0.5.0 or later): ${INSTALL_CMD}" "${output}" "zu alt: Meldung von devtools mit Installationsbefehl"
assertEquals "yes" "$([[ -f ${work}/config/clitheme/classic.theme ]] && echo yes)" "zu alt: install trotzdem aufgerufen"

runSetup "${work}/pipx-bin:${BASE_PATH}" FAKE_CHECK=missing
assertEquals "0" "${status}" "fehlt: Exit 0"
assertContains "CLITheme is missing: ${INSTALL_CMD}" "${output}" "fehlt: Meldung von devtools mit Installationsbefehl"
assertEquals "no" "$([[ -e ${work}/config/clitheme ]] && echo yes || echo no)" "fehlt: kein install"

runSetup "${BASE_PATH}"
assertEquals "0" "${status}" "ohne pipx und clitheme: Exit 0"
assertEquals "no" "$([[ -e ${work}/config/clitheme ]] && echo yes || echo no)" "ohne pipx und clitheme: kein install"
assertContains "✗ pipx fehlt" "${output}" "ohne pipx: Meldung mit Installationsweg"
assertNotContains "command not found" "${output}" "ohne pipx: keine rohe Shell-Meldung"

# clitheme vorhanden, install scheitert: Ausgabe und Hinweis auf stderr, setup läuft weiter
mkdir -p "${work}/broken-bin"
cat > "${work}/broken-bin/clitheme" <<'EOF'
#!/bin/sh
echo "Theme-Ordner nicht beschreibbar" >&2
exit 1
EOF
chmod +x "${work}/broken-bin/clitheme"
runSetup "${work}/pipx-bin:${work}/broken-bin:${BASE_PATH}" FAKE_CHECK=ok
assertEquals "0" "${status}" "install scheitert: Exit 0"
assertContains "Theme-Ordner nicht beschreibbar" "${output}" "install scheitert: Ausgabe von clitheme"
assertContains "✗ clitheme install fehlgeschlagen" "${output}" "install scheitert: Statuszeile"
assertContains "clitheme show" "${output}" "install scheitert: Hinweis auf clitheme show"

# Die Ablauflogik steckt in installCliThemes (make.lib.sh), nicht im Rezept
recipe="$(sed -n '/^setup-themes:/,/^$/p' "${ROOT}/Makefile")"
assertContains "installCliThemes" "${recipe}" "Rezept ruft installCliThemes auf"
assertNotContains "\\" "${recipe}" "Rezept ohne \\-Verkettung"

finishTests
