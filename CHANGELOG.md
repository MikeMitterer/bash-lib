# Changelog

Aus Release-Tags und Conventional Commits erzeugt.

## v0.4.0+261105.1713.51c76 — 2026-11-05

CLI-Theme in colors.lib.sh (cli-theme), Theme-Helfer, assert.lib.sh, Befehl bashlib, make install, gitReleaseTag

### Fehlerkorrekturen

- Bump-Funktionen committen leise und brechen bei Commit-Fehler ab (`3887804`)
- pre-commit und post-commit ohne Probleme still (`5ff28cd`)
- tag-\* melden je Schritt eine Statuszeile (`8503b89`)
- geerbte THEME\_\*-Exporte überstimmen die Theme-Datei nicht (`83fe293`)
- bashlib nennt bei überzähligem Argument den Zusatz (`117f766`)
- getPackageName und make hints/version nehmen nur Release-Tags (`d5fe2be`)
- info zeigt Farbzustand und geladenes Theme richtig an (`569047b`)
- ShellCheck-Meldungen in tools.lib.sh behoben (`5465ce5`)
- scriptToDoc und repeat beenden Skripte unter set -e nicht (`4b9cf17`)
- themeAccent/themeMark setzen vor der Rückkehrfarbe zurück (`2390bbf`)

### Weitere Änderungen

- tag-\* committen den Changelog mit changelog --commit (`9e51cf9`)
- Asserts als Bibliothek src/assert.lib.sh (`a501e40`)
- checkStatus nach assert.lib.sh, test.lib.sh entfernt (`f70916a`)

### Neue Funktionen

- Theme-Helfer lesen die CLI-Theme-Datei (`401b453`)
- make setup legt die CLI-Themes mit cli-theme install an (`08db8b5`)
- Befehl bashlib zeigt Version und Befehle des Pakets (`b1d7973`)
- gitReleaseTag liefert den Release-Tag eines Commits (`9902d74`)
- Helfer für alle Theme-Rollen, Beispiel nutzt sie (`72d6642`)
- bashlib-Übersicht wie projecttools, make install (`fd70b0d`)

### Dokumentation

- Beispiel-CLI mit CLI-Theme (help, info, hints, Fehler) (`257edea`)
- themeAccent/themeMark nur an Theme-Helfer oder themeStyle (`5c5bc00`)
- CLI-Theme ab BashLib 0.4.0 (`4c8ba8e`)

## v0.3.0+261103.1253.f86e0 — 2026-11-03

Tag-Funktionen pushen nicht mehr

### Inkompatible Änderungen

- Tag-Funktionen taggen nur lokal, Push als eigener Schritt (`6934fb3`)

### Fehlerkorrekturen

- tag-\* committen CHANGELOG.md lokal, kein push-Target (`85a58d2`)
- Hinweis nach dem Taggen ohne Push-Befehl (`599569a`)

## v0.2.0+261031.2038.b22f0 — 2026-10-31

Makefile nach Konventionen, gescheiterter Push wird gemeldet, Paketname in hints

### Fehlerkorrekturen

- gescheiterten git push melden statt mit Exit 0 weiterzulaufen (`cc8ce2f`)
- Testskripte laufen auch in Pfaden mit Leerzeichen (`4081ab8`)
- Maintainer-Targets in make help kennzeichnen (`eacc2ac`)

### Neue Funktionen

- Makefile nach makefile-conventions mit Setup, Prüflauf und Versionierung (`8543b3a`)
- hints und info nennen den Python-Paketnamen (`55ff7da`)

### Dokumentation

- Beschreibung der tag-\*-Targets in make help kürzen (`3cc46bc`)

## v0.1.0 — 2026-10-28

BashLib als pip-Paket (mmit-bashlib) mit Befehl bashlib-path

### Dokumentation

- README auf Einbinden, Voraussetzungen und BASH\_LIBS ausrichten (`611298f`)
- DEV\_MAKE zeigt auf MakeLib/src (`27896d3`)

### Fehlerkorrekturen

- Makefile läuft ohne MakeLib mit Ersatzfarben (`deac74d`)
- ohne MakeLib keine Ersatzfarben, Ausgabe ohne Farben (`49545e3`)
- Version mit readProjectVersion statt sed lesen (`d657ebd`)

### Neue Funktionen

- BashLib als pip-Paket mit Befehl bashlib-path installierbar machen (`4bd9591`)
