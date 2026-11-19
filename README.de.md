<div align="center">

# BashLib

**Bash-Bibliotheken für eigene Skripte: Ausgabe, Farben, Werkzeuge, Versionen, Docker**

[Voraussetzungen](#voraussetzungen) · [Installation](#installation) ·
[Einbinden](#einbinden) · [Bibliotheken](#bibliotheken) ·
[Lizenz](#lizenz) · [Entwicklung](docs/development.md)

[English](README.md) · Deutsch

</div>

BashLib ist eine Sammlung von Bash-Bibliotheken (`*.lib.sh`), die Skripte mit
`source` einbinden. Sie liefert Farben und einheitliche Hilfeausgaben,
Werkzeugpfade, Datum, Logging, Netz-, Docker- und Versionsfunktionen. Jede
Bibliothek lädt die Bibliotheken, die sie selbst braucht, über die Variable
`BASH_LIBS` nach.

## Übersicht

- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Einbinden](#einbinden)
- [Bibliotheken](#bibliotheken)
- [Hilfe und Hinweise in Makefiles](#hilfe-und-hinweise-in-makefiles)
- [Farben und Themes](#farben-und-themes)
- [Entwicklung](#entwicklung)
- [Lizenz](#lizenz)

## Voraussetzungen

- **Bash 5.** Die Bibliotheken setzen Bash 5 voraus; die aktuellen
  Linux-LTS-Versionen bringen 5.2 oder 5.3 mit. macOS bringt als `/bin/bash`
  nur 3.2 mit; eine aktuelle Bash kommt mit `brew install bash`. Skripte
  starten mit `#!/usr/bin/env bash`, damit die Bash aus dem `PATH` läuft.
  Unter einer älteren Bash bricht `cli.lib.sh` (und damit `tools.lib.sh`)
  sofort ab: Auf stderr stehen `✗ Bash 5 nötig, läuft mit Bash <Version>`
  und `brew install bash`, der Exit-Code ist 1, auch beim Einbinden.
- **`BASH_LIBS`** zeigt auf das Verzeichnis `src` dieses Repos (siehe
  [Installation](#installation)). Ohne die Variable findet keine Bibliothek
  ihre Abhängigkeiten.
- **Einzelne Werkzeuge nur für einzelne Funktionen.** `apps.lib.sh` sucht beim
  Einbinden nach `bat`, `jq`, `nmap`, `realpath`, `tree`, `ts` (moreutils),
  `txts` und `gfind`. Fehlt eines, läuft das Skript trotzdem; erst die
  Funktion, die das Werkzeug braucht, scheitert. `checkIfToolIsAvailable`
  meldet ein fehlendes Werkzeug samt Installationsbefehl.

[↑ Übersicht](#übersicht)

## Installation

```bash
git clone https://github.com/MikeMitterer/bash-lib.git ~/.local/share/bash-lib
```

Danach `BASH_LIBS` dauerhaft setzen, etwa in `~/.bashrc` oder `~/.zshrc`:

```bash
export BASH_LIBS="$HOME/.local/share/bash-lib/src"
```

**`BASH_LIBS` muss exportiert sein**, nicht nur gesetzt: Skripte laufen in
einer eigenen Shell und sehen sonst nichts davon. Der Ort des Klons ist frei;
wichtig ist nur, dass `BASH_LIBS` auf dessen `src` zeigt. Aktualisieren mit
`git -C ~/.local/share/bash-lib pull`.

### Als pip-Paket

Werkzeuge, die BashLib mitbringen sollen, hängen sie als Python-Paket an,
etwa in ihrer `pyproject.toml`:

```toml
dependencies = ["mmit-bashlib @ git+https://github.com/MikeMitterer/bash-lib.git@v0.1.0"]
```

Direkt installiert geht es auch:

```bash
pipx install 'git+https://github.com/MikeMitterer/bash-lib.git@v0.1.0'
export BASH_LIBS="$(bashlib-path)"
```

`bashlib-path` gibt das Verzeichnis der installierten Bibliotheken aus. Mit
`pip install -e <clone>` zeigt es auf `src` des Klons, Änderungen wirken dann
ohne Neuinstallation. `bashlib` zeigt Aufruf, Version und Kurzbeschreibung,
je Befehl des Pakets eine Zeile sowie die Optionen, im gewählten CLI-Theme
([Farben und Themes](#farben-und-themes)); `bashlib --version` gibt nur die
Version aus.

**Für KI-Agenten:** `bashlib --skill` beschreibt die Befehle und jede
Bibliothek als Markdown: wofür sie da ist, wann man sie nimmt und ihre
wichtigsten Funktionen, dazu typische Aufrufe. Der Skill `tools` verweist
Agenten in anderen Projekten darauf; die Ausgabe passt immer zur installierten
Version.

Neue Befehle legt pipx nur beim Installieren an, auch bei `pip install -e`.
Nach einem Update von BashLib deshalb neu installieren:

```bash
make install    # in a clone: installs it editable with pipx
pipx install --force 'git+https://github.com/MikeMitterer/bash-lib.git@<release-tag>'
```

[↑ Übersicht](#übersicht)

## Einbinden

Jede Bibliothek setzt beim Laden eine Wächtervariable (`__TOOLS_LIB__`,
`__COLORS_LIB__` …). Eingebunden wird nur, wenn sie noch leer ist; so lädt
jede Bibliothek höchstens einmal, auch wenn mehrere sie brauchen.

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ ! -r "${BASH_LIBS:-}/tools.lib.sh" ]]; then
    echo "BASH_LIBS does not point to BashLib/src: '${BASH_LIBS:-}'" >&2
    exit 1
fi
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

printThemeHeading "Options"
printThemeRow "-h | --help" "Show help"
printThemeStatus "✓" "Done" SUCCESS
```

`tools.lib.sh` bringt `cli.lib.sh` (Ausgabe im CLI-Theme), `colors.lib.sh`,
`apps.lib.sh`, `dtime.lib.sh` und `version.lib.sh` mit; für die meisten Skripte genügt diese eine Zeile. Makefile-Rezepte binden `make.lib.sh` selbst ein; es bringt nur `cli.lib.sh` und `version.lib.sh` mit, nicht `tools.lib.sh`, weil `BASH_ENV` es in jede Rezeptzeile lädt. Rezepte, die weitere Helfer brauchen, binden `tools.lib.sh` oder die betreffende Bibliothek selbst ein. Das ist ein Breaking Change: Skripte, die bisher `showProjectVersion` oder `showReleaseTags` über `tools.lib.sh` bekamen, binden `make.lib.sh` selbst ein (im CHANGELOG unter „Inkompatible Änderungen“). Die Wächterzeile jeder
Bibliothek steht in ihrem Dateikopf unter „Einbinden“.

**Ein Skript, das auch ohne BashLib laufen soll**, prüft wie oben, ob
`${BASH_LIBS}/tools.lib.sh` lesbar ist, und gibt sonst einfache Ausgaben aus,
statt abzubrechen.

[↑ Übersicht](#übersicht)

## Bibliotheken

| Bibliothek | Inhalt | Lädt mit |
|---|---|---|
| `tools.lib.sh` | Allzweck-Helfer (`trim`, `repeat`, `scriptToDoc`, `logFileStatus`, `showModuleLinks`); lädt die Bibliotheken rechts | cli, apps, dtime, version |
| `cli.lib.sh` | Ausgabe im CLI-Theme: Theme von clitheme, `printThemeHeading`, `printThemeRow`, `printThemeValue`, `printThemeOption`, `printThemeExample`, `printThemeHint`, `printThemeStatus`, `usageLine`, `showMenu` | colors |
| `colors.lib.sh` | Feste ANSI-Farbpalette (`RED`, `GREEN`, `NC` …) | – |
| `make.lib.sh` | Hilfe und Hinweise für Makefiles im CLI-Theme (`printMakeHeading`, `printMakeValue`, `showMakeHeader`, `showMakeTargets`), Einrichtung für Prüf-Targets prüfen (`requireMakeSetup`), editierbar mit pipx installieren (`installEditablePackage`), Version und Release-Tags (`showProjectVersion`, `showReleaseTags`) | cli, version |
| `apps.lib.sh` | Pfade der verwendeten Werkzeuge, `checkIfToolIsAvailable`, fehlender Befehl mit Hinweis (`requireCommand`) | logging, os, cli |
| `logging.lib.sh` | Logging für Skripte | – |
| `os.lib.sh` | Betriebssystem erkennen | – |
| `dtime.lib.sh` | Datum und Uhrzeit | os |
| `fs.lib.sh` | Datei- und Verzeichnisfunktionen | – |
| `net.lib.sh` | IP- und Netzfunktionen, `isLocalPortOpen` | os |
| `docker.lib.sh` | Docker-Images bauen und pushen (Docker Hub, GHCR, ECR) | colors |
| `version.lib.sh` | Versionen lesen und erhöhen, taggen (`semVerBump`), nächste Version ohne Schreiben (`semVerNext`), Release-Tag eines Commits (`gitReleaseTag`), Release-Tags als Liste (`gitListReleaseTags`), Paketname und Befehle aus `pyproject.toml` (`readPackageName`, `readPackageCommands`; nur einzeilige `key = "value"`, kein vollständiger TOML-Parser) | – |
| `build.lib.sh` | Hilfen für Build-Skripte | apps, tools |
| `assert.lib.sh` | Asserts für Bash-Tests (`assertEquals`, `assertContains`, `assertNotContains`, `finishTests`, `checkStatus`); ersetzt das frühere `test.lib.sh` | – |
| `samples.lib.sh` | Dart-Beispiele veröffentlichen | tools |
| `webapp.lib.sh` | Node- und TypeScript-Apps veröffentlichen | colors, fs |
| `python.lib.sh` | Python-venv mit Mindestversion und Paketen (`ensurePythonVenv`) | tools |

[↑ Übersicht](#übersicht)

## Hilfe und Hinweise in Makefiles

`make.lib.sh` gibt `make help`, `make info` und `make hints` im CLI-Theme aus,
in denselben Spalten wie die Hilfe eines Skripts. **Eine Rezeptzeile ergibt
eine Ausgabezeile**, das Rezept liest sich also wie seine Ausgabe:

- **`printMakeHeading TEXT`** gibt eine Überschrift aus, wie
  `printThemeHeading`.
- **`printMakeValue LABEL [VALUE]`** gibt eine Zeile Bezeichnung · Wert aus,
  wie `printThemeValue`; der Wert bricht nie um.
- **`showMakeHeader NAME`** gibt die Kopfzeilen der Hilfe aus, „Please use make
  &lt;target&gt; …“ und „Project: NAME“, target und Name in der Gruppenfarbe des
  Themes. Ist die Sprache deutsch (`LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`
  mit dem Vorrang wie bei gettext), lauten sie „Verwende make &lt;target&gt; …“
  und „Projekt: NAME“. Ist keine dieser Variablen gesetzt, etwa wenn make aus
  einer IDE startet, gilt unter macOS die erste Systemsprache
  (`defaults read -g AppleLanguages`).
- **`showMakeTargets [--set NAME=VALUE]… FILE…`** liest aus den Makefiles
  `##@ Group` und `target: … ## Description`. Server-Targets mit `##R`
  (schreibend) und `##D` (destruktiv) stehen ebenso da, mit Platzhaltern und
  „— Maintainer“, der Target-Name in der Server- bzw. Danger-Farbe des Themes. Eine Beschreibung, die auf
  „— Maintainer“ endet, bekommt die Markierung **[Maintainer]**. `{version}`,
  `{major}`, `{minor}` und `{patch}` zeigen die Projektversion und die Version
  vor und nach jeder Release-Art, etwa „0.6.0 → 0.7.0“; `--set` füllt weitere
  Platzhalter, unbekannte bleiben stehen.
- **`requireMakeSetup --hooks DIR` / `--make MAKE STAMP…`** meldet
  „Nicht eingerichtet“ und `make setup` auf stderr, wenn `core.hooksPath` nicht
  `DIR` ist oder `MAKE -q` die Stempeldateien als veraltet meldet, etwa
  `requireMakeSetup --make "$(MAKE)" .venv/.installed`.
- **`installEditablePackage DIR`** installiert die Arbeitskopie `DIR`
  editierbar mit pipx (`pipx install -e --force DIR`) und meldet
  „✓ BEFEHLE aus DIR“ mit den Befehlen aus `[project.scripts]`. Ohne pipx
  scheitert es mit „pipx fehlt“ und https://pipx.pypa.io, scheitert pipx, mit
  dessen Ausgabe; in beiden Fällen mit Exit 1. Nach einem Update erneut
  aufrufen, denn neue Befehle legt pipx nur beim Installieren an:

  ```makefile
  install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
  	@source "$${BASH_LIBS}/make.lib.sh" && installEditablePackage "$${WORKSPACE}"
  ```

`BASH_ENV` lädt `make.lib.sh` nur in die Rezeptzeilen der Anzeige-Targets.
Bash wertet den Wert von `BASH_ENV` aus, deshalb nennt er `$${BASH_LIBS}`
statt des Pfads selbst. Dateinamen und Werte kommen über die Umgebung ins
Rezept (`$${VAR}`) und werden nur ausgegeben, nie ausgewertet. Die Helfer
brauchen BashLib; ohne `BASH_LIBS` scheitern die Rezeptzeilen mit „command not
found“.

```makefile
SHELL := bash

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
PROJECT_NAME := $(shell basename -- $(WORKSPACE_SQ))
# Values from outside reach recipes only through the environment ("$${VAR}")
export WORKSPACE_SQ PROJECT_NAME
export HELP_FILES = $(value MAKEFILE_LIST)

# make.lib.sh in every recipe line of these targets; Bash expands BASH_ENV,
# so it refers to BASH_LIBS instead of holding the path
help hints: export BASH_ENV := $${BASH_LIBS}/make.lib.sh
# clitheme once for all recipe lines instead of once per line
clitheme_export = $(eval clitheme_export := $$(shell clitheme export --bash 2>/dev/null))$(clitheme_export)
help hints: export CLITHEME_EXPORT = $(clitheme_export)

.PHONY: help
help: ## Show this help
	@showMakeHeader "$${PROJECT_NAME}"
	@showMakeTargets $${HELP_FILES}

.PHONY: hints
hints: ## Commands to copy
	@printMakeHeading "Working copy"
	@printMakeValue   "Install" "pipx install -e $${WORKSPACE_SQ}"
	@echo
```

[↑ Übersicht](#übersicht)

## Farben und Themes

Die Ausgabehelfer nehmen Farben und Abstände von
[CLITheme](https://github.com/MikeMitterer/python-clitheme) (`clitheme export`),
wie Python-Werkzeuge und Makefiles; die Theme-Datei liest nur CLITheme.
`CLI_THEME` wählt das Theme (Standard `classic`); `clitheme install` legt die
Vorlagen an. Ohne clitheme oder Theme-Datei gibt es keine Farben, bei
`NO_COLOR`, in Pipes und bei `TERM=dumb` ebenfalls nicht. Rollen, Abstände
und Rückfallverhalten stehen in [docs/themes.md](docs/themes.md). Das Theme
gibt es ab BashLib 0.4.0; ältere Releases haben die fest eingebauten Themes
mit `MAKE_THEME`. Heute kommt es über `clitheme export` (CLITheme ab 0.5.0).

Ein lauffähiges Beispiel mit Hilfe, Info, Hinweisen, Statuszeilen und
Fehlermeldungen liegt in [examples/](examples/README.md):
`./examples/cli-demo.sh --help`.

[↑ Übersicht](#übersicht)

## Entwicklung

Tests und Ablauf für Änderungen an BashLib stehen in
[docs/development.md](docs/development.md).

[↑ Übersicht](#übersicht)

## Lizenz

Copyright © 2019–2026 Michael Mitterer. **MangoLila GmbH** ist Anbieterin und
Lizenzgeberin.

BashLib steht unter der **[EUPL 1.2](LICENSE)**, nur Version 1.2. Sie erlaubt
private und gewerbliche Nutzung, Änderungen, Weitergabe, Verkauf und Hosting
ohne kostenpflichtige Lizenz.

Wer BashLib oder eine geänderte Fassung weitergibt oder als Netzwerkdienst
anbietet, muss die Urheber- und Lizenzhinweise erhalten, Änderungen
kennzeichnen und den zugehörigen Quelltext nach den Copyleft-Regeln der
Lizenz bereitstellen.

Die Gewährleistungs- und Haftungsausschlüsse der EUPL-Artikel 7 und 8 gelten
auch gegenüber Verbrauchern, soweit das Gesetz es zulässt. Zwingende Rechte
bleiben unberührt, darunter die Haftung für Vorsatz, grobe Fahrlässigkeit,
Personenschäden und nach dem Produkthaftungsgesetz. Eine zusätzliche Garantie
wird nicht übernommen.

Kontakt: **office@MangoLila.at**.

Details: [LICENSE](LICENSE) · [Deutscher Lizenztext](LICENSE.de.txt) ·
[Anbieter- und Verbrauchererklärung](LICENSING.md)
