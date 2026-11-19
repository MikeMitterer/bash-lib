#!/usr/bin/env bash
readonly __APPS_LIB__="apps.lib.sh";

#------------------------------------------------------------------------------
# Definiert die Pfade der in den Scripts verwendeten Applikationen
#
# Für Agenten (bashlib --skill):
#     Zweck:   Feste Pfade der verwendeten Werkzeuge (`JQ`, `FIND`, `CLIPBOARD` …) und Prüfung, ob ein Befehl da ist
#     Wann:    ein Skript braucht ein externes Werkzeug oder soll mit Hinweis abbrechen, wenn es fehlt
#     Wichtig: requireCommand, checkIfToolIsAvailable, searchToolInPath, JQ, FIND
#
# Einbinden:
#     if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Verwendete Tools

if [[ "${__OS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/os.lib.sh"; fi
if [[ "${__LOGGING_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/logging.lib.sh"; fi
# shellcheck source=SCRIPTDIR/cli.lib.sh
if [[ "${__CLI_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/cli.lib.sh"; fi

# Commandline-Tools die in den Scripts Verwendung finden
#
# Werden diese Tools über Cron ausgeführt benötigt "cron" vollen
# Felsplattenzugriff!
#
# Usage:
#     checkIfToolIsAvailable "${TREE}"
#     checkIfToolIsAvailable "${RSYNC}"
#     checkIfToolIsAvailable "${TS}" "brew install moreutils" "apt install moreutils"
checkIfToolIsAvailable() {
    local CMD=${1?checkIfToolIsAvailable must have at least one Parameter: CMD!}
    local INSTALL_MAC="${2-brew install $(basename "${CMD}")}"
    local INSTALL_LINUX="${3-apt install $(basename "${CMD}")}"

    if [[ ! -f "${CMD}" && ! -L  "${CMD}" ]]; then {
        echo
        echo -e "${RED}Could not find '${CMD}' command!${NC}";
        echo -e "    Install '$(basename "${CMD}")' via '${YELLOW}${INSTALL_MAC}${NC}'";
        echo -e "    or via '${YELLOW}${INSTALL_LINUX}${NC}'";
        echo
        exit 255
    } fi

    debug "'${YELLOW}${CMD}${NC}' will be used in script and is available!"
}

searchToolInPath() {
    local APP_NAME=${1?searchToolInPath must have at least one Parameter: APP_NAME!}; shift
    local LOCATIONS=("$@")

    local FILE_FOUND=""
    for LOCATION in "${LOCATIONS[@]}"; do
        # echo "L $LOCATION"
        [[ -f "${LOCATION}" || -L "${LOCATION}" ]] && FILE_FOUND="${LOCATION}" && break
    done
    if [[ "${FILE_FOUND}" == "" ]]; then
        # echo 
        # echo -e "${RED}Could not find ${LOCATION} '"${APP_NAME}"'! Check your tools.lib.sh${NC}" 
        echo "${APP_NAME}"
        #echo
        exit 255    
    fi    
    echo "${FILE_FOUND}"
}

# Nur zum Testen ob die Tools gefunden werden
# Usage:
#    checkIfToolIsAvailable "${NOT_AVAILABLE}"
readonly NOT_AVAILABLE="/usr/bin/not_available"

#set +e
#
# Sollte hier ein weiterer Eintrag dazukommen, muss der Eintrag auch bei den
# Tests (_testTools.sh) eingetragen werden!
#
readonly AWK="/usr/bin/awk"

# https://github.com/sharkdp/bat
readonly BAT_LOCATIONS=( "/usr/local/bin/bat" "/opt/homebrew/bin/bat" "/usr/bin/batcat" )
readonly BAT=$(searchToolInPath "bat | batcat" "${BAT_LOCATIONS[@]}")

readonly CURL="/usr/bin/curl"

readonly CLIPBOARD_LOCATIONS=( "/usr/bin/pbcopy" "/opt/homebrew/bin/pbcopy" "/usr/bin/xclip" )
readonly CLIPBOARD=$(searchToolInPath "pbcopy | xclip" "${CLIPBOARD_LOCATIONS[@]}")


# brew install findutils
readonly FIND_LOCATIONS=( "/usr/local/bin/gfind" "/opt/homebrew/bin/gfind" "/usr/bin/find" )
readonly FIND=$(searchToolInPath "gfind | find" "${FIND_LOCATIONS[@]}")

readonly GREP="$([[ -f /usr/bin/grep ]] && echo "/usr/bin/grep" || echo "/bin/grep" )"

readonly JQ_LOCATIONS=( "/usr/local/bin/jq" "/opt/homebrew/bin/jq" "/usr/bin/jq" )
readonly JQ=$(searchToolInPath "jq" "${JQ_LOCATIONS[@]}")

readonly NMAP_LOCATIONS=( "/usr/local/bin/nmap" "/opt/homebrew/bin/nmap" "/usr/bin/nmap" )
readonly NMAP=$(searchToolInPath "nmap" "${NMAP_LOCATIONS[@]}")

readonly REALPATH_LOCATIONS=( "/usr/local/bin/realpath" "/opt/homebrew/bin/realpath" "/bin/realpath" "/usr/bin/realpath" )
readonly REALPATH=$(searchToolInPath "realpath" "${REALPATH_LOCATIONS[@]}")

readonly RSYNC="$([[ -f /usr/local/bin/rsync ]] && echo "/usr/local/bin/rsync" || echo "/usr/bin/rsync" )"

readonly SORT="/usr/bin/sort"

readonly TAIL="/usr/bin/tail"

readonly TEE="/usr/bin/tee"

readonly TREE_LOCATIONS=( "/usr/local/bin/tree" "/opt/homebrew/bin/tree" "/usr/bin/tree" )
readonly TREE=$(searchToolInPath "tree" "${TREE_LOCATIONS[@]}")

# TimeStamp
readonly TS_LOCATIONS=( "/usr/local/bin/ts" "/opt/homebrew/bin/ts" "/usr/bin/ts" )
readonly TS=$(searchToolInPath "ts" "${TS_LOCATIONS[@]}")

# pip3 install TxtStyle
#
# Config ist unter:
#     ~/.txts.conf
#
# Weitere Infos:
#     https://github.com/armandino/TxtStyle
#
readonly TXTS_LOCATIONS=( "/usr/local/bin/txts" "/opt/homebrew/bin/txts" "${HOME}/.local/bin/txts" )
readonly TXTS=$(searchToolInPath "txts" "${TXTS_LOCATIONS[@]}") 

#set -e

# Prüft, ob der Befehl $1 im PATH ist; fehlt er, steht „✗ BEFEHL fehlt“ und darunter der
# Hinweis $2 (etwa Installationsbefehl oder URL) auf stderr. Das Skript endet nicht;
# anders als checkIfToolIsAvailable, das einen Dateipfad prüft und mit exit 255 endet.
#
# Usage:
#     requireCommand pipx "https://pipx.pypa.io" || exit 1
#
# Exit:
#     0  vorhanden (keine Ausgabe)
#     1  fehlt (Meldung auf stderr)
#     2  Aufruf falsch: BEFEHL oder HINWEIS fehlt
#
requireCommand() {
    if (( $# != 2 )) || [[ -z ${1} || -z ${2} ]]; then
        printf 'requireCommand: BEFEHL HINWEIS erwartet\n' >&2
        return 2
    fi
    command -v "${1}" >/dev/null 2>&1 && return 0
    {
        printThemeStatus "✗" "${1} fehlt" ERR
        printThemeHint "$(themeEscape "${2}")"
    } >&2
    return 1
}
