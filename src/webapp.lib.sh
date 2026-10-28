#!/usr/bin/env bash
readonly __WEBAPP_LIB__="webapp.lib.sh";

#------------------------------------------------------------------------------
# Lib zum publishen von (Node / TS) Applikationen
# Einbinden:
#     if [[ "${__WEBAPP_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/webapp.lib.sh"; fi
#
#------------------------------------------------------------------------------

if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi
if [[ "${__FS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/fs.lib.sh"; fi

#------------------------------------------------------------------------------
# BASIS

DOW=$(date +"%u")
readonly PUBLISH_ONLY_ON_DAY=1

readonly PREP_SCRIPT=".prep.kts"
readonly PREP_PROPERTIES=".prep.config.properties"

readonly DEPLOY_DIR=".deploy"

# defined in ~/.ssh/config
readonly RSYNC_HOST="ls2"
readonly RSYNC_SETTINGS=".rsync"

# Per default sollten die Beispiele in 'examples' sein
WEBAPP_FOLDERS_TO_TEST=(
    "dist"
)

WEBAPP_FOLDER_FOUND="false"
for WEBAPP_FOLDER in ${WEBAPP_FOLDERS_TO_TEST[@]}
do
    if [[ -d ${WEBAPP_FOLDER} ]]; then
        WEBAPP_FOLDER_FOUND="true"
        break
    fi
done

if [[ ${WEBAPP_FOLDER_FOUND} == "false" ]]; then
    TESTED_FOLDERS=$(printf "'%s' " "${WEBAPP_FOLDERS_TO_TEST[@]}")

    echo -e "None of the Examples-Folders ${ERROR}${TESTED_FOLDERS}${NC}does exist!"
    exit 1
fi

if [[ ! -f "package.json" ]]; then
    echo -e "${ERROR}Could not find a 'package.json'!${NC}"
    exit 1
fi

# Ohne diesen "hack" crasht grep ohne dass das Script
# mit einem nennenswerten Fehler beendet wird!!!!
#     https://unix.stackexchange.com/a/427598/539922
#
PACKAGE_NAME=`\grep "name" package.json || [[ $? != 0 ]]`
if [[ ${PACKAGE_NAME} == "" ]]; then
    echo -e "${ERROR}Not a valid NODE package. Could not find a \"name\" in package.json!${NC}"
    exit 1
fi
NODE_MODULE=$(echo "${PACKAGE_NAME}" | sed -e 's/.*"name":[^"]*"\([^"]*\)".*/\1/g')
NODE_MODULE_RAW=$(echo "${NODE_MODULE}" | sed -e 's/[^/]*\///g')

RSYNC_DESTINATION='not set!'
if [[ -f "${RSYNC_SETTINGS}" ]]; then
    . "${RSYNC_SETTINGS}"
fi

#------------------------------------------------------------------------------
# Functions
#

#
# Erstellt das .rsync-File im WebApp-Folder
#
#   Usage:
#        generateRsyncSettingForWebApp "${WEBAPP_NAME}" "${RSYNC_SETTINGS}" force
#        generateRsyncSettingForWebApp "${WEBAPP_NAME}" "${RSYNC_SETTINGS}"
#
#   cmdline:
#        deployWebApp.sh -g --force
#
generateRsyncSettingForWebApp() {
    local APP_NAME=${1}
    local RSYNC_FILE=${2}
    local FORCE=${3-""}

    # Check if .rsync-File exists
    if [[ -f "${RSYNC_FILE}" && ${FORCE} != "force" ]]; then
        echo -e "\t${GREEN}RSYNC-Setting for ${RSYNC_FILE} already exists!${NC}"
        exit
    fi

    echo
    echo -e "\tName:     ${APP_NAME}"

    local TEMPLATE="# Rsync-Destination für dieses sample
                    #
                    #   - ssh ${RSYNC_HOST}
                    #   - cat ~/website/config/nginx/_template.conf.txt | sed -e 's/%example%/${APP_NAME}/' > ~/website/config/nginx/${APP_NAME}.conf
                    #   - cat ~/website/config/nginx/${APP_NAME}.conf
                    #   - sudo mkdir -p ~/website/data/example/${APP_NAME}
                    #   - sudo chown ubuntu:ubuntu ~/website/data/example/${APP_NAME}
                    #   - sudo chmod 775 ~/website/data/example/${APP_NAME}
                    #   - echo '${APP_NAME}' > ~/website/data/example/${APP_NAME}/index.html
                    #   - ls -lad ~/website/data/example/${APP_NAME}
                    #   - cd ~/website && docker-compose restart
                    #

                    RSYNC_DESTINATION=\":~/website/data/example/${APP_NAME}/\"
                    EXAMPLE_URL=\"http://${APP_NAME}.example.mikemitterer.at/\"
                    "

    echo -e "${TEMPLATE}" | sed -e 's/^[ \t]*//' > "${RSYNC_FILE}"

    echo -e "\t${GREEN}${RSYNC_FILE} created${NC}"
    echo
}

# Zeigt die URLs aus RSYNC an
#
# Argumente:
#   RSYNC_FILE - Der Pfad zur RSYNC-Einstellungsdatei.
#
# Diese Funktion überprüft, ob die RSYNC-Einstellungsdatei existiert.
# Wenn sie existiert, extrahiert sie die URL aus der 15. Zeile der Datei,
# verarbeitet sie, um die Domain zu extrahieren, und gibt die URL in einem formatierten Format aus.
listURLsForWebApp() {
    local RSYNC_FILE=${1}

    # Überprüfen, ob die RSYNC-Einstellungsdatei existiert
    _testIfRsyncExists "${RSYNC_FILE}"

    # Extrahieren der URL aus der 15. Zeile der RSYNC-Datei, Verarbeiten zur Extraktion der Domain
    local URL=$(awk 'FNR==15' "${RSYNC_FILE}" | cut -d ' ' -f 5- | sed -e "s/.*http:\/\/\([^/]*\)\/.*/http:\/\/\1/")

    # Ausgabe der formatierten URL
    echo -e "\t${GREEN}${URL}${NC}"
    echo
}


# Zeigt die URLs aus RSYNC im README-Format an
listURLs4ForWebAppREADME() {
    local RSYNC_FILE=${1}

    _testIfRsyncExists "${RSYNC_FILE}"

    local URL=$(awk 'FNR==15' "${RSYNC_FILE}" | cut -d ' ' -f 5- | sed -e "s/.*http:\/\/\([^/]*\)\/.*/- \[\1\]\(http:\/\/\1\)/")

    echo -e "\t${GREEN}${URL}${NC}"
    echo
}

#
# Erstellt die links für die WebSite
#
#   Usage:
#
#   cmdline:
#
#
listURL4ForWebAppWebSite() {
    local APP_NAME=${1}
    local APP_DESCRIPTION=$2;
    local NODE_MODULE=$3;
    local RSYNC_FILE=${4}

    _testIfRsyncExists "${RSYNC_FILE}"

    local URL=$(awk 'FNR==15' ${RSYNC_FILE} | sed "s/EXAMPLE_URL=//" | sed "s/\"//g")

    local TEMPLATE="
    <div id=\"${APP_NAME}\" class=\"liveexamples\">
        <div class=\"caption row\">
            <div class=\"col\">Node-Module</div>
            <div class=\"col\">Live - link</div>
        </div>
        <div class=\"row\">
            <div class=\"col\">
                <a href=\"https://www.npmjs.com/package/@mmit/${NODE_MODULE}\" target=\"_blank\">${APP_DESCRIPTION}</a>
            </div>
            <div class=\"col\">
                <a href=\"${URL}\" rel=\"noopener\" target=\"_blank\">Live - ${APP_NAME} example</a>
            </div>
        </div>
    </div>
    "

    echo -e "${GREEN}${TEMPLATE}${NC}"
    echo
}

#
# Zeigt den Script-Teil von .rsync an
#
showRsyncScript() {
    local RSYNC_FILE=${1}

    _testIfRsyncExists "${RSYNC_FILE}"

    cat "${RSYNC_FILE}" | \grep -e "^#   -" | sed -e "s/#   - /   /g"
    echo
}

#
# Rsync zu Amazon Light-Sail
#
deployWebApp() {
    local RSYNC_FILE=${1}
    local DRY_RUN=${2-""}

    _testIfRsyncExists "${RSYNC_FILE}"

    local PREFIX=""

    # --progress
    # -a - archive mode; equals -rlptgoD
    # -J -
    if [[ ${DRY_RUN} == "dry-run" ]]; then
        PREFIX="echo"
    fi

    ${PREFIX} rsync -e "ssh ${RSYNC_HOST}" -a -J --delete ./${WEBAPP_FOLDER}/ ${RSYNC_DESTINATION}
    echo -e "${GREEN}Done!${NC}"

    listURLsForWebApp "${RSYNC_FILE}"
}


# Wenn das .rsync-File nicht existiert
# wird das Script mit einer Fehlermeldung beendet
_testIfRsyncExists() {
    local RSYNC_FILE=${1}

    # Check if .rsync-File exists
    if [[ ! -f "${RSYNC_FILE}" ]]; then
        echo -e "\t${ERROR}No RSYNC-Setting for ${APP_NAME}!${NC}"
        exit
    fi
}
