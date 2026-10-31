#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testVersionPush.sh — Versions-Bump bei erfolgreichem, gescheitertem und
# fehlendem Push
#
# Legt je Fall ein Wegwerf-Repo mit VERSION-Datei an, dazu ein lokales
# Bare-Remote, das den Push annimmt oder per pre-receive-Hook abweist, oder
# gar kein Remote. Bindet src/version.lib.sh dieser Arbeitskopie ein, nicht
# die unter BASH_LIBS.
#
#   ./test/_testVersionPush.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="${ROOT}/src/version.lib.sh"

# Eigene Git-Konfiguration der Nutzer (Signieren, Hooks, Aliase) bleibt draußen
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

tests_run=0
tests_failed=0
work=""

assertEquals() {
    local expected="$1" actual="$2" message="$3"
    tests_run=$((tests_run + 1))
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  ✓ ${message}"
    else
        tests_failed=$((tests_failed + 1))
        echo "  ✗ ${message} (erwartet '${expected}', war '${actual}')"
    fi
}

assertContains() {
    local needle="$1" haystack="$2" message="$3"
    tests_run=$((tests_run + 1))
    if [[ -n "${needle}" && "${haystack}" == *"${needle}"* ]]; then
        echo "  ✓ ${message}"
    else
        tests_failed=$((tests_failed + 1))
        echo "  ✗ ${message} ('${needle}' fehlt in: ${haystack})"
    fi
}

# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() {
    if [[ -n "${work}" && -d "${work}" ]]; then
        command rm -rf -- "${work}"
    fi
}
trap cleanup EXIT

# Legt ein Repo mit VERSION 0.1.0 und einem Commit an.
#
# Params:
#   $1 - Name unter ${work}
#   $2 - ok (Remote nimmt an), reject (Remote weist ab) oder none (kein Remote)
makeRepo() {
    local name="$1" kind="$2"
    local repo="${work}/${name}" remote="${work}/${name}.git"
    git init -q -b main "${repo}"
    git -C "${repo}" config user.name "Test"
    git -C "${repo}" config user.email "test@example.invalid"
    printf '0.1.0\n' > "${repo}/VERSION"
    git -C "${repo}" add VERSION
    git -C "${repo}" commit -q -m "init"
    [[ "${kind}" == "none" ]] && return 0

    git init -q --bare "${remote}"
    git -C "${repo}" remote add origin "${remote}"
    git -C "${repo}" push -q -u origin main
    if [[ "${kind}" == "reject" ]]; then
        printf '#!/bin/sh\necho "push abgewiesen (Test)" >&2\nexit 1\n' > "${remote}/hooks/pre-receive"
        chmod +x "${remote}/hooks/pre-receive"
    fi
}

# Führt eine Funktion der version.lib.sh im Repo aus.
# Setzt rc, out (letzte Zeile stdout, also der Tag) und err (stderr).
#
# Params:
#   $1    - Name unter ${work}
#   $2... - Funktion und Argumente
runIn() {
    local repo="${work}/$1"
    shift
    rc=0
    # shellcheck source=src/version.lib.sh
    ( cd "${repo}" && . "${LIB}" && "$@" ) > "${work}/out" 2> "${work}/err" || rc=$?
    out="$(tail -n1 "${work}/out")"
    err="$(cat "${work}/err")"
}

# Neuester lokaler Tag eines Repos
localTag() {
    git -C "${work}/$1" tag --sort=-creatordate | head -n1
}

work="$(mktemp -d "${TMPDIR:-/tmp}/bashlib-versionpush.XXXXXX")"
work="$(cd "${work}" && pwd -P)"

echo
echo "Versions-Bump und git push"
echo

makeRepo sem-ok ok
runIn sem-ok semVerBump patch VERSION
assertEquals "0" "${rc}" "semVerBump, Remote nimmt an: Exit 0"
assertEquals "${out}" "$(git -C "${work}/sem-ok.git" tag)" "semVerBump, Remote nimmt an: Tag liegt auf dem Remote"

makeRepo sem-reject reject
runIn sem-reject semVerBump patch VERSION
assertEquals "yes" "$([[ ${rc} -ne 0 ]] && echo yes)" "semVerBump, Remote weist ab: Exit ≠ 0 (war ${rc})"
assertContains "$(localTag sem-reject)" "$(grep 'nur lokal' <<< "${err}")" "semVerBump, Remote weist ab: stderr meldet den Tag als nur lokal"
assertContains "git push --follow-tags" "$(grep 'Nachpushen' <<< "${err}")" "semVerBump, Remote weist ab: stderr nennt den Befehl zum Nachpushen"
assertEquals "" "$(git -C "${work}/sem-reject.git" tag)" "semVerBump, Remote weist ab: Tag nicht auf dem Remote"

makeRepo sem-none none
runIn sem-none semVerBump patch VERSION
assertEquals "0" "${rc}" "semVerBump ohne Remote: Exit 0"
assertContains "Kein Remote" "${err}" "semVerBump ohne Remote: Hinweis auf stderr"
assertEquals "${out}" "$(localTag sem-none)" "semVerBump ohne Remote: Tag lokal angelegt"

makeRepo cal-reject reject
runIn cal-reject calVerBump VERSION
assertEquals "yes" "$([[ ${rc} -ne 0 ]] && echo yes)" "calVerBump, Remote weist ab: Exit ≠ 0 (war ${rc})"

makeRepo bump-reject reject
runIn bump-reject bumpVer patch VERSION
assertEquals "yes" "$([[ ${rc} -ne 0 ]] && echo yes)" "bumpVer, Remote weist ab: Exit ≠ 0 (war ${rc})"

# Reuse-Zweig: HEAD trägt schon einen Tag des Jahres, der Push des Tags scheitert
makeRepo reuse-reject reject
git -C "${work}/reuse-reject" tag -a "v$(date -u +%y).1.0+000000.0000.test" -m "reuse"
runIn reuse-reject gitUpdateVersionTag
assertEquals "yes" "$([[ ${rc} -ne 0 ]] && echo yes)" "gitUpdateVersionTag (Reuse), Remote weist ab: Exit ≠ 0 (war ${rc})"
assertContains "$(localTag reuse-reject)" "$(grep 'nur lokal' <<< "${err}")" "gitUpdateVersionTag (Reuse), Remote weist ab: stderr meldet den Tag als nur lokal"

echo
if [[ ${tests_failed} -eq 0 ]]; then
    echo "  ${tests_run} Tests, alle gruen"
    exit 0
fi
echo "  ${tests_failed} von ${tests_run} Tests fehlgeschlagen"
exit 1
