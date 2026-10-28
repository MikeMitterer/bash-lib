#!/usr/bin/env bash
readonly __BUILD_LIB__="build.lib.sh";

# DOCKER (wird benötigt damit docker aus Gradle heraus funktioniert!)
export PATH="${PATH}:/usr/local/bin:~/bin"

#------------------------------------------------------------------------------
# Einbinden der globalen Build-Lib
#   Hier ist z.b. "CLIPBOARD" definiert
#
# Einbinden:
#     if [[ "${__BUILD_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/build.lib.sh"; fi


if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi

# --------------------------------------------------------------------------------------------------
# Funktionen und VARs die in allen Build-Scripts verwendet werden
#

#------------------------------------------------------------------------------
# Global VARs

#------------------------------------------------------------------------------
# Functions
#

declare -a samples=()

# Vars müssen im Haupt-Script gesetzt worden sein!
if [[ -z ${NAMESPACE+x} ]]; then echo "Var 'NAMESPACE' nicht gesetzt!"; exit 1; fi
if [[ -z ${NAME+x} ]]; then echo "Var 'NAME' nicht gesetzt!"; exit 1; fi

# Zeigt das/die entsprechende(n) Images an (Lokal bzw. für Amazon)
#
# Anstatt | head -n 10 wird sed verwendet da der zweite "head-Aufruf"
# beim Amazon-Teil nicht funktioniert...???
#
# Usage:
#   showImages ${_TAG} ${_NAMESPACE} ${_NAME} ${_AMAZON_REPO_URI}
#
showImages() {
    local _TAG=$1
    local _NAMESPACE=$2
    local _NAME=$3
    local _AMAZON_REPO_URI=${4:-'not-set'}

    echo
    echo -e "Latest _TAG:   ${GREEN}${_TAG}${NC}"
    echo

    echo -e "Image:         ${GREEN}${_NAMESPACE}/${_NAME}${NC}"
    # Eliminiert das Warning:
    #   "WARNING: This output is designed for human readability. For machine-readable output, please use --format.
    docker images "${_NAMESPACE}/${_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | sed -n 1,10p
    echo

    if [[ "${_AMAZON_REPO_URI}" != "not-set" ]]; then
        echo -e "Amazon:        ${LIGHT_GREEN}${_AMAZON_REPO_URI}/${_NAME}${NC}"
        docker images "${_AMAZON_REPO_URI}/${_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" | sed -n 1,10p
        echo
    fi
}

showSamples() {
    echo
    echo -e "Docker-Image:    ${GREEN}${NAMESPACE}/${NAME}${NC}"
    echo

    echo "Samples:"

    # get length of an array
    length=${#samples[@]}

    # use for loop to read all values and indexes
    for (( index=0; index<${length}; index++ ));
    do
        TEMP=$(
        echo -e "${samples[$index]}" | \
            sed "s/^# /${SED_YELLOW}[$index]${SED_NC} /g" | \
            sed "s/\|\|/${SED_GREEN}/g" | \
            sed "s/\[deprecated\]/${SED_RED}\[deprecated\]${SED_NC}/g"
        )

        echo -e -n "\t"
        echo -e -n "$TEMP"
        echo -e -n "${NC}"

        echo -e "\n\n"
    done

    # Read input
    echo -e -n "Copy command to clipboard! Enter the ${YELLOW}sample-number${NC}: "
    read sample_id
    if [[ $((sample_id+0)) -lt $((length+0)) ]]
    then
        toClipboard "${samples[sample_id + 0]}";
    fi
}

toClipboard() {
    local _VALUE=$1

    # SED1 - Alles löschen bis zum Pipe (Markiert das Ende der ersten Zeile
    # SED2 - \t's und blanks löschen

    # TR - Newline wird gelöscht damit das Command beim einfügen nicht gleich
    # ausgeführt wird

    echo "${_VALUE}" \
        | sed -E "s/#[^|]*\|\|//g" \
        | sed "s/\\\t//g; s/\\\//g; s/[ ]\{1,\}/ /g; ; s/^ //g;" \
        | tr -d '\n' \
        | ${CLIPBOARD}
}

# Im aktuellen Verzeichnis wird das Tag-File mit der Version 0.1 angelegt
# Es wird auch die globale Variable '_TAG' neu gesetzt
prepareTagFile() {
    local _TAGFILE="$1"
    local _DATE=$(date "+%A, %F %T %z")

    # BashScript - aus Tools
    _TAG=$(gitVersion)

    #if [ ! -f "${_TAGFILE}" ];
    #then

    echo "# ${_DATE}" > "${_TAGFILE}"
    echo >> "${_TAGFILE}"
    echo "tag=${_TAG}" >> "${_TAGFILE}"

    #fi
}

# Es wird überprüft ob das letzte Login länger als 12 Stunden her ist
#
# Die Maximalzeit kann übergeben werden (in Minuten)
#
# Usage:
#    local _LOGIN_TO_OLD=$(checkLastLogin 2)
#
#    if [[ $_LOGIN_TO_OLD == true ]]; then
#        echo "Login ist zu alt!"
#        # Update des Markers
#        date > ".last_login"
#    else
#        echo "Login ist ok!"
#    fi
#
# Parameter:
#   $1 - Maximale Zeit in Minuten
#
checkLastLogin() {
    local _MAX_MIN=${1:=$(( 12 * 60 ))}

    local _LOGIN_TO_OLD=true

    if [[ -f ".last_login" ]]; then
        local _NOW=$(date +%s)

        if [[ "${MACHINE}" == "Mac" ]]; then
            local _LAST_LOGIN_TIME=$(stat -f "%m" ".last_login")
        else
            local _LAST_LOGIN_TIME=$(stat --format "%Y" ".last_login")
        fi

        local _DIFF_MIN=$(( (_NOW - _LAST_LOGIN_TIME) / 60 ))
        # local _MAX_MIN=$(( 12 * 60 ))

        if [[ $_DIFF_MIN -lt $_MAX_MIN ]]; then
            _LOGIN_TO_OLD=false
        fi
    fi
    echo $_LOGIN_TO_OLD
}

