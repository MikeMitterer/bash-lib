#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# package.test.sh — BashLib als pip-Paket installieren und benutzen
#
# Baut das Paket einmal normal und einmal editierbar in je eine eigene venv
# und prueft, dass `bashlib-path` auf die *.lib.sh zeigt, sie sich einbinden
# lassen und `bashlib` Version und Befehle zeigt. Braucht Python ab 3.11 (PYTHON, sonst python3) und pip-Zugriff auf
# setuptools. Laeuft nicht in testAll.sh, weil es Pakete installiert:
#
#   make test-package
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# assertEquals, assertContains, … und finishTests aus dieser Arbeitskopie
. "${ROOT}/src/assert.lib.sh"
PYTHON="${PYTHON:-python3}"

work=""

# shellcheck disable=SC2329  # per trap aufgerufen
cleanup() {
    removeOwnEggInfos
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
    local overview
    rc=0
    overview="$(NO_COLOR=1 "${work}/${name}/bin/bashlib")" || rc=$?
    assertEquals "0" "${rc}" "${name}: bashlib laeuft"
    assertEquals "yes" "$([[ ${overview} == *"BashLib ${expected_version}"*"bashlib-path "* ]] && echo yes)" \
        "${name}: bashlib zeigt Version und bashlib-path"
}

expected_version="$(sed -n 's/^version = "\(.*\)"$/\1/p' "${ROOT}/pyproject.toml" 2>/dev/null)"
# pip legt beim Bauen python/*.egg-info im Checkout an; nur selbst angelegte entfernen.
eggInfos() { find "${ROOT}/python" -maxdepth 1 -name '*.egg-info' -type d | sort; }
EGG_INFOS_BEFORE="$(eggInfos)"
readonly EGG_INFOS_BEFORE
removeOwnEggInfos() {
    local dir
    while IFS= read -r dir; do
        [[ -n ${dir} ]] && ! grep -qxF -- "${dir}" <<< "${EGG_INFOS_BEFORE}" && command rm -rf -- "${dir}"
    done <<< "$(eggInfos)"
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
assertEquals "${expected_version:-?}" "${version:-fehlt}" "Version aus pyproject.toml"

removeOwnEggInfos
assertEquals "${EGG_INFOS_BEFORE}" "$(eggInfos)" "keine neuen python/*.egg-info im Checkout"

finishTests
