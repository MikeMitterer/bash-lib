#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testVersionPush.sh — Versions-Bumps taggen nur lokal, git push
# veröffentlicht; gitReleaseTag findet den Release-Tag eines Commits
#
# Legt je Fall ein Wegwerf-Repo mit VERSION-Datei an, dazu ein lokales
# Bare-Remote oder gar kein Remote. Bindet src/version.lib.sh dieser Arbeitskopie ein, nicht
# die unter BASH_LIBS.
#
#   ./test/_testVersionPush.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"
LIB="${ROOT}/src/version.lib.sh"

# Eigene Git-Konfiguration der Nutzer (Signieren, Hooks, Aliase) bleibt draußen
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

work=""

# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() {
    if [[ -n "${work}" && -d "${work}" ]]; then
        command rm -rf -- "${work}"
    fi
}
trap cleanup EXIT

# Legt ein Repo mit VERSION 0.1.0 und einem Commit an. Bei einem Remote
# liegt main dort schon; base hält den Commit, den das Remote kennt.
#
# Params:
#   $1 - Name unter ${work}
#   $2 - ok (mit lokalem Bare-Remote) oder none (kein Remote)
makeRepo() {
    local name="$1" kind="$2"
    local repo="${work}/${name}" remote="${work}/${name}.git"
    git init -q -b main "${repo}"
    git -C "${repo}" config user.name "Test"
    git -C "${repo}" config user.email "test@example.invalid"
    printf '0.1.0\n' > "${repo}/VERSION"
    git -C "${repo}" add VERSION
    git -C "${repo}" commit -q -m "init"
    base="$(git -C "${repo}" rev-parse HEAD)"
    [[ "${kind}" == "none" ]] && return 0

    git init -q --bare "${remote}"
    git -C "${repo}" remote add origin "${remote}"
    git -C "${repo}" push -q -u origin main
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

# Tags und Stand von main im Remote eines Repos
remoteTags() {
    git -C "${work}/$1.git" tag
}
remoteMain() {
    git -C "${work}/$1.git" rev-parse main
}

# Prüft, dass ein Bump nichts gepusht hat: kein Tag, main auf ${base}.
#
# Params:
#   $1 - Name unter ${work}
#   $2 - Beschriftung der Prüfung
assertNothingPushed() {
    assertEquals "" "$(remoteTags "$1")" "$2: kein Tag im Remote"
    assertEquals "${base}" "$(remoteMain "$1")" "$2: kein neuer Commit im Remote"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/bashlib-versionpush.XXXXXX")"
work="$(cd "${work}" && pwd -P)"

echo
echo "Versions-Bumps taggen nur lokal"
echo

makeRepo sem-ok ok
runIn sem-ok semVerBump patch VERSION
assertEquals "0" "${rc}" "semVerBump: Exit 0"
assertEquals "${out}" "$(localTag sem-ok)" "semVerBump: Tag lokal angelegt"
assertNothingPushed sem-ok "semVerBump"
assertContains "${out}" "$(grep 'nur lokal' <<< "${err}")" "semVerBump: stderr meldet den Tag als nur lokal"
assertEquals "" "$(grep 'git push' <<< "${err}")" "semVerBump: stderr nennt keinen Push-Befehl"

# Vorgemerktes CHANGELOG.md geht in den Bump-Commit; der Tag liegt auf HEAD
makeRepo sem-changelog none
printf '# Changelog\n\n## v0.1.1\n' > "${work}/sem-changelog/CHANGELOG.md"
git -C "${work}/sem-changelog" add CHANGELOG.md
runIn sem-changelog semVerBump patch VERSION
assertEquals "0" "${rc}" "semVerBump mit Changelog: Exit 0"
assertEquals $'CHANGELOG.md\nVERSION' "$(git -C "${work}/sem-changelog" show --name-only --format= HEAD)" \
    "semVerBump mit Changelog: Bump-Commit enthält CHANGELOG.md und VERSION"
assertEquals "${out}" "$(git -C "${work}/sem-changelog" tag --points-at HEAD)" "semVerBump mit Changelog: Tag zeigt auf HEAD"
assertEquals "" "$(git -C "${work}/sem-changelog" status --porcelain)" "semVerBump mit Changelog: nichts bleibt offen"

makeRepo bump-ok ok
runIn bump-ok bumpVer patch VERSION
assertEquals "0" "${rc}" "bumpVer: Exit 0"
assertNothingPushed bump-ok "bumpVer"

makeRepo cal-ok ok
runIn cal-ok calVerBump VERSION
assertEquals "0" "${rc}" "calVerBump: Exit 0"
assertNothingPushed cal-ok "calVerBump"

makeRepo uvt-ok ok
runIn uvt-ok gitUpdateVersionTag
assertEquals "0" "${rc}" "gitUpdateVersionTag: Exit 0"
assertNothingPushed uvt-ok "gitUpdateVersionTag"

# Reuse-Zweig: HEAD trägt schon einen Tag des Jahres
makeRepo reuse-ok ok
reuseTag="v$(date -u +%y).1.0+000000.0000.test"
git -C "${work}/reuse-ok" tag -a "${reuseTag}" -m "reuse"
runIn reuse-ok gitUpdateVersionTag
assertEquals "0" "${rc}" "gitUpdateVersionTag (Reuse): Exit 0"
assertEquals "${reuseTag}" "${out}" "gitUpdateVersionTag (Reuse): gibt den vorhandenen Tag zurück"
assertNothingPushed reuse-ok "gitUpdateVersionTag (Reuse)"
assertContains "${reuseTag}" "$(grep 'nichts gepusht' <<< "${err}")" "gitUpdateVersionTag (Reuse): stderr meldet, dass nichts gepusht wurde"
assertEquals "" "$(grep 'git push' <<< "${err}")" "gitUpdateVersionTag (Reuse): stderr nennt keinen Push-Befehl"

makeRepo sem-none none
runIn sem-none semVerBump patch VERSION
assertEquals "0" "${rc}" "semVerBump ohne Remote: Exit 0"
assertContains "Kein Remote" "${err}" "semVerBump ohne Remote: Hinweis auf stderr"
assertEquals "${out}" "$(localTag sem-none)" "semVerBump ohne Remote: Tag lokal angelegt"

echo
echo "Veröffentlichen mit git push"
echo

# git push --follow-tags bringt Tag und Bump-Commit ins Remote
makeRepo push-ok ok
runIn push-ok semVerBump patch VERSION
pushTag="${out}"
pushRc=0
git -C "${work}/push-ok" push -q --follow-tags 2> /dev/null || pushRc=$?
assertEquals "0" "${pushRc}" "git push --follow-tags: Exit 0"
assertEquals "${pushTag}" "$(remoteTags push-ok)" "git push --follow-tags: Tag liegt im Remote"
assertEquals "$(git -C "${work}/push-ok" rev-parse HEAD)" "$(remoteMain push-ok)" "git push --follow-tags: Bump-Commit liegt im Remote"

echo
echo "Release-Tag eines Commits"
echo

# Commit 1 mit v-Tag, Commit 2 mit Nicht-Release-Tag (näher an HEAD), Commit 3 ohne Tag
makeRepo release none
git -C "${work}/release" tag -a v0.1.0+261105.1000.abc12 -m "release"
releaseCommit="$(git -C "${work}/release" rev-parse HEAD)"
git -C "${work}/release" commit -q --allow-empty -m "deploy"
git -C "${work}/release" tag -a deploy-2026-11 -m "deploy"
git -C "${work}/release" commit -q --allow-empty -m "weiter"
runIn release gitReleaseTag
assertEquals "0" "${rc}" "gitReleaseTag: Exit 0"
assertEquals "v0.1.0+261105.1000.abc12" "${out}" "gitReleaseTag: v-Tag statt des näheren deploy-Tags"
runIn release gitReleaseTag "${releaseCommit}" "${work}/release"
assertEquals "v0.1.0+261105.1000.abc12" "${out}" "gitReleaseTag: Commit und Repo als Argumente"
runIn release gitVersion
assertEquals "0.1.0+261105.1000.abc12" "${out}" "gitVersion: Version aus dem v-Tag"
runIn release semVerWithDate
assertEquals "0.1.0" "${out%%+*}" "semVerWithDate: Basis aus dem v-Tag"
runIn release gitDockerTag 0
assertEquals "0.1.0" "${out%%-*}" "gitDockerTag: Basis aus dem v-Tag"
hash="$(git -C "${work}/release" rev-parse --short=5 HEAD)"
runIn release getPackageName demo
assertEquals "demo-0.1.0-261105.1000.abc12-${hash}.zip" "${out}" "getPackageName: Version aus dem v-Tag"

makeRepo untagged none
git -C "${work}/untagged" tag deploy-2026-11
runIn untagged gitReleaseTag
assertEquals "1" "${rc}" "gitReleaseTag ohne v-Tag: Exit 1"
assertEquals "" "${out}" "gitReleaseTag ohne v-Tag: keine Ausgabe"
runIn untagged gitReleaseTag gibtsnicht
assertEquals "2" "${rc}" "gitReleaseTag mit unbekanntem Commit: Exit 2"
mkdir -p "${work}/nogit"
runIn nogit gitReleaseTag
assertEquals "2" "${rc}" "gitReleaseTag außerhalb eines Repos: Exit 2"

finishTests
