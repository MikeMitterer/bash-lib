# Changelog

Aus Release-Tags und Conventional Commits erzeugt.

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
