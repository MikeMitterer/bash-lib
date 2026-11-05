# Makefile — BashLib
#
# Aufbau nach makefile-conventions. BashLib ist selbst die Bibliothek: Tests
# und Versionierung nehmen immer src/ dieses Checkouts, nicht BASH_LIBS aus
# der Umgebung. In einem Worktree prüft make test also genau diesen Stand.

SHELL := bash

.DEFAULT_GOAL := help

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
PROJECT_NAME := $(shell basename -- $(WORKSPACE_SQ))
BASH_LIBS    := $(WORKSPACE)/src
# Werte von außen nur über die Umgebung in Rezepte geben ("$${VAR}")
export WORKSPACE WORKSPACE_SQ PROJECT_NAME BASH_LIBS

# Release-Tags der pipx-Werkzeuge (ProjectTools)
include .dev-tools.conf.sh

# MakeLib ist optional (DEV_MAKE aus der Umgebung)
-include ${DEV_MAKE}/colours.mk

# Fallbacks, wenn DEV_MAKE nicht verfügbar ist
YELLOW ?= $(shell printf "\033[38;5;3m")
GREEN  ?= $(shell printf "\033[38;5;2m")
BLUE   ?= $(shell printf "\033[38;5;6m")
ORANGE ?= $(shell printf "\033[38;5;214m")
RED    ?= $(shell printf "\033[38;5;1m")
WHITE  ?= $(shell printf "\033[38;5;7m")
RESET  ?= $(shell printf "\033[0m")
NC     ?= $(shell printf "\033[0m")
THEME_COLOR_GROUP   ?= $(YELLOW)
THEME_COLOR_TARGET  ?= $(BLUE)
THEME_COLOR_DESC    ?= $(GREEN)
THEME_COLOR_DANGER  ?= $(RED)
THEME_INDENT_GROUP  ?= $(shell printf '%2s' '')
THEME_INDENT_TARGET ?= $(shell printf '%7s' '')
THEME_WIDTH_TARGET  ?= 22
THEME_COLUMN_GAP    ?= 1
THEME_GROUP_SPACING ?= 1

# Kennzeichnet in der Hilfe die Maintainer-Targets nach makefile-conventions
# (status, version, tag-*). In der Target-Beschreibung steht dafür am Ende
# „— Maintainer“.
MAINTAINER_MARK = $(THEME_COLOR_DANGER)[Maintainer]$(THEME_COLOR_DESC)

# ProjectTools und CLITheme: Tag und Quelle stehen nur in .dev-tools.conf.sh; devtools (Paket
# mmit-devtools) liest sie, prüft die Mindestversion und nennt den Installationsbefehl. pipx run
# holt devtools am Tag aus DEVTOOLS_TAG; der Tag geht über die Umgebung in den Befehl.
export DEVTOOLS_SPEC := git+https://github.com/MikeMitterer/python-devtools.git@$(DEVTOOLS_TAG)
# --no-path-check: ohne Warnung, wenn devtools zusätzlich im PATH installiert ist
DEV_TOOLS = pipx run --no-path-check --spec "$$DEVTOOLS_SPEC" devtools
# devtools braucht pipx: eine Meldung, wenn es fehlt, und der Grund, wenn devtools nichts liefert.
PIPX_URL := https://pipx.pypa.io
pipx_missing = printf '  $(RED)✗$(RESET) pipx fehlt: $(YELLOW)$(PIPX_URL)$(RESET)\n' >&2
devtools_unavailable = $$(command -v pipx >/dev/null && echo 'pipx run devtools gescheitert' || echo 'pipx fehlt ($(PIPX_URL))')

# ─── Hilfe ───────────────────────────────────────────────────────────────────

# Liste der Makefiles unausgewertet über die Umgebung (siehe Standard-Header)
export HELP_FILES = $(value MAKEFILE_LIST)

