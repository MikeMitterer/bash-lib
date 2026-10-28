# Entwicklung

**Für alle, die an BashLib selbst arbeiten.** Wie man die Bibliotheken nutzt,
steht im [README](../README.md).

## Voraussetzungen

- Bash ab 4.3 und `BASH_LIBS` auf das `src` dieses Checkouts, wie im
  [README](../README.md#installation) beschrieben.
- Optional [MakeLib](https://github.com/MikeMitterer/make-lib) mit `DEV_MAKE`
  auf deren `src`: Das Makefile nimmt dann deren Farben und Themes, sonst
  erscheint die Ausgabe ohne Farben.

## Testen

```bash
make test
```

Das startet `test/testAll.sh`. Die Tests laden jede Bibliothek und rufen
ausgewählte Funktionen auf; ohne `BASH_LIBS` brechen sie mit „Var
'BASH_LIBS' nicht gesetzt!“ ab. Änderungen an Skripten zusätzlich mit
`bash -n` und ShellCheck prüfen.

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
Makefile liest sie von dort. Ein Release ist ein Tag `vX.Y.Z` auf `master`,
passend zu dieser Version. Projekte wie ProjectTools hängen über diesen Tag
an BashLib.

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
