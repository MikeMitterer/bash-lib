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

# ProjectTools und CLITheme: Tag und Quelle stehen nur in .dev-tools.conf.sh; devtools (Paket
# mmit-devtools) liest sie, prüft die Mindestversion und nennt den Installationsbefehl. pipx run
# holt devtools am Tag aus DEVTOOLS_TAG; der Tag geht über die Umgebung in den Befehl.
export DEVTOOLS_SPEC := git+https://github.com/MikeMitterer/python-devtools.git@$(DEVTOOLS_TAG)
# --no-path-check: ohne Warnung, wenn devtools zusätzlich im PATH installiert ist
DEV_TOOLS = pipx run --no-path-check --spec "$$DEVTOOLS_SPEC" devtools
# devtools braucht pipx: eine Meldung, wenn es fehlt, und der Grund, wenn devtools nichts liefert.
PIPX_URL := https://pipx.pypa.io
devtools_unavailable = $$(command -v pipx >/dev/null && echo 'pipx run devtools gescheitert' || echo 'pipx fehlt ($(PIPX_URL))')

# ─── Hilfe ───────────────────────────────────────────────────────────────────

# Liste der Makefiles unausgewertet über die Umgebung (siehe Standard-Header)
export HELP_FILES = $(value MAKEFILE_LIST)

# help, info und hints laden make.lib.sh über BASH_ENV in jede Rezeptzeile; so steht
# jede Ausgabezeile als eigener Befehl da. Bash wertet BASH_ENV aus: darum der Verweis
# auf BASH_LIBS statt des Pfads, ein $(…) im Checkout-Pfad bleibt Text.
help info hints: export BASH_ENV := $${BASH_LIBS}/make.lib.sh

# Ausgabe (gekürzt):
#
#   Please use `make <target>' where <target> is one of
#
#   Project: BashLib
#          help                   Alle verfügbaren Befehle anzeigen
#     Setup
#          setup                  Git-Hooks aktiv (pre-commit: docs-check), fehlende CLI-Themes angelegt
#     Versionierung
#          tag-minor              Minor 0.7.0 → 0.8.0, neue Funktion  [MSG="..."] [Maintainer]
#
# „— Maintainer“ am Ende wird zu [Maintainer]; {major}, {minor} und {patch} füllt
# showMakeTargets mit der Version davor und danach.
.PHONY: help
help: ## Alle verfügbaren Befehle anzeigen
	@showMakeHeader "$${PROJECT_NAME}"
	@showMakeTargets $${HELP_FILES}

# Repo-Adresse (origin als https) und letzter Release-Tag (v…, kein deploy-Tag) aus
# repo-info (ProjectTools). Die Ausgabe enthält nur erlaubte Zeichen, auch der Ersatz
# ohne Remote oder Tag. Mit = läuft repo-info nur, wenn hints die Werte braucht.
NO_REPO_INFO := repo-info fehlt (ProjectTools, siehe make hints)
REPO_URL     = $(or $(shell repo-info --url 2>/dev/null),$(NO_REPO_INFO))
RELEASE_TAG  = $(or $(shell repo-info --release-tag 2>/dev/null),$(NO_REPO_INFO))
# Python-Paket und Befehl aus pyproject.toml ([project] name, erster Eintrag in
# [project.scripts]); nur erlaubte Zeichen, sonst leer.
PACKAGE_NAME := $(shell source $(WORKSPACE_SQ)/src/version.lib.sh 2>/dev/null && readPackageName)
# Befehle aus [project.scripts], durch Leerzeichen getrennt; der erste ist PACKAGE_CMD
PACKAGE_CMDS := $(shell source $(WORKSPACE_SQ)/src/version.lib.sh 2>/dev/null && readPackageCommands)
PACKAGE_CMD  := $(firstword $(PACKAGE_CMDS))
NO_PACKAGE   := nicht lesbar (pyproject.toml, [project] name)
PACKAGE      := $(or $(PACKAGE_NAME),$(NO_PACKAGE))

.PHONY: info
info: ## Umgebungsvariablen anzeigen
	@echo
	@printMakeValue PROJECT_NAME "$${PROJECT_NAME}"
	@printMakeValue WORKSPACE    "$${WORKSPACE}"
	@printMakeValue BASH_LIBS    "$${BASH_LIBS}"
	@printMakeValue PACKAGE      '$(PACKAGE)'
	@printMakeValue VERSION      "$$(readProjectVersion 2>/dev/null || echo 'keine Versionsdatei')"
	@printMakeValue THEME        "$${THEME_NAME:-ohne clitheme (clitheme export)}"
	@echo
	@# devtools rückt um zwei Zeichen ein; fünf mehr stellen die Zeilen unter die Werte oben.
	@set -o pipefail; $(DEV_TOOLS) status 2>/dev/null | sed 's/^/     /' || echo "       Werkzeugstand nicht abrufbar: $(devtools_unavailable)"
	@echo

