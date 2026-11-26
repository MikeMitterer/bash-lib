#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testHelpers.sh — requireCommand (apps.lib.sh), readPackageName und
# readPackageCommands (version.lib.sh)
#
#   ./test/_testHelpers.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

work="$(mktemp -d)"
# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() { command rm -rf -- "${work}"; }
trap cleanup EXIT

# Führt "$@" nach dem Einbinden von $LIB aus; setzt rc, out und err
runLib() {
    local -r lib="$1"; shift
    rc=0
    out="$(cd "${work}" && NO_COLOR=1 BASH_LIBS="${ROOT}/src" \
        bash -c '. "${BASH_LIBS}/$1"; shift; "$@"' _ "${lib}" "$@" 2>"${work}/err")" || rc=$?
    err="$(cat "${work}/err")"
}

# Führt den Code $2 nach dem Einbinden von $1 in derselben Bash aus; setzt rc, out und err
# shellcheck disable=SC2016  # der Ausdruck läuft erst in der inneren Bash
runCode() {
    rc=0
    out="$(NO_COLOR=1 BASH_LIBS="${ROOT}/src" bash -c '. "${BASH_LIBS}/$1"; eval "$2"' _ "$1" "$2" 2>"${work}/err")" || rc=$?
    err="$(cat "${work}/err")"
}

echo
echo "requireCommand"
echo

runLib apps.lib.sh requireCommand bash "brew install bash"
assertEquals "0" "${rc}" "vorhanden: Rückgabe 0"
assertEquals "" "${out}${err}" "vorhanden: keine Ausgabe"
runLib apps.lib.sh requireCommand gibt-es-nicht-bashlib "https://example.org"
assertEquals "1" "${rc}" "fehlt: Rückgabe 1"
assertContains "✗ gibt-es-nicht-bashlib fehlt" "${err}" "fehlt: Meldung auf stderr"
assertContains $'\n       https://example.org' "${err}" "fehlt: Hinweis in eigener Zeile"
assertEquals "" "${out}" "fehlt: nichts auf stdout"
# shellcheck disable=SC2016  # der Hinweis soll $(…) wörtlich enthalten
runLib apps.lib.sh requireCommand gibt-es-nicht-bashlib '$(touch executed) `touch executed`'
# shellcheck disable=SC2016  # der Text soll $(…) wörtlich enthalten
assertContains '$(touch executed)' "${err}" "Hinweis mit \$(…) wörtlich"
assertEquals "no" "$([[ -e ${work}/executed ]] && echo yes || echo no)" "Hinweis: nichts ausgeführt"
runLib apps.lib.sh requireCommand
assertEquals "2" "${rc}" "ohne Argumente: Aufruffehler Exit 2"
runCode apps.lib.sh 'requireCommand gibt-es-nicht-bashlib x; echo "weiter $?"'
assertEquals "weiter 1" "${out}" "beendet das Skript nicht, Rückgabe 1"

echo
echo "readPackageName und readPackageCommands"
echo

mkdir -p "${work}/pkg"
cat > "${work}/pkg/pyproject.toml" <<'EOF'
[build-system]
name = "nicht-das-paket"

[project]
name = "mmit-demo"
version = "1.2.3"

[project.scripts]
demo = "demo.cli:main"
demo-path = "demo.cli:path"
"böse$(touch executed)" = "demo.cli:x"

[tool.other]
name = "auch-nicht"
EOF
runLib version.lib.sh readPackageName "${work}/pkg"
assertEquals "0" "${rc}" "readPackageName: Exit 0"
assertEquals "mmit-demo" "${out}" "readPackageName: Name aus [project], nicht aus anderen Abschnitten"
runLib version.lib.sh readPackageCommands "${work}/pkg"
assertEquals "0" "${rc}" "readPackageCommands: Exit 0"
assertEquals $'demo\ndemo-path' "${out}" "readPackageCommands: Schlüssel aus [project.scripts], ungültige Namen fehlen"
assertEquals "no" "$([[ -e ${work}/executed ]] && echo yes || echo no)" "readPackageCommands: nichts ausgeführt"
runCode version.lib.sh "cd '${work}/pkg' && readPackageName"
assertEquals "mmit-demo" "${out}" "readPackageName ohne Verzeichnis: aktuelles Verzeichnis"

mkdir -p "${work}/bad"
# shellcheck disable=SC2016  # der Text soll $(…) wörtlich enthalten
printf '[project]\nname = "böse$(touch executed)"\n' > "${work}/bad/pyproject.toml"
runLib version.lib.sh readPackageName "${work}/bad"
assertEquals "1" "${rc}" "ungültiger Name: Exit 1"
assertEquals "" "${out}" "ungültiger Name: keine Ausgabe"
runLib version.lib.sh readPackageName "${work}/fehlt"
assertEquals "1" "${rc}" "ohne pyproject.toml: Exit 1"
mkdir -p "${work}/empty"
printf '[project]\nname = "x"\n' > "${work}/empty/pyproject.toml"
runLib version.lib.sh readPackageCommands "${work}/empty"
assertEquals "1" "${rc}" "ohne [project.scripts]: Exit 1"

# Skripte ohne Python-Starter: Dateinamen aus script-files, auch als mehrzeilige Liste
mkdir -p "${work}/files"
cat > "${work}/files/pyproject.toml" <<'EOF'
[project]
name = "demo"

[tool.setuptools]
packages = ["demo"]
script-files = ["bin/demo", "bin/demo-path",
    "tools/demo-x", "bin/böse$(touch executed)",
]

[tool.other]
script-files = ["bin/nicht"]
EOF
runLib version.lib.sh readPackageCommands "${work}/files"
assertEquals $'demo\ndemo-path\ndemo-x' "${out}" "readPackageCommands: Dateinamen aus script-files, ungültige fehlen"
assertEquals "no" "$([[ -e ${work}/executed ]] && echo yes || echo no)" "readPackageCommands, script-files: nichts ausgeführt"

finishTests
