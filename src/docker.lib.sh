#!/usr/bin/env bash
readonly __DOCKER_LIB__="docker.lib.sh";

# -----------------------------------------------------------------------------
# Einige Docker bzw. Docker-Machine Tools
#
# Einbinden:
#     if [[ "${__DOCKER_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/docker.lib.sh"; fi

if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi

#------------------------------------------------------------------------------
# Colors (https://goo.gl/ku0OM6)
#
# Sed benötigt die "geescapted" Version...

#C1='\033[1;32m' # Green
#C1SED='\\033[1;32m' # Green
#
#C2='\033[1;31m' # Red
#C2SED='\\033[1;31m' # Red#
#
#C3='\033[1;33m' # Orange
#C3SED='\\033[1;33m' # Orange
#
#C0='\033[0m' # No Color
#C0SED='\\033[0m' # No Color
#
#COK=${C1}
#CERROR=${C2}
#CWARNING=${C3}
#NC=${C0}

# Aktiviert die definierte Docker-Machine
activateDockerMachine() {
    local _DOCKER_MACHINE=$1

    if ! $(type "docker-machine" &> /dev/null) ; then
        echo -e "${ERROR}No Docker-Machine installed!${NC}"
        exit 1
    fi

    # Aktivieren der Docker-Machine
    echo -e "Activating ${GREEN}${_DOCKER_MACHINE}${NC}..."
    eval $(docker-machine env ${_DOCKER_MACHINE})
}

# Entspricht der custom-bash-Funktion dm-local
# und deaktiviert eine aktive Docker-Machine
deactivateDockerMachine() {

    # unset funkt im Script nicht...
    # set -u <var> funkt auch nicht

    if $(type "docker-machine" &> /dev/null) ; then
        eval $(docker-machine env -u)

        if [[ -n "${DOCKER_HOST:-}" ]]; then
            echo -e "${ERROR}There is an active Docker-Machine: ${DOCKER_HOST} - deactivate it!${NC}"
            exit 1
        fi

        echo -e "${WARNING}Active Docker-Machine deactivated!${NC}"
    fi
}

# Pusht ein Docker-Image in das AWS-Repo
# $1 - Amazon-Repo-URI, [AWS-Account-ID].dkr.ecr.[Region].amazonaws.com
#      AWS-Account-ID: 12-stellige AWS-Kontonummer
#      Region: ZB eu-west-1
# $2 - Name des Images, keycloak
# $3 - Tag des Images, 12.0.1
# $4 - Region, default: eu-west-1
pushImage2Amazon() {
    local _AMAZON_REPO_URI=$1
    local _NAME=$2
    local _TAG=$3
    local _REGION=${4:-'eu-west-1'}

    deactivateDockerMachine

    if ! grep --quiet "ecr-login" "${HOME}/.docker/config.json" ; then
      # Anfrage für das Docker-Login
      aws ecr get-login-password --region "${_REGION}" \
        | docker login --username AWS --password-stdin "${_AMAZON_REPO_URI}"
    fi

    # Übertragen des Images zu Amazon
    docker push "${_AMAZON_REPO_URI}/${_NAME}:latest"
    docker push "${_AMAZON_REPO_URI}/${_NAME}:$_TAG"
}

# Aktiviert zuerst die entsprechende Docker-Machine und
# holt dann vom Amazon-Repo das entsprechende Image
pullImageOnRemoteHost() {
    local _DOCKER_MACHINE=$1
    local _AMAZON_REPO_URI=$2
    local _NAME=$3
    local _VERSION=${4:-'latest'}
    local _REGION=${5:-'eu-west-1'}

    activateDockerMachine ${_DOCKER_MACHINE}

    if ! grep --quiet "ecr-login" "${HOME}/.docker/config.json" ; then
      # Anfrage für das Docker-Login
      aws ecr get-login-password --region "${_REGION}" \
        | docker login --username AWS --password-stdin "${_AMAZON_REPO_URI}"
    fi

    if [ $? -eq 0 ]; then
        docker pull "${_AMAZON_REPO_URI}/${_NAME}:${_VERSION}"
    fi

    deactivateDockerMachine
}

