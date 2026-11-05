#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# assert.sh — gemeinsame Asserts der Bash-Tests unter test/
#
# Kein Test: testAll.sh führt nur _test*.sh aus. Einbinden mit
#
#     . "$(dirname "$0")/assert.sh"
#
# Jeder Assert zählt tests_run, ein Fehlschlag zusätzlich tests_failed.
# finishTests gibt am Ende die Summenzeile aus und beendet den Test mit Exit 0
# (alle grün) oder 1.
# ------------------------------------------------------------------------------

tests_run=0
tests_failed=0

# Params:
#   $1 - erwarteter Wert
#   $2 - tatsächlicher Wert
#   $3 - Beschreibung
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

# Params:
#   $1 - gesuchter Text (nicht leer)
#   $2 - Text, in dem er stehen muss
#   $3 - Beschreibung
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

# Params:
#   $1 - Text, der nicht vorkommen darf
#   $2 - geprüfter Text
#   $3 - Beschreibung
assertNotContains() {
    local needle="$1" haystack="$2" message="$3"
    tests_run=$((tests_run + 1))
    if [[ "${haystack}" != *"${needle}"* ]]; then
        echo "  ✓ ${message}"
    else
        tests_failed=$((tests_failed + 1))
        echo "  ✗ ${message} ('${needle}' steht in: ${haystack})"
    fi
}

# Summenzeile ausgeben und den Test beenden: Exit 0, wenn alle grün sind, sonst 1.
finishTests() {
    echo
    if [[ ${tests_failed} -eq 0 ]]; then
        echo "  ${tests_run} Tests, alle gruen"
        exit 0
    fi
    echo "  ${tests_failed} von ${tests_run} Tests fehlgeschlagen"
    exit 1
}
