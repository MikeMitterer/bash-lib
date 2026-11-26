#!/usr/bin/env bash
readonly __PYTHON_LIB__="python.lib.sh";

#------------------------------------------------------------------------------
# Python-Umgebungen für Projekte: Mindestversion aus requires-python lesen,
# passenden Interpreter im PATH finden, venv anlegen und Pakete installieren
#
# Für Agenten (bashlib --skill):
#     Zweck:   Python-Mindestversion lesen, passenden Interpreter finden, venv anlegen und Pakete installieren
#     Wann:    ein Projekt braucht eine venv oder ein Python ab einer Version, etwa in `make setup`, ohne feste Version wie python3.14
#     Wichtig: readRequiresPython, findPython, ensurePythonVenv, isPythonAtLeast, readPythonVersion
#
# Einbinden:
#     if [[ "${__PYTHON_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/python.lib.sh"; fi
#
#------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/tools.lib.sh
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

# Stellt eine venv bereit: Der Interpreter muss vorhanden und (mit --min) neu genug
# sein; eine vorhandene venv ebenso. Ohne --python nimmt sie den neuesten passenden
# aus dem PATH (findPython mit --min). Fehlt die venv, legt sie `PYTHON -m venv` an.
# Mit PIP-ARGUMENTEN installiert pip in der venv (leise); seine Ausgabe erscheint nur
# bei einem Fehler. Bei Erfolg keine Ausgabe. Projektspezifisches (Stempeldatei,
# Links) bleibt beim Aufrufer; das Skript endet nicht.
#
# Usage:
#     ensurePythonVenv --python python3.14 --venv .venv --min 3.14 -- -e '.[dev]'
#     ensurePythonVenv --venv .venv --min "$(readRequiresPython pyproject.toml)" -- -e .
#
# Params:
#     --python PYTHON   Interpreter für die neue venv (Befehl oder Pfad); ohne: findPython MIN
#     --venv ORDNER     Ort der venv
#     --min X.Y         Mindestversion für Interpreter und vorhandene venv (optional)
#     -- PIP-ARGUMENTE  Argumente für `pip install` (optional)
#
# Exit:
#     0  venv bereit, Pakete installiert
#     1  Interpreter fehlt oder ist zu alt, venv zu alt, venv oder pip gescheitert
#     2  Aufruf falsch (auch ohne --python und ohne --min)
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
    if [[ -z ${_venv} || ( -z ${_python} && -z ${_min} ) ]]; then
        printf 'ensurePythonVenv: --venv ORDNER und --python PYTHON oder --min X.Y erwartet\n' >&2
        return 2
    fi
    if [[ -n ${_min} && ! ${_min} =~ ^[0-9]+\.[0-9]+$ ]]; then
        printf 'ensurePythonVenv: --min X.Y erwartet, war %s\n' "${_min}" >&2
        return 2
    fi
    if [[ -z ${_python} ]]; then
        _python="$(findPython "${_min}")" || return 1
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

