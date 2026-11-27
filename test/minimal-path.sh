#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# minimal-path.sh — verkürzter PATH für Tests, die ein fehlendes Werkzeug nachstellen
#
# Zum Einbinden in test/_test*.sh. Der Ordner eines Befehls (etwa /opt/homebrew/bin
# für bash) enthält oft auch Werkzeuge wie pipx; ihn in den PATH zu nehmen, ließe
# „pipx fehlt“ ins Leere laufen. minimalPath verlinkt deshalb nur die genannten
# Befehle, requireMissing bricht ab, wenn ein nachgestellt fehlendes Werkzeug doch
# gefunden wird (etwa pipx aus apt in /usr/bin).
#
#   . "${ROOT}/test/minimal-path.sh"
#   BASE_PATH="$(minimalPath "${work}/base-bin" bash make)"
#   requireMissing "${BASE_PATH}" pipx devtools
# ------------------------------------------------------------------------------

# Legt ORDNER mit Links auf die BEFEHLE aus dem aktuellen PATH an und gibt
# „ORDNER:/usr/bin:/bin“ aus. Die Bash 5 kommt so vor /bin (macOS: Bash 3.2).
#   minimalPath ORDNER BEFEHL...
minimalPath() {
    local -r dir="$1"; shift
    local cmd target
    mkdir -p "${dir}"
    for cmd in "$@"; do
        target="$(command -v "${cmd}")" || { echo "minimalPath: ${cmd} fehlt im PATH" >&2; return 1; }
        ln -sf "${target}" "${dir}/${cmd}"
    done
    printf '%s:/usr/bin:/bin' "${dir}"
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
