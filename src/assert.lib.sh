#!/usr/bin/env bash
readonly __ASSERT_LIB__="assert.lib.sh";

#------------------------------------------------------------------------------
# Asserts für Bash-Tests: vergleichen, zählen, Summenzeile und Exit-Code
#
# Ohne Abhängigkeiten zu anderen Bibliotheken. Ausgabe je Prüfung
# „  ✓ Beschreibung“ oder „  ✗ Beschreibung (Grund)“; finishTests gibt am Ende
# die Summenzeile aus und beendet das Skript mit Exit 0 (alle grün) oder 1.
#
# Einbinden:
#     if [[ "${__ASSERT_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/assert.lib.sh"; fi
#
# Usage:
#     assertEquals "0" "${rc}" "Exit 0"
#     assertContains "fertig" "${out}" "Meldung nennt fertig"
#     finishTests
#
#------------------------------------------------------------------------------

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
