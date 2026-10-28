#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# package.test.sh — BashLib als pip-Paket installieren und benutzen
#
# Baut das Paket einmal normal und einmal editierbar in je eine eigene venv
# und prueft, dass `bashlib-path` auf die *.lib.sh zeigt und sie sich einbinden
# lassen. Braucht Python ab 3.11 (PYTHON, sonst python3) und pip-Zugriff auf
# setuptools. Laeuft nicht in testAll.sh, weil es Pakete installiert:
#
#   make test-package
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"

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

# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() {
    if [[ -n "${work}" && -d "${work}" ]]; then
        command rm -rf -- "${work}"
    fi
}
trap cleanup EXIT

# Installiert BashLib in eine neue venv.
#
# Params:
#   $1    - Name der venv unter ${work}
#   $2... - zusaetzliche Argumente fuer pip install (z. B. -e)
install() {
    local venv="${work}/$1"
    shift
    "${PYTHON}" -m venv "${venv}" &&
        "${venv}/bin/python" -m pip install --quiet --disable-pip-version-check "$@" "${ROOT}"
}

# Prueft eine Installation: bashlib-path, Einbinden einer Bibliothek und das
# erwartete Verzeichnis.
#
# Params:
#   $1 - Name der venv unter ${work}
#   $2 - erwartetes Verzeichnis oder leer, wenn es im Paket liegen muss
checkInstall() {
    local name="$1" expected="$2" dir rc=0
    dir="$("${work}/${name}/bin/bashlib-path")" || rc=$?
    assertEquals "0" "${rc}" "${name}: bashlib-path laeuft"
    if [[ -n "${expected}" ]]; then
        assertEquals "${expected}" "${dir}" "${name}: zeigt auf src der Arbeitskopie"
    else
        assertEquals "${work}/${name}" "${dir:0:${#work}+${#name}+1}" "${name}: liegt in der venv"
    fi
    assertEquals "yes" "$([[ -r "${dir}/colors.lib.sh" && -r "${dir}/tools.lib.sh" ]] && echo yes)" \
        "${name}: Bibliotheken vorhanden"
    rc=0
    BASH_LIBS="${dir}" bash -c '. "${BASH_LIBS}/tools.lib.sh" && [[ -n "${__TOOLS_LIB__:-}" ]]' || rc=$?
    assertEquals "0" "${rc}" "${name}: tools.lib.sh laesst sich einbinden"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/bashlib-package.XXXXXX")"
work="$(cd "${work}" && pwd -P)"

echo
echo "BashLib als pip-Paket"
echo

rc=0
install wheel || rc=$?
assertEquals "0" "${rc}" "pip install"
[[ ${rc} -eq 0 ]] && checkInstall wheel ""

rc=0
install editable -e || rc=$?
assertEquals "0" "${rc}" "pip install -e"
[[ ${rc} -eq 0 ]] && checkInstall editable "$(cd "${ROOT}/src" && pwd -P)"

version="$("${work}/wheel/bin/python" -c 'from importlib.metadata import version; print(version("mmit-bashlib"))' 2>/dev/null)"
expected="$(sed -n 's/^version = "\(.*\)"$/\1/p' "${ROOT}/pyproject.toml" 2>/dev/null)"
assertEquals "${expected:-?}" "${version:-fehlt}" "Version aus pyproject.toml"

echo
if [[ ${tests_failed} -eq 0 ]]; then
    echo "  ${tests_run} Tests, alle gruen"
    exit 0
fi
echo "  ${tests_failed} von ${tests_run} Tests fehlgeschlagen"
exit 1
