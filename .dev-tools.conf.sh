#!/usr/bin/env bash
# Versionen der Entwicklungswerkzeuge, die dieses Projekt über pipx braucht.
# Das Makefile bindet die Datei mit include ein; Bash kann sie sourcen.
# Deshalb NAME=wert ohne Anführungszeichen und ohne Leerzeichen um das =.
# shellcheck disable=SC2034  # vom Makefile gelesen

# Gelesen von devtools (Paket mmit-devtools, Projekt DevTools). Je Werkzeug: PACKAGE ist das
# pipx-Paket, TAG der Release-Tag, seine SemVer-Zahl die Mindestversion. SOURCE ist die Quelle
# für die Installation: die Git-URL (dann gilt der Tag) oder der Pfad einer Arbeitskopie.
# EDITABLE=yes bindet eine Arbeitskopie bearbeitbar ein (pipx install -e), no als festen Stand.

# DevTools selbst: der einmal je Rechner installierte Starter `devtools` gibt an diesen Tag
# weiter, wenn er abweicht; fehlt er, nennt das Makefile `pipx install` mit Quelle und Tag.
# Ab v0.9.0 devtools tstamp, an dem der Einrichtungsstempel der .venv hängt (T-87).
DEVTOOLS_TAG=v0.9.0+261125.1112.8ae5a
DEVTOOLS_SOURCE=git+https://github.com/MikeMitterer/python-devtools.git

# ProjectTools (docs-check, repo-status, changelog, repo-info ab 0.5.0;
# tag-version ab 0.7.0, das make tag-* seit T-65 aufruft; SKILLS in docs-check ab 0.13.0).
PROJECTTOOLS_PACKAGE=mmit-projecttools
PROJECTTOOLS_LABEL=ProjectTools
PROJECTTOOLS_TAG=v0.13.0+261124.1206.7d2cf
PROJECTTOOLS_SOURCE=git+https://github.com/MikeMitterer/bash-ProjectTools.git
PROJECTTOOLS_EDITABLE=yes

# CLITheme (clitheme: Theme-Dateien, Farben für Makefile und Skripte).
# Makefile (help, hints, info) und colors.lib.sh nehmen Farben und Abstände aus clitheme export.
CLITHEME_PACKAGE=mmit-clitheme
CLITHEME_LABEL=CLITheme
CLITHEME_TAG=v0.13.0+261124.1051.a8560
CLITHEME_SOURCE=git+https://github.com/MikeMitterer/python-clitheme.git
CLITHEME_EDITABLE=yes
