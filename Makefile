# Makefile — BashLib
#
# Aufbau nach makefile-conventions. BashLib ist selbst die Bibliothek: Tests
# und Versionierung nehmen immer src/ dieses Checkouts, nicht BASH_LIBS aus
# der Umgebung. In einem Worktree prüft make test also genau diesen Stand.

SHELL := bash

.DEFAULT_GOAL := help

# MSG für make tag-* unausgewertet übernehmen, vor dem ersten $(shell …): Make
# exportiert Variablen von der Kommandozeile und wertet sie dabei aus, aus $HOME
# würde OME und $(shell …) liefe. Im Rezept nur als "$${MSG:-}".
override MSG := $(value MSG)
export MSG

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
PROJECT_NAME := $(shell basename -- $(WORKSPACE_SQ))
BASH_LIBS    := $(WORKSPACE)/src
# Werte von außen nur über die Umgebung in Rezepte geben ("$${VAR}")
export WORKSPACE WORKSPACE_SQ PROJECT_NAME BASH_LIBS

# Release-Tags und Quellen der Werkzeuge (ProjectTools, CLITheme) und von DevTools selbst stehen
# nur in .dev-tools.conf.sh. Aufgerufen wird das einmal je Rechner installierte devtools
# (Starter); es gibt an DEVTOOLS_TAG weiter, wenn dieser abweicht (Konzept DevTools T-20). Mit
# --project installiert und prüft es die Werkzeuge in .tools/ dieses Checkouts.
include .dev-tools.conf.sh
# Ohne die Git-Variablen eines Hooks (make docs-check im pre-commit): pip und pipx schrieben
# sonst in den Index dieses Repositorys.
DEV_TOOLS := env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE devtools --project
# Bricht ab, wenn der Starter fehlt, und nennt seinen Installationsbefehl mit Quelle und Tag aus
# .dev-tools.conf.sh. Im Rezept vor jedem Aufruf von devtools: @$(REQUIRE_STARTER) && …
REQUIRE_STARTER = source "$${BASH_LIBS}/apps.lib.sh" && \
	requireCommand devtools "pipx install '$(DEVTOOLS_SOURCE)@$(DEVTOOLS_TAG)'"
# Werkzeuge aus .tools/ im Checkout (make setup) vorn im PATH; ein global installiertes
# ProjectTools oder clitheme zählt nicht.
export PATH := $(WORKSPACE)/.tools/bin:$(PATH)

# Entwicklungs-venv für make build (python -m build) und mit bashlib dieses Checkouts für
# make docs-check (SKILLS). BashLib hat keine Laufzeit-Abhängigkeiten; PYTHON_BOOTSTRAP=…
# überschreibt den Interpreter, als Wert von außen nur über die Umgebung.
PYTHON_BOOTSTRAP ?= python3
export PYTHON_BOOTSTRAP
VENV         := .venv
PYTHON       := $(VENV)/bin/python
VENV_STAMP   := $(VENV)/.installed
SETUP_STAMPS := $(VENV_STAMP) $(VENV)/bin/bashlib

# ─── Hilfe ───────────────────────────────────────────────────────────────────

# Liste der Makefiles unausgewertet über die Umgebung (siehe Standard-Header)
export HELP_FILES = $(value MAKEFILE_LIST)

