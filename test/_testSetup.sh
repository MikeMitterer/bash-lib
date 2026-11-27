#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testSetup.sh — make setup richtet nur den Checkout ein (Git-Hooks, Werkzeuge
# in .tools/ über den Starter devtools); die CLI-Themes des Users legt
# make install mit clitheme install an
#
# Ruft make in einer Kopie mit Makefile, Werkzeug-Tags und src dieses
# Checkouts auf; die .venv gilt dort als eingerichtet (Stempel), damit der Test
# nichts aus dem Paketindex lädt. Eine tote, fehlende oder verlinkte .venv baut
# make mit GNU Make und /usr/bin/make über ein nachgebautes Python neu
# (rm -rf .venv, dann venv).
# Nachgebautes devtools, pipx und Python halten ihre Argumente fest; die Themes
# legt das echte clitheme in einem eigenen XDG_CONFIG_HOME an.
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

# Nachgebautes Python für die .venv: -m venv ORDNER legt bin/python an, wie das echte venv auch
# hinter einem Link; scheitert mit FAKE_VENV_FAIL. bin/python startet (-c ''), pip install hält
# nur die Argumente fest, statt den Paketindex zu fragen.
mkdir -p "${work}/py-bin"
cat > "${work}/py-bin/venv-python" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != -c ]] || exit 0
printf 'venv-python %s\n' "$*" >> "${FAKE_LOG}"
EOF
cat > "${work}/py-bin/python3" <<EOF
#!/usr/bin/env bash
printf 'bootstrap %s\n' "\$*" >> "\${FAKE_LOG}"
[[ -z \${FAKE_VENV_FAIL:-} ]] || { echo "venv gescheitert" >&2; exit 1; }
dir="\${*: -1}"
mkdir -p "\${dir}/bin"
cp "${work}/py-bin/venv-python" "\${dir}/bin/python"
EOF
chmod +x "${work}/py-bin/venv-python" "${work}/py-bin/python3"

# Eingerichtete .venv wie nach make setup: bin/python, dann die Stempel (Abhängigkeiten, .venv)
setUpVenv() {
    mkdir -p "$1/bin"
    cp "${work}/py-bin/venv-python" "$1/bin/python"
    touch -t 202601010000 "$1/bin/python"
    touch "$1/.dependencies"
    touch "$1/.installed"
}

# Kopie des Checkouts als Git-Repo, .venv als eingerichtet markiert
repo="${work}/repo"
mkdir -p "${repo}"
cp "${ROOT}/Makefile" "${ROOT}/.dev-tools.conf.sh" "${ROOT}/pyproject.toml" "${repo}/"
ln -s "${ROOT}/src" "${repo}/src"
mkdir "${repo}/.githooks"
setUpVenv "${repo}/.venv"
git init -q "${repo}"

# Nachgebautes devtools (Starter): hält die Argumente fest, scheitert mit FAKE_FAIL; tstamp legt
# den Stempel der Abhängigkeiten nur an, wenn er fehlt, wie das echte bei gleichen Abhängigkeiten
mkdir -p "${work}/devtools-bin" "${work}/pipx-bin" "${work}/theme-bin"
cat > "${work}/devtools-bin/devtools" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == tstamp ]]; then
    [[ -e $2 ]] || { mkdir -p "$(dirname "$2")" && : > "$2"; }
    exit
fi
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
        "${MAKE_BIN:-make}" --no-print-directory -C "${repo}" "${target}" 2>&1 < /dev/null)"
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
echo "make setup: tote .venv"
echo

SETUP_PATH="${work}/devtools-bin:${work}/theme-bin:${BASE_PATH}"
venv="${repo}/.venv"
# Ziel einer verlinkten .venv, außerhalb des Checkouts
linked="${work}/linked-venv"

# Zustand vor dem Lauf: $1 dead (bin/python zeigt ins Leere) oder missing (bin/python fehlt), die
# Stempel jeweils aktuell; link: .venv ist ein Link auf eine venv mit startendem Python, deren
# Einrichtung veraltet ist (neue Abhängigkeit), sodass setup dort Pakete installieren würde
prepareVenv() {
    command rm -rf -- "${venv}" "${linked}"
    case "$1" in
        dead)    setUpVenv "${venv}"; ln -sf "${work}/entfernt/python3.14" "${venv}/bin/python" ;;
        missing) setUpVenv "${venv}"; command rm -f -- "${venv}/bin/python" ;;
        link)    setUpVenv "${linked}"; ln -s "${linked}" "${venv}"
                 # Alles im Ziel alt, die Einrichtung veraltet (.installed vor .dependencies);
                 # die Marke liegt danach: Was der Lauf im Ziel schreibt, ist neuer als sie
                 find "${linked}" -exec touch -h -t 202601010000 {} +
                 touch -t 202601020000 "${linked}/.installed"
                 touch -t 202601030000 "${linked}/.dependencies"
                 touch -t 202601040000 "${work}/linked-mark" ;;
    esac
}
# Einträge im Ziel des Links und, was der Lauf dort geschrieben hat (find -newer, auf macOS und
# Linux); setzen entries und changed. Scheitert die Erfassung, scheitert der Test.
linkedState() {
    local rc=0
    entries="$(cd "${linked}" && find . | LC_ALL=C sort)" || rc=$?
    changed="$(find "${linked}" -newer "${work}/linked-mark")" || rc=$?
    assertEquals "0" "${rc}" "${label}: Ziel des Links erfasst"
}
isUpToDate() { "${MAKE_BIN}" --no-print-directory -C "${repo}" --question .venv/.installed \
    && echo yes || echo no; }

