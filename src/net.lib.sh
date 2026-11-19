#!/usr/bin/env bash
# tools.lib.sh bindet net.lib.sh ein; ein zweites . net.lib.sh ohne
# Guard bricht sonst an readonly ab.
[[ -z "${__NET_LIB__:-}" ]] || return 0
readonly __NET_LIB__="net.lib.sh";

#------------------------------------------------------------------------------
# Alle IP + Netz-Spezifischen Funktionen
#
# Für Agenten (bashlib --skill):
#     Zweck:   IP- und Netzfunktionen
#     Wann:    interne IP oder die IP eines Hosts ermitteln, prüfen, ob ein lokaler Port offen ist
#     Wichtig: getIntIP, getIPFor, getNetworkFromIP, isLocalPortOpen
#
# Einbinden:
#     if [[ "${__NET_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/net.lib.sh"; fi
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Verwendete Tools

if [[ "${__OS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/os.lib.sh"; fi

# Die interne IP wird geholt (Am Mac entweder von en0 oder en7)
#
# Usage:
#     readonly INT_IP=$(getIntIP)
#
getIntIP() {
    if [[ "${MACHINE}" == "Mac" ]]; then
      local _INT_IP_TEMP="$(ifconfig en0 | awk ' /inet.*broadcast/ { print $2 }')"

      if [[ "${_INT_IP_TEMP}" == "" ]]; then
          _INT_IP_TEMP="$(ifconfig en7 | awk ' /inet.*broadcast/ { print $2 }')"
      fi
    else
        local _INT_IP_TEMP=$(hostname -I | awk '{print $1}')
    fi

    echo "${_INT_IP_TEMP}"
}

# Der Network-Part (die ersten 3 digits) der IP wird zurückgegeben
#
# Usage:
#     readonly INT_IP=$(getIntIP)
#     readonly INT_IP_NET=$(getNetworkFromIP "${INT_IP}")
#
getNetworkFromIP() {
    local _IP=${1-}
    echo "${_IP}" | awk -F '.' '{printf("%s.%s.%s", $1,$2,$3)}'
}

# Gibt die IP für den angegebenen DNS-Namen zurück
#
# Usage:
#     readonly IP=$(getIPFor "host.example.com")
#
# Required:
#     sudo apt install dnsutils
#
getIPFor() {
    local _DNS_NAME=${1?showIPFor is missing first parameter: 'DNS_NAME'}
    local _IP_IS="$(dig +short "${_DNS_NAME}" | \grep -v '\.$')"
    local _RESULT=$?

    if [[ "${_IP_IS}" == "" ]]; then
        _IP_IS="$(host "${_DNS_NAME}" | awk '/has address.*/{ print $4 ; exit }')"
        _RESULT=$?
    fi
    if [[ "${_IP_IS}" == "" ]]; then
        if [[ "${MACHINE}" == "Mac" ]]; then
            _IP_IS="$(ping -c 1 "${_DNS_NAME}" | \grep "time=" | awk '{ print $4 }' | sed 's/://')"
        else
            _IP_IS="$(ping -c 1 "${_DNS_NAME}" | \grep "time=" | awk '{ print $5 }' | sed -e 's/[():]//g')"
        fi
        _RESULT=$?
    fi
    if [[ "${_IP_IS}" == "" ]]; then
        _IP_IS="$(nmap -sn "${_DNS_NAME}" | \grep "scan report" | sed -e 's/[^(]*(//' -e 's/).*//')"
        _RESULT=$?
    fi

    if [[ ${_RESULT} -ne 0 ]]; then
        _IP_IS="unknown"
    fi

    echo "${_IP_IS}"
}

# Prüft ob der angegebene Port offen ist
#
# Usage:
#     local _IS_PORT_APP_SERVER_OPEN=$(isLocalPortOpen "${PORT_APP_SERVER}")
#     local _MARK_APP_SERVER_PORT=$(isLocalPortOpen "${PORT_APP_SERVER}" "${GREEN}" "${RED}")
#
# Weitere Infos:
#     https://adamtheautomator.com/check-if-a-port-is-open-in-linux/
#
isLocalPortOpen() {
    local _PORT=${1?"isPortOpen must be called with one parameter: 'PORT'"}
    local _RET_IF_OPEN=${2-'true'}
    local _RET_IF_CLOSED=${3-'false'}

    if [[ "$(lsof -i -P -n | \grep LISTEN | \grep :"${_PORT}")" != "" ]];then
      echo "${_RET_IF_OPEN}";
    else
      echo "${_RET_IF_CLOSED}";
    fi
}
