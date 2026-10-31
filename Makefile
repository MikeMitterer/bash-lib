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

# ProjectTools (docs-check, repo-status, changelog) per pipx, Tag aus .dev-tools.conf.sh
PROJECTTOOLS_MIN     := $(patsubst v%,%,$(firstword $(subst +, ,$(PROJECTTOOLS_TAG))))
PROJECTTOOLS_INSTALL := pipx install --force 'git+https://github.com/MikeMitterer/bash-ProjectTools.git@$(PROJECTTOOLS_TAG)'
PROJECTTOOLS_FOUND    = $(shell projecttools --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

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
	@echo "    $(YELLOW)VERSION$(RESET)       = $(BLUE)$$(source "$${BASH_LIBS}/version.lib.sh" 2>/dev/null && readProjectVersion 2>/dev/null || echo 'nicht gesetzt')$(RESET)"
	@echo "    $(YELLOW)ProjectTools$(RESET)  = $(BLUE)$(or $(PROJECTTOOLS_FOUND),fehlt)$(RESET) (verlangt ab $(PROJECTTOOLS_MIN))"
	@echo

# Repo-Adresse aus git remote origin (SSH oder HTTPS) als https-URL; leer ohne Remote.
# Trennzeichen | statt #: Make läse # in $(shell …) als Kommentar.
# Werte von außen landen im Rezept; Ref-Namen dürfen $, ( und ) enthalten. Nur
# erlaubte Zeichen übernehmen, sonst leer – ein Tag wie v1$(touch x) liefe sonst.
REPO_URL    := $(shell git remote get-url origin 2>/dev/null | sed -E 's|^git@([^:]+):|https://\1/|; s|\.git$$||' | grep -xE '[A-Za-z0-9._:/@+~-]+')
RELEASE_TAG := $(or $(shell git describe --tags --abbrev=0 2>/dev/null | grep -xE '[A-Za-z0-9._+-]+'),vX.Y.Z)
NO_REMOTE   := kein Remote origin (git remote add origin …)
COMMA       := ,

# Eine Zeile für hints: Beschriftung, auf THEME_WIDTH_TARGET Zeichen aufgefüllt,
# dann der Wert. printf füllt nach Bytes auf; die Breite zählt deshalb Zeichen
# (UTF-8-Folgebytes zählen nicht). Aufruf: $(call hint_row,Beschriftung,Wert),
# ohne Komma in den Werten.
hint_row = label="$(1)"; \
	chars=$$(printf '%s' "$$label" | LC_ALL=C tr -d '\200-\277' | wc -c); \
	printf "$(THEME_INDENT_TARGET)$(THEME_COLOR_TARGET)%s$(RESET)%*s$(THEME_COLOR_DESC)%s$(RESET)\n" \
		"$$label" $$(( $(THEME_WIDTH_TARGET) - chars + $(THEME_COLUMN_GAP) )) "" "$(2)"

# Setzt checkout auf den pipx-Befehl für die Arbeitskopie hinter der Variable $(1), wenn an
# deren Git-Wurzel das Paket $(2) liegt.
tool_checkout = top=""; [[ -n "$${$(1):-}" ]] && top=$$(git -C "$${$(1)}" rev-parse --show-toplevel 2>/dev/null); \
	if [[ -n "$$top" ]] && grep -qx 'name = "$(2)"' "$$top/pyproject.toml" 2>/dev/null; then \
		checkout="pipx install -e '$$(printf '%s' "$$top" | sed "s/'/'\\\\''/g")'"; \
	else checkout="keine Arbeitskopie über $(1)"; fi

.PHONY: hints
hints: ## Nützliche Links und Hinweise anzeigen
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)Erster Start$(RESET)"
	@$(call hint_row,1. Setup,make setup)
	@$(call hint_row,2. Prüfen,make check)
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)BashLib in anderen Projekten$(RESET)"
	@$(call hint_row,Installieren,$(if $(REPO_URL),pipx install 'git+$(REPO_URL).git@$(RELEASE_TAG)',$(NO_REMOTE)))
	@$(call hint_row,Arbeitskopie,pipx install -e $${WORKSPACE_SQ})
	@$(call hint_row,Umgebung,export BASH_LIBS=\$$(bashlib-path))
	@for ((i=0; i<$(THEME_GROUP_SPACING); i++)); do echo; done
	@echo "$(THEME_INDENT_GROUP)$(THEME_COLOR_GROUP)ProjectTools (docs-check$(COMMA) status$(COMMA) changelog)$(RESET)"
	@$(call hint_row,Installieren,$(PROJECTTOOLS_INSTALL))
	@$(call tool_checkout,PROJECT_TOOLS,mmit-projecttools); $(call hint_row,Arbeitskopie,$$checkout)
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
	@found='$(PROJECTTOOLS_FOUND)'; \
	if [[ -z "$$found" ]]; then problem='fehlt'; \
	elif [[ "$$(printf '%s\n' '$(PROJECTTOOLS_MIN)' "$$found" | sort -V | head -1)" != '$(PROJECTTOOLS_MIN)' ]]; then problem="$$found ist zu alt"; \
	else exit 0; fi; \
	printf '  $(RED)✗$(RESET) ProjectTools %s (verlangt ab %s): $(YELLOW)%s$(RESET)\n' "$$problem" '$(PROJECTTOOLS_MIN)' "$(PROJECTTOOLS_INSTALL)" >&2; \
	exit 1

