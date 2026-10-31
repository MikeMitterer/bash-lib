#!/usr/bin/env bash
#set -Eeuo pipefail
#LC_ALL=C

: "${GREEN:=""}"
: "${NC:=""}"

readonly __VERSION_LIB__="version.lib.sh";

#------------------------------------------------------------------------------
# Gibt die verschiedenen, verwendeten, Versionen (GIT usw.) aus
#
# Einbinden:
#     if [[ "${__VERSION_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/version.lib.sh"; fi
#
#------------------------------------------------------------------------------

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Private
#

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Public
#

# Helper für die Anzeige der aktuellen GIT-Version
showDevVersion() {
    echo "Development: "
    echo -e "    ${GREEN}$(gitVersion)${NC}"
}

# Gibt die aktuelle (SemVer-kompatible) Version zurück.
#
# Quelle: Git-Tag (z. B. v25.3.1+250812.1410); bei dirty -> ".d"
# Fallback ohne Tag: 0.0.0+YYMMDD.HHMM[.hash][.d]
#
# Version kann so gesetzt werden: `git tag -a v1.1 -m "SSH-Server implementiert"`
# Mit `git tag -n v1.1` kann die Message angezeigt werden
#
# Die Tags sollten immer "mitgepusht" werden:
#     git config --global push.followTags true
#
# Usage:
#      echo "Version: $(gitVersion)"
#
gitVersion() {
    local _repo="."
    local _hash_len=5

    # Hilfsfunktion lokal, wie im File üblich
    _git() { command git -C "$_repo" "$@" 2>/dev/null; }

    # 1) Tag lesen (bevorzugt vYY.MINOR.PATCH+YYMMDD.HHMM)
    local _tag _ver
    _tag="$(_git describe --tags --abbrev=0 --match 'v[0-9]*' || true)"

    if [[ -n "$_tag" ]]; then
        # Tag ohne führendes "v"
        _ver="${_tag#v}"
    else
        # 2) Fallback ohne Tag: 0.0.0 + Zeit (und optional Hash)
        local _date_part _time_part _hash=""
        _date_part="$(date -u +%y%m%d)"
        _time_part="$(date -u +%H%M)"

        if _git rev-parse HEAD >/dev/null; then
            _hash="$(_git rev-parse --short="${_hash_len}" HEAD || true)"
        fi

        _ver="0.0.0+${_date_part}.${_time_part}"
        [[ -n "$_hash" ]] && _ver+=".${_hash}"
    fi

    # 3) Dirty-Flag (als zusätzliches Build-Ident in SemVer)
    if _git rev-parse --git-dir >/dev/null 2>&1; then
        if ! _git diff --quiet --ignore-submodules --; then
            # Wenn bereits Build-Meta vorhanden ist (enthält '+'), hänge ".d" an,
            # sonst beginne neues Build-Meta mit "+d".
            if [[ "$_ver" == *"+"* ]]; then
                _ver+=".d"
            else
                _ver+="+d"
            fi
        fi
    fi

    printf '%s\n' "$_ver"
}

# Gibt die Git-Major-Version zurück
#
# Usage:
#      echo "Major: $(gitMajorVersion)"
#
gitMajorVersion() {
    local _repo="."
    local _VERSION
    _VERSION="$(gitVersion)"

    # Build-Meta (+...) entfernen
    _VERSION="${_VERSION%%+*}"
    # PreRelease (-...) entfernen
    _VERSION="${_VERSION%%-*}"

    local _MAJOR
    _MAJOR="$(echo "${_VERSION}" | awk -F'.' '{print $1}')"

    printf '%s\n' "$_MAJOR"
}

# Gibt die Git-Minor-Version zurück
#
# Usage:
#      echo "Minor: $(gitMinorVersion)"
#
gitMinorVersion() {
    local _repo="."
    local _VERSION
    _VERSION="$(gitVersion)"

    # Build-Meta (+...) entfernen
    _VERSION="${_VERSION%%+*}"
    # PreRelease (-...) entfernen
    _VERSION="${_VERSION%%-*}"

    local _MINOR
    _MINOR="$(echo "${_VERSION}" | awk -F'.' '{print $2}')"

    printf '%s\n' "$_MINOR"
}

# Gibt die Git-Patch-Version zurück (Dritter Teil in der Versionsnummer)
#
# Usage:
#      echo "Patch: $(gitPatchVersion)"
#
gitPatchVersion() {
    local _repo="."

    # Tag oder Fallback-Version holen
    local _VERSION
    _VERSION="$(gitVersion)"

    # Alles nach einem '+' (Build-Meta) entfernen
    _VERSION="${_VERSION%%+*}"
    # Alles nach einem '-' (PreRelease) entfernen
    _VERSION="${_VERSION%%-*}"

    # Patch extrahieren (dritter Punkt-getrennter Teil)
    local _PATCH
    _PATCH="$(echo "${_VERSION}" | awk -F'.' '{print $3}')"

    printf '%s\n' "$_PATCH"
}

# Versionsinfo in der CalVer-Variante
#
# Die CalVer setzt sich aus dem aktuellen Jahr und dem
# aktuellen Quartal zusammen
calVer() {
    local QUARTER=$((($(date +%-m) - 1) / 3 + 1))
    date +"%y.$QUARTER"
}

