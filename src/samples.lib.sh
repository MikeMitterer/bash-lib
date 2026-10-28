#!/usr/bin/env bash
readonly __SAMPLES_LIB__="samples.lib.sh";

#------------------------------------------------------------------------------
# Lib zum publishen von (Dart) samples
#
# Einbinden:
#     if [[ "${__SAMPLES_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/samples.lib.sh"; fi
#
#------------------------------------------------------------------------------

# Benötigte libs...
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

#------------------------------------------------------------------------------
# BASIS

DOW=$(date +"%u")
PUBLISH_ONLY_ON_DAY=1

PREP_SCRIPT=".prep.kts"
PREP_PROPERTIES=".prep.config.properties"

DEPLOY_DIR=".deploy"

# defined in ~/.ssh/config
RSYNC_HOST="ls2"

# Per default sollten die Beispiele in 'examples' sein
EXAMPLE_FOLDER_TO_TEST=(
    "example"
    "samples"
    "dist"
)

EXAMPLE_FOLDER_FOUND="false"
for EXAMPLE_FOLDER in ${EXAMPLE_FOLDER_TO_TEST[@]}
do
    if [[ -d ${EXAMPLE_FOLDER} ]]; then
        EXAMPLE_FOLDER_FOUND="true"
        break
    fi
done

if [[ ${EXAMPLE_FOLDER_FOUND} == "false" ]]; then
    TESTED_FOLDERS=$(printf "'%s' " "${EXAMPLE_FOLDER_TO_TEST[@]}")

    echo -e "None of the Examples-Folders ${ERROR}${TESTED_FOLDERS}${NC} does exist!"
    exit 1
fi

declare -a EXAMPLES=(
    $(find ${EXAMPLE_FOLDER} -type d -maxdepth 1 -not -path '*/\.*' -not -path '*/_*' -not -name ${EXAMPLE_FOLDER})
)

# Könnte im deploy-samples.sh-Script noch mit
#   declare -a SAMPLES=(
#       "example/browser"
#   )
# überschrieben werden


#------------------------------------------------------------------------------
# Functions
#

#
# Usage: listSamples "${SAMPLES[@]}"
#
listSamples() {
    local SAMPLES=("${@}")

    echo "Examples:"

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        # Check if .rsync-File exists
        if [[ ! -f "${SAMPLE}/.rsync" ]]; then
            echo -e "\t${RED}RSYNC-Setting for ${SAMPLE} does not exist!${NC}"

        else
            # Alte version:
            # local RSYNC_DESTINATION=$(cat "${SAMPLE}/.rsync" | sed -e "s/^#.*$//g" -e "/^$/d" | head -n 1)

            . "${SAMPLE}/.rsync"

            if [[ ! -n "${RSYNC_DESTINATION+set}" ]]; then
                echo
                echo -e "\t${RED}Could not find a valid RSYNC_DESTINATION in "${SAMPLE}/.rsync"!${NC}"
                break
            fi

            if [[ ! -n "${EXAMPLE_URL+set}" ]]; then
                echo
                echo -e "\t${RED}Could not find a valid EXAMPLE_URL in "${SAMPLE}/.rsync"!${NC}"
                break
            fi

            echo -e "\tSource: ${YELLOW}${SAMPLE}${NC}"
            echo -e "\t\tName:                      $(basename ${SAMPLE})"

            if [[ -f "${SAMPLE}/${PREP_SCRIPT}" ]]; then
                echo -e "\t\tPrep-Script:               ${GREEN}YES${NC}"
            fi

            if [[ -f "${SAMPLE}/${PREP_PROPERTIES}" ]]; then
            echo -e "\t\tPrep-Properties:           ${GREEN}YES${NC}"

                #if ! grep --quiet "pubspec.template=../../tool/templates/pubspec.tmpl.yaml" "${SAMPLE}/${PREP_PROPERTIES}"; then
                #    echo -e "\t\t${YELLOW}Uses special pubspec.yaml: ${GREEN}YES${NC}"
                #fi
            fi
        
            echo -e "\t\tRSYNC-to:                  ${RSYNC_DESTINATION}"
            echo -e "\t\tURL:                       ${BLUE}${EXAMPLE_URL}${NC}"

        echo
        fi
    done

    echo
}

