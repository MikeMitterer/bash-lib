#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testMakeTag.sh — make tag-* gibt nur kurze Statuszeilen aus
#
# Kopiert den Arbeitsstand dieser Arbeitskopie (versionierte und neue, nicht
# ignorierte Dateien) in ein Wegwerf-Repo mit aktiven .githooks und ruft dort
# make tag-patch auf. Prüft die Ausgabe bei Erfolg und bei einem Fehler, dass
# Version-Commit, Tag und Changelog-Commit nur lokal liegen (Bare-Remote), und
# die Ausgabe der Git-Hooks bei einem Commit.
#
# Braucht ProjectTools (docs-check, changelog) wie make check.
#
#   ./test/_testMakeTag.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

# Eigene Git-Konfiguration der Nutzer (Signieren, Hooks, Aliase) bleibt draußen
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
# Ein umgebendes make (make check) gibt sonst seine Flags weiter
unset MAKEFLAGS MAKELEVEL MFLAGS

work=""

# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() {
    if [[ -n "${work}" && -d "${work}" ]]; then
        command rm -rf -- "${work}"
    fi
}
trap cleanup EXIT

# Legt unter ${work}/<name> ein Repo mit dem Arbeitsstand dieser Arbeitskopie
# und einem Commit an; die Hooks aus .githooks sind aktiv.
#
# Params:
#   $1 - Name unter ${work}
makeRepo() {
    local repo="${work}/$1"
    mkdir -p "${repo}"
    ( cd "${ROOT}" && git ls-files -z --cached --others --exclude-standard \
        | while IFS= read -r -d '' file; do [[ -e "${file}" ]] && printf '%s\0' "${file}"; done \
        | tar --null -T - -cf - ) | tar -xf - -C "${repo}"
    git init -q -b master "${repo}"
    git -C "${repo}" config user.name "Test"
    git -C "${repo}" config user.email "test@example.invalid"
    git -C "${repo}" config core.hooksPath .githooks
    git -C "${repo}" add -A
    git -C "${repo}" commit -q --no-verify -m "init"
}

