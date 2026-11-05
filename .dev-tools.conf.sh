#!/usr/bin/env bash
# Versionen der Entwicklungswerkzeuge, die dieses Projekt über pipx braucht.
# Das Makefile bindet die Datei mit include ein; Bash kann sie sourcen.
# Deshalb NAME=wert ohne Anführungszeichen und ohne Leerzeichen um das =.
# shellcheck disable=SC2034  # vom Makefile gelesen

# Gelesen von devtools (Paket mmit-devtools, Projekt DevTools). Je Werkzeug: PACKAGE ist das
# pipx-Paket, TAG der Release-Tag, seine SemVer-Zahl die Mindestversion. SOURCE ist die Quelle
# für die Installation: die Git-URL (dann gilt der Tag) oder der Pfad einer Arbeitskopie.
# EDITABLE=yes bindet eine Arbeitskopie bearbeitbar ein (pipx install -e), no als festen Stand.

# DevTools selbst (devtools status|check|command), aufgerufen mit pipx run.
DEVTOOLS_TAG=v0.3.0+261102.1831.3723d

# ProjectTools (docs-check, repo-status, changelog).
PROJECTTOOLS_PACKAGE=mmit-projecttools
PROJECTTOOLS_LABEL=ProjectTools
PROJECTTOOLS_TAG=v0.4.0+261103.1343.9d0a8
PROJECTTOOLS_SOURCE=git+https://github.com/MikeMitterer/bash-ProjectTools.git
PROJECTTOOLS_EDITABLE=yes

# CLITheme (cli-theme install legt die Theme-Dateien an, die colors.lib.sh liest).
# Nur make setup, make info und make hints brauchen es; die Bibliotheken nicht.
CLITHEME_PACKAGE=mmit-cli-theme
CLITHEME_LABEL=CLITheme
CLITHEME_TAG=v0.4.0+261102.1800.5c1a8
CLITHEME_SOURCE=git+https://github.com/MikeMitterer/python-clitheme.git
CLITHEME_EDITABLE=yes
