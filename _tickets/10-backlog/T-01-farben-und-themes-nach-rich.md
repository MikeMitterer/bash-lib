# T-01 · Farben und Themes nach dem Vorbild von rich

**Warum dieses Ticket:** Mike, 2026-10-04, in AgentLessons (T-66, Punkt 9):
„(a) - rich nehmen, dann gehen wir schlussendlich den umgekehrten Weg für die
hausinternen Scripte mit colors.mk und colors.sh - wir bilden ‚rich‘, für die
Farben und Themes, nach“. AgentLessons gibt seit T-67 über das PyPI-Paket
`rich` (und `rich-argparse` für die Hilfe) aus. Damit alle Hauswerkzeuge gleich
aussehen, folgen die Bash- und Make-Ausgaben künftig diesem Modell, nicht
umgekehrt.

**Grundsatz (Mike, 2026-10-04):** „der Unterschied bei den Makefile und
Bash-Scripten soll sein, dass die Farben anpassbar bleiben aber sonst richten
sich dann die Änderungen an rich bzw. agent-lessons aus.“ Also: **Farben
bleiben anpassbar; Stilnamen, Layout, Abschaltregeln und Hilfeformat richten
sich nach rich bzw. AgentLessons.**

**Ziel (Mike, 2026-10-04):** „Das Layout bei Bash und Makefiles richtet sich
auch nach rich + agent-lesson. Ich möchte dass die ganzen cmdline-Geschichten
gleich oder zumindest sehr ähnlich aussehen.“ Maßstab für jede Änderung:
Eine Ausgabe oder Hilfe von BashLib, MakeLib und AgentLessons nebeneinander
gelegt sieht gleich aus, abgesehen von bewusst angepassten Farben.

## Konventionen, an denen sich BashLib und MakeLib ausrichten

Referenz ist AgentLessons ab T-67: `agent_lessons/cli/output.py`
(`Output`, `help_formatter`) und `theme` in den Startwerten
`agent_lessons/resources/defaults/settings.yaml`.

### Benannte Stile statt Farbnummern

Ausgabefunktionen sprechen nur benannte Stile an, nie direkt eine Farbe:

| Stil | Verwendung | Standard (rich-Schreibweise) |
|---|---|---|
| `group` | Gruppenüberschrift | `bold yellow` |
| `label` | Bezeichnung in der linken Spalte, Optionsnamen in der Hilfe | `blue` |
| `value` | Wert in der rechten Spalte, Metavariable in der Hilfe | `green` |
| `muted` | eingerückter Fließtext, Hinweise | `dim` |
| `danger` | Fehlermeldung (auf stderr) | `bold red` |

- Stilangaben folgen der Schreibweise von rich: Attribute und Farbname in
  beliebiger Reihenfolge, etwa `bold yellow`, `dim`, `red on black`,
  `#ff8800`, `color(208)`. BashLib übersetzt sie in ANSI-Codes.
- Die vorhandenen `ANSI_COLOR_*`-Werte bleiben als Farbpalette erhalten; sie
  sind Bausteine, keine Stile.

### Anpassbare Farben (der einzige gewollte Unterschied)

- Jeder Stil ist einzeln überschreibbar, etwa über `THEME_GROUP`,
  `THEME_LABEL`, `THEME_VALUE`, `THEME_MUTED`, `THEME_DANGER` (Werte in
  rich-Schreibweise).
- Benannte Themes (heute `MAKE_THEME`) bleiben möglich und liefern nur eine
  andere Zuordnung derselben fünf Stile.
- Ein ungültiger Stilwert fällt auf den Standard zurück; die Ausgabe scheitert
  nie an der Farbkonfiguration.

### Layout wie in AgentLessons

- Gruppenüberschrift mit 2 Leerzeichen Einrückung.
- Zeilen „Bezeichnung · Wert“: 7 Leerzeichen Einrückung, Bezeichnungsspalte
  23 Zeichen breit. Ist die Bezeichnung zu lang, steht der Wert in der
  nächsten Zeile ab Spalte 30.
- Fließtext mit 7 Leerzeichen Einrückung, Zeile für Zeile.
- Genau **eine Leerzeile zwischen Gruppen**, keine vor der ersten.
- Lange Werte (etwa absolute Pfade) werden weder umbrochen noch gekürzt.
- Keine Symbole (`▶ ✓ ✗ ⚠ ℹ →`) in Ausgaben.
- Fehlermeldungen auf stderr im Stil `danger`.

### Farbe abschalten

Keine Escape-Codes, also auch kein Fettdruck, wenn

- `NO_COLOR` gesetzt ist, **auch mit leerem Wert**,
- `TERM=dumb` gilt oder
- die Ausgabe nicht an ein Terminal geht (Pipe, Datei).

### Hilfeformat

- Kurz- und Langform in einer festen Spalte: `-i | --info`. Ohne Kurzform
  bleibt der Platz frei (fünf Leerzeichen, dann `--restore DATEI`).
- Metavariable direkt dahinter, im Stil `value`; Optionsnamen im Stil `label`;
  Gruppennamen im Stil `group`, gefolgt von einem Doppelpunkt.
- Beispiele am Ende als eigener Block „Beispiele:“ mit eingerückten Aufrufen.

## Umfang (noch zu planen)

- `src/colors.lib.sh`: die fünf Stile mit Standardwerten, Übersetzung der
  rich-Schreibweise in ANSI, Überschreiben über `THEME_*`, Abschaltregeln.
- Ausgabehelfer (heute `printTheme` u. a.) auf das Layout oben umstellen:
  Gruppe, Zeile, Text, Fehler.
- `usageLine` bzw. die Hilfeausgabe auf das Hilfeformat oben umstellen.
- MakeLib (`colors.mk`, Make-Themes, Help-Target) auf dieselben Stilnamen und
  dasselbe Layout; dort eigener Auftrag.
- Eine Übersicht der Themes so ablegen, dass Bash, Make und das `theme` in
  AgentLessons dieselben Werte verwenden können.

**Stand:** Backlog, 2026-10-04. Nur festgehalten, nicht begonnen.