# Versionsinfo als HashVer-Variante
#
# Die HashVer setzt sich aus dem aktuellen Jahr, dem aktuellen
# Quartal und dem aktuellen Hash-Wert des letzten Git-Commits zusammen
#
# Usage:
#   echo $(hashVer 4 "RC1")
#   echo $(hashVer 4 "" .)
#   echo $(hashVer 4 )
#   echo $(hashVer 4 "")
#   echo $(hashVer 4 "alpha")
#   echo $(hashVer 4 "alpha" ".")
#   echo $(hashVer 0 "alpha")
#   echo $(hashVer 0 )
#
# Params:
#   HASH_DIGITS - Anzahl der Stellen des Hashwertes
#   PRERELEASE_IDENTIFIER - Damit kann definiert werden ob
#                           die Version ein Snapshot, eine alpha usw. ist
#   META_SEPARATOR - Laut SemVer ist der Meta-Separator ein + allerdings kann Docker das nicht
hashVer() {
    local HASH_DIGITS=${1:-8}
    local PRERELEASE_IDENTIFIER=${2:-"SNAPSHOT"}
    local META_SEPARATOR=${3:-"+"}

    local POSTFIX=${PRERELEASE_IDENTIFIER}
    local POSTFIX_SEPARATOR=""
    local QUARTER=$((($(date +%-m) - 1) / 3 + 1))

    if [[ HASH_DIGITS -gt 0 ]]; then
        local HASH=$(git rev-parse HEAD | cut -c-$HASH_DIGITS)

        date +"%y.$QUARTER.0-$POSTFIX$POSTFIX_SEPARATOR%m%d$META_SEPARATOR${HASH}"

    else
        if [[ $POSTFIX != "SNAPSHOT" ]]; then
            date +"%y.$QUARTER.0-$POSTFIX$POSTFIX_SEPARATOR%m%d"
        else
            date +"%y.$QUARTER"
        fi
    fi
}

# Zeigt die Version aus einem Jason-Package an
#
# Usage:
#   packageVersion
#
packageVersion() {
    if [[ ! -f "package.json" ]]; then
        echo
        echo -e "${RED}This is not a NODE-Project!${NC}"
        echo
        return 1
    fi

    # Implizit ein "pull" ist wahrscheinlich
    # nicht so gut...
    #
    # if [[ -d ".git" ]]; then
    #     git pull >> /dev/null
    # fi

    # -r (raw) entfernt die Anführungszeichen
    jq -r '.version' <"package.json"
}

# Liest die aktuelle Projekt-Version framework-korrekt aus der Versionsdatei.
#
# Auto-Detect-Kette (erste vorhandene Datei gewinnt):
#   package.json → pyproject.toml → pom.xml → build.gradle.kts →
#   build.gradle → VERSION
# Deckt npm, Python, Maven und Gradle (Groovy + Kotlin DSL) ab. VERSION ist nur
# der Fallback für Projekte OHNE Framework-Versionsdatei — existiert eine
# Framework-Datei, ist sie die Single Source of Truth.
#
# Hinweis: Die Bump-Funktionen (semVerBump/calVerBump/bumpVer) schreiben nur
# package.json/pyproject.toml/VERSION. readProjectVersion liest zusätzlich
# Maven/Gradle (read-only) — für JVM-Projekte ist das Bumpen noch manuell.
#
# Gradle: Version bevorzugt aus gradle.properties (`version=...`), sonst aus dem
#   Build-Skript (`version = "..."` / `version '...'`).
# Maven: erstes <version> unter <project> — der <parent>-Block wird übersprungen;
#   `<version>${prop}</version>` (Property-Referenz) wird NICHT aufgelöst.
#
# Ersetzt die pro-Makefile inline-Extraktion, die sonst zwischen Repos driftet.
#
# Keine Fehlerausgaben — Meldungen gehören in den Aufrufer (ANSI-Farben,
# Kontext). Fehler werden ausschliesslich über Exit-Codes signalisiert.
#
# readProjectVersion [source=auto] [repo=.]
#
# Parameter:
#   $1  source  (default: auto; sonst package.json|pyproject.toml|pom.xml|
#               build.gradle|build.gradle.kts|gradle.properties|VERSION)
#   $2  repo    (default: .)   Verzeichnis, das die Versionsdatei enthält
#
# Rückgabe (stdout): nackte Version, z.B. "0.2.0"
#
# Exit-Codes:
#   0  — Version erfolgreich gelesen
#   5  — keine Versionsdatei gefunden          (source=auto)
#   6  — angeforderte Quelldatei nicht vorhanden / unbekannt
#   7  — Version konnte nicht gelesen werden    (leer)
#
# Usage:
#   ver="$(readProjectVersion)"            || { echo "keine Versionsdatei" >&2; exit 1; }
#   ver="$(readProjectVersion auto ../app)"
#   ver="$(readProjectVersion pyproject.toml)"
#
readProjectVersion() {
    local _source="${1:-auto}"
    local _repo="${2:-.}"

    # 1) Quelldatei bestimmen (Auto-Detect: Framework zuerst, VERSION als Fallback)
    if [[ "$_source" == "auto" ]]; then
        if   [[ -f "${_repo}/package.json"     ]]; then _source="package.json"
        elif [[ -f "${_repo}/pyproject.toml"   ]]; then _source="pyproject.toml"
        elif [[ -f "${_repo}/pom.xml"          ]]; then _source="pom.xml"
        elif [[ -f "${_repo}/build.gradle.kts" ]]; then _source="build.gradle.kts"
        elif [[ -f "${_repo}/build.gradle"     ]]; then _source="build.gradle"
        elif [[ -f "${_repo}/VERSION"          ]]; then _source="VERSION"
        else
            return 5
        fi
    elif [[ ! -f "${_repo}/${_source}" ]]; then
        return 6
    fi

    # 2) Version framework-korrekt lesen
    local _ver=""
    case "$_source" in
        package.json)
            if command -v jq >/dev/null 2>&1; then
                _ver="$(jq -r '.version // empty' <"${_repo}/package.json")"
            else
                _ver="$(sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "${_repo}/package.json" | head -1)"
            fi
            ;;
        pyproject.toml)
            _ver="$(awk -F'"' '/^version[[:space:]]*=/{print $2; exit}' "${_repo}/pyproject.toml")"
            ;;
        pom.xml)
            # Maven: erstes <version> unter <project>; <parent>-Block (dessen
            # eigene <version>) vorher entfernen. Property-Refs bleiben unaufgelöst.
            _ver="$(sed -e '/<parent>/,/<\/parent>/d' "${_repo}/pom.xml" \
                      | grep -m1 -oE '<version>[^<]*</version>' \
                      | sed -E 's#</?version>##g' | tr -d '[:space:]')"
            ;;
        build.gradle|build.gradle.kts)
            # Gradle: gradle.properties (version=...) hat Vorrang vor dem Build-Skript
            if [[ -f "${_repo}/gradle.properties" ]] \
               && grep -qE '^[[:space:]]*version[[:space:]]*=' "${_repo}/gradle.properties"; then
                _ver="$(grep -E '^[[:space:]]*version[[:space:]]*=' "${_repo}/gradle.properties" \
                          | head -1 | sed -E 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')"
            else
                # version = "1.2.3" | version = '1.2.3' | version '1.2.3' | version("1.2.3")
                _ver="$(sed -nE "s/^[[:space:]]*version[[:space:]]*[=(][[:space:]]*[\"']([^\"']+)[\"'].*/\1/p; s/^[[:space:]]*version[[:space:]]+[\"']([^\"']+)[\"'].*/\1/p" "${_repo}/${_source}" | head -1)"
            fi
            ;;
        gradle.properties)
            _ver="$(grep -E '^[[:space:]]*version[[:space:]]*=' "${_repo}/gradle.properties" \
                      | head -1 | sed -E 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r')"
            ;;
        VERSION)
            _ver="$(cat "${_repo}/VERSION")"
            ;;
        *)
            return 6
            ;;
    esac

    [[ -z "$_ver" || "$_ver" == "{}" ]] && return 7
    printf '%s\n' "$_ver"
}

