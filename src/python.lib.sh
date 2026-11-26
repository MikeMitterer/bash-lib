#!/usr/bin/env bash
readonly __PYTHON_LIB__="python.lib.sh";

#------------------------------------------------------------------------------
# Python-Umgebungen für Projekte: Mindestversion aus requires-python lesen,
# passenden Interpreter im PATH finden, venv anlegen und Pakete installieren
#
# Für Agenten (bashlib --skill):
#     Zweck:   Python-Versionsgrenzen aus requires-python lesen (>=X.Y, optional <X.Y), passenden Interpreter finden, venv anlegen und Pakete installieren
#     Wann:    ein Projekt braucht eine venv oder ein Python in einem Versionsbereich, etwa in `make setup`, ohne feste Version wie python3.14
#     Wichtig: findPythonFor, readRequiresPython, findPython, ensurePythonVenv, isPythonAtLeast, readPythonVersion
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
#     ensurePythonVenv --python "$(findPythonFor pyproject.toml)" --venv .venv -- -e .
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

# Versionsgrenzen aus requires-python: `requires-python = "…"` in [project] einer
# pyproject.toml oder `Requires-Python: …` einer installierten METADATA (dist-info).
# Verstanden wird genau eine Untergrenze >=X.Y, dazu höchstens eine exklusive
# Obergrenze <X.Y über der Untergrenze, durch Komma getrennt und in beliebiger
# Reihenfolge (setuptools schreibt `<3.15,>=3.13`). Alles andere (!=, ~=, ==, <=, >, drei
# Stellen, nur eine Obergrenze) meldet die Funktion mit der Angabe, statt zu raten.
# Ausgabe: MIN, mit Obergrenze „MIN MAX“, passend als Argumente für findPython.
#
# Usage:
#     read -r min max <<<"$(readRequiresPython pyproject.toml)" || exit 1
#     python="$(findPythonFor pyproject.toml)"      # dasselbe samt findPython
#
# Exit:
#     0  „X.Y“ oder „X.Y A.B“ (A.B exklusiv) auf stdout
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
    # METADATA (E-Mail-Format, erste Zeile ein Kopffeld „Name: …“): nur der Kopf bis zur
    # ersten Leerzeile, Felder in beliebiger Reihenfolge, Name ohne Groß-/Kleinschreibung.
    # pyproject.toml: nur im Abschnitt [project], Schlüssel auch eingerückt, Kopf mit
    # Leerzeichen und Kommentar, Wert in "…" oder '…'. CRLF-Zeilenenden zählen wie LF.
    _spec="$(awk '
        { sub(/\r$/, "") }
        NR == 1 && /^[A-Za-z][A-Za-z0-9-]*:/ { meta = 1 }
        meta && /^$/ { exit }
        meta {
            if (tolower($0) ~ /^requires-python:/) { v = $0; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); print v; exit }
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
    # Je Bedingung Operator und X.Y; dezimal wie in Python (3.09 ist 3.9)
    local -r _lower='^>=[[:space:]]*([0-9]+)\.([0-9]+)$' _upper='^<[[:space:]]*([0-9]+)\.([0-9]+)$'
    local _part _min="" _max="" _understood=yes
    local -a _parts
    IFS=',' read -r -a _parts <<<"${_spec}"
    for _part in "${_parts[@]}"; do
        _part="${_part#"${_part%%[![:space:]]*}"}"
        _part="${_part%"${_part##*[![:space:]]}"}"
        if [[ -z ${_min} && ${_part} =~ ${_lower} ]]; then
            _min="$((10#${BASH_REMATCH[1]})).$((10#${BASH_REMATCH[2]}))"
        elif [[ -z ${_max} && ${_part} =~ ${_upper} ]]; then
            _max="$((10#${BASH_REMATCH[1]})).$((10#${BASH_REMATCH[2]}))"
        else
            _understood=no
        fi
    done
    if [[ ${_understood} == no || -z ${_min} ]] || { [[ -n ${_max} ]] && ! _pythonVersionBelow "${_min}" "${_max}"; }; then
        printThemeStatus "✗" "${_file}: requires-python \"${_spec}\" nicht verstanden, erwartet >=X.Y oder >=X.Y,<X.Y" ERR >&2
        return 1
    fi
    printf '%s\n' "${_min}${_max:+ ${_max}}"
}

