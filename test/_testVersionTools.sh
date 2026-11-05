#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testVersionTools.sh — semVerNext, gitListReleaseTags, showProjectVersion und
# showReleaseTags mit echtem git; dazu make help, version und tags
#
# Legt Wegwerf-Repos mit VERSION-Datei und Tags an. Bindet src/ dieser
# Arbeitskopie ein, nicht die Bibliotheken unter BASH_LIBS.
#
#   ./test/_testVersionTools.sh
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

# Repo mit VERSION $2 und einem Commit unter ${work}/$1
makeRepo() {
    local repo="${work}/$1"
    git init -q -b main "${repo}"
    git -C "${repo}" config user.name "Test"
    git -C "${repo}" config user.email "test@example.invalid"
    printf '%s\n' "$2" > "${repo}/VERSION"
    git -C "${repo}" add VERSION
    git -C "${repo}" commit -q -m "init"
}

# Führt $2… nach dem Einbinden von tools.lib.sh in ${work}/$1 aus, ohne Farben.
# Setzt rc und out (stdout und stderr).
runIn() {
    local dir="${work}/$1"
    shift
    rc=0
    out="$(cd "${dir}" && NO_COLOR=1 XDG_CONFIG_HOME="${work}/config" BASH_LIBS="${ROOT}/src" \
        bash -c '. "${BASH_LIBS}/tools.lib.sh" >/dev/null 2>&1; "$@"' _ "$@" 2>&1)" || rc=$?
}

echo
echo "semVerNext"
echo

makeRepo next 0.4.9
runIn next semVerNext major
assertEquals "1.0.0" "${out}" "major: 0.4.9 → 1.0.0"
runIn next semVerNext minor
assertEquals "0.5.0" "${out}" "minor: 0.4.9 → 0.5.0"
runIn next semVerNext patch
assertEquals "0.4.10" "${out}" "patch: 0.4.9 → 0.4.10"
assertEquals "0.4.9" "$(cat "${work}/next/VERSION")" "schreibt die Versionsdatei nicht"
assertEquals "" "$(git -C "${work}/next" status --porcelain)" "kein Commit, keine Änderung"
assertEquals "" "$(git -C "${work}/next" tag)" "kein Tag"
runIn next semVerNext patch VERSION "${work}/next"
assertEquals "0.4.10" "${out}" "Quelle und Verzeichnis als Argument"
runIn next semVerNext bogus
assertEquals "2" "${rc}" "unbekannter bump-Typ: Exit 2"
mkdir -p "${work}/empty"
runIn empty semVerNext patch
assertEquals "5" "${rc}" "ohne Versionsdatei: Exit 5 wie readProjectVersion"

# semVerBump nimmt dieselbe Rechnung: Ergebnis gleich der Vorschau
makeRepo bump 0.4.9
runIn bump semVerNext minor
preview="${out}"
runIn bump semVerBump minor VERSION
assertEquals "0" "${rc}" "semVerBump: Exit 0"
assertEquals "${preview}" "$(cat "${work}/bump/VERSION")" "semVerBump schreibt die Version aus semVerNext"
runIn bump semVerBump bogus VERSION
assertEquals "2" "${rc}" "semVerBump mit unbekanntem bump-Typ: Exit 2"
assertContains "unbekannter bump-Typ: bogus" "${out}" "semVerBump: Meldung bleibt"

echo
echo "gitListReleaseTags"
echo

makeRepo tags 0.3.0
git -C "${work}/tags" tag -a v0.1.0 -m "Erstes Release"
git -C "${work}/tags" commit -q --allow-empty -m "zwei"
git -C "${work}/tags" tag -a v0.2.0+261101.1200.abcde -m "Zweites Release"$'\n\n'"Details"
git -C "${work}/tags" tag -a deploy-2026-11 -m "kein Release"
git -C "${work}/tags" commit -q --allow-empty -m "drei"
git -C "${work}/tags" tag -a v0.10.0 -m "Zehntes Release"
git -C "${work}/tags" tag vorab
runIn tags gitListReleaseTags
assertEquals "0" "${rc}" "Exit 0"
assertEquals $'v0.10.0\tZehntes Release\nv0.2.0+261101.1200.abcde\tZweites Release\nv0.1.0\tErstes Release' \
    "${out}" "nur v[0-9]*, neueste Version zuerst, Tag<TAB>erste Zeile der Nachricht"