#
# Usage: updateSamples "${SAMPLES[@]}"
#
updateSamples() {
    local SAMPLES=("${@}")

    echo "Update:"

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        local SAMPLE_NAME="$(basename ${SAMPLE})"
    
        echo -e "\t${YELLOW}${SAMPLE_NAME}${NC}"

        cd ${SAMPLE}
        if [[ ! -f "pubspec.yaml" ]]; then
            echo -e "\t    ${RED}no pubspec.yaml${NC}..."

            # Zurück zum Ursprung
            cd - >> /dev/null
            continue
        fi

        # if [ $(find . -name "pubspec.lock" -maxdepth 1 -mmin +$((60*24))) ]; then echo "OK"; fi
        if [[ \
            ! -f "pubspec.lock" || \
            ${OPTION1} == "--force" || \
            ${OPTION2} == "--force" || \
            $(find . -name "pubspec.lock" -maxdepth 1 -mmin +$((60*12))) || \
            "pubspec.yaml" -nt "pubspec.lock" \
            ]]; then

            # Update pub
            pub update
        else
            echo -e "\t    ${GREEN}is up to date${NC}..."
        fi

        # Zurück zum Ursprung
        cd - >> /dev/null
    done
}

#
# Usage: deploySamples "${SAMPLES[@]}"
#
deploySamples() {
    local SAMPLES=("${@}")
    local RELEASE_OPTION=""

    # Check if release-option is set
    if [[ ${OPTION1} == "--release" ||  ${OPTION2} == "--release" ]]; then
        RELEASE_OPTION="--release"
        echo "Deploy in RELEASE-Mode:"
    else
        echo "Deploy with Dev-Compiler (DEV-Mode):"
    fi

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        echo -e "\t${YELLOW}${SAMPLE}${NC}..."

        # Check if .rsync-File exists
        if [[ -f "${SAMPLE}/web/index.html" ]]; then
            cd ${SAMPLE}

            # Update pub
            # pub update

            # Set current date in index.html
            sed -i.bak -e "s#<span class=\"pubdate\">[^<]*</span>#<span class=\"pubdate\">$(date +"%Y-%m-%d / %H:%M:%S")</span>#g" web/index.html
            rm -f web/index.html.bak

            # Dart build
            rm -rf "${DEPLOY_DIR}"

            if [[ ${OPTION1} == "--release" ||  ${OPTION2} == "--release" ]]; then
                rm -rf .dart_tool
                echo -e "\t${YELLOW}'.dart_tool' removed (happens in release-mode)${NC}..."
            fi

            # --output web:deploy
            pub run build_runner build --delete-conflicting-outputs ${RELEASE_OPTION} --output web:"${DEPLOY_DIR}"

            # Zurück zum Ursprung
            cd - >> /dev/null
        else
            echo -e "\t${ERROR}${SAMPLE} has no index.html - so it's probably a cmdline-App...${NC}"
        fi

    done
}


#
# Usage: publishSamples "${SAMPLES[@]}"
#
publishSamples() {
    local SAMPLES=("${@}")

    #
    # Strings: if [ "$x" == "valid" ]; then
    #          if [ "$x" != "valid" ]; then
    # Numbers: if [ (("$x" == 99)) ]; then
    #          if [ (("$x" != 99)) ]; then
    #
    if [[ "${OPTION1}" != "--force" \
            && "${OPTION2}" != "--force" \
            && (("${DOW}" != "${PUBLISH_ONLY_ON_DAY}")) ]]; then

        echo -e "${ERROR}Sorry - today is not a publishing day.${NC}"
        echo "To force publishing use '--force'"
        exit 0
    fi

    echo "Publish:"

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        echo -e "\t${YELLOW}${SAMPLE}${NC}..."

        # Check if .rsync-File exists
        if [[ ! -f "${SAMPLE}/.rsync" ]]; then
            echo -e "\t${RED}RSYNC-Setting for ${SAMPLE} does not exist!${NC}"
            continue 
        fi

        . "${SAMPLE}/.rsync"

        if [[ ! -n "${RSYNC_DESTINATION+set}" ]]; then
            echo
            echo -e "\t${RED}Could not find a valid RSYNC_DESTINATION in "${SAMPLE}/.rsync"!${NC}"
            exit 2
        fi

        if [[ ! -n "${EXAMPLE_URL+set}" ]]; then
            echo
            echo -e "\t${RED}Could not find a valid EXAMPLE_URL in "${SAMPLE}/.rsync"!${NC}"
            exit 2
        fi


        cd ${SAMPLE}

        # Check if DIR exists
        if [[ ! -d "${DEPLOY_DIR}" ]];then
            echo -e "${ERROR}No '${DEPLOY_DIR}'-dir for ${SAMPLE}${NC}"
            exit 1
        fi

        # Sync is to slow
        # aws s3 sync --delete deploy/ s3://${S3BUCKET}

        # Copies to Amazon bucket
        # Uses 'Bucket-all-samples-for-mikemitterer.at' policy on AWS
        # e.g. aws s3 cp deploy/ s3://samples.m4d.router.mikemitterer.at --recursive
        # aws s3 rm s3://${S3BUCKET}/
        # aws s3 cp deploy/ s3://${S3BUCKET} --recursive

        # --progress
        # -a - archive mode; equals -rlptgoD
        # -J - 
        rsync -e "ssh ${RSYNC_HOST}" -a -J --delete ./${DEPLOY_DIR}/ ${RSYNC_DESTINATION}

        echo -e "\tDone! - ${BLUE}${EXAMPLE_URL}${NC}\n"

        # Zurück zum Ursprung
        cd - >> /dev/null
    done
}