# Deaktiviert eine evtl. vorhandene Docker-Machine
# und holt dann vom Amazon-Repo das entsprechende Image
pullImageFromAmazon2LocalHost() {
    local _AMAZON_REPO_URI=$1
    local _NAME=$2
    local _VERSION=${3:-'latest'}

    deactivateDockerMachine

    if [ $? -eq 0 ]; then
        docker pull "${_AMAZON_REPO_URI}/${_NAME}:${_VERSION}"
    fi
}



# Generiert das Docker-Zertifikate für die DM neu
regenerateCerts() {
    local _DOCKER_MACHINE=$1

    if ! $(type "docker-machine" &> /dev/null) ; then
        echo -e "${ERROR}No Docker-Machine installed!${NC}"
        exit 1
    fi

    docker-machine regenerate-certs ${_DOCKER_MACHINE}
}

# Container Liste wird von Amazon abgeholt
#
# Die beiden "shift" nach _REGION ermöglichen es als letzten Param
# das Container-Array zu übergeben. Es wird also ein shift pro Parameter
# benötigt.
#
#   Usage: pullContainer "${AMAZON_REPO_URI}" "${AMAZON_REGION}" "${CONTAINERS[@]}"
#
pullContainer() {
    local _AMAZON_REPO_URI=$1;
    local _REGION=${2}; shift; shift
    local _CONTAINERS=("${@}")

    type aws >/dev/null 2>&1 || { echo >&2 "$(colorError 'aws is required but it''s not installed!')"; exit 1; }

    # Am MAC wird noch das klassische Login gemacht, unter
    # Linux nicht mehr.
    # Weitere Infos:
    #     https://github.com/awslabs/amazon-ecr-credential-helper
    #
    if ! grep --quiet "ecr-login" "${HOME}/.docker/config.json" ; then
        # Anfrage für das Docker-Login...
        aws ecr get-login-password --region "${_REGION}" \
          | docker login --username AWS --password-stdin "${_AMAZON_REPO_URI}"
    fi

    # Loop Through ARRAY
    for CONTAINER in "${_CONTAINERS[@]}"
    do
        echo -e "Pulling ${YELLOW}${_AMAZON_REPO_URI}/${CONTAINER}${NC} from '${YELLOW}${_REGION}${NC}'"
        docker pull "${_AMAZON_REPO_URI}/${CONTAINER}"
        docker inspect "${_AMAZON_REPO_URI}/${CONTAINER}" --format "{{.ID}} {{.RepoTags}} {{.Architecture}}"
    done
}

# Startet die im compose-file definierten container und wartet
# bis der Server mit dem gewünschten Port antwortet
#
#   Usage:
#       startContainer ${_PORT}
#       "${PORT_MOBICHARTS_UI}" "docker-compose.yml" "mobicharts" "Listening on port 8030"
startContainer() {
    local _PORT=${1:-"8080"}
    local _YAMLFILE=${2:-'docker-compose.yml'}
    local _SERVICE_TO_TEST=${3:-"app"}
    local _TRIGGER_TEXT=${4:-"Tomcat started on port(s): ${_PORT}"}

    # docker-compose -f "${_YAMLFILE}" up -d
    docker compose -f "${_YAMLFILE}" up -d

    echo
    colorGreen "Waiting for port ${_PORT} to become ready..."

    # _TRIGGER_TEXT="Embedded Server runs on.*${_PORT}"
    # _TRIGGER_TEXT="Started Application.Companion"

    local _MAX_CHECKS=20
    local _counter=0

    # -i - Ignore case
    # -C - Print NUM lines of output context.
    #
    # Vor set war bis zum 28.10.2020 noch:
    #     | cut -c -200 \
    #     | sed 's/^/    /' \
    until docker compose -f "${_YAMLFILE}" logs "${_SERVICE_TO_TEST}" \
            | grep --color -C 5 -e "${_TRIGGER_TEXT}"; do
    
        >&2 echo " └ waiting... (${_counter} < ${_MAX_CHECKS})"

        _counter=$((_counter+1))
        if test "${_counter}" -gt ${_MAX_CHECKS}; then
          
            echo -e "\nCould not find: '${ERROR}${_TRIGGER_TEXT}${NC}'...\n"
            echo -e "Here are the logs:\n"

            docker compose -f "${_YAMLFILE}" logs "${_SERVICE_TO_TEST}" | grep --color -E "${_TRIGGER_TEXT}|$"
            exit 1
        fi
        sleep 2
    done
}


