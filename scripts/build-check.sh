#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# build-check.sh — das Wheel aus dist/ wie ein User ohne Klon installieren
#
# Für make build-check (Konzept DevTools T-20 und T-43): pipx installiert das
# Wheel mit seinem eigenen Python in ein leeres PIPX_HOME, ohne rechnerlokale
# Zuordnung und ohne Zugriff auf GitHub. Danach müssen `bashlib --version` und
# `bashlib-path` laufen und tools.lib.sh aus dem installierten Paket ladbar
# sein. Nach dem Vorbild von scripts/build-check.sh in CLITheme.
#
#   make build && make build-check
#
# Exit: 0 Paket läuft, 1 kein Wheel oder Installation bzw. Aufruf gescheitert
# ------------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# printThemeStatus aus dieser Arbeitskopie
. "${ROOT}/src/cli.lib.sh"

# Temporärer Ordner für pipx; global, weil der EXIT-Trap erst nach main läuft
home=""

fail() {
    printThemeStatus "✗" "$1" ERR >&2
    exit 1
}

main() {
    local built=("${ROOT}"/dist/mmit_bashlib-*.whl)
    [[ -f "${built[0]}" ]] || fail "Kein Wheel unter dist/: make build"
    local wheel="dist/${built[0]##*/}"

    home="$(mktemp -d)"
    trap 'command rm -rf -- "${home}"' EXIT
    # Die eine Git-Einstellung über die Umgebung ersetzt die Zuordnung von devtools und leitet
    # jeden Abruf von GitHub ins Leere; DEVTOOLS_LOCAL_SOURCES=off gilt für alles, was DevTools
    # dabei startet.
    env PIPX_HOME="${home}/pipx" PIPX_BIN_DIR="${home}/bin" PIPX_MAN_DIR="${home}/man" \
        GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=url.https://github.invalid/.insteadOf \
        GIT_CONFIG_VALUE_0=https://github.com/ DEVTOOLS_LOCAL_SOURCES=off GIT_TERMINAL_PROMPT=0 \
        pipx install --quiet "${built[0]}" >/dev/null \
        || fail "${wheel} lässt sich mit pipx ohne lokale Repos und GitHub nicht installieren"

    local version libs
    version="$("${home}/bin/bashlib" --version 2>&1)" || fail "bashlib --version scheitert nach der Installation von ${wheel}"
    libs="$("${home}/bin/bashlib-path")" || fail "bashlib-path scheitert nach der Installation von ${wheel}"
    BASH_LIBS="${libs}" bash -c '. "${BASH_LIBS}/tools.lib.sh" && [[ -n "${__TOOLS_LIB__:-}" ]]' \
        || fail "tools.lib.sh aus ${libs} lässt sich nicht laden"
    printThemeStatus "✓" "bashlib ${version%%$'\n'*} aus ${wheel}, mit pipx ohne lokale Repos und GitHub" OK
}

main "$@"