#
# Erstellt das .rsync-File im jeweiligen sample Ordner
#
#   Usage:
#       generateRsyncSetting "${EXAMPLES[@]}"
#
#   cmdline:
#       ./deploy-samples.sh -p mdl_animation --force
#
generateRsyncSetting() {
    local SAMPLES=("${@}")

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        local SAMPLE_NAME="$(basename ${SAMPLE})"

        # Check if .rsync-File exists
        if [[ -f "${SAMPLE}/.rsync" && ${OPTION1} != "--force" &&  ${OPTION2} != "--force" ]]; then
            echo -e "\t${GREEN}RSYNC-Setting for ${SAMPLE} already exists!${NC}"
            continue
        fi

        echo -e "\tSource: ${YELLOW}${SAMPLE}${NC}"
        echo -e "\t\tName:     ${SAMPLE_NAME}"

        local TEMPLATE="# Rsync-Destination für dieses sample
                        #
                        #   - ssh ls2
                        #   - cat ~/website/config/nginx/_template.conf.txt | sed -e 's/%example%/${SAMPLE_NAME}/' > ~/website/config/nginx/${SAMPLE_NAME}.conf
                        #   - cat ~/website/config/nginx/${SAMPLE_NAME}.conf
                        #   - sudo mkdir -p ~/website/data/example/${SAMPLE_NAME}
                        #   - sudo chown ubuntu:ubuntu ~/website/data/example/${SAMPLE_NAME}
                        #   - sudo chmod 775 ~/website/data/example/${SAMPLE_NAME}
                        #   - echo '${SAMPLE_NAME}' > ~/website/data/example/${SAMPLE_NAME}/index.html
                        #   - ls -lad ~/website/data/example/${SAMPLE_NAME}
                        #   - cd ~/website && docker-compose restart
                        #
                        RSYNC_DESTINATION=\":~/website/data/example/${SAMPLE_NAME}/\"
                        EXAMPLE_URL=\"http://${SAMPLE_NAME}.example.mikemitterer.at/\"
                        "

        echo -e "${TEMPLATE}" | sed -e 's/^[ \t]*//' > "${SAMPLE}/.rsync"

        echo -e "\t\t${GREEN}.rsync created${NC}"
        echo
    done
}

#
# Das Script .prep.kts wird für das jeweilige Sample aufgerufen
#
# Mit der option --force wird das .prep-Script erstellt wenn es das File noch nicht
# gibt. (Eigentlich wird es verlinkt mit samples/_scripts/.prep.default.kts)
#
prepareSamples() {
    local SAMPLES=("${@}")

    echo "Examples:"

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        # Wenn .prep.kts nicht existiert wird es erstellt
        if [[ ! -f "${SAMPLE}/${PREP_SCRIPT}" && \
                ! -L "${SAMPLE}/${PREP_SCRIPT}" && \
                    (${OPTION1} == "--force" ||  ${OPTION2} == "--force") ]]; then
        
            # GoTo sample
            cd ${SAMPLE}
                                                                             
            ln -s ../_scripts/.prep.default.kts .prep.kts

            # Zurück zum Ursprung
            cd - >> /dev/null
        fi

        # Wenn das .preps.config.properties-File nicht existiert wird es erstellt
        if [[ ! -f "${SAMPLE}/${PREP_PROPERTIES}" && \
                ! -L "${SAMPLE}/${PREP_PROPERTIES}" && \
                    (${OPTION1} == "--force" ||  ${OPTION2} == "--force") ]]; then

            # GoTo sample
            cd ${SAMPLE}

            # Default-Eintrag für das Properties-File
            echo -e "log.level=info\n" > ${PREP_PROPERTIES}
            echo -e "pubspec.template=../_templates/pubspec.tmpl.yaml\n" >> ${PREP_PROPERTIES}

            echo -e "sample.html.template=../_templates/default.index.html" >> ${PREP_PROPERTIES}
            echo -e "sample.content=.sitegen/html/_content/index.html\n" >> ${PREP_PROPERTIES}

            # Zurück zum Ursprung
            cd - >> /dev/null
        fi

        if [[ -f "${SAMPLE}/${PREP_SCRIPT}" || \
                -L "${SAMPLE}/${PREP_SCRIPT}" ]]; then

            echo -e "\t\tPrep-Script: ${GREEN}YES${NC} - (${SAMPLE})"

            # GoTo sample
            cd ${SAMPLE}
        
            kscript "${PREP_SCRIPT}"

            # Zurück zum Ursprung
            cd - >> /dev/null
        else
            echo -e "\t\tPrep-Script: ${ERROR}NO${NC}  - (${SAMPLE})"

            # Zurück zum Ursprung
            cd - >> /dev/null
        fi
    done

    echo
}