# Erzeugt eine kurze, SemVer-kompatible Version:
#   <TAG-oder-0.0.0>[-PRERELEASE][+YYMMDD.HHMM.<hash>[.dirty]]
#
# Usage:
#   semVerWithDate [prerelease] [repo] [docker_safe] [hash_len]
#
#   semVerWithDate rc1
#   semVerWithDate rc1 . 1 7
#   semVerWithDate rc1 /path/to/repo 1 7
#   semVerWithDate rc1 /path/to/repo 0 7
#   semVerWithDate rc1 /path/to/repo 1 5
#
# git:
#     git tag -a v1.4.2 -m "…"
#
# Parameter:
#   $1  prerelease        (optional, z. B. rc1)
#   $2  repo              (default: .)
#   $3  docker_safe       (default: 0; 1 => "-build-" statt "+")
#   $4  hash_len          (default: 5)
#
semVerWithDate() {
    local _prerelease="${1:-}"
    local _repo="${2:-.}"
    local _docker_safe="${3:-0}"
    local _hash_len="${4:-5}"

    _git() { command git -C "$_repo" "$@" 2>/dev/null; }

    # Basisversion immer aus Repo-Tag (vX.Y.Z), Fallback 0.0.0
    local _base=""
    if _git rev-parse --git-dir >/dev/null; then
        local _tag
        _tag=$(_git describe --tags --abbrev=0 --match 'v[0-9]*' || true)
        _base="${_tag#v}"
    fi
    [[ -z "$_base" ]] && _base="0.0.0"

    # Build-Meta: yymmdd.hhmm + kurzer Hash + optional dirty
    local _date_part _time_part _hash _dirty=""
    _date_part="$(date -u +%y%m%d)"
    _time_part="$(date -u +%H%M)"

    if _git rev-parse HEAD >/dev/null; then
        _hash="$(_git rev-parse --short="${_hash_len}" HEAD || true)"
        if ! _git diff --quiet --ignore-submodules --; then
            _dirty=".dirty"
        fi
    else
        _hash="nogit"
    fi

    local _build="${_date_part}.${_time_part}.${_hash}${_dirty}"

    # Version zusammensetzen
    local _v="$_base"
    [[ -n "$_prerelease" ]] && _v+="-${_prerelease}"

    if [[ "$_docker_safe" == "1" ]]; then
        _v+="-build-${_build}" # Docker- & Registry-freundlich
    else
        _v+="+${_build}" # SemVer-konform
    fi

    printf '%s\n' "$_v"
}