runIn tags gitListReleaseTags 2
assertEquals "2" "$(wc -l <<< "${out}" | tr -d ' ')" "Anzahl begrenzt die Zeilen"
runIn empty gitListReleaseTags 3 "${work}/next"
assertEquals "0" "${rc}" "Repo ohne Release-Tag: Exit 0"
assertEquals "" "${out}" "Repo ohne Release-Tag: leere Liste"
runIn tags gitListReleaseTags abc
assertEquals "2" "${rc}" "Anzahl keine Zahl: Exit 2"
runIn empty gitListReleaseTags 3
assertEquals "2" "${rc}" "kein Git-Repo: Exit 2"

echo
echo "showProjectVersion und showReleaseTags"
echo

runIn tags showProjectVersion
assertContains "Version                0.3.0" "${out}" "Version aus der Versionsdatei"
assertContains "Release-Tag            v0.10.0" "${out}" "Release-Tag über gitReleaseTag"
runIn next showProjectVersion
assertContains "Release-Tag            kein Release-Tag" "${out}" "ohne Tag: kein Release-Tag"
runIn empty showProjectVersion auto "${work}/empty"
assertContains "Version                keine Versionsdatei" "${out}" "ohne Versionsdatei: Grund statt Version"

runIn tags showReleaseTags
assertContains "v0.2.0+261101.1200.abcde  Zweites Release" "${out}" "Tag und Nachricht in einer Zeile"
assertContains "v0.10.0                   Zehntes Release" "${out}" "Spalte so breit wie der längste Tag"
assertNotContains "deploy-2026-11" "${out}" "andere Tags fehlen"
runIn next showReleaseTags
assertContains "keine Release-Tags" "${out}" "ohne Tag: Hinweis"
runIn tags showReleaseTags x
assertEquals "2" "${rc}" "ungültige Anzahl: Exit 2"

# tools.lib.sh bindet version.lib.sh ein; ein zweites . ohne Guard darf nicht abbrechen
runIn next bash -c 'set -e; . "${BASH_LIBS}/version.lib.sh"; echo weiter'
assertEquals "0" "${rc}" "version.lib.sh nach tools.lib.sh erneut eingebunden: Exit 0"
assertEquals "weiter" "${out}" "version.lib.sh erneut eingebunden: Skript läuft weiter"

echo
echo "make help, version und tags"
echo

# Ohne Farbcodes; ROOT ist BashLib selbst mit echtem Tag und pyproject.toml
plain() { sed $'s/\033\\[[0-9;]*m//g; s/\033(B//g'; }
ver="$(cd "${ROOT}" && BASH_LIBS="${ROOT}/src" bash -c '. src/version.lib.sh; readProjectVersion')"
help="$(make --no-print-directory -C "${ROOT}" help 2>&1 | plain)"
for bump in major minor patch; do
    next="$(cd "${ROOT}" && bash -c '. src/version.lib.sh; semVerNext "$1"' _ "${bump}")"
    assertContains "${ver} → ${next}" "$(grep -E "^ +tag-${bump} " <<< "${help}")" "help: tag-${bump} zeigt ${ver} → ${next}"
done
assertNotContains "{major}" "${help}" "help: kein Platzhalter übrig"

version="$(make --no-print-directory -C "${ROOT}" version 2>&1 | plain)"
assertContains "Version                ${ver}" "${version}" "make version: Version"
assertContains "Release-Tag            $(git -C "${ROOT}" describe --tags --abbrev=0 --match 'v[0-9]*')" \
    "${version}" "make version: Release-Tag"

tags="$(make --no-print-directory -C "${ROOT}" tags 2>&1 | plain)"
assertEquals "$(git -C "${ROOT}" tag -l 'v[0-9]*' | wc -l | awk '{print ($1 > 10) ? 10 : $1}')" \
    "$(grep -cE '^ +v[0-9]' <<< "${tags}")" "make tags: höchstens 10 Release-Tags"

finishTests
