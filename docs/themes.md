<!-- Teil der BashLib-Doku; Überblick im README -->
# CLI-Themes und Abstände

**Die Theme-Helfer nehmen Farben und Abstände von
[CLITheme](https://github.com/MikeMitterer/python-clitheme) (Befehl `clitheme`,
ab 0.5.0).** Python-Werkzeuge, Makefiles und Bash-Skripte zeigen damit dasselbe
Theme; die Theme-Datei liest nur CLITheme. Skripte binden wie bisher
`tools.lib.sh` ein, das `cli.lib.sh` mitbringt; wer nur die Ausgabe braucht,
bindet `cli.lib.sh` allein ein.

```bash
if [[ "${__TOOLS_LIB__:=}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
printThemeHeading "Werkzeuge"
printThemeRow "--help" "Hilfe anzeigen"
printThemeStatus "✓" "Fertig" OK
```

```bash
CLI_THEME=ocean ./mein-skript.sh --help
```

## Theme von clitheme

`cli.lib.sh` ruft beim Einbinden einmal `clitheme export --bash` auf.
clitheme liest das gewählte Theme (`CLI_THEME`, Standard `classic`; Datei unter
`${XDG_CONFIG_HOME:-~/.config}/clitheme/`), prüft es und gibt die aufgelösten
Werte gequotet aus. `cli.lib.sh` übernimmt sie ohne `eval` (`themeImport`): Es
setzt nur die unten genannten `THEME_*`-Variablen, andere Namen (etwa eine neue
Rolle einer späteren clitheme-Fassung) bleiben ungesetzt. Farben gelten nur als
SGR-Folge, Abstände nur als Zahl; passt ein Wert nicht oder fehlt einer, gibt es
keine Farben und den Hinweis unten. `clitheme install` legt
die mitgelieferten Vorlagen an, `clitheme show` zeigt das gewählte Theme.
Format, Rollen und Fehlerfälle der Theme-Datei beschreibt das README von
CLITheme.

**Einmal je make-Lauf:** Lädt ein Makefile `make.lib.sh` über `BASH_ENV` in
jede Rezeptzeile, startet sonst jede Zeile clitheme. Gibt das Makefile die
Ausgabe von `clitheme export --bash` in `CLITHEME_EXPORT` mit (Beispiel im
README und in `make.lib.sh`), übernimmt `cli.lib.sh` sie mit derselben Prüfung
und ruft clitheme nicht auf. So startet clitheme je make-Lauf einmal, mit Make
ab 4.4 zweimal (es gibt `BASH_ENV` auch an `$(shell)` weiter), unabhängig von
der Zahl der Zeilen. Trägt sie einen Befund in `THEME_NOTICE`, gilt sie
nicht, und `cli.lib.sh` fragt clitheme selbst. Ein anderes `CLI_THEME` oder eine
geänderte Theme-Datei gilt beim nächsten make-Lauf.

Danach stehen bereit:

- **Farben** `THEME_COLOR_*` als Escape-Text (`\x1B[…m`) wie die Palette, für
  die Theme-Helfer; `C_OFF` beendet eine Farbe.
- **Abstände** `THEME_INDENT_*` als Leerzeichen, `THEME_WIDTH_TARGET`,
  `THEME_COLUMN_GAP`, `THEME_WIDTH_HELP` und `THEME_GROUP_SPACING` als Zahl.
- **`THEME_NAME`**, **`THEME_SOURCE`** und **`THEME_ORIGIN`**: Name des gewählten
  Themes, Pfad seiner Datei und woher die Wahl kommt (`CLI_THEME` oder
  `default`), etwa für eine Info-Ausgabe.

**Ohne clitheme** (nicht installiert oder Aufruf gescheitert): keine Farben,
die Abstände von classic. Findet clitheme keine gültige Theme-Datei, liefert es
selbst keine Farben und einen Befund. Bei der ersten Theme-Ausgabe am Terminal
steht der Hinweis einmal auf stderr, etwa:

```text
  ⚠ clitheme fehlt, Ausgabe ohne Farben
       pipx install git+https://github.com/MikeMitterer/python-clitheme.git
```

Ist clitheme installiert, scheitert aber, lautet der Hinweis „clitheme export
gescheitert, Ausgabe ohne Farben“, und die zweite Zeile nennt
`clitheme export --bash`; der Aufruf zeigt den Grund.

Bis BashLib 0.5 las `colors.lib.sh` die Datei unter `cli-theme/` selbst und
setzte die Rollen `C_HEAD` … und Abstände `W_KEY` …; `MAKE_THEME` galt als
Ersatzname. Diese Variablen gibt es nicht mehr.

## THEME_*-Variablen

