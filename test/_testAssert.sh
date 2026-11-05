#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# _testAssert.sh — Funktionen aus src/assert.lib.sh selbst
#
# checkStatus: Ausgabe wie im früheren test.lib.sh, bei Fehler Exit 1. Die
# Bibliothek setzt keine globalen Farbvariablen und lässt sich nach
# colors.lib.sh ohne Fehler einbinden.
#
#   ./test/_testAssert.sh
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"

LIB="${ROOT}/src/assert.lib.sh"

echo
echo "assert.lib.sh"
echo

rc=0
out="$(bash -c '. "$1"; checkStatus 0 "foo bar"' _ "${LIB}")" || rc=$?
assertEquals "0" "${rc}" "checkStatus 0: Exit 0"
assertEquals $'\t\033[0;32mOK    \033[0m\tCalling foo bar works!' "${out}" "checkStatus 0: OK-Zeile wie bisher"

rc=0
out="$(bash -c '. "$1"; checkStatus 3 "foo"; echo weiter' _ "${LIB}")" || rc=$?
assertEquals "1" "${rc}" "checkStatus 3: Exit 1"
assertEquals $'\t\033[0;31mFAILED\033[0m\tCalling foo failed!' "${out}" "checkStatus 3: FAILED-Zeile, danach Abbruch"

rc=0
err="$(BASH_LIBS="${ROOT}/src" bash -c '. "$BASH_LIBS/colors.lib.sh"; . "$1"; printf "%s|%s|%s" "${RED+gesetzt}" "${SUCCESS-}" "${FAILED-}"' _ "${LIB}" 2>&1)" || rc=$?
assertEquals "0" "${rc}" "nach colors.lib.sh: Exit 0"
assertEquals "gesetzt|"'\x1B[38;5;10m|\x1B[38;5;196m' "${err}" "nach colors.lib.sh: keine Fehler, Farben von colors.lib.sh bleiben"

out="$(bash -c '. "$1"; printf "%s|%s|%s|%s|%s" "${RED-}" "${GREEN-}" "${NC-}" "${SUCCESS-}" "${FAILED-}"' _ "${LIB}")"
assertEquals "||||" "${out}" "setzt keine globalen Farbvariablen"

assertEquals "" "$(ls "${ROOT}/src/test.lib.sh" 2>/dev/null)" "src/test.lib.sh gibt es nicht mehr"

finishTests