# Führt make im Repo aus. Setzt rc und out (stdout und stderr ohne Farbcodes).
#
# Params:
#   $1    - Name unter ${work}
#   $2... - Targets und Variablen für make
runMake() {
    local repo="${work}/$1"
    shift
    rc=0
    ( cd "${repo}" && make "$@" ) > "${work}/out" 2>&1 || rc=$?
    out="$(sed $'s/\033\\[[0-9;]*m//g' "${work}/out")"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/bashlib-maketag.XXXXXX")"
work="$(cd "${work}" && pwd -P)"

echo
echo "make tag-patch: Statuszeilen bei Erfolg"
echo

makeRepo ok
# Bare-Remote mit dem Ausgangsstand: tag-* darf dort nichts ablegen
git init -q --bare "${work}/ok.git"
git -C "${work}/ok" remote add origin "${work}/ok.git"
git -C "${work}/ok" push -q -u origin master
base="$(git -C "${work}/ok" rev-parse HEAD)"
old="$(cd "${work}/ok" && . src/version.lib.sh && readProjectVersion)"
IFS=. read -r major minor patch <<< "${old}"
new="${major}.${minor}.$((patch + 1))"
# develop wie beim Board, auf dem Stand von master
git -C "${work}/ok" branch develop
# Mit C-Locale wie in Agenten-Shells: der Changelog bleibt trotzdem deutsch
LANG=C.UTF-8 LC_ALL= LANGUAGE= runMake ok tag-patch
tag="$(git -C "${work}/ok" tag --sort=-creatordate | head -n1)"
assertEquals "0" "${rc}" "Exit 0"
assertContains "Version" "$(grep "${old} → ${new}" <<< "${out}")" "Statuszeile Version alt → neu"
assertContains "nur lokal" "$(grep -F "${tag}" <<< "${out}")" "Statuszeile Tag mit Hinweis nur lokal"
assertContains "Changelog" "$(grep 'CHANGELOG.md' <<< "${out}")" "Statuszeile Changelog"
assertContains "vorgespult" "$(grep 'develop' <<< "${out}")" "Statuszeile develop"
assertEquals "4" "$(grep -c . <<< "${out}")" "genau vier Zeilen"
assertNotContains "semVerBump" "${out}" "keine Rezeptzeile"
assertNotContains "file changed" "${out}" "keine rohe git-commit-Ausgabe"
assertNotContains "[master" "${out}" "keine rohe git-commit-Kopfzeile"
assertNotContains "Ergebnis" "${out}" "keine docs-check-Ergebniszeile"
assertNotContains "Hinweis:" "${out}" "kein Roh-Hinweis der Bibliothek"
assertNotContains "${work}" "${out}" "kein absoluter Pfad"
assertEquals "" "$(git -C "${work}/ok" status --porcelain)" "Working Tree danach sauber"
assertEquals "docs(changelog): update release history" "$(git -C "${work}/ok" log -1 --format=%s)" "Changelog-Commit liegt lokal"
assertEquals "Aus Release-Tags und Conventional Commits erzeugt." "$(sed -n 3p "${work}/ok/CHANGELOG.md")" "Changelog deutsch, auch unter LANG=C.UTF-8"
assertContains "## ${tag} " "$(cat "${work}/ok/CHANGELOG.md")" "Changelog hat den Abschnitt des neuen Tags"
assertEquals "$(git -C "${work}/ok" rev-parse master)" "$(git -C "${work}/ok" rev-parse develop)" "develop danach auf master vorgespult"
assertEquals "chore: bump version to ${new}" "$(git -C "${work}/ok" log -1 --format=%s "${tag}")" "Tag zeigt auf den Version-Commit"
assertEquals "" "$(git -C "${work}/ok.git" tag)" "kein Tag im Remote"
assertEquals "${base}" "$(git -C "${work}/ok.git" rev-parse master)" "kein neuer Commit im Remote"

# hints und version nennen den Release-Tag, nicht einen näheren deploy-Tag. repo-info
# nimmt nur http(s)-Adressen; das lokale Remote ist oben schon geprüft.
git -C "${work}/ok" remote set-url origin https://example.org/ok.git
git -C "${work}/ok" commit -q --no-verify --allow-empty -m "deploy"
git -C "${work}/ok" tag -a deploy-2026-11 -m "deploy"
runMake ok hints
assertContains ".git@${tag}'" "${out}" "make hints: Installationsbefehl mit dem Release-Tag"
assertNotContains "deploy-2026-11" "${out}" "make hints: kein deploy-Tag"
runMake ok version
assertContains "${tag}" "$(grep 'Release-Tag' <<< "${out}")" "make version: Release-Tag ist der Release-Tag"

# Das Rezept bumpt mit tag-version (ProjectTools), lässt changelog selbst committen
# (ohne Push) und spult danach develop vor; kein eigener Umweg, kein alter Befehlsname.
recipe="$(sed -n '/^define release$/,/^endef$/p' "${ROOT}/Makefile")"
assertContains 'tag-version $(1) --message' "${recipe}" "Rezept bumpt mit tag-version und MSG"
assertContains "tag-version --fast-forward" "${recipe}" "Rezept spult develop mit tag-version vor"
assertNotContains "version-bump" "${recipe}" "Rezept ohne version-bump"
assertContains "changelog --commit" "${recipe}" "Rezept ruft changelog --commit auf"
assertNotContains "--generate" "${recipe}" "Rezept ohne changelog --generate"
assertNotContains "git commit" "${recipe}" "Rezept ohne eigenen Changelog-Commit"

echo
echo "make tag-patch: nur auf master, nur wenn develop nicht weiter ist"
echo

# Auf einem Ticket-Branch: das Board übernimmt per Merge-Commit, ein Tag dort
# fiele aus der First-Parent-Historie und damit aus dem Changelog.
makeRepo branch
git -C "${work}/branch" checkout -q -b t-1-ticket
before="$(git -C "${work}/branch" rev-parse HEAD)"
runMake branch tag-patch
assertEquals "1" "$(( rc != 0 ))" "Ticket-Branch: Exit ungleich 0"
assertContains "nur auf master" "${out}" "Ticket-Branch: Meldung nennt master"
assertEquals "" "$(git -C "${work}/branch" tag)" "Ticket-Branch: kein Tag"
assertEquals "${before}" "$(git -C "${work}/branch" rev-parse HEAD)" "Ticket-Branch: kein Versionssprung"

# develop hat nicht abgenommene Tickets
makeRepo ahead
git -C "${work}/ahead" branch develop
git -C "${work}/ahead" checkout -q develop
git -C "${work}/ahead" commit -q --no-verify --allow-empty -m "feat: noch nicht abgenommen"
git -C "${work}/ahead" checkout -q master
before="$(git -C "${work}/ahead" rev-parse HEAD)"
runMake ahead tag-patch
assertEquals "1" "$(( rc != 0 ))" "develop weiter: Exit ungleich 0"
assertContains "develop ist weiter als master" "${out}" "develop weiter: Meldung"
assertContains "al ticket accept" "${out}" "develop weiter: nächster Schritt"
assertEquals "" "$(git -C "${work}/ahead" tag)" "develop weiter: kein Tag"
assertEquals "${before}" "$(git -C "${work}/ahead" rev-parse HEAD)" "develop weiter: kein Versionssprung"

echo
echo "make tag-patch: Fehler bleiben sichtbar"
echo

makeRepo dirty
printf '\n' >> "${work}/dirty/README.md"
runMake dirty tag-patch
assertEquals "1" "$(( rc != 0 ))" "Exit ungleich 0 bei dirty Working Tree"
assertContains "dirty" "${out}" "Fehlermeldung nennt den dirty Working Tree"
assertEquals "" "$(git -C "${work}/dirty" tag)" "kein Tag angelegt"

echo
echo "Git-Hooks: still ohne Probleme, Fehler sichtbar"
echo

# Lokaler post-commit-Hook wie der Jenkins-Auslöser über at
makeRepo hooks
hook="${work}/hooks/.git/hooks/post-commit"
printf '#!/usr/bin/env bash\necho "job 7 at Tue Nov  3 12:00:00 2026" >&2\n' > "${hook}"
chmod +x "${hook}"
printf '\n' >> "${work}/hooks/README.md"
commitOut="$(git -C "${work}/hooks" commit -q -am "docs: Zeile" 2>&1)"
commitRc=$?
assertEquals "0" "${commitRc}" "Commit ohne Probleme: Exit 0"
assertEquals "" "${commitOut}" "Commit ohne Probleme: keine Hook-Ausgabe"

printf '#!/usr/bin/env bash\necho "Jenkins nicht erreichbar" >&2\nexit 2\n' > "${hook}"
printf '\n' >> "${work}/hooks/README.md"
commitOut="$(git -C "${work}/hooks" commit -q -am "docs: noch eine Zeile" 2>&1)"
assertContains "Jenkins nicht erreichbar" "${commitOut}" "fehlgeschlagener post-commit-Hook: Ausgabe sichtbar"

# pre-commit bricht bei Problemen ab und zeigt sie
printf '\n[kaputt](gibt-es-nicht.md)\n' >> "${work}/hooks/README.md"
commitRc=0
commitOut="$(git -C "${work}/hooks" commit -q -am "docs: kaputter Link" 2>&1)" || commitRc=$?
assertEquals "1" "$(( commitRc != 0 ))" "pre-commit mit Problemen: Commit abgebrochen"
assertContains "Commit abgebrochen" "${commitOut}" "pre-commit mit Problemen: Meldung sichtbar"

finishTests