.PHONY: help
help: ## Alle verfügbaren Befehle anzeigen
	@echo
	@echo "Please use \`make <$(THEME_COLOR_GROUP)target$(RESET)>' where <target> is one of"
	@echo
	@echo "Project: $(THEME_COLOR_GROUP)$${PROJECT_NAME}$(RESET)"
	@echo
	@set -o pipefail; grep -hE '^(##@|[a-zA-Z0-9_-]+:.*?## )' $${HELP_FILES} | \
	  awk 'function row(label, description) { \
	      sub(/ — Maintainer$$/, " $(MAINTAINER_MARK)", description); \
	      printf "$(THEME_INDENT_TARGET)$(THEME_COLOR_TARGET)%s$(RESET)", label; \
	      padding = $(THEME_WIDTH_TARGET) - length(label) + $(THEME_COLUMN_GAP); \
	      if (length(label) > $(THEME_WIDTH_TARGET)) { printf "\n$(THEME_INDENT_TARGET)"; padding = $(THEME_WIDTH_TARGET) + $(THEME_COLUMN_GAP) }; \
	      printf "%*s$(THEME_COLOR_DESC)%s$(RESET)\n", padding, "", description \
	    }; BEGIN {FS = ":.*## "}; \
	    /^##@/ { for (i=0; i<$(THEME_GROUP_SPACING); i++) printf "\n"; heading=substr($$0, 4); sub(/^[[:space:]]+/, "", heading); printf "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)%s$(RESET)\n", heading; next }; \
	    /## / { row($$1, $$2) }'
	@echo

.PHONY: info
info: ## Umgebungsvariablen anzeigen
	@echo
	@echo "    $(YELLOW)PROJECT_NAME$(RESET)  = $(BLUE)$${PROJECT_NAME}$(RESET)"
	@echo "    $(YELLOW)WORKSPACE$(RESET)     = $(BLUE)$${WORKSPACE}$(RESET)"
	@echo "    $(YELLOW)BASH_LIBS$(RESET)     = $(BLUE)$${BASH_LIBS}$(RESET)"
	@echo "    $(YELLOW)DEV_MAKE$(RESET)      = $(BLUE)$${DEV_MAKE:-nicht gesetzt}$(RESET)"
	@echo "    $(YELLOW)PACKAGE$(RESET)       = $(BLUE)$(or $(PACKAGE_NAME),$(NO_PACKAGE))$(RESET)"
	@echo "    $(YELLOW)VERSION$(RESET)       = $(BLUE)$$(source "$${BASH_LIBS}/version.lib.sh" 2>/dev/null && readProjectVersion 2>/dev/null || echo 'nicht gesetzt')$(RESET)"
	@# devtools rückt um zwei Zeichen ein; zwei mehr stellen die Zeilen unter die Variablen.
	@set -o pipefail; $(DEV_TOOLS) status 2>/dev/null | sed 's/^/  /' || echo "    Werkzeugstand nicht abrufbar: $(devtools_unavailable)"
	@echo

# Repo-Adresse aus git remote origin (SSH oder HTTPS) als https-URL; leer ohne Remote.
# Trennzeichen | statt #: Make läse # in $(shell …) als Kommentar.
# Werte von außen landen im Rezept; Ref-Namen dürfen $, ( und ) enthalten. Nur
# erlaubte Zeichen übernehmen, sonst leer – ein Tag wie v1$(touch x) liefe sonst.
REPO_URL    := $(shell git remote get-url origin 2>/dev/null | sed -E 's|^git@([^:]+):|https://\1/|; s|\.git$$||' | grep -xE '[A-Za-z0-9._:/@+~-]+')
# Release-Tag (v…) über gitReleaseTag dieses Checkouts; ein deploy-Tag zählt nicht.
RELEASE_TAG := $(or $(shell source "$(BASH_LIBS)/version.lib.sh" 2>/dev/null && gitReleaseTag | grep -xE '[A-Za-z0-9._+-]+'),vX.Y.Z)
NO_REMOTE   := kein Remote origin (git remote add origin …)
# Python-Paket und Befehl aus pyproject.toml ([project] name, erster Eintrag in
# [project.scripts]); nur erlaubte Zeichen, sonst leer wie bei REPO_URL.
PACKAGE_NAME := $(shell awk -F'"' '/^\[/ { s = $$0 } s == "[project]" && /^name *=/ { print $$2; exit }' pyproject.toml 2>/dev/null | grep -xE '[A-Za-z0-9._-]+')
# Befehle aus [project.scripts], durch Leerzeichen getrennt; der erste ist PACKAGE_CMD
PACKAGE_CMDS := $(shell awk -F' *= *' '/^\[/ { s = $$0; next } s == "[project.scripts]" && NF > 1 { print $$1 }' pyproject.toml 2>/dev/null | grep -xE '[A-Za-z0-9._-]+')
PACKAGE_CMD  := $(firstword $(PACKAGE_CMDS))
NO_PACKAGE   := nicht lesbar (pyproject.toml, [project] name)
COMMA       := ,

