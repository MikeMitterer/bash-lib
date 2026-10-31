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

APPNAME="$(basename "$0")"
APPGROUP="bashtest"

SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")

#------------------------------------------------------------------------------
# Set WORKSPACE
#
cd "${SCRIPTPATH}"

#------------------------------------------------------------------------------
# Precondition
#

# Wird von build.lib.sb benötigt
NAMESPACE="mikemitterer"
NAME="xenial"

mkdir -p "samples"

#------------------------------------------------------------------------------
# Erster Test ist das Einbinden der LIBs
#

if [ -z ${TEST_LIB+x} ]; then
    readonly TEST_LIB="test.lib.sh"; . "${BASH_LIBS}/${TEST_LIB}"
fi

if [ -z ${BUILD_LIB+x} ]; then
    readonly BUILD_LIB="build.lib.sh"; . "${BASH_LIBS}/${BUILD_LIB}"
fi

#------------------------------------------------------------------------------
# Test
#

testBuildFunctions() {

    toClipboard "Test" >> /dev/null
    checkStatus ${?} "toClipboard 'Test'"
}

testBuildFunctions