# Interpreter passend zu requires-python in DATEI (pyproject.toml oder METADATA):
# readRequiresPython liest Unter- und optional Obergrenze, findPython wählt damit.
# Meldungen und Exit-Codes kommen von diesen beiden.
#
# Usage:
#     python="$(findPythonFor pyproject.toml)" || exit 1
#
# Exit:
#     0  Pfad auf stdout
#     1  Angabe fehlt oder nicht verstanden, oder kein passender Interpreter im PATH
#     2  Aufruf falsch
#
findPythonFor() {
    if (( $# != 1 )) || [[ -z ${1} ]]; then
        printf 'findPythonFor: DATEI erwartet\n' >&2
        return 2
    fi
    local _bounds
    local -a _args
    _bounds="$(readRequiresPython "${1}")" || return 1
    read -r -a _args <<<"${_bounds}"
    findPython "${_args[@]}"
}

# Wahr, wenn Version $1 (X.Y) kleiner ist als $2 (X.Y), dezimal verglichen
_pythonVersionBelow() {
    local -r _a="${1}" _b="${2}"
    (( 10#${_a%%.*} < 10#${_b%%.*} || ( 10#${_a%%.*} == 10#${_b%%.*} && 10#${_a#*.} < 10#${_b#*.} ) ))
}

# Pfad des neuesten Interpreters im PATH mit mindestens Version MIN (X.Y) und, mit MAX,
# einer Version unter MAX (exklusiv, wie <X.Y in requires-python). Kandidaten
# sind python3 und python3.N in jedem Ordner des PATH; tote Links, Fehlschläge und zu
# alte übergeht sie still. Die Versionsabfrage ist gültiges Python 2 und 3, auch ein
# sehr altes Python antwortet also. Den Starter /usr/bin/python3 von macOS ruft sie
# nur auf, wenn die Command Line Tools da sind (xcode-select -p); sonst öffnete er ein
# Installationsfenster. Erkannt wird er am Ziel, nicht an der Schreibweise: auch über
# /usr/bin/ im PATH oder einen Link darauf. Die Plattform kommt aus OSTYPE, nicht aus
# dem PATH; fehlt xcode-select im PATH, gilt das wie fehlende Command Line Tools.
# MIN und MAX sind dezimal (3.09 ist 3.9). Bei gleicher Version gewinnt der erste im PATH.
#
# Usage:
#     python="$(findPython 3.14)" || exit 1
#     python="$(findPython 3.13 3.15)" || exit 1     # 3.13 oder 3.14
#
# Exit:
#     0  Pfad auf stdout
#     1  kein passender Interpreter im PATH (Meldung auf stderr)
#     2  Aufruf falsch
#
findPython() {
    if (( $# < 1 || $# > 2 )) || [[ ! ${1} =~ ^[0-9]+\.[0-9]+$ ]] \
        || { (( $# == 2 )) && { [[ ! ${2} =~ ^[0-9]+\.[0-9]+$ ]] || ! _pythonVersionBelow "${1}" "${2}"; }; }; then
        printf 'findPython: MIN [MAX] als X.Y erwartet, MAX über MIN\n' >&2
        return 2
    fi
    local -r _max="${2:-}"
    [[ ${1} =~ ^([0-9]+)\.([0-9]+)$ ]]
    local -r _wantMajor="$((10#${BASH_REMATCH[1]}))" _wantMinor="$((10#${BASH_REMATCH[2]}))"
    local _dir _candidate _version _best="" _bestMajor=-1 _bestMinor=-1 _major _minor _tools=""
    local -a _dirs
    IFS=':' read -r -a _dirs <<<"${PATH}"
    for _dir in "${_dirs[@]}"; do
        [[ -n ${_dir} && -d ${_dir} ]] || continue
        for _candidate in "${_dir}/python3" "${_dir}"/python3.[0-9]*; do
            [[ ${_candidate##*/} =~ ^python3(\.[0-9]+)?$ && -f ${_candidate} && -x ${_candidate} ]] || continue
            if [[ ${OSTYPE} == darwin* && ${_candidate} -ef /usr/bin/python3 ]]; then
                [[ -n ${_tools} ]] || { xcode-select -p >/dev/null 2>&1 && _tools=yes || _tools=no; }
                [[ ${_tools} == yes ]] || continue
            fi
            _version="$(readPythonVersion "${_candidate}" </dev/null)" || continue
            [[ ${_version} =~ ^([0-9]+)\.([0-9]+)$ ]] || continue
            _major="$((10#${BASH_REMATCH[1]}))" _minor="$((10#${BASH_REMATCH[2]}))"
            (( _major > _wantMajor || ( _major == _wantMajor && _minor >= _wantMinor ) )) || continue
            [[ -z ${_max} ]] || _pythonVersionBelow "${_major}.${_minor}" "${_max}" || continue
            if (( _major > _bestMajor || ( _major == _bestMajor && _minor > _bestMinor ) )); then
                _best="${_candidate}" _bestMajor="${_major}" _bestMinor="${_minor}"
            fi
        done
    done
    if [[ -z ${_best} && -n ${_max} ]]; then
        { printThemeStatus "✗" "kein Python ab ${1} und unter ${_max} im PATH" ERR
          printThemeHint "Python ab ${1} und unter ${_max} installieren"; } >&2
        return 1
    elif [[ -z ${_best} ]]; then
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