# Wenn Container laufen werden diese angehalten
#
# Param:
#   #1 - Docker-Compose-File, default: docker-compose.yml
#   #2 - Löschen der Container, default: clear
#        'clear' | 'true' - lösch die verwendeten Container
#        'keep' | 'false' - Behält den Content der Container
#
# Usage:
#   stopContainer 'docker-compose.yml' 'clear'
#   stopContainer 'docker-compose.yml' 'keep'
#
stopContainer() {
    local _YAMLFILE=${1:-'docker-compose.yml'}
    local _CLEAR_VOLUMES=${2:-'clear'}

    colorGreen "Stopping container(s)..."

    NR_OF_IDS=$(docker compose ps -q | wc -l)
    if [[ $((NR_OF_IDS)) -eq 0 ]]; then
        echo -e "  ${INFO}Nothing to stop here!${NC}"
    else
        if [[ "${_CLEAR_VOLUMES}" == "clear" || "${_CLEAR_VOLUMES}" == "true" ]]; then
            docker compose -f "${_YAMLFILE}" down --volumes --remove-orphans
        else
            docker compose -f "${_YAMLFILE}" down --remove-orphans
        fi
    fi
}

# Anzeige der aktuellen Container Logs
showLogs() {
    local _YAMLFILE=${1:-'docker-compose.yml'}
    local _SERVICE=${2-""}

    local NR_OF_IDS=$(docker compose ps -q | wc -l)

    if [[ $((NR_OF_IDS)) -eq 0 ]]; then
        echo -e "${INFO}No active containers!${NC}"
    else
        if [[ "${_SERVICE}" == "" ]]; then
            docker compose -f "${_YAMLFILE}" logs -f
        else
            docker compose -f "${_YAMLFILE}" logs -f "${_SERVICE}"
        fi
    fi
}

# Listet die Container-Versionen auf Amazon ECR auf
showContainerVersionsOnAmazonECR() {
    local _AMAZON_REPO_NAME=$1

    # Bis zum 11.10.22 hat die jq-Zeile so ausgesehen:
    # | jq -cC '.[] | { version: .imageTags[0], tag: .imageTags[1], pa: .imagePushedAt | strftime("%Y-%m-%d") }' \
    # Produziert aber die Fehlermeldung:
    #     jq: error (at <stdin>:463): strftime/1 requires parsed datetime inputs
    #

    echo "Amazon ECR (${_AMAZON_REPO_NAME}):"
    aws ecr describe-images --repository-name ${_AMAZON_REPO_NAME} \
        --query 'sort_by(imageDetails,& imagePushedAt)[*]' \
        | jq -cC '.[] | { version: .imageTags[0], tag: .imageTags[1], pa: .imagePushedAt }' \
        | sed "s/^/    /"
}

