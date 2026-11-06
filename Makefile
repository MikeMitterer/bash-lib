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

# Farben und Abstände aus dem Theme von CLITheme (clitheme export, ab 0.5.0), dieselben
# wie in den Skripten. Ohne clitheme bleiben die THEME_*-Farben leer, und die Ausgabe
# kommt ohne Escape-Folgen. RESET nur, wenn das Theme Farben liefert.
-include $(shell clitheme export --make 2>/dev/null)
RESET := $(if $(strip $(THEME_COLOR_GROUP)$(THEME_COLOR_TARGET)$(THEME_COLOR_DESC)),$(shell printf '\033[0m'))
# Name des gewählten Themes für make info, über die Umgebung ins Rezept
export THEME_NAME

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

# Gruppen, Targets und [Maintainer] (Beschreibung endet auf „— Maintainer“) gibt
# showMakeHelp aus make.lib.sh im CLI-Theme aus; {major}, {minor} und {patch}
# zeigen die Version vorher und nachher (semVerNext).
.PHONY: help
help: ## Alle verfügbaren Befehle anzeigen
	@echo
	@echo "Please use \`make <$(THEME_COLOR_GROUP)target$(RESET)>' where <target> is one of"
	@echo
	@echo "Project: $(THEME_COLOR_GROUP)$${PROJECT_NAME}$(RESET)"
	@source "$${BASH_LIBS}/make.lib.sh"; \
	 ver=$$(readProjectVersion 2>/dev/null) || ver='x.y.z'; \
	 bump() { local next; next=$$(semVerNext "$$1" 2>/dev/null) || next="$$2"; printf '%s=%s → %s' "$$1" "$$ver" "$$next"; }; \
	 showMakeHelp --set "$$(bump major X+1.0.0)" --set "$$(bump minor x.Y+1.0)" --set "$$(bump patch x.y.Z+1)" \
		$${HELP_FILES}

.PHONY: info
info: ## Umgebungsvariablen anzeigen
	@echo
	@source "$${BASH_LIBS}/make.lib.sh"; \
	 version=$$(readProjectVersion 2>/dev/null); \
	 showMakeInfo \
		PROJECT_NAME "$${PROJECT_NAME}" WORKSPACE "$${WORKSPACE}" BASH_LIBS "$${BASH_LIBS}" \
		PACKAGE '$(or $(PACKAGE_NAME),$(NO_PACKAGE))' VERSION "$${version}" \
		THEME "$${THEME_NAME:-ohne clitheme (clitheme export)}"
	@# devtools rückt um zwei Zeichen ein; fünf mehr stellen die Zeilen unter die Werte oben.
	@set -o pipefail; $(DEV_TOOLS) status 2>/dev/null | sed 's/^/     /' || echo "       Werkzeugstand nicht abrufbar: $(devtools_unavailable)"
	@echo

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

# Zeilen „## Titel“ und „Beschriftung<TAB>Wert“ für showMakeHints aus make.lib.sh;
# die Make-Werte darin sind oben auf erlaubte Zeichen geprüft.
.PHONY: hints
hints: ## Nützliche Links und Hinweise anzeigen
	@source "$${BASH_LIBS}/make.lib.sh"; \
	 projecttools=$$($(DEV_TOOLS) command projecttools 2>/dev/null) || projecttools="nicht abrufbar: $(devtools_unavailable)"; \
	 clitheme=$$($(DEV_TOOLS) command clitheme 2>/dev/null) || clitheme="nicht abrufbar: $(devtools_unavailable)"; \
	 { printf '## %s\n' 'Erster Start'; \
	   printf '%s\t%s\n' '1. Setup' 'make setup' '2. Prüfen' 'make check'; \
	   printf '## %s\n' 'BashLib in anderen Projekten'; \
	   printf '%s\t%s\n' \
		'Paket' '$(or $(PACKAGE_NAME),$(NO_PACKAGE))$(if $(PACKAGE_CMD), (Befehl $(PACKAGE_CMD)))' \
		'Installieren' "$(if $(filter https://%,$(REPO_URL)),pipx install 'git+$(REPO_URL).git@$(RELEASE_TAG)',$(REPO_URL))" \
		'Arbeitskopie' "pipx install -e $${WORKSPACE_SQ}" \
		'Umgebung' 'export BASH_LIBS=$$(bashlib-path)'; \
	   printf '## %s\n' 'ProjectTools (docs-check, status, changelog)'; \
	   printf '%s\t%s\n' 'Installieren' "$$projecttools"; \
	   printf '## %s\n' 'CLITheme (Farben und Abstände der Ausgabe)'; \
	   printf '%s\t%s\n' 'Installieren' "$$clitheme" \
		'Themes anlegen' 'clitheme install (macht make setup)' 'Auswahl' 'export CLI_THEME=ocean'; \
	   printf '## %s\n' 'Links'; \
	   printf '%s\t%s\n' 'Repository' '$(REPO_URL)'; \
	 } | showMakeHints