for MAKE_BIN in make /usr/bin/make; do
    for kind in dead missing; do
        for target in setup require-setup; do
            label="${MAKE_BIN}, ${kind}, ${target}"
            prepareVenv "${kind}"
            runMake "${target}" "${SETUP_PATH}" PYTHON_BOOTSTRAP="${work}/py-bin/python3"
            assertEquals "0" "${status}" "${label}: Exit 0"
            assertContains "bootstrap -m venv .venv" "$(cat "${work}/log")" "${label}: .venv mit venv neu"
            assertContains "venv-python -m pip install" "$(cat "${work}/log")" "${label}: Pakete installiert"
            runMake "${target}" "${SETUP_PATH}" PYTHON_BOOTSTRAP="${work}/py-bin/python3"
            assertNotContains "bootstrap" "$(cat "${work}/log")" "${label}, zweiter Aufruf: keine neue .venv"
            assertNotContains "pip install" "$(cat "${work}/log")" "${label}, zweiter Aufruf: keine Installation"
            assertEquals "yes" "$(isUpToDate)" "${label}: danach aktuell (make --question)"
        done
    done

    label="${MAKE_BIN}, venv scheitert"
    prepareVenv dead
    runMake setup "${SETUP_PATH}" PYTHON_BOOTSTRAP="${work}/py-bin/python3" FAKE_VENV_FAIL=1
    assertEquals "1" "$(( status != 0 ))" "${label}: Exit ungleich 0"
    assertContains "venv gescheitert" "${output}" "${label}: Meldung von venv"
    assertNotContains "pip install" "$(cat "${work}/log")" "${label}: keine Paketinstallation"
    assertEquals "no" "$([[ -e ${venv}/.installed ]] && echo yes || echo no)" "${label}: kein Stempel"

    label="${MAKE_BIN}, .venv ist ein Link"
    prepareVenv link
    linkedState; before="${entries}"
    runMake setup "${SETUP_PATH}" PYTHON_BOOTSTRAP="${work}/py-bin/python3"
    assertEquals "0" "${status}" "${label}: Exit 0"
    assertContains "bootstrap -m venv .venv" "$(cat "${work}/log")" "${label}: .venv mit venv neu"
    assertEquals "no" "$([[ -L ${venv} ]] && echo yes || echo no)" "${label}: eigene .venv statt des Links"
    linkedState
    assertEquals "${before}" "${entries}" "${label}: im Ziel des Links nichts hinzu oder weg"
    assertEquals "" "${changed}" "${label}: im Ziel des Links nichts geschrieben"
    assertEquals "yes" "$(isUpToDate)" "${label}: danach aktuell (make --question)"

    # rm -rf scheitert: Der Link liegt in einem schreibgeschützten Checkout. Als root greift der
    # Schreibschutz nicht, dann entfällt der Fall.
    label="${MAKE_BIN}, rm -rf scheitert"
    if (( EUID == 0 )); then echo "  – ${label}: als root übersprungen"; continue; fi
    prepareVenv link
    linkedState; before="${entries}"
    chmod a-w "${repo}"
    runMake setup "${SETUP_PATH}" PYTHON_BOOTSTRAP="${work}/py-bin/python3"
    chmod u+w "${repo}"
    assertEquals "1" "$(( status != 0 ))" "${label}: Exit ungleich 0"
    assertNotContains "bootstrap" "$(cat "${work}/log")" "${label}: keine neue .venv"
    assertNotContains "pip install" "$(cat "${work}/log")" "${label}: keine Paketinstallation"
    linkedState
    assertEquals "${before}" "${entries}" "${label}: im Ziel des Links nichts hinzu oder weg"
    assertEquals "" "${changed}" "${label}: im Ziel des Links nichts geschrieben, auch kein Stempel"
done
unset MAKE_BIN
# Eingerichtete .venv für die folgenden Tests
command rm -rf -- "${venv}"
setUpVenv "${venv}"

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