# Erzeugt einen Docker-kompatiblen Image-Tag auf Basis des aktuellen Git-Tags.
#
# Format: <version>-<YYMMDD>.<HHMM>.<hash>[.ahead<N>][.d]
#   .ahead<N>  — N Commits seit dem letzten Tag (Repo ist weiter als der Tag)
#   .d         — Working-Tree hat uncommittete Änderungen (dirty)
#
# Das "+" aus SemVer-Build-Meta ist in Docker-Tags nicht erlaubt — daher "-" als Trenner.
# Build-Meta des Git-Tags (z.B. +260402.1006.abc12) wird vor Verwendung entfernt.
#
# Parameter:
#   $1  strict    (default: 2)
#                 0 = Tag immer generieren (Fallback "0.0.0", .ahead/.d als Indikatoren)
#                 1 = strict:         Fehler bei kein Tag, dirty ODER ahead > 0
#                 2 = relaxed strict: Fehler bei kein Tag oder dirty; ahead erlaubt
#   $2  repo      (default: .)
#   $3  hash_len  (default: 5)
#
# Rückgabewerte:
#   0  — Tag erfolgreich generiert
#   2  — kein Git-Tag vorhanden        (strict >= 1)
#   3  — Working-Tree ist dirty        (strict >= 1)
#   4  — Repo ist ahead vom letzten Tag (strict == 1)
#
# Keine Fehlerausgaben — Fehlermeldungen gehören in den Aufrufer,
# der dort ANSI-Farben und Kontext zur Verfügung hat.
#
# Usage:
#   gitDockerTag                          # relaxed strict (default), aktuelles Repo
#   gitDockerTag 1                        # strict: kein Tag, dirty oder ahead → Fehler
#   gitDockerTag 2                        # relaxed strict (explizit): ahead erlaubt
#   gitDockerTag 0                        # immer generieren, Fallback 0.0.0
#   gitDockerTag 2 /path/to/repo          # anderes Repo
#   gitDockerTag 0 . 7                    # 7-stelliger Hash
#
#   # Typische Verwendung in build.sh — set -e sicher:
#   # || verhindert set -e UND sichert den Exit-Code in einem Schritt
#   _rc=0
#   TAG="$(gitDockerTag)" || _rc=$?
#   [[ $_rc -eq 2 ]] && { echo "Kein Git-Tag" >&2;      exit 1; }
#   [[ $_rc -eq 3 ]] && { echo "Working-Tree dirty" >&2; exit 1; }
#   [[ $_rc -eq 4 ]] && { echo "Repo ist ahead" >&2;    exit 1; }
#   readonly TAG
#
#   TAG="$(gitDockerTag 0)"   # CI-Fallback: immer bauen, .d/.ahead zeigen Status
#
#   # Beispiel-Ausgaben (Git-Tag: v0.1.0+260402.1006.abc12, Build-Meta wird entfernt):
#   #   0.1.0-260412.1030.abc12          ← sauber, genau am Tag
#   #   0.1.0-260412.1030.def34.ahead3   ← 3 Commits nach dem Tag (anderer Hash)
#   #   0.1.0-260412.1030.abc12.d        ← uncommittete Änderungen
#   #   0.1.0-260412.1030.def34.ahead3.d ← ahead + dirty
#   #   0.0.0-260412.1030.abc12          ← kein Tag, strict=0 (Fallback)
#
gitDockerTag() {
    local _strict="${1:-2}"
    local _repo="${2:-.}"
    local _hash_len="${3:-5}"

    _git() { command git -C "$_repo" "$@" 2>/dev/null; }

    # 1) Git-Tag lesen
    local _tag_ref
    _tag_ref="$(_git describe --tags --abbrev=0 --match 'v[0-9]*' || true)"

    if [[ -z "$_tag_ref" ]]; then
        [[ "$_strict" -ge 1 ]] && return 2
        _tag_ref=""
    fi

    # 2) Dirty-Check
    if ! _git diff --quiet --ignore-submodules --; then
        [[ "$_strict" -ge 1 ]] && return 3
    fi

    # 3) Bestandteile ermitteln
    # Build-Meta (+YYMMDD.HHMM.hash) aus dem Git-Tag entfernen — in Docker-Tags nicht erlaubt
    local _base="${_tag_ref#v}"
    _base="${_base%%+*}"
    [[ -z "$_base" ]] && _base="0.0.0"

    local _hash
    _hash="$(_git rev-parse --short="${_hash_len}" HEAD || echo "nogit")"

    local _meta
    _meta="$(date -u +%y%m%d).$(date -u +%H%M).${_hash}"

    # 4) Ahead-Count: Commits seit dem letzten Tag
    local _ahead=0
    if [[ -n "$_tag_ref" ]]; then
        _ahead="$(_git rev-list "${_tag_ref}..HEAD" --count || echo 0)"
        if [[ "$_ahead" -gt 0 ]]; then
            [[ "$_strict" -eq 1 ]] && return 4
            _meta+=".ahead${_ahead}"
        fi
    fi

    # 5) Dirty-Suffix
    _git diff --quiet --ignore-submodules -- || _meta+=".d"

    printf '%s\n' "${_base}-${_meta}"
}

