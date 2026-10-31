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
einem temporären Ordner: mit einem lokalen Remote, das den Push annimmt,
einem, das ihn abweist, und ohne Remote. Es bindet `src/version.lib.sh` der
eigenen Arbeitskopie ein, nicht die unter `BASH_LIBS`, und blendet die
globale Git-Konfiguration aus.

Das pip-Paket (`pyproject.toml`, Befehl `bashlib-path`) prüft

```bash
make test-package
```

Es installiert BashLib einmal normal und einmal mit `pip install -e` in je
eine temporäre venv und bindet daraus eine Bibliothek ein. Dafür braucht es
Python ab 3.11 (`PYTHON=…`, sonst `python3`) und Zugriff auf den
Paketindex für setuptools.

## Version und Release

Die Version steht nur in `pyproject.toml` (`version = "X.Y.Z"`); das
Makefile liest sie mit `readProjectVersion` (`make version`). Ein Release
entsteht auf `master` mit

```bash
make tag-patch    # bzw. tag-minor, tag-major; MSG="…" setzt die Tag-Message
```

Das erhöht die Version mit `semVerBump`, committet, setzt den Tag
`vX.Y.Z+YYMMDD.HHMM.hash`, pusht und schreibt danach `CHANGELOG.md` mit
`changelog --publish`. Scheitert der Push, bricht das Target vor dem
Changelog ab. `make changelog` zeigt vorher eine Vorschau. Projekte wie
ProjectTools hängen über diesen Tag an BashLib.

## Neue Bibliothek

Eine neue Datei `src/<name>.lib.sh` folgt dem Muster der vorhandenen:

1. Erste Zeile nach dem Shebang setzt die Wächtervariable, etwa
   `readonly __NAME_LIB__="name.lib.sh";`.
2. Der Dateikopf beschreibt den Zweck und nennt unter „Einbinden“ die
   Wächterzeile.
3. Abhängigkeiten lädt sie über `${BASH_LIBS}` mit derselben Wächterzeile.

Danach die Tabelle der Bibliotheken im README ergänzen.

## Farben und Themes

Palette und Themes sind mit MakeLib `colours.mk` und ProjectTools
`colors.py` abgestimmt; wer sie ändert, ändert alle drei. Details in
[themes.md](themes.md).
