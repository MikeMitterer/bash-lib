#!/usr/bin/env bash
# shellcheck disable=SC2034
readonly __COLORS_LIB__="colors.lib.sh";

#------------------------------------------------------------------------------
# ANSI Colors für diverse Scripts
#
# Die Palette (RED, GREEN, NC, …) bleibt fest. Farben und Abstände der
# Theme-Helfer (themeLine, themeHeading und die print*-Helfer in tools.lib.sh)
# kommen aus der Theme-Datei von CLITheme, siehe Abschnitt „CLI-Theme“ unten
# und docs/themes.md.
#
# Für Agenten (bashlib --skill):
#     Zweck:   Feste ANSI-Farbpalette als Variablen
#     Wann:    ein Text braucht eine feste Farbe; für Hilfe und Status die Theme-Helfer aus cli.lib.sh nehmen
#     Wichtig: RED, GREEN, YELLOW, BLUE, NC
#
# Einbinden:
#     if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi
#
# Usage:
#     Sample: echo -e "I ${RED}love${NC} Stack Overflow\n"
#
# Weitere Infos:
#       https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
#       https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
#       https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
#
# Mit 'showScriptColors' oder 'showAllColors' können die Farben zum testen
# ausgegeben werden.
#
#------------------------------------------------------------------------------

# ANSI-Color Farbcode wird mit ESC eingeleitet
# Macht die ganze Sache lesbarer
readonly ESC="\x1B"

# Followed by the command, somtimes delimited by opening 
# square bracket ([), known as a 
# Control Sequence Introducer (CSI), optionally followed 
# by arguments and the command itself.
readonly CSI="["

# [38 + [48 - definieren den 256 Color-Space
# [38;5 - Vordergrund
# [48;5 - Hintergrund
readonly FG_COLOR="38;5"
readonly BG_COLOR="48;5"

# https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797#256-colors 
readonly ANSI_COLOR_RED="196"
readonly ANSI_COLOR_GREEN="10"
readonly ANSI_COLOR_YELLOW="11"
readonly ANSI_COLOR_ORANGE="208"
readonly ANSI_COLOR_BROWN="94"
readonly ANSI_COLOR_BLUE="33"
readonly ANSI_COLOR_PURPLE="164"
readonly ANSI_COLOR_CYAN="51"
readonly ANSI_COLOR_DARK_GREY="245"
readonly ANSI_COLOR_GREY="${ANSI_COLOR_DARK_GREY}"

readonly ANSI_COLOR_LIGHT_RED="203"
readonly ANSI_COLOR_LIGHT_GREEN="155"
readonly ANSI_COLOR_LIGHT_BLUE="45"
readonly ANSI_COLOR_LIGHT_PURPLE="170"
readonly ANSI_COLOR_LIGHT_CYAN="123"
readonly ANSI_COLOR_LIGHT_GRAY="251"
readonly ANSI_COLOR_WHITE="15"

# Grep-Colors --------------------------------------------------------------------------------------
# Usage:
#     GREP_COLOR='${GREP_COLOR_GREEN}' \grep --color='auto' '^[^=]*'"

readonly GREP_COLOR_RED="${FG_COLOR};${ANSI_COLOR_RED}"
readonly GREP_COLOR_GREEN="${FG_COLOR};${ANSI_COLOR_GREEN}"
readonly GREP_COLOR_YELLOW="${FG_COLOR};${ANSI_COLOR_YELLOW}"
readonly GREP_COLOR_ORANGE="${FG_COLOR};${ANSI_COLOR_ORANGE}"
readonly GREP_COLOR_BROWN="${FG_COLOR};${ANSI_COLOR_BROWN}"
readonly GREP_COLOR_BLUE="${FG_COLOR};${ANSI_COLOR_BLUE}"
readonly GREP_COLOR_PURPLE="${FG_COLOR};${ANSI_COLOR_PURPLE}"
readonly GREP_COLOR_CYAN="${FG_COLOR};${ANSI_COLOR_CYAN}"
readonly GREP_COLOR_DARK_GREY="${FG_COLOR};${ANSI_COLOR_DARK_GREY}"
readonly GREP_COLOR_GREY="${GREP_COLOR_DARK_GREY}"

readonly GREP_COLOR_LIGHT_RED="${FG_COLOR};${ANSI_COLOR_LIGHT_RED}"
readonly GREP_COLOR_LIGHT_GREEN="${FG_COLOR};${ANSI_COLOR_LIGHT_GREEN}"
readonly GREP_COLOR_LIGHT_BLUE="${FG_COLOR};${ANSI_COLOR_LIGHT_BLUE}"
readonly GREP_COLOR_LIGHT_PURPLE="${FG_COLOR};${ANSI_COLOR_LIGHT_PURPLE}"
readonly GREP_COLOR_LIGHT_CYAN="${FG_COLOR};${ANSI_COLOR_LIGHT_CYAN}"
readonly GREP_COLOR_LIGHT_GRAY="${FG_COLOR};${ANSI_COLOR_LIGHT_GRAY}"
readonly GREP_COLOR_WHITE="${FG_COLOR};${ANSI_COLOR_WHITE}"

