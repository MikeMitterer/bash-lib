#!/usr/bin/env bash
readonly __MAKE_LIB__="make.lib.sh";

#------------------------------------------------------------------------------
# Hilfe und Hinweiszeilen für Makefiles im CLI-Theme
#
# showMakeHelp liest aus Makefiles `##@ Gruppe` und `target: … ## Beschreibung`,
# showMakeHints liest `## Titel` und `Beschriftung<TAB>Wert` von stdin. Beide geben
# über die Theme-Helfer aus tools.lib.sh aus (printThemeHeading, printThemeRow,
# printThemeValue, themeMark), also in denselben Spalten wie die Hilfe eines
# Skripts. Am Terminal mit Farben, in einer Pipe und mit NO_COLOR ohne.
#
# Texte aus den Dateien, aus --set und von stdin werden nur ausgegeben, nie
# ausgewertet: $(…), Backticks, Apostrophe und Backslashes erscheinen wörtlich.
#
# Einbinden:
#     if [[ "${__MAKE_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/make.lib.sh"; fi
#
# Usage (im Makefile, Dateinamen über die Umgebung):
#     export HELP_FILES = $(value MAKEFILE_LIST)
#     help:
#         @source "$${BASH_LIBS}/make.lib.sh" && showMakeHelp $${HELP_FILES}
#
#------------------------------------------------------------------------------

# shellcheck source=SCRIPTDIR/tools.lib.sh
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

# Endet eine Beschreibung so, steht dafür die Markierung [Maintainer] in der Rolle C_MARK.
readonly MAKE_MAINTAINER_SUFFIX=" — Maintainer"

