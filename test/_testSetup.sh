#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetup.sh — make setup richtet den Checkout ein: Git-Hooks, Werkzeuge in
# .tools/ über den Starter devtools, CLI-Themes mit clitheme install
#
# Ruft make setup in einer Kopie mit Makefile, Werkzeug-Tags und src dieses
# Checkouts auf; die .venv gilt dort als eingerichtet (Stempel), damit der Test
# nichts aus dem Paketindex lädt. Ein nachgebautes devtools hält seine
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
touch "${repo}/.venv/.installed"
git init -q "${repo}"

# Nachgebautes devtools (Starter): hält die Argumente fest, scheitert mit FAKE_FAIL
mkdir -p "${work}/devtools-bin" "${work}/theme-bin"
cat > "${work}/devtools-bin/devtools" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_LOG}"
[[ -z ${FAKE_FAIL:-} ]] || { echo "  ✗ ProjectTools nicht installiert" >&2; exit 1; }
EOF
chmod +x "${work}/devtools-bin/devtools"
# Das echte clitheme, allein in einem eigenen bin; ohne clitheme schlägt der Test fehl.
clitheme="$(command -v clitheme)" || { echo "clitheme fehlt" >&2; exit 1; }
ln -s "${clitheme}" "${work}/theme-bin/clitheme"

# Ohne ~/.local/bin, damit installierte Werkzeuge nicht mitspielen.
# Die Bash 5 steht vor /bin (macOS: Bash 3.2), sonst bricht cli.lib.sh ab.
BASE_PATH="$(dirname "$(command -v bash)"):$(dirname "$(command -v git)"):/usr/bin:/bin:$(dirname "$(command -v make)")"
conf() { sed -n "s/^$1=//p" "${ROOT}/.dev-tools.conf.sh"; }
STARTER_CMD="pipx install '$(conf DEVTOOLS_SOURCE)@$(conf DEVTOOLS_TAG)'"

# Setzt output (ohne Farbcodes) und status. $1 PATH, weitere Argumente: Umgebung für make
runSetup() {
    local path="$1"; shift
    command rm -rf -- "${work}/config"
    : > "${work}/log"
    git -C "${repo}" config --unset core.hooksPath
    output="$(env -i HOME="${work}" PATH="${path}" XDG_CONFIG_HOME="${work}/config" XDG_CACHE_HOME="${work}/cache" \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 FAKE_LOG="${work}/log" "$@" \
        make --no-print-directory -C "${repo}" setup 2>&1 < /dev/null)"
    status=$?
    output="$(printf '%s' "${output}" | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')"
}

echo
echo "make setup"
echo

runSetup "${work}/devtools-bin:${work}/theme-bin:${BASE_PATH}"
assertEquals "0" "${status}" "eingerichtet: Exit 0"
assertEquals ".githooks" "$(git -C "${repo}" config core.hooksPath)" "eingerichtet: Git-Hooks aus .githooks"
assertEquals "--project install" "$(cat "${work}/log")" "eingerichtet: devtools installiert die Werkzeuge nach .tools/"
assertEquals "yes" "$([[ -f ${work}/config/clitheme/classic.theme ]] && echo yes)" "eingerichtet: clitheme install legt classic an"
assertContains "✓ CLI-Themes in ${work}/config/clitheme" "${output}" "eingerichtet: Statuszeile nennt den Ordner"

runSetup "${work}/devtools-bin:${work}/theme-bin:${BASE_PATH}" FAKE_FAIL=1
assertEquals "1" "$(( status != 0 ))" "devtools install scheitert: Exit ungleich 0"
assertContains "ProjectTools nicht installiert" "${output}" "devtools install scheitert: Meldung von devtools"

runSetup "${work}/theme-bin:${BASE_PATH}"
assertEquals "1" "$(( status != 0 ))" "ohne Starter: Exit ungleich 0"
assertContains "✗ devtools fehlt" "${output}" "ohne Starter: Meldung"
assertContains "${STARTER_CMD}" "${output}" "ohne Starter: pipx install mit Quelle und Tag aus .dev-tools.conf.sh"
assertNotContains "command not found" "${output}" "ohne Starter: keine rohe Shell-Meldung"

# clitheme vorhanden, install scheitert: Ausgabe und Hinweis auf stderr, setup läuft weiter
mkdir -p "${work}/broken-bin"
cat > "${work}/broken-bin/clitheme" <<'EOF'
#!/bin/sh
echo "Theme-Ordner nicht beschreibbar" >&2
exit 1
EOF
chmod +x "${work}/broken-bin/clitheme"
runSetup "${work}/devtools-bin:${work}/broken-bin:${BASE_PATH}"
assertEquals "0" "${status}" "clitheme install scheitert: Exit 0"
assertContains "Theme-Ordner nicht beschreibbar" "${output}" "clitheme install scheitert: Ausgabe von clitheme"
assertContains "✗ clitheme install fehlgeschlagen" "${output}" "clitheme install scheitert: Statuszeile"

finishTests