# Shell-Colors -------------------------------------------------------------------------------------
# Usage:
#     echo -e "${GREEN}This line has '\${GREEN}'-Foreground${NC}"

readonly RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_RED}m"
readonly GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_GREEN}m"
readonly YELLOW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_YELLOW}m"
readonly ORANGE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_ORANGE}m"
readonly BROWN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BROWN}m"
readonly BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BLUE}m"
readonly PURPLE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PURPLE}m"
readonly CYAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CYAN}m"
readonly DARK_GREY="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_DARK_GREY}m"
readonly GREY="${DARK_GREY}"

readonly LIGHT_RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_RED}m"
readonly LIGHT_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_GREEN}m"
readonly LIGHT_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_BLUE}m"
readonly LIGHT_PURPLE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_PURPLE}m"
readonly LIGHT_CYAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_CYAN}m"
readonly LIGHT_GRAY="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIGHT_GRAY}m"
readonly WHITE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_WHITE}m"

readonly SUCCESS=${GREEN}
readonly INFO=${BLUE}
readonly WARNING=${ORANGE}
readonly FAILED=${RED}
readonly ERROR=${RED}

readonly NC="${ESC}[0m" # No Color

colorGreen() {
    local TEXT=${1}
    echo -e "${GREEN}${TEXT}${NC}"
}

colorError() {
    local TEXT=${1}
    echo -e "${ERROR}${TEXT}${NC}"
}

#------------------------------------------------------------------------------
# DIALOG
#   https://linux.die.net/man/1/dialog
#   https://stackoverflow.com/a/27875395/504184
#

readonly DCBLACK='\Z0'
readonly DCRED='\Z1'
readonly DCGREEN='\Z2'
readonly DCYELLOW='\Z3'
readonly DCBLUE='\Z4'
readonly DCMAGENTA='\Z5'
readonly DCCYAN='\Z6'
readonly DCWHITE='\Z7'
readonly DCOFF='\Zn'

readonly DCSUCCESS=${DCGREEN}
readonly DCINFO=${DCBLUE}
readonly DCWARNING=${DCYELLOW}
readonly DCFAILED=${DCRED}
readonly DCERROR=${DCRED}

#------------------------------------------------------------------------------
# Colors (https://goo.gl/ku0OM6)

# Kann nicht gelöscht werden - wurde bei
# allen Docker-Gen-Scripts verwendet!!!!
#     build -s
#
readonly C1="${GREEN}" # Green
readonly C2="${RED}" # Red
readonly C0="${NC}" # No Color

#
# readonly CM1='\033[1;33m' # Yellow (Menu)
# readonly CM0='\033[0m' # No Color

# Für SED - hier wird ein doppeltes Escape benötigt
readonly SED_GREEN='\\033[38;5;10m'
readonly SED_YELLOW='\\033[38;5;11m'
readonly SED_RED='\\033[38;5;196m'
readonly SED_NC='\\033[0m' # No Color

#readonly CMM1='\\033[1;33m'
#readonly CMM0='\\033[0m'

#readonly SED_GREEN=$CC1
#readonly SED_RED=$CC2

#------------------------------------------------------------------------------
# Sample Colors

showScriptColors() {
    echo
    echo -e "${RED}This line has '\${RED}'-Foreground"
    echo -e "${GREEN}This line has '\${GREEN}'-Foreground"
    echo -e "${YELLOW}This line has '\${YELLOW}'-Foreground"
    echo -e "${ORANGE}This line has '\${ORANGE}'-Foreground"
    echo -e "${BROWN}This line has '\${BROWN}'-Foreground"
    echo -e "${BLUE}This line has '\${BLUE}'-Foreground"
    echo -e "${PURPLE}This line has '\${PURPLE}'-Foreground"
    echo -e "${CYAN}This line has '\${CYAN}'-Foreground"
    echo -e "${GREY}This line has '\${GREY}'-Foreground"
    echo
    echo -e "${LIGHT_RED}This line has '\${LIGHT_RED}'-Foreground"
    echo -e "${LIGHT_GREEN}This line has '\${LIGHT_GREEN}'-Foreground"
    echo -e "${LIGHT_BLUE}This line has '\${LIGHT_BLUE}'-Foreground"
    echo -e "${LIGHT_PURPLE}This line has '\${LIGHT_PURPLE}'-Foreground"
    echo -e "${LIGHT_CYAN}This line has '\${LIGHT_CYAN}'-Foreground"
    echo -e "${LIGHT_GRAY}This line has '\${LIGHT_GRAY}'-Foreground"
    echo -e "${WHITE}This line has '\${WHITE}'-Foreground"
    echo
    echo -e "${SUCCESS}This line has '\${SUCCESS}'-Foreground"
    echo -e "${INFO}This line has '\${INFO}'-Foreground"
    echo -e "${WARNING}This line has '\${WARNING}'-Foreground"
    echo -e "${FAILED}This line has '\${FAILED}'-Foreground"
    echo -e "${ERROR}This line has '\${ERROR}'-Foreground${NC}"
    echo
}