# Hilfe aus Makefiles: Gruppen (`##@ Gruppe`) als Überschrift, Targets mit
# `## Beschreibung` als Zeile. Zuweisungen (NAME := …) und Targets ohne `##`
# zählen nicht. Eine Beschreibung, die auf „ — Maintainer“ endet, bekommt die
# Markierung [Maintainer]; {NAME} ersetzt der Wert aus --set NAME=WERT,
# unbekannte Platzhalter bleiben stehen. Die Ausgabe endet mit einer Leerzeile.
#
# Usage:
#     showMakeHelp Makefile
#     showMakeHelp --set "minor=0.4.0 → 0.5.0" Makefile extra.mk
#
# Params:
#     --set NAME=WERT   Wert für den Platzhalter {NAME}; NAME aus A-Z, a-z, 0-9, _
#     $@                Makefiles in der Reihenfolge der Ausgabe (etwa MAKEFILE_LIST)
#
# Exit:
#     0  Hilfe ausgegeben
#     1  eine Datei ist nicht lesbar (dann ohne Ausgabe)
#     2  Aufruf falsch: --set ohne NAME=WERT oder keine Datei
#
showMakeHelp() {
    local -A _values=()
    local -a _files=()
    local _file _line _setting _target _description _maintainer
    local -r _GROUP='^##@[[:space:]]*(.*)$'
    local -r _TARGET='^([A-Za-z0-9_-]+):(.*)$'

    while (( $# > 0 )); do
        case "${1}" in
            --set)
                _setting="${2-}"
                if [[ ! ${_setting} =~ ^[A-Za-z0-9_]+= ]]; then
                    printf 'showMakeHelp: NAME=WERT erwartet, war %s\n' "${_setting}" >&2
                    return 2
                fi
                _values["${_setting%%=*}"]="${_setting#*=}"
                shift 2
                ;;
            --)
                shift
                _files+=("$@")
                break
                ;;
            *)
                _files+=("${1}")
                shift
                ;;
        esac
    done
    if (( ${#_files[@]} == 0 )); then
        printf 'showMakeHelp: keine Datei angegeben\n' >&2
        return 2
    fi
    for _file in "${_files[@]}"; do
        if [[ ! -f ${_file} || ! -r ${_file} ]]; then
            printf 'showMakeHelp: %s ist nicht lesbar\n' "${_file}" >&2
            return 1
        fi
    done

    for _file in "${_files[@]}"; do
        while IFS= read -r _line || [[ -n ${_line} ]]; do
            _line="${_line%$'\r'}"
            if [[ ${_line} =~ ${_GROUP} ]]; then
                printThemeHeading "$(makeEscape "$(makeTrim "${BASH_REMATCH[1]}")")"
            elif [[ ${_line} =~ ${_TARGET} && ${BASH_REMATCH[2]} != =* \
                    && ${BASH_REMATCH[2]} == *"## "* ]]; then
                _target="${BASH_REMATCH[1]}"
                _description="$(makeTrim "${BASH_REMATCH[2]#*"## "}")"
                _maintainer=""
                if [[ ${_description} == *"${MAKE_MAINTAINER_SUFFIX}" ]]; then
                    _description="${_description%"${MAKE_MAINTAINER_SUFFIX}"}"
                    _maintainer=" $(themeMark "[Maintainer]")"
                fi
                printThemeRow "${_target}" "$(makeEscape "$(makeFill _values "${_description}")")${_maintainer}"
            fi
        done < "${_file}"
    done
    echo
}

# Hinweiszeilen von stdin: `## Titel` wird Überschrift, `Beschriftung<TAB>Wert`
# eine Zeile mit dem Wert in der Rolle C_VAL, der nie umbricht. Eine Zeile ohne
# TAB ist eine Beschriftung ohne Wert; leere Zeilen zählen nicht. Die Ausgabe
# endet mit einer Leerzeile.
#
# Usage:
#     printf '%s\t%s\n' "Vor dem Commit" "make check" | showMakeHints
#     { printf '## %s\n' Links; printf '%s\t%s\n' Repository "${url}"; } | showMakeHints
#
showMakeHints() {
    local _line _label _value
    while IFS= read -r _line || [[ -n ${_line} ]]; do
        _line="${_line%$'\r'}"
        if [[ ${_line} == "## "* ]]; then
            printThemeHeading "$(makeEscape "$(makeTrim "${_line#"## "}")")"
        elif [[ -n ${_line//[[:space:]]/} ]]; then
            _label="${_line%%$'\t'*}"
            _value=""
            [[ ${_line} == *$'\t'* ]] && _value="${_line#*$'\t'}"
            printThemeValue "$(makeEscape "$(makeTrim "${_label}")")" "$(makeEscape "$(makeTrim "${_value}")")"
        fi
    done
    echo
}

# Ersetzt {NAME} durch den Wert aus dem assoziativen Array $1; unbekannte
# Platzhalter bleiben, wie sie sind. Werte werden nicht erneut durchsucht.
#
# Params:
#     $1 - Name eines assoziativen Arrays NAME → WERT
#     $2 - Text mit Platzhaltern
makeFill() {
    local -n _fillValues="${1}"
    local _rest="${2}" _result="" _after
    local -r _NAME='^([A-Za-z0-9_]+)\}(.*)$'
    while [[ ${_rest} == *"{"* ]]; do
        _result+="${_rest%%"{"*}"
        _after="${_rest#*"{"}"
        if [[ ${_after} =~ ${_NAME} ]]; then
            if [[ -v "_fillValues[${BASH_REMATCH[1]}]" ]]; then
                _result+="${_fillValues[${BASH_REMATCH[1]}]}"
            else
                _result+="{${BASH_REMATCH[1]}}"
            fi
            _rest="${BASH_REMATCH[2]}"
        else
            _result+="{"
            _rest="${_after}"
        fi
    done
    printf '%s' "${_result}${_rest}"
}

# Verdoppelt Backslashes: Die Theme-Helfer geben Text mit printf %b aus, ein
# Backslash im Text erscheint so wörtlich.
#
# Params:
#     $1 - Text
makeEscape() {
    local _rest="${1}" _result=""
    while [[ ${_rest} == *\\* ]]; do
        _result+="${_rest%%\\*}\\\\"
        _rest="${_rest#*\\}"
    done
    printf '%s' "${_result}${_rest}"
}

# Entfernt Leerraum am Anfang und Ende.
#
# Params:
#     $1 - Text
makeTrim() {
    local _text="${1}"
    _text="${_text#"${_text%%[![:space:]]*}"}"
    printf '%s' "${_text%"${_text##*[![:space:]]}"}"
}
