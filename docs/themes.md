<!-- Teil der BashLib-Doku; Überblick im README -->
# CLI-Themes und Abstände

**Die Theme-Helfer lesen Farben und Abstände aus der Theme-Datei von
[CLITheme](https://github.com/MikeMitterer/python-clitheme).** Python-Werkzeuge
und Makefiles verwenden dieselbe Datei. Skripte binden wie bisher
`colors.lib.sh` oder `tools.lib.sh` ein; ein zusätzliches Modul gibt es nicht.

```bash
if [[ "${__TOOLS_LIB__:=}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
printThemeHeading "Werkzeuge"
printThemeRow "--help" "Hilfe anzeigen"
printThemeStatus "✓" "Fertig" OK
```

```bash
CLI_THEME=ocean ./mein-skript.sh --help
```

## Theme-Datei

**Ort:** `${XDG_CONFIG_HOME:-~/.config}/cli-theme/<name>.theme`. `CLI_THEME`
wählt den Namen (Standard `classic`; Buchstaben, Ziffern, `-` und `_`).
`MAKE_THEME` gilt als veralteter Ersatzname, wenn `CLI_THEME` fehlt.
`cli-theme install` legt die mitgelieferten Vorlagen an, `cli-theme show` zeigt
das gewählte Theme. Format und Rollen beschreibt das README von CLITheme.

`colors.lib.sh` liest die Datei beim Einbinden einmal, Zeile für Zeile nach
den Regeln von CLITheme, und bindet sie nie mit `source` ein. Danach stehen
bereit:

- **Rollen** `C_HEAD`, `C_KEY`, `C_TEXT`, `C_VAL`, `C_HINT`, `C_ACC`, `C_OK`,
  `C_WARN`, `C_ERR`, `C_MARK` mit dem Wert aus der Datei, etwa `bold+11`;
  `C_OFF` beendet eine Farbe.
- **Abstände** `I_HEAD`, `I_ROW`, `I_HINT`, `W_KEY`, `GAP`, `WIDTH`, `SPACE`
  als Zahl.
- **`THEME_NAME`**, **`THEME_SOURCE`** und **`THEME_ORIGIN`**: Name des gewählten
  Themes, Pfad seiner Datei und woher die Wahl kommt (`CLI_THEME`, `MAKE_THEME`
  oder `Standard`), etwa für eine Info-Ausgabe.

**Ohne gültige Datei:** keine Farben, die Abstände der classic-Vorlage. Das
gilt für eine fehlende Datei, einen ungültigen Eintrag, fehlende Einträge,
einen ungültigen `CLI_THEME` und für Links oder Nicht-Dateien. Bei der ersten
Theme-Ausgabe am Terminal steht einmal ein Hinweis auf stderr, etwa:

```text
  ⚠ CLI-Theme fehlt (/home/mike/.config/cli-theme/classic.theme)
       cli-theme install
```

## THEME_*-Variablen

Die bisherigen Variablen bleiben und werden aus den Rollen gesetzt. Werte, die
das Skript selbst vor dem Einbinden setzt, gewinnen. Geerbte, exportierte Werte
zählen nicht: MakeLib exportiert seine `THEME_*`-Werte an jedes Rezept, und ein
Skript, das aus make startet, zeigt trotzdem das gewählte Theme. Ein anderes
Theme für einen Aufruf wählt `CLI_THEME`.

| Variable | Rolle | Variable | Abstand |
|---|---|---|---|
| `THEME_COLOR_GROUP` | `C_HEAD` | `THEME_INDENT_GROUP` | `I_HEAD` Leerzeichen |
| `THEME_COLOR_TARGET` | `C_KEY` | `THEME_INDENT_TARGET` | `I_ROW` Leerzeichen |
| `THEME_COLOR_DESC` | `C_TEXT` | `THEME_INDENT_HINT` | `I_HINT` Leerzeichen |
| `THEME_COLOR_VALUE` | `C_VAL` | `THEME_WIDTH_TARGET` | `W_KEY` |
| `THEME_COLOR_HINT` | `C_HINT` | `THEME_COLUMN_GAP` | `GAP` |
| `THEME_COLOR_ACCENT` | `C_ACC` | `THEME_WIDTH_HELP` | `WIDTH` |
| `THEME_COLOR_SUCCESS` | `C_OK` | `THEME_GROUP_SPACING` | `SPACE` |
| `THEME_COLOR_WARNING` | `C_WARN` | | |
| `THEME_COLOR_DANGER` | `C_ERR` | | |
| `THEME_COLOR_SERVER` | `C_MARK` | | |

Die `THEME_COLOR_*`-Werte sind Escape-Strings für `printf '%b'` wie die
Palette. Mit classic beginnt die Beschreibung wie bisher in Spalte 31.

## Ausgabehelfer

`printThemeHeading TEXT`, `printThemeRow LABEL TEXT [EINRÜCKUNG]` und
`printThemeStatus SYMBOL TEXT ROLLE` stehen in `tools.lib.sh`. Als Rolle nimmt
`printThemeStatus` `OK`, `WARN`, `ERR` oder die bisherigen Namen `SUCCESS`,
`WARNING`, `DANGER` und jede andere `THEME_COLOR_*`-Endung.

Für die übrigen Rollen gibt es eigene Helfer; ohne Farben bleibt jeweils nur
der Text in denselben Spalten:

| Helfer | Rolle | Wofür |
|---|---|---|
| `printThemeValue LABEL WERT` | `C_VAL` | Zeile mit Wert, Befehl oder Pfad rechts |
| `printThemeHint TEXT` | `C_HINT`, Einrückung `I_HINT` | Hinweistext in eigener Zeile |
| `themeAccent TEXT [FARBE]` | `C_ACC` | Hervorhebung in einer Beschreibung: Platzhalter, zulässige Werte |
| `themeMark TEXT [FARBE]` | `C_MARK` | Markierung: Maintainer, Server, Herkunft eines Werts |

`themeAccent` und `themeMark` liefern ein Stück Text zum Einbetten und kehren
danach zur Farbe `FARBE` zurück, ohne Angabe zur Farbe der Beschreibung. In
einer Wertzeile gibt man `THEME_COLOR_VALUE` mit:

```bash
printThemeRow "greet NAME" "Begrüßt $(themeAccent NAME)"
printThemeValue "Theme" "${THEME_NAME} $(themeMark "(aus ${THEME_ORIGIN})" "${THEME_COLOR_VALUE}")"
printThemeHint "Jeder Befehl steht für sich und lässt sich kopieren."
```

`usageLine LABEL TEXT [no|yes|intend|ZAHL]` bleibt gültig. `yes`/`intend`
rücken die Beschreibung um vier weitere Leerzeichen ein. Eingebettete
Farbcodes in bestehenden Texten bleiben am Terminal erhalten.

Bewusst wie bisher: eine Leerzeile auch vor der ersten Überschrift und keine
Zeilenumbrüche bei `WIDTH`.

## Farben am Terminal

Die Theme-Helfer färben nur am Terminal, nicht in Pipes, bei `NO_COLOR` und
bei `TERM=dumb`. Die Palette (`RED`, `GREEN`, `NC`, `BOLD`, `GREP_COLOR_*` …)
bleibt unverändert und folgt keinem Theme.

Zurück zum [README](../README.md).