# Installationsbefehle von ProjectTools und CLITheme nennt devtools (Tag aus .dev-tools.conf.sh).
tool_command = $$($(DEV_TOOLS) command $(1) 2>/dev/null || echo "nicht abrufbar: $(devtools_unavailable)")

# Die Make-Werte in den Zeilen sind oben auf erlaubte Zeichen geprüft.
.PHONY: hints
hints: ## Nützliche Links und Hinweise anzeigen
	@printMakeHeading "Erster Start"
	@printMakeValue   "1. Setup"       "make setup"
	@printMakeValue   "2. Prüfen"      "make check"
	@printMakeHeading "BashLib in anderen Projekten"
	@printMakeValue   "Paket"          '$(PACKAGE)$(if $(PACKAGE_CMD), (Befehl $(PACKAGE_CMD)))'
	@printMakeValue   "Installieren"   "$(if $(filter https://%,$(REPO_URL)),pipx install 'git+$(REPO_URL).git@$(RELEASE_TAG)',$(REPO_URL))"
	@printMakeValue   "Arbeitskopie"   "pipx install -e $${WORKSPACE_SQ}"
	@printMakeValue   "Umgebung"       'export BASH_LIBS=$$(bashlib-path)'
	@printMakeHeading "ProjectTools (docs-check, status, changelog)"
	@printMakeValue   "Installieren"   "$(call tool_command,projecttools)"
	@printMakeHeading "CLITheme (Farben und Abstände der Ausgabe)"
	@printMakeValue   "Installieren"   "$(call tool_command,clitheme)"
	@printMakeValue   "Themes anlegen" "clitheme install (macht make setup)"
	@printMakeValue   "Auswahl"        "export CLI_THEME=ocean"
	@printMakeHeading "Links"
	@printMakeValue   "Repository"     '$(REPO_URL)'
	@echo

# ─── Precheck ────────────────────────────────────────────────────────────────

# Ohne `##`: nicht in der Hilfe, läuft als Abhängigkeit von version und tag-*.
# Bewusst ohne printThemeStatus: precheck meldet gerade, dass BashLib fehlt.
.PHONY: precheck
precheck:
	@if [[ ! -r "$${BASH_LIBS:-}/version.lib.sh" ]]; then \
		echo ""; \
		echo "Achtung: 'BASH_LIBS' fehlt oder enthält keine lesbare version.lib.sh!"; \
		echo ""; \
		exit 1; \
	fi

# Ohne `##`: verlangt ProjectTools in Mindestversion und nennt sonst den Installationsbefehl.
.PHONY: require-tools
require-tools:
	@source "$${BASH_LIBS}/apps.lib.sh" && requireCommand pipx "$(PIPX_URL)"
	@$(DEV_TOOLS) check projecttools

# ─── Setup ───────────────────────────────────────────────────────────────────

##@ Setup

# Die Tests brauchen Bash, Git und python3 (Theme-Test); setup aktiviert die
# versionierten Git-Hooks und legt mit clitheme install fehlende Theme-Dateien
# an. Fehlt clitheme, nennt setup den Installationsbefehl und läuft weiter.
# Wiederholbar und ohne Rückfrage.
.PHONY: setup
setup: ## Git-Hooks aktiv (pre-commit: docs-check), fehlende CLI-Themes angelegt
	@git config core.hooksPath .githooks
	@source "$${BASH_LIBS}/cli.lib.sh" && printThemeStatus "✓" "Git-Hooks aus .githooks aktiv" OK
	@$(MAKE) --no-print-directory setup-themes

# Ohne `##`: Teil von setup; scheitert nie, damit setup ohne clitheme durchläuft.
# devtools meldet fehlendes oder zu altes CLITheme samt Installationsbefehl; ohne
# clitheme bleibt die Ausgabe der Skripte farblos.
.PHONY: setup-themes
setup-themes:
	@if source "$${BASH_LIBS}/apps.lib.sh" && requireCommand pipx "$(PIPX_URL)"; then $(DEV_TOOLS) check clitheme >&2 || true; fi; \
	command -v clitheme >/dev/null || exit 0; \
	if output=$$(clitheme install 2>&1); then \
		printThemeStatus "✓" "CLI-Themes in $$(themeEscape "$$(dirname -- "$$(clitheme path)")")" OK; \
	else \
		printf '%s\n' "$$output" >&2; \
		{ printThemeStatus "✗" "clitheme install fehlgeschlagen, Ausgabe ohne Farben" ERR; printThemeHint "clitheme show"; } >&2; \
	fi

# Installiert diese Arbeitskopie editierbar mit pipx (installEditablePackage aus
# make.lib.sh): die Befehle aus [project.scripts] zeigen danach auf src/ dieses
# Checkouts.
.PHONY: install
install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
	@source "$${BASH_LIBS}/make.lib.sh" && installEditablePackage "$${WORKSPACE}"

# Prüf-Targets richten nichts ein; setup ist der einzige Weg (worktree_setup).
.PHONY: require-setup
require-setup:
	@source "$${BASH_LIBS}/make.lib.sh" && requireMakeSetup --hooks .githooks

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
# (readProjectVersion, semVerBump, semVerNext für {major}/{minor}/{patch} in help).

