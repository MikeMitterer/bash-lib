#!/usr/bin/env bash
readonly __FS_LIB__="fs.lib.sh";

#------------------------------------------------------------------------------
# Copy-Funktionen usw. Alles was einigermaßen File/Dir spezifisch ist
#
# Einbinden:
#     if [[ "${__FS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/fs.lib.sh"; fi
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Verwendete Tools


# Kopiert praktisch den Inhalt von _SOURCE_DIR nach _TARGET_DIR
#
# Wenn in _TARGET_DIR schon ein Inhalt zu finden ist wird der
# Content in _BACKUP_DIR gesichert
#
# Params:
#   1 - Source, normalerweise "dist"
#   2 - Target - Source wird nach Target kopiert
#   3 - Backup-Dir
#
syncToLocalDir() {
    local readonly _SOURCE_DIR=${1?Source-Dir is missing for syncToLocalDir}
    local readonly _TARGET_DIR=${2?Target-Dir is missing for syncToLocalDir}
    local readonly _BACKUP_DIR=${3?Backup-Dir is missing for syncToLocalDir}

    if [ ! -d "${_TARGET_DIR}" ]; then
         mkdir -p "${_TARGET_DIR}"
         echo -e "${GREEN}${_TARGET_DIR} created!${NC}"
    else
         mkdir -p "${_BACKUP_DIR}"

         if [ -n "$(ls -A "${_TARGET_DIR}")" ]; then
            local BACKUP_FILE="${_BACKUP_DIR}/static-$(date +"%y%m%d-%H%M%S")"

            mv "${_TARGET_DIR}" "${BACKUP_FILE}"
            mkdir -p "${_TARGET_DIR}"
            echo -e "${GREEN}Made backup: ${BACKUP_FILE}!${NC}"
         fi
    fi

    if [ -d "${_SOURCE_DIR}" ]; then
        cp -R "${_SOURCE_DIR}/" "${_TARGET_DIR}"
        echo
        echo -e "${GREEN}${_TARGET_DIR}:${NC}"
        ls -la "${_TARGET_DIR}"
    else
        echo -e "${RED}Source (${_SOURCE_DIR}) does not exist!${NC}"
    fi
}