# Mindestversion X.Y aus requires-python: `requires-python = ">=X.Y"` in [project] einer
# pyproject.toml oder `Requires-Python: >=X.Y` einer installierten METADATA (dist-info).
# Verstanden wird nur genau eine Untergrenze >=X.Y; mehrere Bedingungen, eine Obergrenze
# oder drei Stellen meldet die Funktion mit der Angabe, statt zu raten.
#
# Usage:
#     min="$(readRequiresPython pyproject.toml)" || exit 1
#
# Exit:
#     0  X.Y auf stdout
#     1  Datei nicht lesbar, keine Angabe oder Angabe nicht verstanden (Meldung auf stderr)
#     2  Aufruf falsch
#
readRequiresPython() {
    if (( $# != 1 )) || [[ -z ${1} ]]; then
        printf 'readRequiresPython: DATEI erwartet\n' >&2
        return 2
    fi
    local -r _file="${1}"
    local _spec
    if [[ ! -r ${_file} ]]; then
        printThemeStatus "✗" "${_file} nicht lesbar" ERR >&2
        return 1
    fi
    # METADATA (erste Zeile Metadata-Version:): nur der Kopf bis zur ersten Leerzeile.
    # pyproject.toml: nur im Abschnitt [project], Schlüssel auch eingerückt, Kopf mit
    # Leerzeichen und Kommentar, Wert in "…" oder '…'. CRLF-Zeilenenden zählen wie LF.
    _spec="$(awk '
        { sub(/\r$/, "") }
        NR == 1 && /^Metadata-Version:/ { meta = 1 }
        meta && /^$/ { exit }
        meta {
            if ($0 ~ /^Requires-Python:/) { v = $0; sub(/^Requires-Python:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); print v; exit }
            next
        }
        /^[ \t]*\[/ { s = $0; sub(/[ \t]*#.*$/, "", s); gsub(/[ \t]/, "", s); next }
        s == "[project]" && /^[ \t]*requires-python[ \t]*=/ {
            v = $0; sub(/^[^=]*=[ \t]*/, "", v); sub(/[ \t]*(#.*)?$/, "", v)
            if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
            print v; exit
        }
    ' "${_file}")"
    if [[ -z ${_spec} ]]; then
        printThemeStatus "✗" "${_file}: keine Angabe requires-python" ERR >&2
        return 1
    fi
    if [[ ! ${_spec} =~ ^\>=[[:space:]]*([0-9]+)\.([0-9]+)$ ]]; then
        printThemeStatus "✗" "${_file}: requires-python \"${_spec}\" nicht verstanden, erwartet >=X.Y" ERR >&2
        return 1
    fi
    # Dezimal wie in Python: 3.09 ist 3.9
    printf '%d.%d\n' "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))"
}

# Pfad des neuesten Interpreters im PATH mit mindestens Version MIN (X.Y). Kandidaten
# sind python3 und python3.N in jedem Ordner des PATH; tote Links, Fehlschläge und zu
# alte übergeht sie still. Die Versionsabfrage ist gültiges Python 2 und 3, auch ein
# sehr altes Python antwortet also. Den Starter /usr/bin/python3 von macOS ruft sie
# nur auf, wenn die Command Line Tools da sind (xcode-select -p); sonst öffnete er ein
# Installationsfenster. Erkannt wird er am Ziel, nicht an der Schreibweise: auch über
# /usr/bin/ im PATH oder einen Link darauf. MIN ist dezimal (3.09 ist 3.9). Bei
# gleicher Version gewinnt der erste im PATH.
#
# Usage:
#     python="$(findPython 3.14)" || exit 1
#
# Exit:
#     0  Pfad auf stdout
#     1  kein passender Interpreter im PATH (Meldung auf stderr)
#     2  Aufruf falsch
#
findPython() {
    if (( $# != 1 )) || [[ ! ${1} =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        printf 'findPython: MIN als X.Y erwartet\n' >&2
        return 2
    fi
    local -r _wantMajor="$((10#${BASH_REMATCH[1]}))" _wantMinor="$((10#${BASH_REMATCH[2]}))"
    local _dir _candidate _version _best="" _bestMajor=-1 _bestMinor=-1 _major _minor _tools=""
    local -a _dirs
    IFS=':' read -r -a _dirs <<<"${PATH}"
    for _dir in "${_dirs[@]}"; do
        [[ -n ${_dir} && -d ${_dir} ]] || continue
        for _candidate in "${_dir}/python3" "${_dir}"/python3.[0-9]*; do
            [[ ${_candidate##*/} =~ ^python3(\.[0-9]+)?$ && -f ${_candidate} && -x ${_candidate} ]] || continue
            if [[ $(uname -s) == Darwin && ${_candidate} -ef /usr/bin/python3 ]]; then
                [[ -n ${_tools} ]] || { xcode-select -p >/dev/null 2>&1 && _tools=yes || _tools=no; }
                [[ ${_tools} == yes ]] || continue
            fi
            _version="$(readPythonVersion "${_candidate}" </dev/null)" || continue
            [[ ${_version} =~ ^([0-9]+)\.([0-9]+)$ ]] || continue
            _major="$((10#${BASH_REMATCH[1]}))" _minor="$((10#${BASH_REMATCH[2]}))"
            (( _major > _wantMajor || ( _major == _wantMajor && _minor >= _wantMinor ) )) || continue
            if (( _major > _bestMajor || ( _major == _bestMajor && _minor > _bestMinor ) )); then
                _best="${_candidate}" _bestMajor="${_major}" _bestMinor="${_minor}"
            fi
        done
    done
    if [[ -z ${_best} ]]; then
        { printThemeStatus "✗" "kein Python ab ${1} im PATH" ERR; printThemeHint "Python ${1} oder neuer installieren"; } >&2
        return 1
    fi
    printf '%s\n' "${_best}"
}

# Version X.Y des Interpreters $1, etwa 3.14 (Abfrage gültig in Python 2 und 3)
readPythonVersion() {
    "${1}" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null
}

# Wahr, wenn der Interpreter $1 mindestens Version $2 (X.Y) hat
isPythonAtLeast() {
    "${1}" -c 'import sys; sys.exit(sys.version_info[:2] < tuple(map(int, sys.argv[1].split("."))))' "${2}" 2>/dev/null
}
