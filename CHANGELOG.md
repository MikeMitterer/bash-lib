# Changelog

Aus Release-Tags und Conventional Commits erzeugt.

## v0.9.0+261107.1447.9f229 — 2026-11-07

make install über installEditablePackage (pipx-Rezept in make.lib.sh); showMakeTargets zeigt Server-Targets mit ##R und ##D wieder an

### Neue Funktionen

- installEditablePackage – pipx-Rezept von make install als Funktion in make.lib.sh (T-60) (`cc541b1`)
- showMakeTargets zeigt Server-Targets mit ##R und ##D (T-59) (`85d622f`)

### Dokumentation

- deutscher Hilfetext im install-Beispiel von installEditablePackage (T-60) (`204f91c`)

## v0.8.0+261107.1105.c9a53 — 2026-11-07

Makefile-Ausgabe zeilenweise: printMakeHeading, printMakeValue, showMakeTargets; showMakeHelp, showMakeInfo und showMakeHints entfernt

### Inkompatible Änderungen

- Makefile-Ausgabe zeilenweise – printMakeHeading, printMakeValue, showMakeTargets (T-58) (`d1d8ba7`)

## v0.7.0+261106.2017.0e5e1 — 2026-11-06

Kopfzeilen der Makefile-Hilfe im Theme (showMakeHeader, showMakeHelp --project), Makefile ohne clitheme export --make

### Neue Funktionen

- Kopfzeilen der Makefile-Hilfe im Theme (T-57) (`f3d6b20`)

## v0.6.0+261106.1941.8649f — 2026-11-06

Theme aus clitheme, neue cli.lib.sh, make.lib.sh und python.lib.sh, einheitliches Hilfeformat

### Inkompatible Änderungen

- Farben und Abstände aus clitheme export statt eigenem Theme-Leser (T-42) (`bf748a8`)
- requireCommand, readPackageName/readPackageCommands; styles.lib.sh und Bash-3.2-Reste entfernt (T-54) (`10272f2`)

### Neue Funktionen

- Makefile-Hilfe und Hinweise im CLI-Theme mit make.lib.sh (T-45) (`8db35ae`)
- printThemeOption und printThemeExample für die Hilfe von Skripten (T-22) (`c4b72d7`)
- showMakeInfo für make info – Name/Wert-Zeilen im Theme (T-46) (`abc4721`)
- requireMakeSetup prüft die Einrichtung für Prüf-Targets (T-47) (`71377b8`)
- ensurePythonVenv legt eine venv mit Mindestversion an (T-48) (`2cddb4b`)

### Fehlerkorrekturen

- make.lib.sh auch unter Bash 3.2, Tests mit echtem clitheme (T-45 R1) (`6edf902`)
- scheiterndes clitheme export eigens melden, Tests mit echtem clitheme (T-42 R1) (`470b7ee`)
- make info ohne eigenen Ersatztext, README-Satz für drei Funktionen (T-46 R1) (`3778b5a`)
- requireMakeSetup bricht bei --hooks/--make ohne Wert mit Exit 2 ab (T-47 R1) (`5a42d78`)
- ensurePythonVenv nimmt für --min nur X.Y (T-48 R1) (`b42e3d5`)

### Weitere Änderungen

- Ausgabe im CLI-Theme in eigene cli.lib.sh, tools.lib.sh nur Allzweck-Helfer (T-53) (`8e8318f`)
- Statuszeilen über printThemeStatus, version/tags über make.lib.sh (T-56) (`c007b6e`)

### Dokumentation

- Bash 5 als Voraussetzung nennen (`20e8d75`)
- README auf Englisch, deutsche Fassung als README.de.md (T-4) (`f144c68`)
- themeEscape in der Tabelle der Helfer (T-56) (`316a6b4`)

## v0.5.0+261105.2226.e848e — 2026-11-05

semVerNext, gitListReleaseTags, showProjectVersion und showReleaseTags, make help mit Versionsvorschau, Release nur auf master, Werkzeugprüfung über devtools

### Neue Funktionen

- semVerNext, gitListReleaseTags und Anzeige für make version/tags (`c6a0177`)

### Fehlerkorrekturen

- tag-\* nur auf master, develop danach vorgespult (`a3860f8`)
- ohne pipx klare Meldung statt roher Fehler oder leerer Zeilen (`74546dd`)

### Weitere Änderungen

- Werkzeugprüfung über devtools statt eigener Versionslogik (`eae663f`)

### Dokumentation

- vorhandenes egg-info bleibt bestehen, pip aktualisiert es (`3767b6f`)
- Ablauf-Erklärung aus der Entwicklerdoku, Begründung bleibt im Makefile (`008baa9`)

## v0.4.0+261105.1713.51c76 — 2026-11-05

CLI-Theme in colors.lib.sh (cli-theme), Theme-Helfer, assert.lib.sh, Befehl bashlib, make install, gitReleaseTag

### Neue Funktionen

- Theme-Helfer lesen die CLI-Theme-Datei (`401b453`)
- make setup legt die CLI-Themes mit cli-theme install an (`08db8b5`)
- Befehl bashlib zeigt Version und Befehle des Pakets (`b1d7973`)
- gitReleaseTag liefert den Release-Tag eines Commits (`9902d74`)
- Helfer für alle Theme-Rollen, Beispiel nutzt sie (`72d6642`)
- bashlib-Übersicht wie projecttools, make install (`fd70b0d`)

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
- Changelog-Sprache unabhängig von der Locale der Shell (`96e3a99`)

### Weitere Änderungen

- tag-\* committen den Changelog mit changelog --commit (`9e51cf9`)
- Asserts als Bibliothek src/assert.lib.sh (`a501e40`)
- checkStatus nach assert.lib.sh, test.lib.sh entfernt (`f70916a`)

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

### Neue Funktionen

- Makefile nach makefile-conventions mit Setup, Prüflauf und Versionierung (`8543b3a`)
- hints und info nennen den Python-Paketnamen (`55ff7da`)

### Fehlerkorrekturen

- gescheiterten git push melden statt mit Exit 0 weiterzulaufen (`cc8ce2f`)
- Testskripte laufen auch in Pfaden mit Leerzeichen (`4081ab8`)
- Maintainer-Targets in make help kennzeichnen (`eacc2ac`)

### Dokumentation

- Beschreibung der tag-\*-Targets in make help kürzen (`3cc46bc`)

## v0.1.0 — 2026-10-28

BashLib als pip-Paket (mmit-bashlib) mit Befehl bashlib-path

### Neue Funktionen

- BashLib als pip-Paket mit Befehl bashlib-path installierbar machen (`4bd9591`)

### Fehlerkorrekturen

- Makefile läuft ohne MakeLib mit Ersatzfarben (`deac74d`)
- ohne MakeLib keine Ersatzfarben, Ausgabe ohne Farben (`49545e3`)
- Version mit readProjectVersion statt sed lesen (`d657ebd`)

### Dokumentation

- README auf Einbinden, Voraussetzungen und BASH\_LIBS ausrichten (`611298f`)
- DEV\_MAKE zeigt auf MakeLib/src (`27896d3`)