#------------------------------------------------------------------------------
# _gitCalcNextVersion [bump=minor|patch] [prerelease] [year=current|last-tag|YY|YYYY]
#
# Berechnet die nächste Version basierend auf vorhandenen Git-Tags.
# Setzt KEINEN Tag — nur Berechnung.
#
# Returns: Basis-Version z.B. "v26.3.0" oder "v26.3.0-rc1"
#
_gitCalcNextVersion() {
  local _bump="${1:-patch}"
  local _pre="${2:-}"
  local _year_sel="${3:-current}"

  # --- Jahr bestimmen -------------------------------------------------------
  local _yy
  case "$_year_sel" in
      current | "")
          _yy="$(date -u +%y)"
          ;;
      last-tag)
          local _ltag
          _ltag="$(git tag --list 'v[0-9][0-9].*' --sort=-creatordate | head -n1 || true)"
          if [[ -n "$_ltag" ]]; then
              _yy="${_ltag#v}"
              _yy="${_yy%%.*}"
          else
              _yy="$(date -u +%y)"
          fi
          ;;
      [0-9][0-9][0-9][0-9])
          _yy="${_year_sel:2:2}"
          ;;
      [0-9][0-9])
          _yy="${_year_sel}"
          ;;
      *)
          printf 'Ungültiger year-Parameter: %s\n' "$_year_sel" >&2
          return 2
          ;;
  esac

  # --- Tags vom Remote holen ------------------------------------------------
  git fetch --tags --quiet 2>/dev/null || true

  # --- Repo-Guards ----------------------------------------------------------
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      printf 'Repo hat noch keinen Commit – bitte zuerst committen.\n' >&2
      return 4
  fi
  if ! git diff --quiet --ignore-submodules -- 2>/dev/null; then
      printf 'Working tree ist dirty – commit/stash vor dem Taggen.\n' >&2
      return 3
  fi

  # --- Hinweise -------------------------------------------------------------
  local _cur_year
  _cur_year="$(date -u +%y)"
  if [[ "$_yy" != "$_cur_year" ]]; then
      printf 'Hinweis: Du taggst für Jahr v%s.*, aktuelles Jahr ist v%s.* (year=%s).\n' \
          "$_yy" "$_cur_year" "$_year_sel" >&2
  fi

  local _last_any _last_year
  _last_any="$(git tag --list 'v[0-9][0-9].*' --sort=-creatordate | head -n1 || true)"
  if [[ -n "$_last_any" ]]; then
      _last_year="${_last_any#v}"
      _last_year="${_last_year%%.*}"
      if [[ "$_last_year" != "$_yy" ]]; then
          printf '   Letztes vorhandenes Jahres-Tag: v%s.*\n' "$_last_year" >&2
      fi
  fi

  # --- Höchstes Minor/Patch im Zieljahr finden ------------------------------
  local _last_minor=0 _last_patch=0
  while IFS= read -r _t; do
      local _vsn="${_t#v}"
      _vsn="${_vsn%%+*}"
      _vsn="${_vsn%%-*}"
      local _maj="${_vsn%%.*}"
      local _rest="${_vsn#${_maj}.}"
      local _min="${_rest%%.*}"
      local _pat="${_rest#*.}"
      if [[ "$_maj" == "$_yy" ]]; then
          if ((10#${_min} > 10#${_last_minor})) ||
              { ((10#${_min} == 10#${_last_minor})) && ((10#${_pat} > 10#${_last_patch})); }; then
              _last_minor="${_min}"
              _last_patch="${_pat}"
          fi
      fi
  done < <(git tag --list "v${_yy}.*" | sort -V)

  # --- Nächste Version bestimmen --------------------------------------------
  local _next_minor _next_patch
  if [[ "$_bump" == "patch" ]] && ((10#${_last_minor} > 0)); then
      _next_minor="${_last_minor}"
      _next_patch=$((10#${_last_patch} + 1))
  else
      _next_minor=$((10#${_last_minor} + 1))
      _next_patch=0
  fi

  # --- Basis + PreRelease zusammensetzen ------------------------------------
  local _base="v${_yy}.${_next_minor}.${_next_patch}"
  [[ -n "$_pre" ]] && _base="${_base}-${_pre}"

  printf '%s\n' "$_base"
}

#------------------------------------------------------------------------------
# _gitPushFollowTags <tag>
#
# Pusht den aktuellen Branch samt annotierter Tags (git push --follow-tags).
# Scheitert der Push, meldet die Funktion auf stderr, dass <tag> und sein
# Commit nur lokal liegen und wie man nachpusht, und gibt den Exit-Code von
# git push zurück.
#
_gitPushFollowTags() {
  local _tag="${1:?_gitPushFollowTags: tag fehlt}"
  local _rc=0
  git push --follow-tags || _rc=$?
  if ((_rc != 0)); then
      local _remote _branch
      _remote="$(git remote | head -n1)"
      _branch="$(git symbolic-ref --short -q HEAD || echo "<branch>")"
      printf 'Fehler: git push fehlgeschlagen (Exit %s) – Tag %s und sein Commit liegen nur lokal!
' "$_rc" "$_tag" >&2
      printf 'Nachpushen: git push --follow-tags (ohne Upstream: git push -u %s %s --follow-tags)
' "$_remote" "$_branch" >&2
  fi
  return "$_rc"
}

#------------------------------------------------------------------------------
# _gitSetVersionTag <base_version>
#
# Erstellt Git-Tag aus Basis-Version + Datum/Uhrzeit + kurzem Commit-Hash.
# Pushed Tag zum Remote (falls vorhanden).
#
# Input:   "v26.3.0" oder "v26.3.0-rc1"
# Returns: vollständiger Tag z.B. "v26.3.0+260327.1445.abc12"
# Exit:    ≠ 0, wenn der Push scheitert (Tag bleibt lokal, Hinweis auf stderr);
#          ohne Remote 0 mit Hinweis "Tag nur lokal erstellt"
#
# Der Hash macht den Tag selbsterklärend — in CI-Logs, Docker-Registries
# und Deployment-Protokollen ist der Commit direkt ablesbar ohne git.
#
_gitSetVersionTag() {
  local _base="${1:?_gitSetVersionTag: base_version fehlt}"
  local _msg="${2:-$(git log -1 --pretty=%s)}"

  # --- Zeitstempel + Hash ---------------------------------------------------
  local _date _hash
  _date="$(date +%y%m%d.%H%M)"
  _hash="$(git rev-parse --short=5 HEAD 2>/dev/null || echo "nogit")"

  # --- Vollständigen Tag zusammensetzen -------------------------------------
  local _tag="${_base}+${_date}.${_hash}"

  # --- Kollision vermeiden (zweites Tag in derselben Minute) ----------------
  if git rev-parse -q --verify "refs/tags/${_tag}" >/dev/null; then
      local _suffix=a
      while git rev-parse -q --verify "refs/tags/${_tag}${_suffix}" >/dev/null; do
          _suffix=$(printf '%s' "$_suffix" | tr '0-9a-y' '1-9a-z')
      done
      _tag="${_tag}${_suffix}"
  fi

  # --- Tag schreiben + pushen -----------------------------------------------
  git tag -a "$_tag" -m "${_msg}"
  if git remote >/dev/null 2>&1 && [[ -n "$(git remote)" ]]; then
      _gitPushFollowTags "$_tag" || return $?
  else
      printf 'Hinweis: Kein Remote konfiguriert – Tag nur lokal erstellt! (%s)\n' "$_tag" >&2
  fi

  printf '%s\n' "$_tag"
}

# gitUpdateVersionTag [bump=minor|patch] [prerelease] [year=current|last-tag|YY|YYYY]
#
# Berechnet nächste Version, setzt Git-Tag und pushed.
# Falls HEAD bereits getaggt ist → existierenden Tag zurückgeben (Reuse).
#
# Zweck
# -----
# Erzeugt/aktualisiert einen Git-Tag nach Schema:
#   v<YY>.<MINOR>.<PATCH>[ -<PRERELEASE> ] + <YYMMDD>.<HHMM>.<hash>
# (Datum/Zeit in UTC, ohne Sekunden; Hash 5 Stellen).
#
# Jahr-Strategie
# --------------
#   year = current    -> nutzt das aktuelle UTC-Jahr (Default)
#   year = last-tag   -> leitet das Jahr aus dem zuletzt vorhandenen Jahres-Tag ab
#   year = 25 / 2025  -> festes Jahr vorgeben (YY oder YYYY)
#
# Logik
# -----
# - Prüft, ob HEAD bereits einen Tag des gewählten Jahres hat → reuse
# - Sucht den höchsten <MINOR>.<PATCH> für dieses Jahr und bump’t:
#       bump=minor  -> <MINOR> + 1, PATCH = 0
#       bump=patch  -> <PATCH> + 1 (nur, wenn im Jahr bereits MINOR>0 existiert,
#                                   sonst startet das Jahr mit 1.0)
# - Tag-Kollisionen (z. B. zweites Tag in derselben Minute) werden mit a,b,c… gelöst
# - Push erfolgt nur, wenn ein Remote existiert; scheitert er, endet die
#   Funktion mit Exit ≠ 0 und Hinweis auf stderr (auch beim Reuse)
#
# Beispiele
# ---------
#   gitUpdateVersionTag                 # Patch im aktuellen Jahr
#   gitUpdateVersionTag minor           # neues Minor-Release im aktuellen Jahr
#   gitUpdateVersionTag "" "" last-tag  # noch einen Patch fürs Vorjahres-Release (falls nötig)
#   gitUpdateVersionTag minor rc1 2024  # RC im Jahr 2026
#
_gitUpdateVersionTag() {
  local _bump="${1:-patch}"
  local _pre="${2:-}"
  local _year_sel="${3:-current}"

  # --- Reuse: Falls HEAD bereits im Zieljahr getaggt ist -------------------
  local _yy
  _yy="$(date -u +%y)"
  local _existing_tag=""
  _existing_tag="$(git tag --points-at HEAD --list "v${_yy}.*" | sort -V | tail -n1 || true)"
  if [[ -n "$_existing_tag" ]]; then
      if git remote >/dev/null 2>&1 && [[ -n "$(git remote)" ]]; then
          _gitPushFollowTags "$_existing_tag" || return $?
      fi
      printf '%s\n' "$_existing_tag"
      return 0
  fi

  local _base
  _base="$(_gitCalcNextVersion "$_bump" "$_pre" "$_year_sel")" || return $?
  _gitSetVersionTag "$_base"
}

gitUpdateVersionTag() { _gitUpdateVersionTag "$@"; }
gitUVT() { _gitUpdateVersionTag "$@"; }

#------------------------------------------------------------------------------
# bumpVer [bump=minor|patch] [source=auto|package.json|pyproject.toml|VERSION] [prerelease] [year=current|last-tag|YY|YYYY] [msg]
#
# Kombiniert Versions-Berechnung, Datei-Update, Git-Commit und Tag-Setzen.
# Reihenfolge: Version berechnen → Datei schreiben → Commit → Tag (zeigt auf Commit)
#
# Usage:
#   bumpVer                               # Patch, auto-detect, letzter Commit als Tag-Message
#   bumpVer minor                         # Minor-bump, auto-detect
#   bumpVer patch auto "" current "msg"   # Patch mit expliziter Tag-Message
#   bumpVer minor pyproject.toml rc1      # Minor mit Prerelease
#
bumpVer() {
  local _bump="${1:-patch}"
  local _source="${2:-auto}"
  local _pre="${3:-}"
  local _year_sel="${4:-current}"
  local _msg="${5:-}"

  # 1. Nächste Version berechnen (noch kein Tag — dirty check passiert hier)
  local _base
  _base="$(_gitCalcNextVersion "$_bump" "$_pre" "$_year_sel")" || return $?

  # Version ohne "v" und ohne Prerelease für Dateien: v26.3.0-rc1 → 26.3.0
  local _version="${_base#v}"
  _version="${_version%%-*}"

  # 2. Quelldatei auto-detect
  if [[ "$_source" == "auto" ]]; then
      if   [[ -f "package.json"   ]]; then _source="package.json"
      elif [[ -f "pyproject.toml" ]]; then _source="pyproject.toml"
      elif [[ -f "VERSION"        ]]; then _source="VERSION"
      else
          printf 'bumpVer: keine Versionsdatei gefunden (package.json, pyproject.toml, VERSION)\n' >&2
          return 5
      fi
  fi

  # 3. Version in Datei schreiben
  case "$_source" in
      package.json)
          npm version --no-git-tag-version --allow-same-version "$_version"
          ;;
      pyproject.toml)
          if command -v poetry >/dev/null 2>&1; then
              poetry version "$_version"
          else
              sed -i "s/^version = .*/version = \"${_version}\"/" pyproject.toml
          fi
          ;;
      VERSION)
          printf '%s\n' "$_version" > VERSION
          ;;
      *)
          printf 'bumpVer: unbekannte Quelldatei: %s\n' "$_source" >&2
          return 6
          ;;
  esac

  # 4. Commit
  git add "$_source"
  [[ "$_source" == "package.json" ]] && git add package-lock.json 2>/dev/null || true
  git commit -m "chore: bump version to ${_version}"

  # 5. Tag auf den chore-Commit setzen
  _gitSetVersionTag "$_base" "${_msg}"
}

#------------------------------------------------------------------------------
# semVerBump [bump=major|minor|patch] [source=auto|package.json|pyproject.toml|VERSION] [prerelease] [msg]
#
# SemVer-Variante von bumpVer: liest die aktuelle Version aus der Versionsdatei,
# erhöht die gewählte Komponente (MAJOR.MINOR.PATCH) und setzt einen Tag im Format
# v0.2.0+YYMMDD.HHMM.hash (identisch zu gitDockerTag, aber mit + statt -).
#
# Im Gegensatz zu bumpVer wird kein CalVer/Jahr-Schema verwendet — die Versionsnummer
# liegt vollständig in der Versionsdatei (package.json, pyproject.toml oder VERSION).
#
# Reihenfolge: Datei lesen → bump berechnen → Datei schreiben → Commit → Tag
#
# Usage:
#   semVerBump                            # Patch, auto-detect
#   semVerBump minor                      # Minor-bump, auto-detect
#   semVerBump major auto "" "Release"    # Major mit Tag-Message
#   semVerBump patch pyproject.toml       # Patch, explizite Quelldatei
#
semVerBump() {
  local _bump="${1:-patch}"
  local _source="${2:-auto}"
  local _pre="${3:-}"
  local _msg="${4:-}"

  # --- Guards ------------------------------------------------------------------
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      printf 'semVerBump: Repo hat noch keinen Commit.\n' >&2
      return 4
  fi
  if ! git diff --quiet --ignore-submodules --; then
      printf 'semVerBump: Working tree ist dirty – commit/stash vor dem Taggen.\n' >&2
      return 3
  fi

  # --- Quelldatei auto-detect --------------------------------------------------
  if [[ "$_source" == "auto" ]]; then
      if   [[ -f "package.json"   ]]; then _source="package.json"
      elif [[ -f "pyproject.toml" ]]; then _source="pyproject.toml"
      elif [[ -f "VERSION"        ]]; then _source="VERSION"
      else
          printf 'semVerBump: keine Versionsdatei gefunden (package.json, pyproject.toml, VERSION)\n' >&2
          return 5
      fi
  fi

  # --- Aktuelle Version lesen --------------------------------------------------
  local _cur
  case "$_source" in
      package.json)
          _cur="$(npm pkg get version --silent 2>/dev/null | tr -d '"')"
          ;;
      pyproject.toml)
          _cur="$(awk -F'"' '/^version /{print $2}' pyproject.toml)"
          ;;
      VERSION)
          _cur="$(cat VERSION)"
          ;;
      *)
          printf 'semVerBump: unbekannte Quelldatei: %s\n' "$_source" >&2
          return 6
          ;;
  esac

  if [[ -z "$_cur" || "$_cur" == "{}" ]]; then
      printf 'semVerBump: Version konnte nicht aus %s gelesen werden.\n' "$_source" >&2
      return 7
  fi

  # --- SemVer-Komponenten und nächste Version ----------------------------------
  local _maj _min _pat _next
  _maj="$(echo "$_cur" | cut -d. -f1)"
  _min="$(echo "$_cur" | cut -d. -f2)"
  _pat="$(echo "$_cur" | cut -d. -f3)"

  case "$_bump" in
      major) _next="$((10#$_maj+1)).0.0" ;;
      minor) _next="$_maj.$((10#$_min+1)).0" ;;
      patch) _next="$_maj.$_min.$((10#$_pat+1))" ;;
      *)
          printf 'semVerBump: unbekannter bump-Typ: %s (major|minor|patch)\n' "$_bump" >&2
          return 2
          ;;
  esac

  local _base="v${_next}"
  [[ -n "$_pre" ]] && _base="${_base}-${_pre}"

  # --- Version in Datei schreiben ----------------------------------------------
  case "$_source" in
      package.json)
          npm version --no-git-tag-version --allow-same-version "$_next"
          ;;
      pyproject.toml)
          if command -v poetry >/dev/null 2>&1; then
              poetry version "$_next"
          else
              sed -i.bak "s/^version = .*/version = \"${_next}\"/" pyproject.toml
              rm -f pyproject.toml.bak
          fi
          ;;
      VERSION)
          printf '%s\n' "$_next" > VERSION
          ;;
  esac

  # --- Commit ------------------------------------------------------------------
  git add "$_source"
  [[ "$_source" == "package.json" ]] && git add package-lock.json 2>/dev/null || true
  git commit -m "chore: bump version to ${_next}"

  # --- Tag setzen (v0.2.0+YYMMDD.HHMM.hash) -----------------------------------
  _gitSetVersionTag "$_base" "${_msg}"
}

