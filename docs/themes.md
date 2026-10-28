<!-- Teil der BashLib-Doku; Überblick im README -->
# CLI-Themes und Abstände

Die drei eigenständigen Dateien MakeLib `colours.mk`, BashLib
`src/colors.lib.sh` und ProjectTools `colors.py` verwenden dieselbe
Palette und Theme-Auswahl: `classic` (Standard), `ocean`, `earth`, `night`,
`mono`, `sunset`, `forest`, `neon`, `shell`. Ein unbekannter Name verwendet
`classic`. Die Auswahl kann wie bisher in der jeweiligen Datei umgestellt
oder mit `MAKE_THEME` überschrieben werden. Es gibt keine generierte Datei.
Make exportiert die Auswahl und Layout-Werte an seine Kindprozesse.

```bash
MAKE_THEME=ocean ./mein-skript.sh --help
```

| Einstellung | Vorgabe | Bedeutung |
|---|---|---|
| `THEME_INDENT_GROUP` | zwei Leerzeichen | Gruppenüberschrift |
| `THEME_INDENT_TARGET` | sieben Leerzeichen | Target oder Option |
| `THEME_WIDTH_TARGET` | `22` | Breite der ersten Spalte |
| `THEME_COLUMN_GAP` | `1` | Mindestabstand zur Beschreibung |
| `THEME_WIDTH_HELP` | `110` | Python-Hilfe: gesamte Textbreite |
| `THEME_GROUP_SPACING` | `1` | Leerzeilen zwischen Gruppen |

Mit diesen Vorgaben beginnt die Beschreibung in Spalte 31. Lange Beschriftungen
stehen bei `usageLine`/`themeLine` und der Python-Hilfe auf einer eigenen Zeile.
Python bricht lange Beschreibungen an der Gesamtbreite um; Bash und Make
geben Beschreibungstexte wie bisher unverändert aus. Einrückungen sind weiterhin
**Leerzeichenketten**, Breiten und Abstände nichtnegative Zahlen. Einzelne
Werte vor dem Include/Source beziehungsweise per Umgebung überschreiben.

`THEME_COLOR_GROUP`, `TARGET`, `DESC`, `SERVER`, `DANGER` (jeweils mit dem Präfix
`THEME_COLOR_`) behalten ihre Namen. Hinzu kommen `THEME_COLOR_SUCCESS` und
`THEME_COLOR_WARNING`. Grundfarben und die bisherigen öffentlichen Makros,
Bash-Funktionen und Argumente bleiben verfügbar. Die Standarddarstellung der
Ausgabehelfer folgt jetzt dem gemeinsamen Theme.

Die neuen Bash-/Python-Helfer geben in Pipes, bei `NO_COLOR` und `TERM=dumb`
keine ANSI-Farben aus. Make berücksichtigt `NO_COLOR` und behält seine bisherige
TERM-basierte Farberkennung. Bash-Grundkonstanten bleiben aus Kompatibilität
unveränderte Escape-Strings für `printf '%b'` oder `echo -e`.

Bash-Ausgabehelfer:

```bash
if [[ "${__TOOLS_LIB__:=}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi
printThemeHeading "Werkzeuge"
printThemeRow "--help" "Hilfe anzeigen"
printThemeStatus "✓" "Fertig" SUCCESS
```

`usageLine LABEL TEXT [no|yes|intend|ZAHL]` bleibt gültig. `yes`/`intend`
rücken die Beschreibung um vier weitere Leerzeichen ein. Bereits eingebettete
Farbcodes in bestehenden Texten bleiben am Terminal erhalten.

`printThemeHeading TEXT`, `printThemeRow LABEL TEXT [EINRÜCKUNG]` und
`printThemeStatus SYMBOL TEXT FARBROLLE` stehen zentral in `tools.lib.sh`.
Skripte verwenden diese Helfer ohne eigene Kopien. Die bisherigen
`themeHeading`-/`themeLine`-Funktionen bleiben verfügbar.

Zurück zum [README](../README.md).