Werte, die das Skript selbst vor dem Einbinden setzt, gewinnen. Geerbte,
exportierte Werte zählen nicht: Ein Makefile, das seine `THEME_*`-Werte an jedes
Rezept exportiert, ändert das Theme eines Skripts nicht. Ein anderes Theme für
einen Aufruf wählt `CLI_THEME`.

| Variable | Rolle in CLITheme | Variable | Abstand |
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
`printThemeStatus SYMBOL TEXT ROLLE` stehen in `cli.lib.sh`. Als Rolle nimmt
`printThemeStatus` `OK`, `WARN`, `ERR` oder die bisherigen Namen `SUCCESS`,
`WARNING`, `DANGER` und jede andere `THEME_COLOR_*`-Endung.

Für die übrigen Rollen gibt es eigene Helfer; ohne Farben bleibt jeweils nur
der Text in denselben Spalten:

| Helfer | Rolle | Wofür |
|---|---|---|
| `printThemeValue LABEL WERT` | `C_VAL` | Zeile mit Wert, Befehl oder Pfad rechts |
| `printThemeOption KURZ LANG [METAVARIABLE] TEXT` | `C_KEY`, Metavariable `C_ACC` | Option der Hilfe; Kurzform-Spalte reserviert, Langformen bündig |
| `printThemeExample AUFRUF TEXT` | `C_KEY` | Beispielaufruf; ein langer Aufruf steht in eigener Zeile, der Text darunter |
| `printThemeHint TEXT` | `C_HINT`, Einrückung `I_HINT` | Hinweistext in eigener Zeile |
| `themeAccent TEXT [FARBE]` | `C_ACC` | Hervorhebung in einer Beschreibung: Platzhalter, zulässige Werte |
| `themeMark TEXT [FARBE]` | `C_MARK` | Markierung: Server, Herkunft eines Werts |
| `themeEscape TEXT` | – | Backslashes verdoppeln, damit Text von außen (Pfade, Werte) über die Helfer wörtlich erscheint |

`themeAccent` und `themeMark` liefern ein Stück Text zum Einbetten und kehren
danach zur Farbe `FARBE` zurück, ohne Angabe zur Farbe der Beschreibung. In
einer Wertzeile gibt man `THEME_COLOR_VALUE` mit:

```bash
printThemeRow "greet NAME" "Begrüßt $(themeAccent NAME)"
printThemeValue "Theme" "${THEME_NAME} $(themeMark "(aus ${THEME_ORIGIN})" "${THEME_COLOR_VALUE}")"
printThemeHint "Jeder Befehl steht für sich und lässt sich kopieren."
```

**Das Ergebnis enthält Escape-Text** (`\x1B[…m`). Es gehört nur an die
Theme-Helfer oben oder an `themeStyle TEXT FARBE`; die setzen ihn am Terminal
um und entfernen ihn in Pipes und mit `NO_COLOR`. Mit `echo` oder `printf`
steht er roh in der Ausgabe. `printf '%b'` hilft nicht, weil es auch in einer
Pipe färbt. Für eine eigene Zeile außerhalb der Helfer:

```bash
themeStyle "Fertig: $(themeAccent 3) Dateien" "${THEME_COLOR_DESC}"; echo
```

Eine Hilfe mit Optionen und Beispielen; ohne Kurzform bleibt ihr Platz frei,
die Langformen stehen bündig untereinander:

```bash
printThemeHeading "Optionen"
printThemeOption -i --info "Einstellungen anzeigen"
printThemeOption "" --restore DATEI "Sicherung zurückspielen"
printThemeHeading "Beispiele"
printThemeExample "demo --restore backup.tar" "Sicherung zurückspielen"
```

```text
  Optionen
       -i | --info            Einstellungen anzeigen
            --restore DATEI   Sicherung zurückspielen

  Beispiele
       demo --restore backup.tar
                              Sicherung zurückspielen
```

`usageLine LABEL TEXT [no|yes|intend|ZAHL]` bleibt gültig. `yes`/`intend`
rücken die Beschreibung um vier weitere Leerzeichen ein. Eingebettete
Farbcodes in bestehenden Texten bleiben am Terminal erhalten.

Bewusst wie bisher: eine Leerzeile auch vor der ersten Überschrift und keine
Zeilenumbrüche bei `THEME_WIDTH_HELP`.

## Farben am Terminal

Die Theme-Helfer färben nur am Terminal, nicht in Pipes, bei `NO_COLOR` und
bei `TERM=dumb`. Die Palette (`RED`, `GREEN`, `NC`, `BOLD`, `GREP_COLOR_*` …)
bleibt unverändert und folgt keinem Theme.

Zurück zum [README](../README.de.md).