# Eine Zeile für hints: Beschriftung, auf THEME_WIDTH_TARGET Zeichen aufgefüllt,
# dann der Wert. printf füllt nach Bytes auf; die Breite zählt deshalb Zeichen
# (UTF-8-Folgebytes zählen nicht). Aufruf: $(call hint_row,Beschriftung,Wert),
# ohne Komma in den Werten.
hint_row = label="$(1)"; \
	chars=$$(printf '%s' "$$label" | LC_ALL=C tr -d '\200-\277' | wc -c); \
	printf "$(THEME_INDENT_TARGET)$(THEME_COLOR_TARGET)%s$(RESET)%*s$(THEME_COLOR_DESC)%s$(RESET)\n" \
		"$$label" $$(( $(THEME_WIDTH_TARGET) - chars + $(THEME_COLUMN_GAP) )) "" "$(2)"

.PHONY: hints
hints: ## Nützliche Links und Hinweise anzeigen
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)Erster Start$(RESET)"
	@$(call hint_row,1. Setup,make setup)
	@$(call hint_row,2. Prüfen,make check)
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)BashLib in anderen Projekten$(RESET)"
	@$(call hint_row,Paket,$(or $(PACKAGE_NAME),$(NO_PACKAGE))$(if $(PACKAGE_CMD), (Befehl $(PACKAGE_CMD))))
	@$(call hint_row,Installieren,$(if $(REPO_URL),pipx install 'git+$(REPO_URL).git@$(RELEASE_TAG)',$(NO_REMOTE)))
	@$(call hint_row,Arbeitskopie,pipx install -e $${WORKSPACE_SQ})
	@$(call hint_row,Umgebung,export BASH_LIBS=\$$(bashlib-path))
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)ProjectTools (docs-check$(COMMA) status$(COMMA) changelog)$(RESET)"
	@cmd=$$($(DEV_TOOLS) command projecttools 2>/dev/null) || cmd="nicht abrufbar: $(devtools_unavailable)"; $(call hint_row,Installieren,$$cmd)
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)CLITheme (Farben und Abstände der Ausgabe)$(RESET)"
	@cmd=$$($(DEV_TOOLS) command clitheme 2>/dev/null) || cmd="nicht abrufbar: $(devtools_unavailable)"; $(call hint_row,Installieren,$$cmd)
	@$(call hint_row,Themes anlegen,cli-theme install (macht make setup))
	@$(call hint_row,Auswahl,export CLI_THEME=ocean)
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)Links$(RESET)"
	@$(call hint_row,Repository,$(or $(REPO_URL),$(NO_REMOTE)))
	@echo

# ─── Precheck ────────────────────────────────────────────────────────────────

# Ohne `##`: nicht in der Hilfe, läuft als Abhängigkeit von version und tag-*.
.PHONY: precheck
precheck:
	@if [[ ! -r "$${BASH_LIBS:-}/version.lib.sh" ]]; then \
		echo ""; \
		echo "$(RED)Achtung: '$(YELLOW)BASH_LIBS$(RED)' fehlt oder enthält keine lesbare version.lib.sh!$(RESET)"; \
		echo ""; \
		exit 1; \
	fi

# Ohne `##`: verlangt ProjectTools in Mindestversion und nennt sonst den Installationsbefehl.
.PHONY: require-tools
require-tools:
	@command -v pipx >/dev/null || { $(pipx_missing); exit 1; }
	@$(DEV_TOOLS) check projecttools

# ─── Setup ───────────────────────────────────────────────────────────────────

##@ Setup

# Die Tests brauchen Bash, Git und python3 (Theme-Test); setup aktiviert die
# versionierten Git-Hooks und legt mit cli-theme install fehlende Theme-Dateien
# an. Fehlt cli-theme, nennt setup den Installationsbefehl und läuft weiter.
# Wiederholbar und ohne Rückfrage.
.PHONY: setup
setup: ## Git-Hooks aktiv (pre-commit: docs-check), fehlende CLI-Themes angelegt
	@git config core.hooksPath .githooks
	@echo -e "  $(GREEN)✓$(RESET) Git-Hooks aus .githooks aktiv"
	@$(MAKE) --no-print-directory setup-themes