# help, info und hints laden make.lib.sh über BASH_ENV in jede Rezeptzeile; so steht
# jede Ausgabezeile als eigener Befehl da. Bash wertet BASH_ENV aus: darum der Verweis
# auf BASH_LIBS statt des Pfads, ein $(…) im Checkout-Pfad bleibt Text.
help info hints: export BASH_ENV := $${BASH_LIBS}/make.lib.sh
# Das Theme einmal je make-Lauf: clitheme_export ruft clitheme beim ersten Bedarf auf und
# merkt sich die Ausgabe; make.lib.sh übernimmt sie geprüft, statt clitheme je Zeile zu starten.
# Make ab 4.4 gibt BASH_ENV auch an $(shell): Dort lädt make.lib.sh das Theme ein zweites Mal.
clitheme_export = $(eval clitheme_export := $$(shell clitheme export --bash 2>/dev/null))$(clitheme_export)
help info hints: export CLITHEME_EXPORT = $(clitheme_export)

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
# [project.scripts]); nur erlaubte Zeichen, sonst leer. Erst beim ersten Bedarf gelesen
# und gemerkt (wie clitheme_export), nicht bei jedem make. $$(WORKSPACE_SQ): eval liest
# seinen Text als Make-Code, der Checkout-Pfad darf erst danach eingesetzt werden.
PACKAGE_NAME = $(eval PACKAGE_NAME := $$(shell source $$(WORKSPACE_SQ)/src/version.lib.sh 2>/dev/null && readPackageName))$(PACKAGE_NAME)
# Befehle aus [project.scripts], durch Leerzeichen getrennt; der erste ist PACKAGE_CMD
PACKAGE_CMDS = $(eval PACKAGE_CMDS := $$(shell source $$(WORKSPACE_SQ)/src/version.lib.sh 2>/dev/null && readPackageCommands))$(PACKAGE_CMDS)
PACKAGE_CMD  = $(firstword $(PACKAGE_CMDS))
NO_PACKAGE   := nicht lesbar (pyproject.toml, [project] name)
PACKAGE      = $(or $(PACKAGE_NAME),$(NO_PACKAGE))

# Die Zeilen von devtools status rückt devtools um zwei Zeichen ein; fünf mehr stellen
# sie unter die Werte oben.
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
	@set -o pipefail; $(DEV_TOOLS) status 2>/dev/null | sed 's/^/     /' || echo "       Werkzeugstand nicht abrufbar: devtools fehlt (make hints)"
	@echo

# Die Make-Werte in den Zeilen sind oben auf erlaubte Zeichen geprüft.
.PHONY: hints
hints: ## Nützliche Links und Hinweise anzeigen
	@printMakeHeading "Alltag"
	@printMakeValue   "Neuer Checkout" "make setup"
	@printMakeValue   "Vor dem Commit" "make check"
	@printMakeValue   "Starter"        "pipx install '$(DEVTOOLS_SOURCE)@$(DEVTOOLS_TAG)'"
	@printMakeHeading "BashLib in anderen Projekten"
	@printMakeValue   "Paket"          '$(PACKAGE)$(if $(PACKAGE_CMD), (Befehl $(PACKAGE_CMD)))'
	@printMakeValue   "Installieren"   "$(if $(filter https://%,$(REPO_URL)),pipx install 'git+$(REPO_URL).git@$(RELEASE_TAG)',$(REPO_URL))"
	@printMakeValue   "Arbeitskopie"   "pipx install -e $${WORKSPACE_SQ}"
	@printMakeValue   "Umgebung"       'export BASH_LIBS=$$(bashlib-path)'
	@printMakeHeading "ProjectTools (docs-check, status, changelog, tag-version)"
	@printMakeValue   "Einrichten"     "make setup"
	@printMakeHeading "CLITheme (Farben und Abstände der Ausgabe)"
	@printMakeValue   "Einrichten"     "make setup"
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
		echo "Achtung: 'BASH_LIBS' fehlt oder enthält keine lesbare version.lib.sh!" >&2; \
		exit 1; \
	fi

# Ohne `##`: verlangt ProjectTools in .tools/ in Mindestversion und nennt sonst den Grund.
.PHONY: require-tools
require-tools:
	@$(REQUIRE_STARTER) && $(DEV_TOOLS) check projecttools

# ─── Setup ───────────────────────────────────────────────────────────────────

##@ Setup

# Installiert diese Arbeitskopie editierbar mit pipx (installEditablePackage aus
# make.lib.sh): die Befehle aus [project.scripts] zeigen danach auf src/ dieses
# Checkouts. BashLib hat keine Abhängigkeiten aus Git und braucht darum kein devtools exec.
# Danach legt clitheme install fehlende Theme-Dateien für den User an (installCliThemes);
# das scheitert nie, ohne Themes bleibt die Ausgabe farblos.
.PHONY: install
install: ## Befehle aus dieser Arbeitskopie (pipx, editierbar) und CLI-Themes
	@source "$${BASH_LIBS}/make.lib.sh" && installEditablePackage "$${WORKSPACE}"
	@source "$${BASH_LIBS}/make.lib.sh" && installCliThemes || true

