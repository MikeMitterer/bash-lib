#!/usr/bin/env bash
readonly __DTIME_LIB__="dtime.lib.sh";

#------------------------------------------------------------------------------
# Einige Date/Time-Definitionen
#
# Einbinden:
#     if [[ "${__DTIME_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/dtime.lib.sh"; fi
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Verwendete Tools

if [[ "${__OS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/os.lib.sh"; fi

#------------------------------------------------------------------------------
# Date / Time
#
# Format von Date:
#   https://www.cyberciti.biz/faq/linux-unix-formatting-dates-for-display/
#

# Day of year
# Usage:
#     DEST_DATA="${BACKUPDISK}/data$(( ${DAY_OF_YEAR} % 3 ))"
#     echo "DOY ${DAY_OF_YEAR}"
readonly DAY_OF_YEAR=$(date +"%j" | sed 's/^0*//')

# Kalenderwoche
# Eine evtl. führende 0 wird gelöscht!
#
# Usage:
#   echo "CW $(( CALENDAR_WEEK % 3 ))"
#   readonly BACKUP_FOLDER="backup_$(( CALENDAR_WEEK % 3 ))"; echo "BackupFolder: ${BACKUP_FOLDER}"
readonly CALENDAR_WEEK=$(date +"%V" | sed 's/^0//')

# Aktuelles Monat
readonly MONTH=$(date +"%m" | sed 's/^0//')

# Letztes Monat

if [[ "${MACHINE}" == "Linux" ]]; then
    readonly LAST_MONTH=$(date --date="$(date +%Y-%m-15) -1 month" +'%m'  | sed 's/^0//')
else
    readonly LAST_MONTH=$(date -v -1m -jf '%Y-%m-%d %H:%M:%S' "$(date +"%Y-%m-15 %H:%M:%S")" +"%m" | sed 's/^0//' )
fi

# Aktuelles Jahr
readonly YEAR=$(date +"%Y")

# Letztes Jahr
if [[ "${MACHINE}" == "Linux" ]]; then
    readonly LAST_YEAR=$(date --date="$(date +%Y-01-15) -1 month" +'%Y')
else
    readonly LAST_YEAR=$(date -v -1m -jf '%Y-%m-%d %H:%M:%S' "$(date +"%Y-01-15 %H:%M:%S")" +"%Y")
fi

# Format für ISO 8601
#
# Usage:
#     date +'%Y-%m-%dT%H:%M:%S%z'
#     echo "$(date +"${ISO_8601_FORMAT}")"
readonly ISO_8601_FORMAT="%Y-%m-%dT%H:%M:%S%z"

# Usage:
#     echo "$(date +"${LOG_DATE_FORMAT}")"
readonly LOG_DATE_FORMAT="%Y-%m-%d %H:%M:%S"

