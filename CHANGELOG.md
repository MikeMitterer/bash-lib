# Changelog

Generated from release tags and Conventional Commits.

## v0.2.0+261031.2038.b22f0 — 2026-10-31

Makefile nach Konventionen, gescheiterter Push wird gemeldet, Paketname in hints

### Fixes

- gescheiterten git push melden statt mit Exit 0 weiterzulaufen (`cc8ce2f`)
- Testskripte laufen auch in Pfaden mit Leerzeichen (`4081ab8`)
- Maintainer-Targets in make help kennzeichnen (`eacc2ac`)

### Features

- Makefile nach makefile-conventions mit Setup, Prüflauf und Versionierung (`8543b3a`)
- hints und info nennen den Python-Paketnamen (`55ff7da`)

### Documentation

- Beschreibung der tag-\*-Targets in make help kürzen (`3cc46bc`)

## v0.1.0 — 2026-10-28

BashLib als pip-Paket (mmit-bashlib) mit Befehl bashlib-path

### Documentation

- README auf Einbinden, Voraussetzungen und BASH\_LIBS ausrichten (`611298f`)
- DEV\_MAKE zeigt auf MakeLib/src (`27896d3`)

### Fixes

- Makefile läuft ohne MakeLib mit Ersatzfarben (`deac74d`)
- ohne MakeLib keine Ersatzfarben, Ausgabe ohne Farben (`49545e3`)
- Version mit readProjectVersion statt sed lesen (`d657ebd`)

### Features

- BashLib als pip-Paket mit Befehl bashlib-path installierbar machen (`4bd9591`)
