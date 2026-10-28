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

# Files bzw. Dirs die für die Tests
# benötigt werden
mkdir -p "samples"
mkdir -p "dist"
echo -e "{\n    \"name\": \"@mmit/auth\"\n}" > "package.json"

# Test eines invaliden packages:
# echo -e "dkdkdjk" > "package.json"
# rm -f package.json
# touch package.json

#------------------------------------------------------------------------------
# Einbinden der globalen Build-Lib
#   Hier sind z.B. Farben, generell globale VARs und Funktionen definiert
#

testImports() {
    LIBS=(
        # Muss ganz oben stehen da sonst
        # checkStatus nicht bekannt ist!
        "test.lib.sh"

        # Colors wird von einigen Libs benötigt
        "colors.lib.sh"

        "styles.lib.sh"

        "apps.lib.sh"
        
        # dtime pass hier da "build" indirekt "tools" einbindet und die
        # bindet "dtime" ein.
        "dtime.lib.sh"

        "build.lib.sh"
        # "tools.lib.sh"
        "docker.lib.sh"
        # "logging.lib.sh"
        # "os.lib.sh"
        "net.lib.sh"
        "samples.lib.sh"
        # "tools.lib.sh"
        "version.lib.sh"
        "fs.lib.sh"
        "webapp.lib.sh"

    )

    for LIB in "${LIBS[@]}"
    do
        . "${BASH_LIBS}/${LIB}" #> /dev/null
        checkStatus ${?} "${LIB}"
    done

}

testImports