# Listet die Files auf Amazon S3
#
# sort
#   -b - Ignore leading blanks.
#   -t - Separator
#   -k - key to sort (Feld 4 getrennt durch blank)
#   -V - sort Version
#   -r - reverse (aktuelle Version ganz unten)
showDebianVersionsOnAmazonS3() {
    local _AMAZON_DEBIAN_REPO_PATH=$1
    local _AMAZON_DEBIAN_REPO_NAME=$2
    local _AMAZON_DEBIAN_REPO="${_AMAZON_DEBIAN_REPO_PATH}/${_AMAZON_DEBIAN_REPO_NAME}"

    echo "Amazon S3 (${_AMAZON_DEBIAN_REPO}):"
    aws s3 ls ${_AMAZON_DEBIAN_REPO}/ \
        | gsort -b -k 4,4 -V  \
        | sed "s/^/    /" \
        | echo -e "$(sed "s/\(${_AMAZON_DEBIAN_REPO_NAME}.*\.deb\)/${SED_GREEN}\1${SED_NC}/")"
}

# Minor version in Tag.properties wird in Basis-Script um eins erhöht
# und hier neu geschrieben
#
# Usage:
#    TAGFILE="_TAG.properties"
#    _MAJOR="$(cat ${TAGFILE} | grep -i "major=" | sed "s/major=//g")"
#    _MINOR="$(cat ${TAGFILE} | grep -i "minor=" | sed "s/minor=//g")"
#    _TAG="${_MAJOR}.$((++_MINOR))"
#    ...
#    updateTagProps "${TAGFILE}" "${_MAJOR}" "${_MINOR}"
#
updateTagProps() {
    local _PROPS_FILE=$1
    local _MAJOR=$2
    local _MINOR=$3

    echo -e "# $(date -R)\n" > "${_PROPS_FILE}"
    echo "major=${_MAJOR}" >> "${_PROPS_FILE}"
    echo "minor=${_MINOR}" >> "${_PROPS_FILE}"

}

# Login to DockerHub
# Das Passwort wird aus der Datei ${DOCKER_PW_FILE} gelesen
# Login wird nur jede 12h durchgeführt!
#
# @param {string} ${1} - Username, Default: mikemitterer
#
loginToDockerHub() {
        local _USERNAME=${1:-'mangolila'}

        if [[ ! -f "${DOCKER_PW_FILE}" ]]; then
             local _pw_dir
             _pw_dir=$(dirname "${DOCKER_PW_FILE}")
             echo -e "\n${ERROR}Docker-Hub-Passwortdatei nicht gefunden:${NC} ${YELLOW}${DOCKER_PW_FILE}${NC}"
             echo -e "\nDie Datei enthält nur das Docker-Hub-Passwort bzw. — empfohlen — einen"
             echo -e "Access-Token; er wird per --password-stdin an 'docker login' übergeben."
             echo -e "\n${YELLOW}1) Access-Token erzeugen:${NC}"
             echo -e "     Docker Hub → Account Settings → Security → New Access Token"
             echo -e "     ${BLUE}https://app.docker.com/settings/personal-access-tokens${NC}"
             echo -e "\n${YELLOW}2) Token in die Datei schreiben (ohne Zeilenumbruch, Rechte einschränken):${NC}"
             echo -e "     ${BLUE}mkdir -p ${_pw_dir}${NC}"
             echo -e "     ${BLUE}printf '%s' '<TOKEN>' > ${DOCKER_PW_FILE}${NC}"
             echo -e "     ${BLUE}chmod 600 ${DOCKER_PW_FILE}${NC}\n"
             exit 1
        fi

        # Gültigkeit (in Minuten) des Logins
        local _LOGIN_TO_OLD=$(checkLastLogin $(( 12 * 60 )))

        if [[ $_LOGIN_TO_OLD == true ]]; then
            echo -e "\n${YELLOW}Login to DockerHub...${NC}"
            docker login --username "${_USERNAME}" --password-stdin < "${DOCKER_PW_FILE}"

            date > ".last_login"
        else
            echo -e "\n${GREEN}DockerHub Login not necessary${NC} - last login was '${YELLOW}$(cat .last_login)${NC}' (${GREEN}less than 12h ago${NC})"
        fi
}