# Alle 256 verfügbaren Farben werden in einer Loop ausgegeben
#
# Usage:
#   showAllColors
#
showAllColors() {
    echo
    showColorsInRange "Default colors" 0 7
    echo
    showColorsInRange "High-intensity colors" 8 15
    echo
    showColorsInRange "216 Colors" 16 231
    echo
    showColorsInRange "Grayscale colors" 232 255
    echo
    echo "More infos on Wikipedia: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit"
    echo
}

# Zeigt die ANSI-Farben in einem bestimmten Range an
#
# SO zum Range:
#   https://stackoverflow.com/questions/169511/how-do-i-iterate-over-a-range-of-numbers-defined-by-variables-in-bash
#
# Usage:
#    showColorsInRange "Default colors" 0 7
#   
showColorsInRange() {
    local DESCRIPTION="$1"
    local FROM="$2"
    local TO="$3"

    echo "${DESCRIPTION}:"
    for COLOR in $(seq "${FROM}" "${TO}"); do
        echo -e "   ${ESC}[38;5;${COLOR}m - Color code is '\$ESC[38;5;${COLOR}m' 0123456789 *+#${NC}";
    done
}





# Ergänzte MakeLib-Palette; vorhandene Konstanten behalten ihre Werte.
readonly ANSI_COLOR_BLACK="0"
readonly BLACK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BLACK}m"
readonly ANSI_COLOR_STEEL_BLUE="75"
readonly STEEL_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_STEEL_BLUE}m"
readonly ANSI_COLOR_GOLD="220"
readonly GOLD="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_GOLD}m"
readonly ANSI_COLOR_CORAL="203"
readonly CORAL="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CORAL}m"
readonly ANSI_COLOR_TAN="179"
readonly TAN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TAN}m"
readonly ANSI_COLOR_OLIVE="143"
readonly OLIVE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_OLIVE}m"
readonly ANSI_COLOR_AMBER="208"
readonly AMBER="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_AMBER}m"
readonly ANSI_COLOR_BRICK="160"
readonly BRICK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BRICK}m"
readonly ANSI_COLOR_SLATE_BLUE="111"
readonly SLATE_BLUE="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_SLATE_BLUE}m"
readonly ANSI_COLOR_TEAL="79"
readonly TEAL="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TEAL}m"
readonly ANSI_COLOR_SALMON="215"
readonly SALMON="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_SALMON}m"
readonly ANSI_COLOR_HOT_PINK="197"
readonly HOT_PINK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_HOT_PINK}m"
readonly ANSI_COLOR_PINK="205"
readonly PINK="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PINK}m"
readonly ANSI_COLOR_CREAM="223"
readonly CREAM="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_CREAM}m"
readonly ANSI_COLOR_BRIGHT_RED="196"
readonly BRIGHT_RED="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_BRIGHT_RED}m"
readonly ANSI_COLOR_DARK_GREEN="34"
readonly DARK_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_DARK_GREEN}m"
readonly ANSI_COLOR_LIME="77"
readonly LIME="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_LIME}m"
readonly ANSI_COLOR_PALE_GREEN="151"
readonly PALE_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_PALE_GREEN}m"
readonly ANSI_COLOR_STRAW="185"
readonly STRAW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_STRAW}m"
readonly ANSI_COLOR_TERRACOTTA="167"
readonly TERRACOTTA="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_TERRACOTTA}m"
readonly ANSI_COLOR_MAGENTA="201"
readonly MAGENTA="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_MAGENTA}m"
readonly ANSI_COLOR_NEON_GREEN="118"
readonly NEON_GREEN="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_NEON_GREEN}m"
readonly ANSI_COLOR_NEON_YELLOW="226"
readonly NEON_YELLOW="${ESC}${CSI}${FG_COLOR};${ANSI_COLOR_NEON_YELLOW}m"
readonly BOLD="${ESC}[1m"
readonly RESET="${NC}"