# Der einzige Einrichtungsweg, auch für agent-lessons (worktree_setup); wiederholbar und ohne
# Rückfrage. Die Tests brauchen Bash, Git und python3 (Theme-Test). setup aktiviert die
# versionierten Git-Hooks, legt die .venv an, bringt ProjectTools und CLITheme mit den Tags aus
# .dev-tools.conf.sh nach .tools/. Außerhalb des Checkouts ändert setup nur Paket-Caches und
# core.hooksPath; die Theme-Dateien des Users legt make install an.
.PHONY: setup
setup: $(SETUP_STAMPS) ## Bereit zum Entwickeln: Git-Hooks, .venv, Werkzeuge in .tools/
	@git config core.hooksPath .githooks
	@source "$${BASH_LIBS}/cli.lib.sh" && printThemeStatus "✓" "Git-Hooks aus .githooks aktiv" OK
	@$(REQUIRE_STARTER) && $(DEV_TOOLS) install

# Stempeldatei: nur setup legt sie an. Ohne Voraussetzung, weil BashLib keine Abhängigkeiten
# hat; ein Versionssprung in pyproject.toml macht die Einrichtung so nicht veraltet.
$(VENV_STAMP):
	@source "$${BASH_LIBS}/apps.lib.sh" && requireCommand "$${PYTHON_BOOTSTRAP}" "PYTHON_BOOTSTRAP=… überschreibt"
	@test -x $(PYTHON) || "$${PYTHON_BOOTSTRAP}" -m venv $(VENV)
	@source "$${BASH_LIBS}/cli.lib.sh" && { $(PYTHON) -m pip install -q --disable-pip-version-check build || { \
		printThemeStatus "✗" "build nicht installiert: Netz und Paketindex prüfen" ERR >&2; exit 1; }; }
	@touch "$@"
	@source "$${BASH_LIBS}/cli.lib.sh" && printThemeStatus "✓" "$(VENV) eingerichtet" OK

# bashlib dieses Checkouts editierbar in der .venv: docs-check prüft damit die Ausgabe von
# bashlib --skill (SKILLS in .docs-check.conf.sh), auch in der Kopie des pre-commit-Hooks.
# Editierbar nur mit pyproject.toml verlangt pip ab 21.3; das pip eines älteren Pythons
# (macOS: 3.9) wird dafür zuerst angehoben.
$(VENV)/bin/bashlib: $(VENV_STAMP)
	@source "$${BASH_LIBS}/cli.lib.sh" && { { $(PYTHON) -m pip install -q --disable-pip-version-check --upgrade pip && \
		$(PYTHON) -m pip install -q --disable-pip-version-check -e .; } || { \
		printThemeStatus "✗" "bashlib nicht in $(VENV) installiert: Netz und Paketindex prüfen" ERR >&2; exit 1; }; }
	@touch "$@"

# Prüf-Targets richten nichts ein; setup ist der einzige Weg (worktree_setup).
.PHONY: require-setup
require-setup:
	@source "$${BASH_LIBS}/make.lib.sh" && requireMakeSetup --hooks .githooks --make "$(MAKE)" $(SETUP_STAMPS)

# Setzt den Checkout zurück; make setup richtet ihn wieder ein. Die Installation beim User
# (install) und die Git-Konfiguration bleiben.
.PHONY: clean
clean: ## Checkout zurücksetzen: .venv, .tools/, dist/ und build/ entfernen
	@rm -rf -- "$${WORKSPACE}/$(VENV)" "$${WORKSPACE}/.tools" "$${WORKSPACE}/dist" "$${WORKSPACE}/build"
	@source "$${BASH_LIBS}/cli.lib.sh" && printThemeStatus "✓" "Checkout zurückgesetzt, neu einrichten: make setup" OK