# Prüft ob ein gültiger Login für die GitHub Container Registry (ghcr.io) vorhanden ist.
# Bricht mit einer ausführlichen Fehlermeldung ab wenn kein Login gefunden wird.
# Kein automatischer Login — das muss einmalig manuell erfolgen:
#
#   echo "<PAT>" | docker login ghcr.io -u <github-username> --password-stdin
#
#   PAT benötigt Scope: write:packages
#   Unter: GitHub → Settings → Developer settings → Personal access tokens
#
checkCHCRLogin() {
    if ! grep --quiet "ghcr.io" "${HOME}/.docker/config.json" 2>/dev/null; then
        echo -e "\n${ERROR}Kein Login für ghcr.io gefunden.${NC}"
        echo -e "\n${YELLOW}Einmalig anmelden mit:${NC}"
        echo -e "    echo \"<PAT>\" | docker login ghcr.io -u <github-username> --password-stdin"
        echo -e "\n${YELLOW}PAT erzeugen unter:${NC}"
        echo -e "    GitHub → Settings → Developer settings → Personal access tokens"
        echo -e "    Erforderlicher Scope: ${YELLOW}write:packages${NC}"
        echo -e "\n${YELLOW}Hinweis:${NC} Der PAT muss vom persönlichen GitHub-Account stammen,"
        echo -e "    auch wenn das Image in eine Organisation gepusht wird."
        echo -e "    Der Account muss Mitglied der Org mit write:packages-Berechtigung sein.\n"
        exit 1
    fi
}

# Prüft ob ein ECR-Repository existiert.
#
# ECR legt Repositories nicht automatisch beim Push an (anders als Docker Hub/
# GHCR). Der Aufrufer nutzt das für einen Preflight-Check vor Login/Push.
#
# Params:
#    - Repository-Name (ohne Registry-Host), z.B. stockinfo
#    - AWS-Region, z.B. eu-west-1
#
# Returns:
#   0 wenn Repo existiert, 1 wenn nicht (oder keine Rechte)
ecrRepoExists() {
    local _name=${1:?}
    local _region=${2:?}

    aws ecr describe-repositories --repository-names "${_name}" --region "${_region}" &>/dev/null
}

# Stellt den Registry-Login für das gewählte Target sicher.
#
# Wird vor einem direkten buildx-Multiarch-Push aufgerufen (der Push läuft aus
# buildx heraus und braucht den Login VOR dem Build). Kapselt die Target-Fall-
# unterscheidung, damit das aufrufende build.sh schlank bleibt.
#
# Bei ECR zusätzlich ein Preflight-Check: das Repository muss existieren — ECR
# legt es nicht automatisch beim Push an. Fehlt es, Abbruch mit fertigem
# create-repository-Befehl im Hinweis.
#
# Params:
#    - Target:          ghcr | dockerhub | ecr
#    - Image-Name:      z.B. stockinfo   (nur für ECR-Repo-Check)
#    - AWS-Region:      nur bei ecr, z.B. eu-west-1
#    - Amazon-Repo-URI: nur bei ecr, z.B. 1234…dkr.ecr.eu-west-1.amazonaws.com
#
# Returns:
#   0 bei Erfolg; Abbruch mit exit 1 bei unbekanntem Target oder fehlendem ECR-Repo.
ensureRegistryLogin() {
    local _target=${1:?}
    local _name=${2:?}
    local _region=${3:-}
    local _amazon_repo_uri=${4:-}

    case "${_target}" in
        ghcr)      checkCHCRLogin ;;
        dockerhub) loginToDockerHub ;;
        ecr)
            if ! ecrRepoExists "${_name}" "${_region}"; then
                echo -e "\n${RED}ECR-Repository fehlt:${NC} ${YELLOW}${_name}${NC} (Region: ${YELLOW}${_region}${NC})" >&2
                echo -e "ECR legt Repositories nicht automatisch beim Push an — bitte zuerst anlegen:" >&2
                echo -e "    ${BLUE}aws ecr create-repository --repository-name ${_name} \\" >&2
                echo -e "        --region ${_region} --image-tag-mutability MUTABLE${NC}\n" >&2
                exit 1
            fi
            aws ecr get-login-password --region "${_region}" \
              | docker login --username AWS --password-stdin "${_amazon_repo_uri}" ;;
        *)
            echo -e "\n${RED}Unbekanntes Target:${NC} ${YELLOW}${_target}${NC} — erlaubt: ghcr | dockerhub | ecr\n" >&2
            exit 1 ;;
    esac
}

