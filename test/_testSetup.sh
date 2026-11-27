#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetup.sh — make setup richtet nur den Checkout ein (Git-Hooks, Werkzeuge
# in .tools/ über den Starter devtools); die CLI-Themes des Users legt
# make install mit clitheme install an
#
# Ruft make in einer Kopie mit Makefile, Werkzeug-Tags und src dieses
# Checkouts auf; die .venv gilt dort als eingerichtet (Stempel), damit der Test
# nichts aus dem Paketindex lädt. Nachgebautes devtools und pipx halten ihre
# Argumente fest; die Themes legt das echte clitheme in einem eigenen
# XDG_CONFIG_HOME an.
#
#   ./test/_testSetup.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"
# Ein umgebendes make (make check) gibt sonst seine Flags weiter
unset MAKEFLAGS MAKELEVEL MFLAGS

# Eigene Git-Konfiguration der Nutzer (Signieren, Hooks, Aliase) bleibt draußen
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# Kopie des Checkouts als Git-Repo, .venv als eingerichtet markiert
repo="${work}/repo"
mkdir -p "${repo}/.venv"
cp "${ROOT}/Makefile" "${ROOT}/.dev-tools.conf.sh" "${ROOT}/pyproject.toml" "${repo}/"
ln -s "${ROOT}/src" "${repo}/src"
mkdir "${repo}/.githooks"
# Reihenfolge der Stempel wie nach make setup: Abhängigkeiten, .venv
touch "${repo}/.venv/.dependencies"
touch "${repo}/.venv/.installed"
git init -q "${repo}"

# Nachgebautes devtools (Starter): hält die Argumente fest, scheitert mit FAKE_FAIL; tstamp
# beim Einlesen des Makefiles lässt den Stempel der Abhängigkeiten, wie er ist
mkdir -p "${work}/devtools-bin" "${work}/pipx-bin" "${work}/theme-bin"
cat > "${work}/devtools-bin/devtools" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != tstamp ]] || exit 0
printf '%s\n' "$*" >> "${FAKE_LOG}"
[[ -z ${FAKE_FAIL:-} ]] || { echo "  ✗ ProjectTools nicht installiert" >&2; exit 1; }
EOF
chmod +x "${work}/devtools-bin/devtools"
# Nachgebautes pipx für make install: hält nur die Argumente fest
cat > "${work}/pipx-bin/pipx" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_LOG}"
EOF
chmod +x "${work}/pipx-bin/pipx"
# Das echte clitheme, allein in einem eigenen bin; ohne clitheme schlägt der Test fehl.
clitheme="$(command -v clitheme)" || { echo "clitheme fehlt" >&2; exit 1; }
ln -s "${clitheme}" "${work}/theme-bin/clitheme"

# PATH ohne devtools und clitheme, wo immer sie installiert sind (isolated-path.sh); die Kopie
# hat kein .tools/bin, das make davorstellen könnte.
. "${ROOT}/test/isolated-path.sh"
BASE_PATH="$(isolatedPath "${work}/base-bin" "devtools clitheme" bash git make)" || exit 1
requireMissing "${repo}/.tools/bin:${BASE_PATH}" devtools clitheme
conf() { sed -n "s/^$1=//p" "${ROOT}/.dev-tools.conf.sh"; }
STARTER_CMD="pipx install '$(conf DEVTOOLS_SOURCE)@$(conf DEVTOOLS_TAG)'"

# Setzt output (ohne Farbcodes) und status. $1 Target, $2 PATH, weitere Argumente: Umgebung
runMake() {
    local target="$1" path="$2"; shift 2
    command rm -rf -- "${work}/config"
    : > "${work}/log"
    git -C "${repo}" config --unset core.hooksPath
    output="$(env -i HOME="${work}" PATH="${path}" XDG_CONFIG_HOME="${work}/config" XDG_CACHE_HOME="${work}/cache" \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 FAKE_LOG="${work}/log" "$@" \
        make --no-print-directory -C "${repo}" "${target}" 2>&1 < /dev/null)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}

echo
echo "make setup"
echo

runMake setup "${work}/devtools-bin:${work}/theme-bin:${BASE_PATH}"
assertEquals "0" "${status}" "eingerichtet: Exit 0"
assertEquals ".githooks" "$(git -C "${repo}" config core.hooksPath)" "eingerichtet: Git-Hooks aus .githooks"
assertEquals "--project install" "$(cat "${work}/log")" "eingerichtet: devtools installiert die Werkzeuge nach .tools/"
assertEquals "no" "$([[ -e ${work}/config ]] && echo yes || echo no)" "eingerichtet: nichts im Config-Ordner des Users"

runMake setup "${work}/devtools-bin:${work}/theme-bin:${BASE_PATH}" FAKE_FAIL=1
assertEquals "1" "$(( status != 0 ))" "devtools install scheitert: Exit ungleich 0"
assertContains "ProjectTools nicht installiert" "${output}" "devtools install scheitert: Meldung von devtools"

runMake setup "${work}/theme-bin:${BASE_PATH}"
assertEquals "1" "$(( status != 0 ))" "ohne Starter: Exit ungleich 0"
assertContains "✗ devtools fehlt" "${output}" "ohne Starter: Meldung"
assertContains "${STARTER_CMD}" "${output}" "ohne Starter: pipx install mit Quelle und Tag aus .dev-tools.conf.sh"
assertNotContains "command not found" "${output}" "ohne Starter: keine rohe Shell-Meldung"

echo
echo "make install: CLI-Themes"
echo

runMake install "${work}/pipx-bin:${work}/theme-bin:${BASE_PATH}"
assertEquals "0" "${status}" "install: Exit 0"
assertEquals "yes" "$([[ -f ${work}/config/clitheme/classic.theme ]] && echo yes)" "install: clitheme install legt classic an"
assertContains "✓ CLI-Themes in ${work}/config/clitheme" "${output}" "install: Statuszeile nennt den Ordner"

# clitheme vorhanden, install scheitert: Ausgabe und Hinweis auf stderr, make install endet mit 0
mkdir -p "${work}/broken-bin"
cat > "${work}/broken-bin/clitheme" <<'EOF'
#!/bin/sh
echo "Theme-Ordner nicht beschreibbar" >&2
exit 1
EOF
chmod +x "${work}/broken-bin/clitheme"
runMake install "${work}/pipx-bin:${work}/broken-bin:${BASE_PATH}"
assertEquals "0" "${status}" "clitheme install scheitert: Exit 0"
assertContains "Theme-Ordner nicht beschreibbar" "${output}" "clitheme install scheitert: Ausgabe von clitheme"
assertContains "✗ clitheme install fehlgeschlagen" "${output}" "clitheme install scheitert: Statuszeile"

finishTests
