#!/usr/bin/env bash

# CI_HOSTNAME muss in .bashrc gesetzt werden. ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if [[ -z ${CI_HOSTNAME+x} ]]; then echo "Var 'CI_HOSTNAME' nicht gesetzt!"; exit 1; fi
if [[ -z ${BASH_LIBS+x} ]]; then echo "Var 'BASH_LIBS' nicht gesetzt!"; exit 1; fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Abbruch bei Problemen (https://goo.gl/hEEJCj)
#
# Wenn ein Fehler nicht automatisch zu einem exit führen soll dann
# kann 'command || true' verwendet werden
#
# Für die $1, $2 Abfragen kann 'CMDLINE=${1:-}' verwendet werden
#
# -e Any subsequent(*) commands which fail will cause the shell script to exit immediately
# -o pipefail sets the exit code of a pipeline to that of the rightmost command
# -u treat unset variables as an error and exit
# -x print each command before executing it
set -eou pipefail

readonly APPNAME="$(basename "$0")"
readonly APPGROUP="bashtest"

readonly SCRIPT=$(realpath "$0")
readonly SCRIPTPATH=$(dirname "${SCRIPT}")

#------------------------------------------------------------------------------
# Set WORKSPACE
#
cd "${SCRIPTPATH}"

#------------------------------------------------------------------------------
# Precondition
#

# Wird von build.lib.sb benötigt
readonly NAMESPACE="mikemitterer"
readonly NAME="xenial"

mkdir -p "samples"

#------------------------------------------------------------------------------
# Erster Test ist das Einbinden der LIBs
#

if [ -z ${TEST_LIB+x} ]; then
    readonly TEST_LIB="test.lib.sh"; . "${BASH_LIBS}/${TEST_LIB}"
fi

if [ -z ${TOOLS_LIB+x} ]; then
    readonly TOOLS_LIB="tools.lib.sh"; . "${BASH_LIBS}/${TOOLS_LIB}"
fi

if [[ "${__APPS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/apps.lib.sh"; fi
if [[ "${__VERSION_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/version.lib.sh"; fi

if [[ "${__LOGGING_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/logging.lib.sh"; fi

LOG_VERBOSITY=$((LOG_LEVEL_DEBUG))
exec 3>&1; trap 'exec 1>&3' EXIT HUP INT QUIT RETURN

#------------------------------------------------------------------------------
# Test
#


testToolsFunctions() {

    colorGreen "Test" >> /dev/null
    checkStatus ${?} "colorGreen 'Test'"

    colorError "Test" >> /dev/null
    checkStatus ${?} "colorError 'Test'"

    showDevVersion >> /dev/null
    checkStatus ${?} "showDevVersion"
}

testTools() {
    echo
    checkIfToolIsAvailable "${AWK}"
    checkIfToolIsAvailable "${BAT}" "brew install bat" "apt install bat"
    checkIfToolIsAvailable "${CLIPBOARD}"
    checkIfToolIsAvailable "${CURL}"
    checkIfToolIsAvailable "${FIND}" "brew install findutils"
    checkIfToolIsAvailable "${GREP}"
    checkIfToolIsAvailable "${JQ}"
    checkIfToolIsAvailable "${NMAP}"
    checkIfToolIsAvailable "${REALPATH}"
    checkIfToolIsAvailable "${RSYNC}"
    checkIfToolIsAvailable "${SORT}"
    checkIfToolIsAvailable "${TEE}"
    checkIfToolIsAvailable "${TREE}"
    checkIfToolIsAvailable "${TS}" "brew install timestamp" "apt install moreutils"
    checkIfToolIsAvailable "${TXTS}" "pipx install TxtStyle" "pipx install TxtStyle"
    echo
}

testToolsFunctions
testTools
