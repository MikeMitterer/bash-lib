#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# isolated-path.sh — PATH für Tests, die ein fehlendes Werkzeug nachstellen
#
# Zum Einbinden in test/_test*.sh. Ein Werkzeug kann überall liegen: pipx etwa
# neben bash in /opt/homebrew/bin (Homebrew) oder in /usr/bin (Debian). Ein PATH
# aus ganzen Ordnern ließe „pipx fehlt“ dann ins Leere laufen. isolatedPath baut
# deshalb einen eigenen Ordner, aus dem die fehlenden Werkzeuge entfernt sind;
# requireMissing bricht ab, wenn eines trotzdem gefunden wird, etwa in .tools/bin,
# das das Makefile vor den PATH stellt.
#
#   . "${ROOT}/test/isolated-path.sh"
#   BASE_PATH="$(isolatedPath "${work}/base-bin" "pipx devtools" bash make git)"
#   requireMissing "${ROOT}/.tools/bin:${BASE_PATH}" pipx devtools
# ------------------------------------------------------------------------------

# Legt ORDNER mit Links auf alle Befehle aus /usr/bin und /bin an (in dieser Rangfolge),
# dazu die BEFEHLE aus dem aktuellen PATH (etwa die Bash 5 statt /bin/bash 3.2), und
# entfernt die WERKZEUGE. Gibt ORDNER aus: Er allein ist der PATH.
#   isolatedPath ORDNER "WERKZEUG..." BEFEHL...
isolatedPath() {
    local -r dir="$1"
    local -a missing
    read -ra missing <<< "$2"
    shift 2
    local cmd target
    mkdir -p "${dir}"
    # Gleiche Namen in /bin überspringt ln mit einer Meldung; /usr/bin geht vor wie im PATH
    ln -s /usr/bin/* /bin/* "${dir}/" 2>/dev/null
    for cmd in "$@"; do
        target="$(command -v "${cmd}")" || { echo "isolatedPath: ${cmd} fehlt im PATH" >&2; return 1; }
        ln -sf "${target}" "${dir}/${cmd}"
    done
    for cmd in "${missing[@]}"; do rm -f "${dir}/${cmd}"; done
    printf '%s' "${dir}"
}

# Bricht den Test ab, wenn einer der BEFEHLE im PATH liegt: Ein Fall „BEFEHL fehlt“
# prüfte sonst nichts.
#   requireMissing PATH BEFEHL...
requireMissing() {
    local -r path="$1"; shift
    local cmd found
    for cmd in "$@"; do
        found="$(PATH="${path}" command -v "${cmd}")" || continue
        echo "Testvoraussetzung verletzt: ${cmd} soll fehlen, liegt aber in ${found}" >&2
        exit 1
    done
}