##@ Versionierung

.PHONY: version
version: precheck ## Version aus pyproject.toml und Release-Tag anzeigen — Maintainer
	@echo
	@source "$${BASH_LIBS}/make.lib.sh" && showProjectVersion
	@echo

.PHONY: tags
tags: precheck ## Letzte 10 Release-Tags mit Nachricht anzeigen
	@echo
	@source "$${BASH_LIBS}/make.lib.sh" && showReleaseTags 10
	@echo

# Eine Statuszeile für tag-* über printThemeStatus (cli.lib.sh): Häkchen, Beschriftung
# auf 10 Zeichen, Wert. Aufruf: $(call release_row,Beschriftung,Wert), ohne Komma in den Werten.
release_row = printThemeStatus "✓" "$$(printf '%-10s %s' "$(1)" "$(2)")" OK

# Sprache von CHANGELOG.md, unabhängig von der Locale der Shell (changelog folgt
# sonst LANG; unter C.UTF-8 käme Englisch). Überschreiben: make … CHANGELOG_LANGUAGE=en
CHANGELOG_LANGUAGE ?= de
export CHANGELOG_LANGUAGE

# $(call release,major|minor|patch): Version heben und lokal taggen (tag-version,
# ProjectTools), CHANGELOG.md committen (changelog --commit), develop vorspulen
# (tag-version --fast-forward); alles nur lokal. Veröffentlicht wird mit
# git push --follow-tags.
# Nur auf master und nur, wenn develop nicht weiter ist (T-36): Das Board übernimmt
# Tickets per Merge-Commit, ein Tag auf einem Ticket-Branch läge dann neben der
# First-Parent-Historie, und changelog ließe das Release aus. Die Prüfung steht
# hier für die Meldungen des Projekts; tag-version prüft dieselben Bedingungen
# vor jeder Änderung noch einmal und bricht dann ohne Tag ab.
# Ausgabe: je Schritt eine Statuszeile. tag-version schreibt seine Step-Zeilen
# auf stdout und Fehler nach stderr; stdout wird ersetzt, damit die vier Zeilen
# des Projekts bleiben. Ob changelog committet hat, zeigt ein neuer HEAD.
define release
	@source "$${BASH_LIBS}/cli.lib.sh"; \
	 branch=$$(git symbolic-ref --short -q HEAD || echo 'detached HEAD'); \
	 if [[ "$$branch" != master ]]; then \
		{ printThemeStatus "✗" "Release nur auf master, nicht auf $$(themeEscape "$$branch"); nach der Abnahme auf master:" ERR; \
		  printThemeHint "make $@"; } >&2; \
		exit 1; \
	 fi; \
	 if git rev-parse -q --verify refs/heads/develop >/dev/null && ! git merge-base --is-ancestor develop HEAD; then \
		{ printThemeStatus "✗" "develop ist weiter als master; erst die Tickets abnehmen:" ERR; \
		  printThemeHint "al ticket accept"; } >&2; \
		exit 1; \
	 fi
	@source "$${BASH_LIBS}/cli.lib.sh"; source "$${BASH_LIBS}/version.lib.sh"; \
	 old=$$(readProjectVersion); \
	 tag-version $(1) --message "$${MSG:-}" >/dev/null || exit $$?; \
	 tag=$$(git tag --points-at HEAD --list 'v*' | sort -V | tail -n1); \
	 $(call release_row,Version,$$old → $$(readProjectVersion)); \
	 $(call release_row,Tag,$${tag} (nur lokal))
	@source "$${BASH_LIBS}/cli.lib.sh"; head=$$(git rev-parse HEAD); \
	 LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --commit >/dev/null || exit $$?; \
	 if [[ "$$(git rev-parse HEAD)" == "$$head" ]]; then \
		$(call release_row,Changelog,CHANGELOG.md unverändert); \
	 else \
		$(call release_row,Changelog,CHANGELOG.md committet); \
	 fi
	@source "$${BASH_LIBS}/cli.lib.sh"; \
	 if git rev-parse -q --verify refs/heads/develop >/dev/null; then \
		tag-version --fast-forward >/dev/null || exit $$?; \
		$(call release_row,develop,auf master vorgespult); \
	 fi
endef

.PHONY: changelog
changelog: require-tools ## Vorschau des Changelogs aus Tags und Commits
	@LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --dry-run

# require-tools vor precheck: ohne ProjectTools bricht ein Release vor dem Bump ab,
# nicht erst nach dem Tag.
.PHONY: tag-major
tag-major: require-tools precheck ## Major {major}, inkompatibel  [MSG="..."] — Maintainer
	$(call release,major)

.PHONY: tag-minor
tag-minor: require-tools precheck ## Minor {minor}, neue Funktion  [MSG="..."] — Maintainer
	$(call release,minor)

.PHONY: tag-patch
tag-patch: require-tools precheck ## Patch {patch}, Fehlerbehebung  [MSG="..."] — Maintainer
	$(call release,patch)