# ─── Status ──────────────────────────────────────────────────────────────────

##@ Status

.PHONY: status
status: require-tools ## Git-Status des Repos und offene Blocker-Issues — Maintainer
	@repo-status --show

# ─── Tests ───────────────────────────────────────────────────────────────────

##@ Tests

# Voller Prüflauf, auch für agent-lessons (integration_check: make check).
.PHONY: check
check: test ## Voller Prüflauf — Doku und alle Bash-Tests

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

# ─── Paket ───────────────────────────────────────────────────────────────────

##@ Paket

# Paket für externe User: Wheel und sdist unter dist/; devtools prüft danach die Metadaten auf
# lokale Pfade (Fehler) und ungepushte Git-Tags (Hinweis), Konzept DevTools T-20. build hängt
# an den Stempeln von setup und richtet so selbst ein, was ihm fehlt.
.PHONY: build
build: $(SETUP_STAMPS) ## Wheel und sdist für externe User unter dist/ bauen und prüfen
	@rm -rf -- "$${WORKSPACE}/dist"
	@source "$${BASH_LIBS}/cli.lib.sh" && { out=$$($(PYTHON) -m build --outdir dist . 2>&1) || { \
		printf '%s\n' "$$out" >&2; printThemeStatus "✗" "Paket nicht gebaut: Netz und Paketindex prüfen" ERR >&2; exit 1; }; }
	@$(REQUIRE_STARTER) && $(DEV_TOOLS) check-dist dist/*

# Wie ein User ohne Klon oder CI: pipx in leerem PIPX_HOME, ohne rechnerlokale Zuordnung und
# ohne GitHub (scripts/build-check.sh).
.PHONY: build-check
build-check: ## Gebautes Paket wie ein User ohne Klon installieren und aufrufen
	@./scripts/build-check.sh

# ─── Versionierung ───────────────────────────────────────────────────────────

# Nach versioning-conventions (templates/versioning.mk): Die Version steht in
# pyproject.toml; gelesen wird sie über version.lib.sh dieses Checkouts
# (readProjectVersion, semVerNext für {major}/{minor}/{patch} in help). Bump,
# Tag und Vorspulen macht tag-version (ProjectTools), das semVerBump aus
# dieser BashLib nutzt (BASH_LIBS oben); das Rezept steht am Ende des Abschnitts.

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

# Sprache von CHANGELOG.md, unabhängig von der Locale der Shell (changelog folgt
# sonst LANG; unter C.UTF-8 käme Englisch). Überschreiben: make … CHANGELOG_LANGUAGE=en
CHANGELOG_LANGUAGE ?= de
export CHANGELOG_LANGUAGE

.PHONY: changelog
changelog: require-tools ## CHANGELOG.md aus Tags und Commits schreiben, ohne Commit
	@LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --generate

.PHONY: tag-major tag-minor tag-patch
tag-major: ## Major {major}, inkompatibel  [MSG="..."] — Maintainer
tag-minor: ## Minor {minor}, neue Funktion  [MSG="..."] — Maintainer
tag-patch: ## Patch {patch}, Fehlerbehebung  [MSG="..."] — Maintainer

# Version heben und lokal taggen, CHANGELOG.md committen, develop vorspulen; alles nur
# lokal, veröffentlicht wird mit git push --follow-tags. Prüfung (nur auf master, develop
# nicht weiter; T-36) und Ablauf stehen nur in tag-version (ProjectTools); ein Fehler in
# einer Zeile bricht die folgenden ab. changelog nennt bei Erfolg den absoluten Pfad der
# Datei, darum ohne stdout; Fehler kommen über stderr.
# require-tools vor precheck: ohne ProjectTools bricht ein Release vor dem Bump ab,
# nicht erst nach dem Tag.
tag-major tag-minor tag-patch: require-tools precheck
	@tag-version "$(patsubst tag-%,%,$@)" --message "$${MSG:-}"
	@LANGUAGE="$${CHANGELOG_LANGUAGE}" changelog --commit >/dev/null
	@tag-version --fast-forward