#------------------------------------------------------------------------------
# _calVerCalcNextVersion [prerelease] [year=current|last-tag|YY|YYYY] [skip_guards=0|1]
#
# Berechnet die nächste CalVer-Version: YY.Q.BUILD
# Jahr und Quartal kommen IMMER aus dem Kalender, BUILD inkrementiert automatisch.
# Quartalwechsel → BUILD reset auf 0.
#
# Kein bump-Parameter — im Gegensatz zu _gitCalcNextVersion gibt es keine
# major/minor/patch-Unterscheidung. Jedes Release im selben Quartal erhöht BUILD.
#
# skip_guards=1 überspringt Dirty-Check (nützlich für Dry-Run).
#
# Returns: z.B. "v26.2.0" oder "v26.2.3-rc1"
#
_calVerCalcNextVersion() {
  local _pre="${1:-}"
  local _year_sel="${2:-current}"
  local _skip_guards="${3:-0}"

  # --- Jahr bestimmen -------------------------------------------------------
  local _yy
  case "$_year_sel" in
      current | "")
          _yy="$(date -u +%y)"
          ;;
      last-tag)
          local _ltag
          _ltag="$(git tag --list 'v[0-9][0-9].*' --sort=-creatordate | head -n1 || true)"
          if [[ -n "$_ltag" ]]; then
              _yy="${_ltag#v}"
              _yy="${_yy%%.*}"
          else
              _yy="$(date -u +%y)"
          fi
          ;;
      [0-9][0-9][0-9][0-9])
          _yy="${_year_sel:2:2}"
          ;;
      [0-9][0-9])
          _yy="${_year_sel}"
          ;;
      *)
          printf 'Ungültiger year-Parameter: %s\n' "$_year_sel" >&2
          return 2
          ;;
  esac

  # --- Quartal aus aktuellem Datum ------------------------------------------
  local _quarter
  _quarter=$(( ($(date -u +%-m) - 1) / 3 + 1 ))

  # --- Tags vom Remote holen ------------------------------------------------
  git fetch --tags --quiet 2>/dev/null || true

  # --- Repo-Guards ----------------------------------------------------------
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      printf 'Repo hat noch keinen Commit – bitte zuerst committen.\n' >&2
      return 4
  fi
  if [[ "$_skip_guards" != "1" ]] && ! git diff --quiet --ignore-submodules -- 2>/dev/null; then
      printf 'Working tree ist dirty – commit/stash vor dem Taggen.\n' >&2
      return 3
  fi

  # --- Höchsten BUILD im aktuellen YY.Q finden -----------------------------
  local _last_build=-1
  while IFS= read -r _t; do
      [[ -z "$_t" ]] && continue
      local _vsn="${_t#v}"
      _vsn="${_vsn%%+*}"
      _vsn="${_vsn%%-*}"
      # Format: YY.Q.BUILD
      local _b="${_vsn##*.}"
      if (( 10#${_b} > _last_build )); then
          _last_build=$((10#${_b}))
      fi
  done < <(git tag --list "v${_yy}.${_quarter}.*" | sort -V)

  local _next_build=$(( _last_build + 1 ))

  # --- Basis + PreRelease zusammensetzen ------------------------------------
  local _base="v${_yy}.${_quarter}.${_next_build}"
  [[ -n "$_pre" ]] && _base="${_base}-${_pre}"

  printf '%s\n' "$_base"
}

#------------------------------------------------------------------------------
# calVerBump [source=auto|package.json|pyproject.toml|VERSION] [prerelease] [year=current|...] [msg]
#
# CalVer-Variante von bumpVer: Jahr+Quartal aus Kalender, BUILD inkrementiert.
# Kombiniert Versions-Berechnung, Datei-Update, Git-Commit und Tag-Setzen.
#
# Usage:
#   calVerBump                               # auto-detect Datei, nächster BUILD
#   calVerBump auto "" current "msg"         # mit expliziter Tag-Message
#   calVerBump auto rc1                      # Release Candidate
#   calVerBump VERSION "" current ""         # explizit VERSION-Datei
#
calVerBump() {
  local _source="${1:-auto}"
  local _pre="${2:-}"
  local _year_sel="${3:-current}"
  local _msg="${4:-}"

  # 1. Nächste Version berechnen
  local _base
  _base="$(_calVerCalcNextVersion "$_pre" "$_year_sel")" || return $?

  # Version ohne "v" und ohne Prerelease für Dateien: v26.2.3-rc1 → 26.2.3
  local _version="${_base#v}"
  _version="${_version%%-*}"

  # 2. Quelldatei auto-detect
  if [[ "$_source" == "auto" ]]; then
      if   [[ -f "package.json"   ]]; then _source="package.json"
      elif [[ -f "pyproject.toml" ]]; then _source="pyproject.toml"
      elif [[ -f "VERSION"        ]]; then _source="VERSION"
      else
          printf 'calVerBump: keine Versionsdatei gefunden (package.json, pyproject.toml, VERSION)\n' >&2
          return 5
      fi
  fi

  # 3. Version in Datei schreiben
  case "$_source" in
      package.json)
          npm version --no-git-tag-version --allow-same-version "$_version"
          ;;
      pyproject.toml)
          if command -v poetry >/dev/null 2>&1; then
              poetry version "$_version"
          else
              sed -i "s/^version = .*/version = \"${_version}\"/" pyproject.toml
          fi
          ;;
      VERSION)
          printf '%s\n' "$_version" > VERSION
          ;;
      *)
          printf 'calVerBump: unbekannte Quelldatei: %s\n' "$_source" >&2
          return 6
          ;;
  esac

  # 4. Commit
  git add "$_source"
  [[ "$_source" == "package.json" ]] && git add package-lock.json 2>/dev/null || true
  git commit -m "chore: bump version to ${_version}"

  # 5. Tag auf den chore-Commit setzen
  _gitSetVersionTag "$_base" "${_msg}"
}