# ─── Setup ───────────────────────────────────────────────────────────────────

##@ Setup

# Die Tests brauchen nur Bash und Git; setup aktiviert die versionierten
# Git-Hooks. Wiederholbar und ohne Rückfrage.
.PHONY: setup
setup: ## Git-Hooks einrichten (pre-commit: make docs-check)
	@git config core.hooksPath .githooks
	@echo -e "  $(GREEN)✓$(RESET) Git-Hooks aus .githooks aktiv"

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
docs-check: require-tools ## Nutzerdoku gegen das Projekt prüfen (Links, Befehle, verbotene Begriffe)
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
	 TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo 'kein Tag'); \
	 echo "    $(YELLOW)version$(RESET)      = $(BLUE)$$VER$(RESET)"; \
	 echo "    $(YELLOW)git tag$(RESET)      = $(BLUE)$$TAG$(RESET)"
	@echo

.PHONY: tags
tags: ## Letzte 10 Tags mit Message anzeigen
	@echo
	@git tag --sort=-version:refname -n1 | head -10 | \
	  awk '{printf "    $(BLUE)%-28s$(RESET) $(GREEN)%s$(RESET)\n", $$1, substr($$0, index($$0,$$2))}'
	@echo

# $(call release,major|minor|patch): bumpen, taggen, pushen, dann CHANGELOG.md
define release
	source "$${BASH_LIBS}/version.lib.sh" && semVerBump $(1) auto "" "$${MSG:-}"
	@changelog --publish
endef

.PHONY: changelog
changelog: require-tools ## Vorschau des Changelogs aus Tags und Commits
	@changelog --dry-run

# require-tools vor precheck: ohne ProjectTools bricht ein Release vor dem Bump ab,
# nicht erst nach dem gepushten Tag.
.PHONY: tag-major
tag-major: require-tools precheck ## Major (X.y.z → X+1.0.0)  [MSG="..."] — Maintainer
	$(call release,major)

.PHONY: tag-minor
tag-minor: require-tools precheck ## Minor (x.Y.z → x.Y+1.0)  [MSG="..."] — Maintainer
	$(call release,minor)

.PHONY: tag-patch
tag-patch: require-tools precheck ## Patch (x.y.Z → x.y.Z+1)  [MSG="..."] — Maintainer
	$(call release,patch)
