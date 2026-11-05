#!/usr/bin/env bash
# Versionen der Entwicklungswerkzeuge, die dieses Projekt über pipx braucht.
# Das Makefile bindet die Datei mit include ein; Bash kann sie sourcen.
# Deshalb NAME=wert ohne Anführungszeichen und ohne Leerzeichen um das =.
# shellcheck disable=SC2034  # vom Makefile gelesen

# ProjectTools (docs-check, repo-status, changelog). pipx braucht den vollen
# Release-Tag; die Mindestversion ist dessen SemVer-Teil (make info, make hints).
PROJECTTOOLS_TAG=v0.4.0+261103.1343.9d0a8

# CLITheme (cli-theme install legt die Theme-Dateien an, die colors.lib.sh liest).
# Nur make setup, make info und make hints brauchen es; die Bibliotheken nicht.
CLITHEME_TAG=v0.4.0+261102.1800.5c1a8
