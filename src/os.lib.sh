#!/usr/bin/env bash
readonly __OS_LIB__="os.lib.sh";

#------------------------------------------------------------------------------
# Checkt im Prinzip das OS auf dem dieses Script läuft
#
# Einbinden:
#     if [[ "${__OS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/os.lib.sh"; fi
#
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Verwendete Tools

#------------------------------------------------------------------------------
# OS Spezifische Tools
#
# Weiter Infos:
#   https://en.wikipedia.org/wiki/Uname#Examples
#
# Usage:
#     if [[ "${MACHINE}" == "Linux" ]]; then
#         ...
#     else
#         ...
#     fi
#
readonly UNAME=$([[ -f /usr/bin/uname ]] && /usr/bin/uname -s || /bin/uname -s)
case "${UNAME}" in
    Linux*)     readonly MACHINE="Linux";;
    Darwin*)    readonly MACHINE="Mac";;
    CYGWIN*)    readonly MACHINE="Cygwin";;
    MINGW*)     readonly MACHINE="MinGw";;
    *)          readonly MACHINE="UNKNOWN: ${UNAME}"
esac

# i686 = 32-bit Intel x86 arch
# x86_64 = 64-bit Intel x86 arch
# arm64 = 64-bit ARM arch, z.B. M1 Mac
# aarch64 = 64-bit ARM arch, z.B. Raspberry Pi 4 Model B
# armv7l = 32-bit ARM arch, z.B. Raspberry Pi 3 Model B
# armv6l = 32-bit ARM arch, z.B. Raspberry Pi 1 Model B
readonly ARCHITECTURE=$([[ -f /usr/bin/uname ]] && /usr/bin/uname -m || /bin/uname -m)
