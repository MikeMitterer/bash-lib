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
- [Farben und Themes](#farben-und-themes)
- [Entwicklung](#entwicklung)
- [Lizenz](#lizenz)

## Voraussetzungen

- **Bash ab 4.3.** macOS bringt Bash 3.2 mit; eine aktuelle Bash kommt mit
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

`tools.lib.sh` bringt `colors.lib.sh`, `apps.lib.sh` und `dtime.lib.sh` mit;
für die meisten Skripte genügt diese eine Zeile. Die Wächterzeile jeder
Bibliothek steht in ihrem Dateikopf unter „Einbinden“.

**Ein Skript, das auch ohne BashLib laufen soll**, prüft wie oben, ob
`${BASH_LIBS}/tools.lib.sh` lesbar ist, und gibt sonst einfache Ausgaben aus,
statt abzubrechen.

[↑ Übersicht](#übersicht)

## Bibliotheken

| Bibliothek | Inhalt | Lädt mit |
|---|---|---|
| `tools.lib.sh` | Ausgabehelfer (`printThemeHeading`, `printThemeRow`, `printThemeStatus`, `usageLine`), Ports, Zeichenketten | colors, apps, dtime |
| `colors.lib.sh` | ANSI-Farben, Themes und Spaltenlayout | – |
| `apps.lib.sh` | Pfade der verwendeten Werkzeuge, `checkIfToolIsAvailable` | logging, os |
| `logging.lib.sh` | Logging für Skripte | – |
| `os.lib.sh` | Betriebssystem erkennen | – |
| `dtime.lib.sh` | Datum und Uhrzeit | os |
| `fs.lib.sh` | Datei- und Verzeichnisfunktionen | – |
| `net.lib.sh` | IP- und Netzfunktionen | os |
| `docker.lib.sh` | Docker-Images bauen und pushen (Docker Hub, GHCR, ECR) | colors |
| `version.lib.sh` | Versionen lesen und erhöhen, taggen (`semVerBump`) | – |
| `build.lib.sh` | Hilfen für Build-Skripte | apps, tools |
| `styles.lib.sh` | Global definierte Ausgabestile | colors |
| `test.lib.sh` | Funktionen für Skripttests | – |
| `samples.lib.sh` | Dart-Beispiele veröffentlichen | tools |
| `webapp.lib.sh` | Node- und TypeScript-Apps veröffentlichen | colors, fs |

[↑ Übersicht](#übersicht)

## Farben und Themes

Die Ausgabehelfer folgen einem gemeinsamen Theme, das auch MakeLib und
ProjectTools verwenden. `MAKE_THEME` wählt es (`classic`, `ocean`, `earth`,
`night`, `mono`, `sunset`, `forest`, `neon`, `shell`); bei `NO_COLOR`, in
Pipes und bei `TERM=dumb` gibt es keine Farben. Layoutwerte und Farbrollen
stehen in [docs/themes.md](docs/themes.md).

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