# Pusht ein Image in die GitHub Container Registry (ghcr.io).
# Bricht ab wenn kein Login vorhanden ist — siehe checkGhcrLogin.
#
# @param {string} ${1} - GitHub Owner (User oder Org, lowercase), z.B. mangolila
# @param {string} ${2} - Image-Name, z.B. decisionmap-frontend
# @param {string} ${3} - Tag, z.B. 26.1.0-SNAPSHOT0330.be70
#
pushImage2GHCR() {
    local _OWNER=${1:?}
    local _NAME=${2:?}
    local _TAG=${3:?}

    checkCHCRLogin

    docker push "ghcr.io/${_OWNER}/${_NAME}:${_TAG}"
    docker push "ghcr.io/${_OWNER}/${_NAME}:latest"
}

# Pusht das Image auf DockerHub
#
# @param {string} ${1} - Namespace, Z.B. mikemitterer
# @param {string} ${2} - Name des Images, Z.B. certbot
# @param {string} ${3} - Tag des Images, Z.B. 1.0.0
pushImage2DockerHub() {
    local _NAMESPACE=${1:-}
    local _NAME=${2:-}
    local _TAG=${3:-}

    loginToDockerHub

    docker push "${_NAMESPACE}/${_NAME}:${_TAG}"
    docker push "${_NAMESPACE}/${_NAME}:latest"
}

# Baut ein Single-Arch Docker-Image und lädt es in den lokalen Cache.
# Wählt automatisch den richtigen Builder: desktop-linux (Mac/Docker Desktop)
# oder default (Linux/CI). Kein --load nötig — non-container-Driver lädt implizit.
#
# Build-Kontext (_context):
#   Der Verzeichnispfad, den Docker als Tarball an BuildKit schickt. Nur Dateien
#   innerhalb dieses Verzeichnisses sind im Dockerfile per COPY/ADD erreichbar.
#   Typisches Layout: build.sh liegt in docker/, Dockerfile und App-Dateien eine
#   Ebene höher → _context=".." zeigt auf das Projektverzeichnis.
#   Faustregel: _context muss das Verzeichnis sein, in dem das Dockerfile liegt —
#   es sei denn, -f zeigt explizit auf einen anderen Pfad.
#
# @param {string} ${1} - Platform, z.B. linux/amd64 oder linux/arm64
# @param {string} ${2} - Lokaler Image-Name (namespace/name), z.B. decisionmap/backend
# @param {string} ${3} - Registry-Image (voll qualifiziert), z.B. ghcr.io/mangolila/decisionmap-backend
# @param {string} ${4} - Tag, z.B. 0.1.0-260412.0824.def34
# @param {string} ${5} - Logfile-Pfad, z.B. logs/build-260414.log
# @param {string} ${6} - Dockerfile-Pfad, default: Dockerfile  (relativ zum _context oder absolut)
# @param {string} ${7} - Build-Kontext, default: ..             (Projektverzeichnis wenn Script in docker/ liegt)
#
buildSingleArchImage() {
    local _platform=${1:?}
    local _local_image=${2:?}
    local _registry_image=${3:?}
    local _tag=${4:?}
    local _logfile=${5:?}
    local _dockerfile=${6:-"Dockerfile"}
    local _context=${7:-".."}

    # Für single-arch --load einen docker-driver Builder verwenden.
    # docker-container-Driver (multiarch) ist nach einem multiarch-Push für --load nicht geeignet.
    # desktop-linux: Docker Desktop (Mac/Windows); default: Linux / CI
    local _builder
    if docker buildx inspect desktop-linux &>/dev/null 2>&1; then
        _builder="desktop-linux"
    else
        _builder="default"
    fi

    docker buildx build --builder "${_builder}" --platform "${_platform}" \
        -f "${_dockerfile}" \
        -t "${_local_image}:latest"    -t "${_local_image}:${_tag}" \
        -t "${_registry_image}:latest" -t "${_registry_image}:${_tag}" \
        "${_context}" 2>&1 | tee "${_logfile}" || return 1

    local _arch
    _arch=$(docker inspect "${_local_image}:latest" --format "{{ .Architecture }}")
    echo -e "\n${GREEN}${_local_image}:latest${NC} gebaut für ${YELLOW}${_arch}${NC}"
}

