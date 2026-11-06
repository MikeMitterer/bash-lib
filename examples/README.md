<!-- Teil der BashLib-Doku; Überblick im README -->
# Beispiel: Kommandozeile mit CLI-Theme

**`cli-demo.sh` zeigt, wie ein Skript mit BashLib Hilfe, Info, Hinweise,
Statuszeilen und Fehlermeldungen ausgibt.** Farben und Abstände kommen von
clitheme ([CLI-Themes und Abstände](../docs/themes.md)). Das
Skript ändert nichts, es gibt nur aus. Es eignet sich als Vorlage und als
schneller Test, ob Theme und Bibliotheken zusammenspielen.

```bash
export BASH_LIBS=/pfad/zu/BashLib/src
./examples/cli-demo.sh --help
```

## Befehle und was du siehst

| Aufruf | Ergebnis |
|---|---|
| `cli-demo.sh`, `-h`, `--help` | Hilfe: Befehle, Umgebung und Beispiele in zwei Spalten; lange Beschriftungen stehen in eigener Zeile; Platzhalter und Werte wie `NAME` oder `classic` sind mit `themeAccent` hervorgehoben (Rolle `C_ACC`) |
| `cli-demo.sh info` | Version, Pfade, gewähltes Theme mit Herkunft (`themeMark`, Rolle `C_MARK`), Ort der Theme-Datei und ob Farben an sind; Werte in `C_VAL` (`printThemeValue`), darunter ein Hinweis in `C_HINT` (`printThemeHint`) |
| `cli-demo.sh hints` | Nächste Schritte; jeder Befehl steht in `C_VAL` für sich und lässt sich kopieren |
| `cli-demo.sh status` | Je eine Statuszeile für Erfolg (`C_OK`), Warnung (`C_WARN`) und Fehler (`C_ERR`) |
| `cli-demo.sh theme` | Jede Farbrolle in ihrer Farbe mit ihrer `THEME_COLOR_*`-Variable, dazu die Abstände; `THEME_WIDTH_HELP` gilt nur für Python-Werkzeuge, BashLib bricht nicht um |
| `cli-demo.sh greet NAME` | Statuszeile „Hallo NAME“ |
| `cli-demo.sh greet` | Fehler auf stderr: „Fehlende Angabe: NAME“, darunter der Befehl `cli-demo.sh greet NAME`; Exit 2 |
| `cli-demo.sh --foo`, `cli-demo.sh bla` | Fehler auf stderr: unbekannte Option bzw. unbekannter Befehl, darunter `cli-demo.sh --help`; Exit 2 |

Ohne `BASH_LIBS` bricht das Skript mit einer Meldung und Exit 1 ab.

## Theme und Farben prüfen

```bash
CLI_THEME=ocean ./examples/cli-demo.sh theme   # anderes Theme
NO_COLOR=1 ./examples/cli-demo.sh hints         # ohne Farben, gleiche Spalten
./examples/cli-demo.sh hints | cat              # Pipe: ohne Farben
```

- **Farben** erscheinen nur am Terminal, nicht in einer Pipe, mit `NO_COLOR`
  oder bei `TERM=dumb`. `info` nennt den Grund in der Zeile „Farben“.
- **Fehlen clitheme oder die Theme-Datei**, ist die Ausgabe farblos mit den
  Abständen von classic; am Terminal steht einmal ein Hinweis mit dem nächsten
  Schritt, etwa `clitheme install`.
- **Spalten**: Mit classic beginnt die Beschreibung in Spalte 31. Ein Theme
  mit anderen Abständen verschiebt sie; `theme` zeigt die Werte.

`test/_testExamples.sh` ruft jeden Befehl auf und prüft Exit-Codes,
Kernzeilen, Spalten und die Farben am Pseudoterminal; so bleibt das Beispiel
aktuell.

Zurück zum [README](../README.de.md).
