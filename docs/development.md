# Entwicklung

**Für alle, die an BashLib selbst arbeiten.** Wie man die Bibliotheken nutzt,
steht im [README](../README.de.md).

## Voraussetzungen

- Bash 5, Git und [pipx](https://pipx.pypa.io).
- [ProjectTools](https://github.com/MikeMitterer/bash-ProjectTools) per pipx
  für `make docs-check`, `make test`, `make status` und `make changelog`. Die
  verlangten Stände stehen in `.dev-tools.conf.sh`; `make info` zeigt den
  installierten Stand, `make hints` den Installationsbefehl. Fehlt ProjectTools
  oder ist es zu alt, brechen diese Targets mit dem Befehl ab. `make hints`
  nimmt Repo-Adresse und letzten Release-Tag aus `repo-info` (ab 0.5.0); ohne
  ProjectTools nennt es den Grund statt der Werte.
- Optional [CLITheme](https://github.com/MikeMitterer/python-clitheme) (Befehl
  `clitheme`, ab 0.5.0): Das Makefile nimmt Farben und Abstände aus
  `clitheme export`, `help`, `hints` und `info` kommen über `make.lib.sh`. Ohne
  CLITheme erscheint die Ausgabe ohne Farben.

## Einrichten und Testen

```bash
make setup
make check
```

`make setup` aktiviert die Git-Hooks aus `.githooks`: pre-commit prüft die
Doku des vorgemerkten Stands mit `make docs-check`, post-commit ruft einen
lokalen Hook aus `.git/hooks/post-commit` weiter auf, falls es einen gibt.
Ohne Probleme bleiben beide still; Probleme der Doku und Fehler des lokalen
Hooks erscheinen vollständig. Danach legt `make setup` mit `clitheme install`
fehlende CLI-Theme-Dateien an, aus denen `cli.lib.sh` das Theme nimmt; vorhandene bleiben
unverändert. Fehlt CLITheme oder ist es zu alt, nennt `make setup` den
pipx-Befehl und läuft weiter; die Ausgabe der Skripte bleibt dann ohne
Farben.

`make install` installiert die Arbeitskopie editierbar mit pipx
(`installEditablePackage` aus `make.lib.sh`); die Befehle des Pakets zeigen
danach auf `src/`. Nach einem Update erneut aufrufen, denn neue Befehle legt
pipx nur beim Installieren an. `test/_testMakeInstall.sh` prüft die Funktion
und das Target mit einem nachgebauten pipx und die Zeilenbreite von
`make help`.

`make check` ist der volle Prüflauf (Doku und alle Bash-Tests); ohne
`make setup` bricht er mit einem Hinweis ab. `make help` listet alle Targets,
`make hints` die Befehle für den ersten Start.

`make test` prüft die Doku und startet `test/testAll.sh`. Die Tests laden
jede Bibliothek und rufen ausgewählte Funktionen auf. Das Makefile setzt
`BASH_LIBS` dabei auf `src` des eigenen Checkouts; wer `test/testAll.sh`
direkt startet, setzt es selbst, sonst bricht es mit „Var 'BASH_LIBS' nicht
gesetzt!“ ab. Änderungen an Skripten zusätzlich mit `bash -n` und ShellCheck
prüfen.
`test/_testShellcheck.sh` lässt ShellCheck über `src/cli.lib.sh`, `src/tools.lib.sh` und weitere Bibliotheken laufen und
schlägt bei jeder Meldung fehl; ohne installiertes `shellcheck` wird er
übersprungen. Bewusst stehen gelassene Stellen tragen ein
`# shellcheck disable=…` mit Begründung.

Die Bash-Tests unter `test/` binden `src/assert.lib.sh` der eigenen
Arbeitskopie ein: `assertEquals`, `assertContains`, `assertNotContains` und
`finishTests` für die Summenzeile und den Exit-Code. Die Bibliothek kommt wie
alle `src/*.lib.sh` ins pip-Paket und steht auch anderen Projekten zur
Verfügung.

`test/_testVersionPush.sh` prüft die Versions-Bumps (`semVerBump`,
`calVerBump`, `bumpVer`, `gitUpdateVersionTag`) gegen echte Git-Repos in
einem temporären Ordner: Mit und ohne lokales Remote taggen sie nur lokal,
und erst `git push --follow-tags` bringt Tag und Commit ins Remote. Außerdem
prüft es `gitReleaseTag`: Ein Tag wie `deploy-2026-11` näher am Commit zählt
nicht, `gitVersion`, `semVerWithDate`, `gitDockerTag` und `getPackageName`
nehmen den v-Tag. `test/_testMakeTag.sh` prüft dasselbe für `make hints`
(Installationsbefehl) und `make version` (Release-Tag).
`test/_testVersionTools.sh` prüft `semVerNext`, `gitListReleaseTags`,
`showProjectVersion` und `showReleaseTags` gegen echte Git-Repos, dazu die
Vorschau `{major}`, `{minor}` und `{patch}` in `make help` sowie `make version`
und `make tags`.
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

`test/_testTheme.sh` prüft, wie `cli.lib.sh` das Theme aus
`clitheme export --bash` übernimmt, mit dem echten clitheme in eigenem
`XDG_CONFIG_HOME` und `XDG_CACHE_HOME`: Werte, Auswahl über `CLI_THEME`,
vorbelegte und geerbte `THEME_*`-Werte, eine fehlende Theme-Datei, ein Befund
mit `$(…)` im Pfad, der nie ausgeführt wird, den Fall ohne clitheme im `PATH`
und ein scheiterndes `clitheme export` (dafür steht `false` unter dem Namen
clitheme, weil das echte nicht scheitert). Die Farben prüft es an einem
Pseudoterminal; dafür braucht es `python3`. Ohne installiertes clitheme schlägt
der Test fehl.

`test/_testSetupThemes.sh` prüft `make setup-themes` (Teil von `make setup`)
mit nachgebautem `pipx` (devtools-Prüfung: vorhanden, zu alt, fehlt) und dem
echten `clitheme` in eigenem `XDG_CONFIG_HOME`, dazu den Lauf ohne pipx.

`test/_testMake.sh` prüft `make.lib.sh` (`showMakeHeader`, `showMakeTargets`, `printMakeHeading`,
`printMakeValue`, `requireMakeSetup` in einem Wegwerf-Repo) mit
denselben Fällen wie `make-help` und `rows` in CLITheme, dazu `make help`, `make info`, `make hints` und das Minimal-Makefile aus
dem README in einem Ordner `it's $(uname)`.

`test/_testHelpFormat.sh` prüft `printThemeOption` und `printThemeExample`:
reservierte Kurzform-Spalte, bündige Langformen, Metavariable, lange Einträge
in eigener Zeile, `usageLine` wie bisher, Farben am Pseudoterminal und eine
Metavariable mit `$(…)`, die nie ausgeführt wird.

`test/_testLibLayout.sh` prüft die Aufteilung: welche Funktion in welcher
Bibliothek steht, dass ein Skript mit nur `tools.lib.sh` alle bisherigen
Funktionen außer `isLocalPortOpen` und denen aus `make.lib.sh` findet, `make.lib.sh`
die Versionsanzeige samt Ausgabe und Allzweck-Helfern mitbringt, `cli.lib.sh` und
`colors.lib.sh` allein einbindbar sind und
ein zweites Einbinden ohne Guard nicht abbricht.

`test/_testHelpers.sh` prüft `requireCommand` (vorhanden, fehlt, Hinweis mit
`$(…)` wörtlich, Aufruffehler, Skript läuft weiter) sowie `readPackageName` und
`readPackageCommands` an einer Beispiel-`pyproject.toml` mit ungültigen Namen.

`test/_testPython.sh` prüft `ensurePythonVenv` mit `python3.14` und einem
älteren `python3`: Interpreter fehlt oder ist zu alt, venv anlegen und
unverändert lassen, vorhandene venv zu alt, pip scheitert (offline mit
`--no-index`) und Aufruffehler.

`test/_testMakeHints.sh` prüft `make hints` in Wegwerf-Repos: SSH-Remote als
https-Adresse, der Release-Tag `v…` statt eines neueren deploy-Tags, der
Ersatz von `repo-info` ohne Remote, der Hinweis ohne ProjectTools und ein Tag
mit Shell-Text, der nie ausgeführt wird.

Das pip-Paket (`pyproject.toml`, Befehle `bashlib` und `bashlib-path`) prüft

```bash
make test-package
```

Es installiert BashLib einmal normal und einmal mit `pip install -e` in je
eine temporäre venv, bindet daraus eine Bibliothek ein und ruft `bashlib` auf. Dafür braucht es
Python ab 3.11 (`PYTHON=…`, sonst `python3`) und Zugriff auf den
Paketindex für setuptools. Das `python/*.egg-info`, das pip dabei im Checkout
anlegt, entfernt der Test wieder. Ein schon vorhandenes bleibt bestehen;
`pip install -e` aktualisiert dabei aber seinen Inhalt auf den aktuellen Stand.

## Version und Release

Die Version steht nur in `pyproject.toml` (`version = "X.Y.Z"`); das
Makefile liest sie mit `readProjectVersion` (`make version`). Ein Release
entsteht nach der Abnahme auf `master` mit

```bash
make tag-patch    # bzw. tag-minor, tag-major; MSG="…" setzt die Tag-Message
git push --follow-tags origin master
```

Jedes `tag-*`-Target erhöht die Version mit `semVerBump`, committet, setzt den Tag
`vX.Y.Z+YYMMDD.HHMM.hash` und committet danach `CHANGELOG.md`
(`changelog --commit`), alles nur lokal, und meldet je Schritt eine
Statuszeile. Veröffentlicht wird erst mit `git push --follow-tags`.
`make changelog` zeigt vorher eine Vorschau.
Projekte wie ProjectTools hängen über diesen Tag an BashLib.
Der Changelog ist deutsch, unabhängig von der Locale der Shell
(`CHANGELOG_LANGUAGE`, Standard `de`).

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

Ausgaben bauen auf den Theme-Helfern aus `cli.lib.sh` auf
(`printThemeHeading`, `printThemeRow`, `printThemeValue`, `themeMark`), nicht
auf eigenen Farben oder Spalten. Namen folgen den vorhandenen: `show<Gegenstand>`
für einen ganzen Block (`showReleaseTags`, `showMakeTargets`), `printTheme<Teil>`
für eine Zeile, in `make.lib.sh` `printMake<Teil>` (`printMakeValue`).

## Farben und Themes

Die Palette (`RED`, `GREEN`, `NC`, …) in `colors.lib.sh` ist fest. Farben und
Abstände der Theme-Helfer kommen aus der Theme-Datei von
[CLITheme](https://github.com/MikeMitterer/python-clitheme); Themes werden dort
gepflegt, nicht in BashLib. `test/_testTheme.sh` prüft, dass `colors.lib.sh`
die Vorlagen von CLITheme gleich liest. Details in [themes.md](themes.md).
