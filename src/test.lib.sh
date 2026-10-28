#!/usr/bin/env bash
readonly __TEST_LIB__="test.lib.sh";

#------------------------------------------------------------------------------
# Einige Funktionen die für die BAST-Tests benötigt werden
#
# Einbinden:
#     if [[ "${__TEST_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/test.lib.sh"; fi
#
#------------------------------------------------------------------------------

# BASH_LIBS muss in .bashrc gesetzt werden. ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if [[ -z ${BASH_LIBS+x} ]]; then echo "Var 'BASH_LIBS' nicht gesetzt!"; exit 1; fi
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# "Colors" wird nicht eingebunden damit beim Testen keine weiteren
# Abhängigkeiten entstehen!

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SUCCESS=${GREEN}
FAILED=${RED}

# Überprüft den Status eines vorhergehenden Functions-Calls
#
# Usage:
#    toClipboard "Test" >> /dev/null
#    checkStatus ${?} "toClipboard 'Test'"
#
checkStatus() {
    local STATUS=${1}
    local FUNCTION="${2}"

    if [[ ${STATUS} -eq 0 ]]; then
        echo -e "\t${SUCCESS}OK    ${NC}\tCalling ${FUNCTION} works!"
    else
        echo -e "\t${FAILED}FAILED${NC}\tCalling ${FUNCTION} failed!"
        exit 1
    fi
}