# Ohne `##`: Teil von setup; scheitert nie, damit setup ohne cli-theme durchläuft.
# devtools meldet fehlendes oder zu altes CLITheme samt Installationsbefehl; ohne
# cli-theme bleibt die Ausgabe der Skripte farblos.
.PHONY: setup-themes
setup-themes:
	@if command -v pipx >/dev/null; then $(DEV_TOOLS) check clitheme >&2 || true; else $(pipx_missing); fi; \
	command -v cli-theme >/dev/null || exit 0; \
	if output=$$(cli-theme install 2>&1); then \
		printf '  $(GREEN)✓$(RESET) CLI-Themes in %s\n' "$$(dirname -- "$$(cli-theme path)")"; \
	else \
		printf '%s\n' "$$output" >&2; \
		printf '  $(RED)✗$(RESET) cli-theme install fehlgeschlagen; Ausgabe ohne Farben: $(YELLOW)cli-theme show$(RESET)\n' >&2; \
	fi

# Installiert diese Arbeitskopie editierbar mit pipx: die Befehle aus
# [project.scripts] zeigen danach auf src/ dieses Checkouts. Neue Befehle legt
# pipx nur beim Installieren an; nach einem Update deshalb erneut aufrufen.
.PHONY: install
install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
	@command -v pipx >/dev/null || { $(pipx_missing); exit 1; }
	@if output=$$(pipx install -e --force "$${WORKSPACE}" 2>&1); then \
		names='$(PACKAGE_CMDS)'; printf '  $(GREEN)✓$(RESET) %s aus %s\n' "$${names// /, }" "$${WORKSPACE}"; \
	else \
		printf '%s\n' "$$output" >&2; \
		printf '  $(RED)✗$(RESET) pipx install fehlgeschlagen\n' >&2; exit 1; \
	fi

# Prüf-Targets richten nichts ein; setup ist der einzige Weg (worktree_setup).
.PHONY: require-setup
require-setup:
	@[[ "$$(git config core.hooksPath)" == ".githooks" ]] || { \
		echo -e "  $(RED)✗$(RESET) Nicht eingerichtet: $(YELLOW)make setup$(RESET)" >&2; \
		exit 1; }

# ─── Status ──────────────────────────────────────────────────────────────────

##@ Status

.PHONY: status
status: require-tools ## Git-Status des Repos und offene Blocker-Issues — Maintainer
	@repo-status --show

# ─── Tests ───────────────────────────────────────────────────────────────────

##@ Tests

# Voller Prüflauf, auch für agent-lessons (integration_check: make check).
.PHONY: check
check: require-setup test ## Voller Prüflauf — Doku und alle Bash-Tests

.PHONY: test
test: docs-check require-setup ## Doku prüfen und Bash-Tests ausführen (test/testAll.sh)
	@./test/testAll.sh

.PHONY: docs-check
docs-check: require-tools ## Nutzerdoku gegen das Projekt prüfen (Links, Befehle, Begriffe)
	@docs-check --run

# Installiert Pakete in temporäre venvs und braucht den Paketindex; deshalb
# nicht Teil von check.
.PHONY: test-package
test-package: ## BashLib als pip-Paket in temporäre venvs installieren und prüfen
	@./test/package.test.sh

# ─── Versionierung ───────────────────────────────────────────────────────────

# Nach versioning-conventions (templates/versioning.mk): Die Version steht in
# pyproject.toml; lesen und erhöhen nur über version.lib.sh dieses Checkouts
# (readProjectVersion, semVerBump).

##@ Versionierung

.PHONY: version
version: precheck ## Aktuelle Version anzeigen (pyproject.toml + git tag) — Maintainer
	@echo
	@VER=$$(source "$${BASH_LIBS}/version.lib.sh" 2>/dev/null && readProjectVersion 2>/dev/null); \
	 [[ -z "$$VER" ]] && VER='nicht gesetzt'; \
	 TAG=$$(source "$${BASH_LIBS}/version.lib.sh" 2>/dev/null && gitReleaseTag || echo 'kein Release-Tag'); \
	 echo "    $(YELLOW)version$(RESET)      = $(BLUE)$$VER$(RESET)"; \
	 echo "    $(YELLOW)git tag$(RESET)      = $(BLUE)$$TAG$(RESET)"
	@echo

.PHONY: tags
tags: ## Letzte 10 Tags mit Message anzeigen
	@echo
	@git tag --sort=-version:refname -n1 | head -10 | \
	  awk '{printf "    $(BLUE)%-28s$(RESET) $(GREEN)%s$(RESET)\n", $$1, substr($$0, index($$0,$$2))}'
	@echo

# Eine Statuszeile für tag-*: Häkchen, Beschriftung, Wert.
# Aufruf: $(call release_row,Beschriftung,Wert), ohne Komma in den Werten.
release_row = printf '  $(GREEN)✓$(RESET) %-10s $(BLUE)%s$(RESET)\n' "$(1)" "$(2)"