# Baut und pusht ein Multi-Arch Docker-Image direkt in die Registry.
# Erfordert einen buildx-Builder namens 'multiarch' mit docker-container-Driver.
# --push ist Pflicht — buildx kann kein multi-arch Image in den lokalen Cache laden.
#
# Build-Kontext (_context):
#   Identische Semantik wie bei buildSingleArchImage — Docker schickt den Inhalt
#   dieses Verzeichnisses an BuildKit. Bei Multi-Arch läuft der Build remote im
#   Builder-Container, daher ist ein kompakter Kontext (+ .dockerignore) besonders
#   wichtig: großer Kontext = langer Upload bei jedem Build.
#
# Cache:
#   Registry-backed Cache (mode=max) unter dem Tag :buildcache neben dem Image.
#   Der docker-container-Driver hält sonst nur einen flüchtigen Cache im Builder-
#   Volume (weg bei Prune/Neuaufsetzen, nicht CI-übergreifend). mode=max cacht auch
#   Zwischen-Stages (z.B. den Node/Vite-Build); image-manifest=true+oci-mediatypes
#   machen den Cache Docker-Hub-/ECR-kompatibel. Beim ersten Build fehlt :buildcache
#   noch — buildx ignoriert das mit einer Warnung.
#   --provenance=false erzeugt ein sauberes Multi-Arch-Manifest ohne Attestations.
#   Voraussetzung: Registry-Login ist erfolgt (ensureRegistryLogin im Aufrufer).
#
# @param {string} ${1} - Platforms (kommagetrennt), z.B. linux/arm64,linux/amd64
# @param {string} ${2} - Registry-Image (voll qualifiziert), z.B. ghcr.io/mangolila/decisionmap-backend
# @param {string} ${3} - Tag, z.B. 0.1.0-260412.0824.def34
# @param {string} ${4} - Logfile-Pfad, z.B. logs/build-260414.log
# @param {string} ${5} - Dockerfile-Pfad, default: Dockerfile  (relativ zum _context oder absolut)
# @param {string} ${6} - Build-Kontext, default: ..             (Projektverzeichnis wenn Script in docker/ liegt)
# @param {string} ${7} - Cache-Ref, default: ${_registry_image}:buildcache
#
buildMultiArchImage() {
    local _platform=${1:?}
    local _registry_image=${2:?}
    local _tag=${3:?}
    local _logfile=${4:?}
    local _dockerfile=${5:-"Dockerfile"}
    local _context=${6:-".."}
    local _cache_ref=${7:-"${_registry_image}:buildcache"}

    echo -e "\nBuilder:\n${YELLOW}$(docker buildx inspect multiarch | sed 's/^/    /g')${NC}\n"

    docker buildx build --builder multiarch --platform "${_platform}" \
        --push \
        --provenance=false \
        --cache-from "type=registry,ref=${_cache_ref}" \
        --cache-to   "type=registry,ref=${_cache_ref},mode=max,image-manifest=true,oci-mediatypes=true" \
        -f "${_dockerfile}" \
        -t "${_registry_image}:latest" \
        -t "${_registry_image}:${_tag}" \
        "${_context}" 2>&1 | tee "${_logfile}" || return 1

    echo -e "\n${GREEN}Multi-Arch Push erfolgreich: ${_registry_image}:${_tag}${NC}"
}

