#!/usr/bin/env bash
# shellcheck disable=SC2034
readonly __STYLES_LIB__="styles.lib.sh";

#------------------------------------------------------------------------------
# Global definierte Styles
#
# Einbinden:
#     if [[ "${__STYLES_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/styles.lib.sh"; fi
#
# Usage:
#     show_menu() {
#         local _intent="${MM_GLOBAL_STYLE_INTENT:-    }"
#         local _title_color="${MM_GLOBAL_STYLE_TITLE_COLOR:-${GREEN}}"
#         local _bullet_color="${MM_GLOBAL_STYLE_BULLET_COLOR:-${YELLOW}}"
#
#         echo -e "${_title_color}$_title${NC}"
#         for i in "${!_options[@]}"; do
#             echo -e "${_intent}${_bullet_color}$((i+1)).${NC} ${_options[$i]}"
#         done
#     }
#
#------------------------------------------------------------------------------

if [[ "${__COLORS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/colors.lib.sh"; fi

# Usage:
#     local _intent="${MM_GLOBAL_STYLE_INTENT:-    }"
# export MM_GLOBAL_STYLE_INTENT="    "

# Usage:
#     local _title_color="${MM_GLOBAL_STYLE_TITLE_COLOR:-${GREEN}}"
# export MM_GLOBAL_STYLE_TITLE_COLOR="${RED}"

# Usage:
#     local _bullet_color="${MM_GLOBAL_STYLE_BULLET_COLOR:-${YELLOW}}"
# export MM_GLOBAL_STYLE_BULLET_COLOR="${BLUE}"

# Usage:
#     local _hint_color="${MM_GLOBAL_STYLE_HINT_COLOR:-${BLUE}}"
# export MM_GLOBAL_STYLE_HINT_COLOR="${BLUE}"