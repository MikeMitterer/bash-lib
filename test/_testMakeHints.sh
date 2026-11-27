#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testMakeHints.sh — make hints nennt Repo-Adresse und letzten Release-Tag aus
# repo-info (ProjectTools)
#
# Legt Wegwerf-Repos mit dem Makefile dieses Checkouts an: SSH-Remote, ein
# Release-Tag v… und ein neuerer deploy-Tag; dazu ohne Remote, ohne ProjectTools
# und mit einem Tag, der Shell-Text enthält.
#
#   ./test/_testMakeHints.sh
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

# Repo unter ${work}/$1 mit Makefile, Werkzeug-Tags und pyproject.toml dieses Checkouts
makeRepo() {
    local repo="${work}/$1"
    mkdir -p "${repo}"
    cp "${ROOT}/Makefile" "${ROOT}/.dev-tools.conf.sh" "${ROOT}/pyproject.toml" "${repo}/"
    ln -s "${ROOT}/src" "${repo}/src"
    git init -q -b master "${repo}"
    git -C "${repo}" config user.name "Test"
    git -C "${repo}" config user.email "test@example.invalid"
    git -C "${repo}" add -A
    git -C "${repo}" commit -q -m "init"
}

# make hints in ${work}/$1 ohne Farben; setzt rc und out. Weitere Argumente: Umgebung
runHints() {
    local repo="${work}/$1"
    shift
    rc=0
    out="$(env "$@" make --no-print-directory -C "${repo}" hints 2>&1 \
        | sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g')" || rc=$?
}

# Wert der Hinweiszeile mit der Beschriftung $1 (erste Fundstelle ab Abschnitt $2)
row() {
    awk -v section="$2" -v label="$1" '
        index($0, section) { inside = 1; next }
        inside && index($0, "       " label " ") == 1 { sub("^ +" label " +", ""); print; exit }' <<< "${out}"
}

echo
echo "make hints mit repo-info"
echo

makeRepo tagged
git -C "${work}/tagged" remote add origin git@github.com:Example/demo.git
git -C "${work}/tagged" tag -a v1.2.3 -m "Release"
git -C "${work}/tagged" commit -q --allow-empty -m "danach"
git -C "${work}/tagged" tag -a deploy-2026-11-06 -m "deploy"
runHints tagged
assertEquals "0" "${rc}" "Exit 0"
assertEquals "https://github.com/Example/demo" "$(row Repository Links)" "Repository: SSH-Remote als https-Adresse"
assertEquals "pipx install 'git+https://github.com/Example/demo.git@v1.2.3'" \
    "$(row 'Ohne Klon' 'BashLib in anderen Projekten')" "Ohne Klon: v-Tag, nicht der neuere deploy-Tag"
# In einem Projekt kommt BashLib über .dev-tools.conf.sh und make setup, nicht über pipx
assertEquals "BASHLIB_* in .dev-tools.conf.sh, dann make setup" \
    "$(row 'Im Projekt' 'BashLib in anderen Projekten')" "Im Projekt: .dev-tools.conf.sh und make setup"
# Werkzeuge richtet make setup ein; hints fragt devtools nicht nach Installationsbefehlen
assertEquals "make setup" "$(row Einrichten 'ProjectTools')" "ProjectTools: Einrichten über make setup"
assertEquals "make setup" "$(row Einrichten 'CLITheme')" "CLITheme: Einrichten über make setup"
assertNotContains "nicht abrufbar" "${out}" "keine Zeile ‚nicht abrufbar‘"

makeRepo local
runHints local
assertEquals "0" "${rc}" "ohne Remote: Exit 0"
noRemote="$(cd "${work}/local" && repo-info --url)"
assertEquals "${noRemote}" "$(row Repository Links)" "ohne Remote: Ersatz von repo-info"
assertEquals "${noRemote}" "$(row 'Ohne Klon' 'BashLib in anderen Projekten')" \
    "ohne Remote: Ohne Klon nennt den Ersatz, keinen kaputten pipx-Befehl"

# Ohne ProjectTools (kein repo-info im PATH): Hinweis statt leerer Zeile
. "${ROOT}/test/minimal-path.sh"
noToolsPath="$(minimalPath "${work}/no-tools-bin" bash make git)" || exit 1
requireMissing "${noToolsPath}" repo-info
runHints tagged PATH="${noToolsPath}"
assertEquals "0" "${rc}" "ohne repo-info: Exit 0"
assertContains "repo-info fehlt" "$(row Repository Links)" "ohne repo-info: Hinweis auf ProjectTools"

# Ein Tag mit Shell-Text gilt nicht als Release-Tag und wird nie ausgeführt
makeRepo hostile
git -C "${work}/hostile" remote add origin https://example.org/demo.git
# shellcheck disable=SC2016  # der Tag soll den Shell-Text wörtlich enthalten
git -C "${work}/hostile" tag -a 'v9$(touch${IFS}executed)' -m "böse"
runHints hostile
assertEquals "0" "${rc}" "Tag mit Shell-Text: Exit 0"
assertEquals "no" "$([[ -e ${work}/hostile/executed ]] && echo yes || echo no)" "Tag mit Shell-Text: nichts ausgeführt"
assertNotContains 'touch' "${out}" "Tag mit Shell-Text: erscheint nicht als Release-Tag"

assertEquals "" "$(grep -n 'git remote get-url\|NO_REMOTE' "${ROOT}/Makefile")" "Makefile: keine eigene Ableitung und kein eigener Ersatztext"

finishTests