# Sprache von CHANGELOG.md, unabhängig von der Locale der Shell (changelog folgt
# sonst LANG; unter C.UTF-8 käme Englisch). Überschreiben: make … CHANGELOG_LANGUAGE=en
CHANGELOG_LANGUAGE ?= de
export CHANGELOG_LANGUAGE

# $(call release,major|minor|patch): bumpen, taggen und CHANGELOG.md committen,
# alles nur lokal; veröffentlicht wird mit git push --follow-tags.
# Nur auf master und nur, wenn develop nicht weiter ist (T-36): Das Board übernimmt
# Tickets per Merge-Commit, ein Tag auf einem Ticket-Branch läge dann neben der
# First-Parent-Historie, und changelog ließe das Release aus. Danach wird develop
# auf master vorgespult, damit die nächste Abnahme master wieder vorspulen kann.
# Ausgabe: je Schritt eine Statuszeile. semVerBump gibt auf stdout nur den Tag
# aus; seine stderr-Ausgabe erscheint bei einem Fehler vollständig, bei Erfolg
# ohne die Zeilen „Hinweis: …“, die hier die Tag-Zeile ersetzt.
# changelog --commit schreibt und committet CHANGELOG.md nur lokal; seine
# Erfolgszeile (mit absolutem Pfad) ersetzt die Changelog-Zeile, Fehler gehen
# nach stderr. Ob committet wurde, zeigt ein neuer HEAD.
define release
	@branch=$$(git symbolic-ref --short -q HEAD || echo 'detached HEAD'); \
	 if [[ "$$branch" != master ]]; then \
		printf '  $(RED)✗$(RESET) Release nur auf master, nicht auf %s; nach der Abnahme auf master:\n       $(YELLOW)make %s$(RESET)\n' "$$branch" '$@' >&2; \
		exit 1; \
	 fi; \
	 if git rev-parse -q --verify refs/heads/develop >/dev/null && ! git merge-base --is-ancestor develop HEAD; then \
		printf '  $(RED)✗$(RESET) develop ist weiter als master; erst die Tickets abnehmen:\n       $(YELLOW)al ticket accept$(RESET)\n' >&2; \
		exit 1; \
	 fi
	@source "$${BASH_LIBS}/version.lib.sh"; \
	 err=$$(mktemp); trap 'command rm -f -- "$$err"' EXIT; \
	 old=$$(readProjectVersion); \
	 tag=$$(semVerBump $(1) auto "" "$${MSG:-}" 2>"$$err") || { rc=$$?; cat "$$err" >&2; exit $$rc; }; \
	 grep -v '^Hinweis: ' "$$err" >&2 || true; \
	 $(call release_row,Version,$$old → $$(readProjectVersion)); \
	 $(call release_row,Tag,$${tag##*$$'\n'} (nur lokal))
	@head=$$(git rev-parse HEAD); \
	 LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --commit >/dev/null || exit $$?; \
	 if [[ "$$(git rev-parse HEAD)" == "$$head" ]]; then \
		$(call release_row,Changelog,CHANGELOG.md unverändert); \
	 else \
		$(call release_row,Changelog,CHANGELOG.md committet); \
	 fi
	@if old=$$(git rev-parse -q --verify refs/heads/develop); then \
		holder=$$(git worktree list --porcelain | awk '/^worktree /{ w = substr($$0, 10) } $$0 == "branch refs/heads/develop" { print w }'); \
		if [[ -n "$$holder" ]]; then git -C "$$holder" merge -q --ff-only master || exit $$?; \
		else git update-ref refs/heads/develop HEAD "$$old" || exit $$?; fi; \
		$(call release_row,develop,auf master vorgespult); \
	 fi
endef

.PHONY: changelog
changelog: require-tools ## Vorschau des Changelogs aus Tags und Commits
	@LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --dry-run

# require-tools vor precheck: ohne ProjectTools bricht ein Release vor dem Bump ab,
# nicht erst nach dem Tag.
.PHONY: tag-major
tag-major: require-tools precheck ## Major (X.y.z → X+1.0.0)  [MSG="..."] — Maintainer
	$(call release,major)

.PHONY: tag-minor
tag-minor: require-tools precheck ## Minor (x.Y.z → x.Y+1.0)  [MSG="..."] — Maintainer
	$(call release,minor)

.PHONY: tag-patch
tag-patch: require-tools precheck ## Patch (x.y.Z → x.y.Z+1)  [MSG="..."] — Maintainer
	$(call release,patch)
