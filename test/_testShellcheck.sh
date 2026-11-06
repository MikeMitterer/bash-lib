#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testShellcheck.sh — ShellCheck meldet in den geprüften Bibliotheken nichts
#
# Bewusst stehen gelassene Stellen tragen ein `# shellcheck disable=…` mit
# Begründung. Ohne installiertes shellcheck wird der Test übersprungen.
#
#   ./test/_testShellcheck.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

# Bibliotheken, die ShellCheck ohne Meldung bestehen müssen
readonly FILES=(src/cli.lib.sh src/tools.lib.sh src/make.lib.sh src/python.lib.sh test/_testMake.sh test/_testPython.sh)

echo
echo "ShellCheck"
echo

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "  – shellcheck nicht installiert, übersprungen"
    finishTests
fi

for file in "${FILES[@]}"; do
    out="$(cd "${ROOT}" && shellcheck -x -P SCRIPTDIR "${file}" 2>&1)"
    assertEquals "" "${out}" "${file}: keine Meldung"
done

finishTests