# ─── Precheck ────────────────────────────────────────────────────────────────

# Ohne `##`: nicht in der Hilfe, läuft als Abhängigkeit von version und tag-*.
.PHONY: precheck
precheck:
	@if [[ ! -r "$${BASH_LIBS:-}/version.lib.sh" ]]; then \
		echo ""; \
		echo "$(THEME_COLOR_DANGER)Achtung: '$(THEME_COLOR_ACCENT)BASH_LIBS$(THEME_COLOR_DANGER)' fehlt oder enthält keine lesbare version.lib.sh!$(RESET)"; \
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
	@echo -e "  $(THEME_COLOR_SUCCESS)✓$(RESET) Git-Hooks aus .githooks aktiv"
	@$(MAKE) --no-print-directory setup-themes

# Ohne `##`: Teil von setup; scheitert nie, damit setup ohne clitheme durchläuft.
# devtools meldet fehlendes oder zu altes CLITheme samt Installationsbefehl; ohne
# clitheme bleibt die Ausgabe der Skripte farblos.
.PHONY: setup-themes
setup-themes:
	@if source "$${BASH_LIBS}/apps.lib.sh" && requireCommand pipx "$(PIPX_URL)"; then $(DEV_TOOLS) check clitheme >&2 || true; fi; \
	command -v clitheme >/dev/null || exit 0; \
	if output=$$(clitheme install 2>&1); then \
		printf '  $(THEME_COLOR_SUCCESS)✓$(RESET) CLI-Themes in %s\n' "$$(dirname -- "$$(clitheme path)")"; \
	else \
		printf '%s\n' "$$output" >&2; \
		printf '  $(THEME_COLOR_DANGER)✗$(RESET) clitheme install fehlgeschlagen; Ausgabe ohne Farben: $(THEME_COLOR_ACCENT)clitheme show$(RESET)\n' >&2; \
	fi

# Installiert diese Arbeitskopie editierbar mit pipx: die Befehle aus
# [project.scripts] zeigen danach auf src/ dieses Checkouts. Neue Befehle legt
# pipx nur beim Installieren an; nach einem Update deshalb erneut aufrufen.
.PHONY: install
install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
	@source "$${BASH_LIBS}/apps.lib.sh" && requireCommand pipx "$(PIPX_URL)"
	@if output=$$(pipx install -e --force "$${WORKSPACE}" 2>&1); then \
		names='$(PACKAGE_CMDS)'; printf '  $(THEME_COLOR_SUCCESS)✓$(RESET) %s aus %s\n' "$${names// /, }" "$${WORKSPACE}"; \
	else \
		printf '%s\n' "$$output" >&2; \
		printf '  $(THEME_COLOR_DANGER)✗$(RESET) pipx install fehlgeschlagen\n' >&2; exit 1; \
	fi

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
	@source "$${BASH_LIBS}/tools.lib.sh" && showProjectVersion
	@echo

.PHONY: tags
tags: precheck ## Letzte 10 Release-Tags mit Nachricht anzeigen
	@echo
	@source "$${BASH_LIBS}/tools.lib.sh" && showReleaseTags 10
	@echo

# Eine Statuszeile für tag-*: Häkchen, Beschriftung, Wert.
# Aufruf: $(call release_row,Beschriftung,Wert), ohne Komma in den Werten.
release_row = printf '  $(THEME_COLOR_SUCCESS)✓$(RESET) %-10s $(THEME_COLOR_VALUE)%s$(RESET)\n' "$(1)" "$(2)"

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
		printf '  $(THEME_COLOR_DANGER)✗$(RESET) Release nur auf master, nicht auf %s; nach der Abnahme auf master:\n       $(THEME_COLOR_ACCENT)make %s$(RESET)\n' "$$branch" '$@' >&2; \
		exit 1; \
	 fi; \
	 if git rev-parse -q --verify refs/heads/develop >/dev/null && ! git merge-base --is-ancestor develop HEAD; then \
		printf '  $(THEME_COLOR_DANGER)✗$(RESET) develop ist weiter als master; erst die Tickets abnehmen:\n       $(THEME_COLOR_ACCENT)al ticket accept$(RESET)\n' >&2; \
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
tag-major: require-tools precheck ## Major-Release {major}, inkompatibel  [MSG="..."] — Maintainer
	$(call release,major)

.PHONY: tag-minor
tag-minor: require-tools precheck ## Minor-Release {minor}, neue Funktion  [MSG="..."] — Maintainer
	$(call release,minor)

.PHONY: tag-patch
tag-patch: require-tools precheck ## Patch-Release {patch}, Fehlerbehebung  [MSG="..."] — Maintainer
	$(call release,patch)
