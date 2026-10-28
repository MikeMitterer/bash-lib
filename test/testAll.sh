#!/usr/bin/env bash

# CI_HOSTNAME muss in .bashrc gesetzt werden. ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

APPNAME="`basename $0`"
APPGROUP="bashtest"

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname ${SCRIPT}`

#------------------------------------------------------------------------------
# Set WORKSPACE
#
cd ${SCRIPTPATH}

#------------------------------------------------------------------------------
# Einbinden der globalen Build-Lib
#   Hier sind z.B. Farben, generell globale VARs und Funktionen definiert
#

if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

#------------------------------------------------------------------------------
# Test
#

FILES=_test*.sh
for FILE in ${FILES}
do
    if test "${FILE}" != "${APPNAME}"
    then
        echo
        echo -e "Processing ${INFO}${FILE}${NC}..."
        ./"${FILE}"
    fi
done
