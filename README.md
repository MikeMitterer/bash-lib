<div align="center">

# BashLib

**Bash-Bibliotheken für eigene Skripte: Ausgabe, Farben, Werkzeuge, Versionen, Docker**

[Voraussetzungen](#voraussetzungen) · [Installation](#installation) ·
[Einbinden](#einbinden) · [Bibliotheken](#bibliotheken) ·
[Lizenz](#lizenz) · [Entwicklung](docs/development.md)

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
  nur 3.2 mit; eine aktuelle Bash kommt mit
  `brew install bash`. Skripte starten mit `#!/usr/bin/env bash`, damit die
  Bash aus dem `PATH` läuft.
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
`pip install -e <Klon>` zeigt es auf `src` des Klons, Änderungen wirken dann
ohne Neuinstallation. `bashlib` zeigt Aufruf, Version und Kurzbeschreibung,
je Befehl des Pakets eine Zeile sowie die Optionen, im gewählten CLI-Theme
([Farben und Themes](#farben-und-themes)); `bashlib --version` gibt nur die
Version aus.

Neue Befehle legt pipx nur beim Installieren an, auch bei `pip install -e`.
Nach einem Update von BashLib deshalb neu installieren:

```bash
make install    # in einem Klon: installiert ihn editierbar mit pipx
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
    echo "BASH_LIBS zeigt nicht auf BashLib/src: '${BASH_LIBS:-}'" >&2
    exit 1
fi
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

printThemeHeading "Optionen"
printThemeRow "-h | --help" "Hilfe anzeigen"
printThemeStatus "✓" "Fertig" SUCCESS
```

`tools.lib.sh` bringt `colors.lib.sh`, `apps.lib.sh`, `dtime.lib.sh` und `version.lib.sh` mit;
für die meisten Skripte genügt diese eine Zeile. Die Wächterzeile jeder
Bibliothek steht in ihrem Dateikopf unter „Einbinden“.

**Ein Skript, das auch ohne BashLib laufen soll**, prüft wie oben, ob
`${BASH_LIBS}/tools.lib.sh` lesbar ist, und gibt sonst einfache Ausgaben aus,
statt abzubrechen.

[↑ Übersicht](#übersicht)

## Bibliotheken

| Bibliothek | Inhalt | Lädt mit |
|---|---|---|
| `tools.lib.sh` | Ausgabehelfer (`printThemeHeading`, `printThemeRow`, `printThemeStatus`, `usageLine`), Version und Release-Tags anzeigen (`showProjectVersion`, `showReleaseTags`), Ports, Zeichenketten | colors, apps, dtime, version |
| `colors.lib.sh` | ANSI-Farben, CLI-Theme und Spaltenlayout | – |
| `make.lib.sh` | Hilfe und Hinweise für Makefiles im CLI-Theme (`showMakeHelp`, `showMakeHints`) | tools |
| `apps.lib.sh` | Pfade der verwendeten Werkzeuge, `checkIfToolIsAvailable` | logging, os |
| `logging.lib.sh` | Logging für Skripte | – |
| `os.lib.sh` | Betriebssystem erkennen | – |
| `dtime.lib.sh` | Datum und Uhrzeit | os |
| `fs.lib.sh` | Datei- und Verzeichnisfunktionen | – |
| `net.lib.sh` | IP- und Netzfunktionen | os |
| `docker.lib.sh` | Docker-Images bauen und pushen (Docker Hub, GHCR, ECR) | colors |
| `version.lib.sh` | Versionen lesen und erhöhen, taggen (`semVerBump`), nächste Version ohne Schreiben (`semVerNext`), Release-Tag eines Commits (`gitReleaseTag`), Release-Tags als Liste (`gitListReleaseTags`) | – |
| `build.lib.sh` | Hilfen für Build-Skripte | apps, tools |
| `styles.lib.sh` | Global definierte Ausgabestile | colors |
| `assert.lib.sh` | Asserts für Bash-Tests (`assertEquals`, `assertContains`, `assertNotContains`, `finishTests`, `checkStatus`); ersetzt das frühere `test.lib.sh` | – |
| `samples.lib.sh` | Dart-Beispiele veröffentlichen | tools |
| `webapp.lib.sh` | Node- und TypeScript-Apps veröffentlichen | colors, fs |

[↑ Übersicht](#übersicht)

## Hilfe und Hinweise in Makefiles

`make.lib.sh` gibt `make help` und `make hints` im CLI-Theme aus, in denselben
Spalten wie die Hilfe eines Skripts:

- **`showMakeHelp [--set NAME=WERT]… DATEI…`** liest aus den Makefiles
  `##@ Gruppe` und `target: … ## Beschreibung`. Eine Beschreibung, die auf
  „— Maintainer“ endet, bekommt die Markierung **[Maintainer]**; `{NAME}`
  ersetzt der Wert aus `--set`, unbekannte Platzhalter bleiben stehen.
- **`showMakeHints`** liest von stdin: `## Titel` wird Überschrift,
  `Beschriftung<TAB>Wert` eine Zeile, deren Wert nie umbricht.

Dateinamen und Werte kommen über die Umgebung ins Rezept (`$${VAR}`) und werden
nur ausgegeben, nie ausgewertet. Ohne BashLib zeigt das Makefile eine schlichte
Liste:

```makefile
SHELL := bash

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
# Werte von außen nur über die Umgebung in Rezepte geben ("$${VAR}")
export WORKSPACE_SQ
export HELP_FILES = $(value MAKEFILE_LIST)

.PHONY: help
help: ## Hilfe anzeigen
	@if [[ -r "$${BASH_LIBS:-}/make.lib.sh" ]]; then \
		source "$${BASH_LIBS}/make.lib.sh" && showMakeHelp $${HELP_FILES}; \
	else grep -hE '^[a-zA-Z0-9_-]+:.*## ' $${HELP_FILES}; fi

.PHONY: hints
hints: ## Befehle zum Kopieren
	@rows() { printf '## %s\n' 'Arbeitskopie'; \
		printf '%s\t%s\n' 'Installieren' "pipx install -e $${WORKSPACE_SQ}"; }; \
	if [[ -r "$${BASH_LIBS:-}/make.lib.sh" ]]; then \
		source "$${BASH_LIBS}/make.lib.sh" && rows | showMakeHints; \
	else rows | expand -t 24; fi
```

[↑ Übersicht](#übersicht)

## Farben und Themes

Die Ausgabehelfer nehmen Farben und Abstände von
[CLITheme](https://github.com/MikeMitterer/python-clitheme) (`clitheme export`),
wie Python-Werkzeuge und Makefiles; die Theme-Datei liest nur CLITheme.
`CLI_THEME` wählt das Theme (Standard `classic`); `clitheme install` legt die
Vorlagen an. Ohne clitheme oder Theme-Datei gibt es keine Farben, bei
`NO_COLOR`, in Pipes und bei `TERM=dumb` ebenfalls nicht.
Rollen, Abstände und Rückfallverhalten stehen in [docs/themes.md](docs/themes.md).
Das Theme gibt es ab BashLib 0.4.0; ältere Releases haben die fest
eingebauten Themes mit `MAKE_THEME`. Heute kommt es über
`clitheme export` (CLITheme ab 0.5.0).

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
