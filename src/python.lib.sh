#!/usr/bin/env bash
readonly __PYTHON_LIB__="python.lib.sh";

#------------------------------------------------------------------------------
# Python-Umgebungen für Projekte: venv mit Mindestversion anlegen und Pakete
# installieren
#
# Einbinden:
#     if [[ "${__PYTHON_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/python.lib.sh"; fi
#
#------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/tools.lib.sh
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

# Stellt eine venv bereit: Der Interpreter muss vorhanden und (mit --min) neu genug
# sein; eine vorhandene venv ebenso. Fehlt die venv, legt sie `PYTHON -m venv` an.
# Mit PIP-ARGUMENTEN installiert pip in der venv (leise); seine Ausgabe erscheint nur
# bei einem Fehler. Bei Erfolg keine Ausgabe. Projektspezifisches (Stempeldatei,
# Links) bleibt beim Aufrufer; das Skript endet nicht.
#
# Usage:
#     ensurePythonVenv --python python3.14 --venv .venv --min 3.14 -- -e '.[dev]'
#
# Params:
#     --python PYTHON   Interpreter für die neue venv (Befehl oder Pfad)
#     --venv ORDNER     Ort der venv
#     --min X.Y         Mindestversion für Interpreter und vorhandene venv (optional)
#     -- PIP-ARGUMENTE  Argumente für `pip install` (optional)
#
# Exit:
#     0  venv bereit, Pakete installiert
#     1  Interpreter fehlt oder ist zu alt, venv zu alt, venv oder pip gescheitert
#     2  Aufruf falsch
#
ensurePythonVenv() {
    local _python="" _venv="" _min="" _output _option
    local -a _pip=()
    while (( $# > 0 )); do
        case "${1}" in
            --python|--venv|--min)
                if (( $# < 2 )) || [[ -z ${2} ]]; then
                    printf 'ensurePythonVenv: %s braucht einen Wert\n' "${1}" >&2
                    return 2
                fi
                _option="${1#--}"
                printf -v "_${_option}" '%s' "${2}"
                shift 2
                ;;
            --) shift; _pip=("$@"); break ;;
            *) printf 'ensurePythonVenv: unbekanntes Argument %s\n' "${1}" >&2; return 2 ;;
        esac
    done
    if [[ -z ${_python} || -z ${_venv} ]]; then
        printf 'ensurePythonVenv: --python PYTHON und --venv ORDNER erwartet\n' >&2
        return 2
    fi
    if [[ -n ${_min} && ! ${_min} =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        printf 'ensurePythonVenv: --min X.Y erwartet, war %s\n' "${_min}" >&2
        return 2
    fi

    if ! command -v "${_python}" >/dev/null 2>&1; then
        { printThemeStatus "✗" "${_python} fehlt" ERR; printThemeHint "Python ${_min:-3} installieren"; } >&2
        return 1
    fi
    if [[ -n ${_min} ]] && ! isPythonAtLeast "${_python}" "${_min}"; then
        printThemeStatus "✗" "${_python} ist $(readPythonVersion "${_python}"), verlangt ab ${_min}" ERR >&2
        return 1
    fi
    if [[ -x ${_venv}/bin/python && -n ${_min} ]] && ! isPythonAtLeast "${_venv}/bin/python" "${_min}"; then
        {
            printThemeStatus "✗" "venv ${_venv} hat Python $(readPythonVersion "${_venv}/bin/python"), verlangt ab ${_min}" ERR
            printThemeHint "rm -rf -- ${_venv}"
        } >&2
        return 1
    fi
    if [[ ! -x ${_venv}/bin/python ]] && ! _output="$("${_python}" -m venv "${_venv}" 2>&1)"; then
        { printf '%s\n' "${_output}"; printThemeStatus "✗" "${_python} -m venv ${_venv} gescheitert" ERR; } >&2
        return 1
    fi
    if (( ${#_pip[@]} > 0 )) \
        && ! _output="$("${_venv}/bin/python" -m pip install -q --disable-pip-version-check "${_pip[@]}" 2>&1)"; then
        { printf '%s\n' "${_output}"; printThemeStatus "✗" "pip install in ${_venv} gescheitert" ERR; } >&2
        return 1
    fi
}

# Version X.Y des Interpreters $1, etwa 3.14
readPythonVersion() {
    "${1}" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null
}

# Wahr, wenn der Interpreter $1 mindestens Version $2 (X.Y) hat
isPythonAtLeast() {
    "${1}" -c 'import sys; sys.exit(sys.version_info[:2] < tuple(map(int, sys.argv[1].split("."))))' "${2}" 2>/dev/null
}
