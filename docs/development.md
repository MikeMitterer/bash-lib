# Entwicklung

**Für alle, die an BashLib selbst arbeiten.** Wie man die Bibliotheken nutzt,
steht im [README](../README.md).

## Voraussetzungen

- Bash ab 4.3 und Git.
- [ProjectTools](https://github.com/MikeMitterer/bash-ProjectTools) per pipx
  für `make docs-check`, `make test`, `make status` und `make changelog`. Den
  verlangten Release-Tag nennt `.dev-tools.conf.sh`, den Installationsbefehl
  `make hints`. Fehlt ProjectTools oder ist es zu alt, brechen diese Targets
  mit dem Befehl ab.
- Optional [MakeLib](https://github.com/MikeMitterer/make-lib) mit `DEV_MAKE`
  auf deren `src`: Das Makefile nimmt dann deren Farben und Themes, sonst
  erscheint die Ausgabe ohne Farben.

## Einrichten und Testen

```bash
make setup
make check
```

`make setup` aktiviert die Git-Hooks aus `.githooks`: pre-commit prüft die
Doku des vorgemerkten Stands mit `make docs-check`, post-commit ruft einen
lokalen Hook aus `.git/hooks/post-commit` weiter auf, falls es einen gibt.
Ohne Probleme bleiben beide still; Probleme der Doku und Fehler des lokalen
Hooks erscheinen vollständig. Danach legt `make setup` mit `cli-theme install`
fehlende CLI-Theme-Dateien an, die `colors.lib.sh` liest; vorhandene bleiben
unverändert. Fehlt CLITheme oder ist es älter als `CLITHEME_TAG` in
`.dev-tools.conf.sh`, nennt `make setup` den pipx-Befehl und läuft weiter;
die Ausgabe der Skripte bleibt dann ohne Farben. Die Bibliotheken selbst
rufen `cli-theme` nie auf. `make hints` zeigt den Installationsbefehl,
`make info` die gefundene Version.
`make check` ist der volle Prüflauf (Doku und alle Bash-Tests); ohne
`make setup` bricht er mit einem Hinweis ab. `make help` listet alle Targets,
`make hints` die Befehle für den ersten Start.

`make test` prüft die Doku und startet `test/testAll.sh`. Die Tests laden
jede Bibliothek und rufen ausgewählte Funktionen auf. Das Makefile setzt
`BASH_LIBS` dabei auf `src` des eigenen Checkouts; wer `test/testAll.sh`
direkt startet, setzt es selbst, sonst bricht es mit „Var 'BASH_LIBS' nicht
gesetzt!“ ab. Änderungen an Skripten zusätzlich mit `bash -n` und ShellCheck
prüfen.

`test/_testVersionPush.sh` prüft die Versions-Bumps (`semVerBump`,
`calVerBump`, `bumpVer`, `gitUpdateVersionTag`) gegen echte Git-Repos in
einem temporären Ordner: Mit und ohne lokales Remote taggen sie nur lokal,
und erst `git push --follow-tags` bringt Tag und Commit ins Remote. Außerdem
prüft es `gitReleaseTag`: Ein Tag wie `deploy-2026-11` näher am Commit zählt
nicht, `gitVersion`, `semVerWithDate` und `gitDockerTag` nehmen den v-Tag.
Es bindet
`src/version.lib.sh` der eigenen Arbeitskopie ein, nicht die unter
`BASH_LIBS`, und blendet die globale Git-Konfiguration aus.

`test/_testMakeTag.sh` kopiert den Arbeitsstand in ein Wegwerf-Repo mit
aktiven Hooks und ruft dort `make tag-patch` auf: Bei Erfolg erscheinen nur
die drei Statuszeilen, bei einem Fehler die Meldung mit Exit ungleich 0. Es
prüft außerdem, dass die Hooks ohne Probleme still bleiben und Fehler zeigen.
Es braucht ProjectTools wie `make check`.

`test/_testBashlibCommand.sh` ruft den Befehl `bashlib` ohne Installation
auf. Ein nachgebautes `dist-info` liefert Version und Befehle wie nach
`pip install`, dazu einen Befehl, der nur dort steht: Er erscheint ohne
weitere Pflegestelle. Die Beschreibung je Befehl ist die erste Zeile des
Docstrings seiner Funktion; die Befehle selbst stehen nur in
`[project.scripts]`.

`test/_testTheme.sh` prüft das Lesen der CLI-Theme-Datei in `colors.lib.sh`
mit eigenem `XDG_CONFIG_HOME`: gültige Themes, fehlende und ungültige Dateien,
Links, `MAKE_THEME`, vorbelegte `THEME_*`-Werte und `NO_COLOR`. Die Farben
prüft es an einem Pseudoterminal; dafür braucht es `python3`. Ist `cli-theme`
installiert, liest es zusätzlich alle Vorlagen von CLITheme mit
`colors.lib.sh` und vergleicht das Ergebnis mit CLITheme selbst sowie die
classic-Abstände in `colors.lib.sh` mit der Vorlage. Ändert CLITheme sein
Format, wird der Test dort rot.

`test/_testSetupThemes.sh` ruft `make setup-themes` (Teil von `make setup`)
mit einem nachgebauten `cli-theme` auf: vorhanden, zu alt, `install` scheitert
und fehlt. In jedem Fall endet der Schritt mit Exit 0 und nennt den nächsten
Schritt.

Das pip-Paket (`pyproject.toml`, Befehle `bashlib` und `bashlib-path`) prüft

```bash
make test-package
```

Es installiert BashLib einmal normal und einmal mit `pip install -e` in je
eine temporäre venv, bindet daraus eine Bibliothek ein und ruft `bashlib` auf. Dafür braucht es
Python ab 3.11 (`PYTHON=…`, sonst `python3`) und Zugriff auf den
Paketindex für setuptools.

## Version und Release

Die Version steht nur in `pyproject.toml` (`version = "X.Y.Z"`); das
Makefile liest sie mit `readProjectVersion` (`make version`). Ein Release
entsteht auf `master` mit

```bash
make tag-patch    # bzw. tag-minor, tag-major; MSG="…" setzt die Tag-Message
git push --follow-tags
```

`make tag-*` erhöht die Version mit `semVerBump`, committet, setzt den Tag
`vX.Y.Z+YYMMDD.HHMM.hash` und committet danach `CHANGELOG.md`
(`changelog --commit`), alles nur lokal. Es meldet je Schritt eine
Statuszeile: Version alt → neu, Tag (nur lokal) und Changelog. Veröffentlicht
wird erst mit `git push --follow-tags`. `make changelog` zeigt vorher eine
Vorschau.
Projekte wie ProjectTools hängen über diesen Tag an BashLib.

Mit `git config push.followTags true` nimmt schon ein einfaches `git push`
alle lokalen annotierten Tags mit. Wer einen Tag erst nach einer Prüfung
veröffentlichen will, lässt die Einstellung weg oder pusht mit
`git push --no-follow-tags`.

## Neue Bibliothek

Eine neue Datei `src/<name>.lib.sh` folgt dem Muster der vorhandenen:

1. Erste Zeile nach dem Shebang setzt die Wächtervariable, etwa
   `readonly __NAME_LIB__="name.lib.sh";`.
2. Der Dateikopf beschreibt den Zweck und nennt unter „Einbinden“ die
   Wächterzeile.
3. Abhängigkeiten lädt sie über `${BASH_LIBS}` mit derselben Wächterzeile.

Danach die Tabelle der Bibliotheken im README ergänzen.

## Farben und Themes

Die Palette (`RED`, `GREEN`, `NC`, …) in `colors.lib.sh` ist fest. Farben und
Abstände der Theme-Helfer kommen aus der Theme-Datei von
[CLITheme](https://github.com/MikeMitterer/python-clitheme); Themes werden dort
gepflegt, nicht in BashLib. `test/_testTheme.sh` prüft, dass `colors.lib.sh`
die Vorlagen von CLITheme gleich liest. Details in [themes.md](themes.md).