# Gibt einen dateifreundlichen Paketnamen zurück.
#
# getPackageName [dirty_flag="d"] [ext="zip"]
#
# Git-Repo:
#   <repo>-<tag_ohne_v_und_mit_plus_zu_minus>-<hash>[.<d>].zip
#   Fallback ohne Tag: <repo>-<YYMMDD.HHMM>-<hash>[.<d>].zip
#
# Nicht-Git:
#   Mit package.json: <dir>-<version_aus_package.json>.zip
#   Sonst Fallback:   <dir>-<YYMMDD.HHMM>.zip
#
# Beispiele:
#   getPackageName              # auto-Name aus Repo oder Verzeichnis
#   getPackageName mypkg        # Basename explizit "mypkg"
#   getPackageName mypkg tar.gz # andere Extension
#
getPackageName() {
    local _base_name="${1:-}"
    local _ext="${2:-zip}"

    # Feste Werte
    local _repo="."
    local _hash_len=5
    local _dirty_flag="d"

    # --- Helfer --------------------------------------------------------------
    _is_git_repo() { git -C "$_repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

    _dir_basename() {
        (cd "$1" >/dev/null 2>&1 && basename "$PWD")
    }

    _read_pkg_version() {
        local _pkg="$1/package.json"
        [[ -f "$_pkg" ]] || return 1
        if command -v jq >/dev/null 2>&1; then
            jq -r '.version // empty' <"$_pkg"
        elif command -v node >/dev/null 2>&1; then
            (cd "$1" && node -p "try{require('./package.json').version||''}catch(e){''}")
        else
            sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$_pkg" | head -1
        fi
    }

    # --- Basisname bestimmen -------------------------------------------------
    local _name=""
    if [[ -n "$_base_name" ]]; then
        _name="$_base_name"
    else
        if _is_git_repo; then
            _name="$(basename "$(git -C "$_repo" rev-parse --show-toplevel)")"
        else
            _name="$(_dir_basename "$_repo")"
        fi
        [[ -z "$_name" ]] && _name="package"
    fi

    # --- Git-Repo: Tag/Hash/Dirty einbauen ----------------------------------
    if _is_git_repo; then
        local _tag _clean _hash="nogit" _dirty=""
        _tag="$(git -C "$_repo" describe --tags --abbrev=0 2>/dev/null || true)"
        if [[ -n "$_tag" ]]; then
            _clean="${_tag#v}"
            _clean="${_clean//+/-}" # dateifreundlich
        else
            _clean="$(date -u +%y%m%d.%H%M)"
        fi

        if git -C "$_repo" rev-parse HEAD >/dev/null 2>&1; then
            _hash="$(git -C "$_repo" rev-parse --short="${_hash_len}" HEAD 2>/dev/null || echo nogit)"
            if ! git -C "$_repo" diff --quiet --ignore-submodules -- 2>/dev/null; then
                _dirty=".${_dirty_flag}"
            fi
        fi

        printf '%s-%s-%s%s.%s\n' "$_name" "$_clean" "$_hash" "$_dirty" "$_ext"
        return 0
    fi

    # --- Nicht-Git: Version aus package.json oder Zeitstempel ----------------
    local _ver
    _ver="$(_read_pkg_version "$_repo" | tr -d '\n')"
    if [[ -n "$_ver" ]]; then
        printf '%s-%s.%s\n' "$_name" "$_ver" "$_ext"
    else
        local _stamp
        _stamp="$(date -u +%y%m%d.%H%M)"
        printf '%s-%s.%s\n' "$_name" "$_stamp" "$_ext"
    fi
}