# Zeigt die URLs aus RSYNC an
listURLs() {
    find ${EXAMPLE_FOLDER}/ -name ".rsync" | xargs awk 'FNR==14' | cut -d ' ' -f 5- | sed -e "s/.*http:\/\/\([^/]*\)\/.*/http:\/\/\1/"
}

# Zeigt die URLs aus RSYNC im README-Format an
listURLs4README() {
    find ${EXAMPLE_FOLDER}/ -name ".rsync" | xargs awk 'FNR==14' | cut -d ' ' -f 5- | sed -e "s/.*http:\/\/\([^/]*\)\/.*/- \[\1\]\(http:\/\/\1\)/"
}

#
# Erstellt die links für die WebSite
#
#   Usage:
#       listURL4WebSite <package Beschreibung> <package Name> <Alles samples>
#
#       listURL4WebSite "Material 4 Dart / Basic Components" "m4d_components" "${EXAMPLES[@]}"
#
#   cmdline:
#       mkdir -p tmp && ./deploy-samples.sh --urls-web > tmp/links4web.html
#
listURL4WebSite() {
    local DESCRIPTION=$1; shift;
    local PACKAGE=$1; shift;
    local SAMPLES=("${@}")

    echo -e "
    <div id=\"${PACKAGE}\" class=\"liveexamples\">
        <div class=\"caption row\">
            <div class=\"col\">Repository / Pub</div>
            <div class=\"col\">Live - link</div>
        </div>
    "
    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        # echo -e "\t${YELLOW}${SAMPLE} / ${PACKAGE}${NC}..."

        local SAMPLE_NAME="$(basename ${SAMPLE})"
        local URL=$(awk 'FNR==14' ${SAMPLE}/.rsync | sed "s/EXAMPLE_URL=//" | sed "s/\"//g")

        # Check if .rsync-File exists
        if [[ ! -f "${SAMPLE}/.rsync" ]]; then
            echo -e "\t${YELLOW}No RSYNC-Setting for ${SAMPLE}!${NC}"
            continue
        fi

        # echo -e "\tSource: ${YELLOW}${SAMPLE}${NC}"
        # echo -e "\t\tName:     ${SAMPLE_NAME}"
        # echo -e "\t\tURL:      ${URL}"

        local TEMPLATE="
        <div class=\"row\">
            <div class=\"col\">
                <a href=\"https://pub.dartlang.org/packages/${PACKAGE}\" target=\"_blank\">${DESCRIPTION}</a>
            </div>
            <div class=\"col\">
                <a href=\"${URL}\" rel=\"noopener\" target=\"_blank\">Live - ${SAMPLE_NAME} example</a>
            </div>
        </div>"

        echo -e "${TEMPLATE}"
        # | sed -e 's/^[ \t]*//'

        cd ${SAMPLE}

        # Update pub
        # pub update

        # Zurück zum Ursprung
        cd - >> /dev/null
    done
    echo -e "    </div>"
}

# Zeigt die App im Browser an
#
# Usage: serveSamples "${SAMPLES[@]}"
#
# Wenn der Port offen ist und eine Fehlermeldung kommt kann die App
# die den Port offen hat mit
#
#   sudo lsof -PiTCP -sTCP:LISTEN | grep 8080
#
# abgefragt werden
#
serveSamples() {
    local SAMPLES=("${@}")
    local RELEASE_OPTION=""

    local PORT="8080"

    # Check if release-option is set
    if [[ ${OPTION1} == "--release" ||  ${OPTION2} == "--release" ]]; then
        RELEASE_OPTION="--release"
        echo "Deploy in RELEASE-Mode:"
    else
        echo "Deploy with Dev-Compiler (DEV-Mode):"
    fi

    # Loop Through ARRAY
    for SAMPLE in "${SAMPLES[@]}"
    do
        echo -e "\t${YELLOW}${SAMPLE}${NC}..."

        # Check if .rsync-File exists
        if [[ -f "${SAMPLE}/web/index.html" ]]; then
            cd ${SAMPLE}

            # Es wird schon mal ein Browserfenster geöffnet
            open http://localhost:${PORT}
                
            # Seite wird gebaut und angezeigt
            pub run build_runner serve --delete-conflicting-outputs --live-reload

            # Zurück zum Ursprung
            cd - >> /dev/null
        else
            echo -e "\t${ERROR}${SAMPLE} has no index.html - so it's probably a cmdline-App...${NC}"
        fi

    done
}
