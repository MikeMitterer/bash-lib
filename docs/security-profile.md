# Sicherheitsprofil

Was in diesem Projekt schutzwürdig ist und welche Grundsatzentscheidungen
gelten. Ein Konzeptticket, das den Aufbau der App berührt, prüft und ergänzt
es. Bei jedem Code-Ticket prüfen Implementer und Reviewer den Diff dagegen
(Guard `security`, Bericht ist Pflicht).
Leere Abschnitte heißen „noch nicht entschieden“; „keine“ ist eine Entscheidung.

**BashLib ist eine Bibliothek ohne eigenen Dienst und läuft mit den Rechten des
aufrufenden Skripts.** Die Risiken liegen dort, wo Code ausgeführt wird, den
BashLib nicht selbst enthält: Werkzeuge aus dem Netz, `eval` und gesourcte
Einstellungsdateien. Dazu kommen Registry-Zugangsdaten und `rsync --delete` im
Altbestand von `docker.lib.sh`, `samples.lib.sh` und `webapp.lib.sh`.

## Übersicht

- [Sensible Daten](#sensible-daten)
- [Speicherorte](#speicherorte)
- [Geheimnisse](#geheimnisse)
- [Anmeldung](#anmeldung)
- [Zugriffe von außen](#zugriffe-von-außen)
- [Ausführung](#ausführung)

## Sensible Daten

BashLib führt keine eigenen Daten und keine personenbezogenen Daten. Schutzwürdig
sind nur Zugangsdaten, die beim Aufruf durchlaufen oder neben dem Projekt liegen:

- Docker-Hub-Passwort oder Access-Token (`loginToDockerHub` in `docker.lib.sh`)
- ECR-Anmeldedaten von `aws ecr get-login-password` (`docker.lib.sh`)
- Jenkins-Zugangsdaten im nicht versionierten lokalen Hook, den
  `.githooks/post-commit` weiter aufruft
- `JENKINS_JOB_TOKEN` in `.jenkins`, siehe [Speicherorte](#speicherorte)

[↑ Übersicht](#übersicht)

## Speicherorte

| Was | Wo | Rechte und Prüfung |
|---|---|---|
| Docker-Hub-Zugang | Datei aus `DOCKER_PW_FILE`; den Pfad setzt das aufrufende Skript | Der Hinweis in `loginToDockerHub` nennt `chmod 600`; die Funktion prüft nur, ob die Datei existiert, nicht ihre Rechte |
| Registry-Anmeldungen | `~/.docker/config.json`, verwaltet von `docker login` | `checkCHCRLogin` sucht darin nur nach `ghcr.io` und gibt nichts daraus aus |
| Zeitpunkt des letzten Logins | `.last_login` im aktuellen Ordner (`loginToDockerHub`) | enthält nur das Datum |
| Jenkins-Zugang für den Trigger | nicht versionierter Hook unter `.git/hooks/post-commit` | außerhalb des Repositorys |

Zugangsdaten gehören nicht ins Repository, das öffentlich ist. Das ist eine
Konvention; keine Prüfung setzt sie durch.

**Bewusste Abweichung:** `.jenkins` enthält `JENKINS_JOB_TOKEN`. Im Repository
liest ihn sonst niemand. Der Eintrag bleibt, weil das Token nach Entscheidung
des Menschen nichts schützt (q-40, Option C).

[↑ Übersicht](#übersicht)

## Geheimnisse

Geheimnisse erreichen `docker login` über die Standardeingabe, nicht über die
Kommandozeile. So tauchen sie nicht in der Prozessliste auf. Das ist eine
Konvention, denn kein Test führt diese Aufrufe aus.

- **Docker Hub:** `loginToDockerHub` leitet die Datei aus `DOCKER_PW_FILE` nach
  `docker login --password-stdin`.
- **ECR:** `aws ecr get-login-password` wird nach `docker login --password-stdin`
  geleitet, an allen Login-Stellen von `docker.lib.sh`.
- **GHCR:** BashLib meldet sich nicht selbst an. `checkCHCRLogin` nennt den
  einmaligen Befehl mit dem Platzhalter `<PAT>` und bricht ab, wenn kein Login
  vorliegt.

[↑ Übersicht](#übersicht)

## Anmeldung

Keine. BashLib hat keine Benutzer, Sitzungen oder Tokens, denn es ist eine
Bibliothek ohne Dienst. Anmeldungen an Registries und per SSH bleiben bei
`docker`, `aws` und `ssh`.

[↑ Übersicht](#übersicht)

## Zugriffe von außen

BashLib vertraut dem aufrufenden Skript und seiner Umgebung. Werte, die nur
angezeigt oder weitergereicht werden, dürfen keinen Shell-Text ausführen; Dateien
und Pfade, die BashLib ausführt, werden nicht geprüft.

**Eingaben, die nie als Code laufen dürfen** (jede mit Test):

| Eingabe | Stelle | Durchgesetzt von |
|---|---|---|
| `MSG` bei `make tag-*` | `Makefile`: `override MSG`, im Rezept als Umgebungsvariable | `test/_testMakeTag.sh` |
| Checkout-Pfad, auch mit `'` und `$(…)` | `Makefile`: `WORKSPACE_SQ`, `BASH_ENV` über `BASH_LIBS` | `test/_testMake.sh` |
| Release-Tag aus `repo-info` | `Makefile`, Target `hints` | `test/_testMakeHints.sh` |
| Werte aus `clitheme export --bash` | `themeLoad` in `cli.lib.sh` | `test/_testTheme.sh` |
| Hinweistext für `requireCommand` | `requireCommand` in `apps.lib.sh`, über `themeEscape` aus `cli.lib.sh` | `test/_testHelpers.sh` |
| Metavariablen in Hilfetexten | `printThemeOption` in `cli.lib.sh` | `test/_testHelpFormat.sh` |
| Befehlsnamen aus `pyproject.toml` | `readPackageCommands` in `version.lib.sh`, ungültige Namen fallen weg | `test/_testHelpers.sh` |

Der Befehl `bashlib` übergibt seine Anzeigewerte an ein festes Bash-Skript als
Positionsargumente (`_render` in `python/bashlib/__init__.py`). Das ist einmalig
gemessen, aber nicht durch einen Test abgesichert.

**Eingaben, denen BashLib voll vertraut** (keine Prüfung):

| Eingabe | Stelle | Folge |
|---|---|---|
| `BASH_LIBS` | jede Einbindezeile in `src/` | Die Dateien dort werden gesourct. Das `Makefile` setzt es fest auf `src` des eigenen Checkouts, `bashlib` auf sein eigenes Paket |
| `.rsync` im Beispielordner | `samples.lib.sh` | wird gesourct |
| `RSYNC_SETTINGS` | `webapp.lib.sh` | wird gesourct |
| Maschinenname für `docker-machine` | `docker.lib.sh` | steht ohne Anführungszeichen im Befehl, dessen Ausgabe `eval` ausführt |

[↑ Übersicht](#übersicht)

## Ausführung

### Installation und Werkzeuge

| Vorgang | Stelle | Was läuft, wer legt es fest |
|---|---|---|
| Werkzeugprüfung | `DEV_TOOLS` im `Makefile`, genutzt von `require-tools` und `setup-themes` | `pipx run` lädt DevTools von GitHub und führt es aus. Den Tag legt `DEVTOOLS_TAG` in `.dev-tools.conf.sh` fest; ein Tag ist kein fester Commit |
| ProjectTools, CLITheme | `.dev-tools.conf.sh` | BashLib installiert sie nicht. `make hints` und `devtools` nennen nur den Befehl, `THEME_CLITHEME_INSTALL` in `cli.lib.sh` ebenso |
| `make install` | `installEditablePackage` in `make.lib.sh` | `pipx install -e --force` mit dem eigenen Checkout; Fehler werden gemeldet (`test/_testMakeInstall.sh`) |
| venv anlegen | `ensurePythonVenv` in `python.lib.sh` | `pip install` mit den Argumenten des Aufrufers; Fehler werden gemeldet (`test/_testPython.sh`) |
| `make test-package` | `test/package.test.sh` | `pip` holt setuptools aus dem Paketindex, in temporäre venvs; nicht Teil von `make check` |
| `make setup` | `Makefile` | setzt `core.hooksPath` auf `.githooks`. Danach laufen die Hooks des Checkouts bei jedem Commit, `post-commit` startet zusätzlich den lokalen Hook |

### Fremde Befehle

| Befehl | Stelle | Über eine Shell | Exit-Code |
|---|---|---|---|
| `clitheme export --bash` | `themeLoad` in `cli.lib.sh` | Ausgabe läuft durch `eval`; `test/_testTheme.sh` prüft das Quoting mit dem echten clitheme | geprüft; bei Fehler Ausgabe ohne Farben und ein Hinweis |
| `docker-machine env` | `docker.lib.sh` | Ausgabe läuft durch `eval`, ohne Anführungszeichen | nicht geprüft |
| `tag-version`, `changelog`, `docs-check`, `repo-status`, `repo-info` | Rezepte im `Makefile` | Rezeptzeile von Make | Make bricht beim ersten Fehler ab; `require-tools` prüft ProjectTools vorher |
| `docker`, `aws` | `docker.lib.sh` | direkt, ECR-Login als Pipe | nicht geprüft, außer das aufrufende Skript setzt `set -e` |
| `rsync --delete`, `ssh` | `samples.lib.sh`, `webapp.lib.sh` | direkt, Ziel ohne Anführungszeichen; **löscht auf dem Zielrechner** | nicht geprüft, außer das aufrufende Skript setzt `set -e` |

Die Bibliotheken in `src/` setzen selbst kein `set -e`. In `src/`, `Makefile` und
`.githooks` steht `git push` nur in Kommentaren: `make tag-*` bleibt lokal, belegt
von `test/_testMakeTag.sh`. Login, Push und `rsync` führt kein Test aus.

### Löschende Befehle

Vollständig für `src/`, `Makefile`, `python/` und `.githooks`. Keine dieser
Stellen fragt nach. Geprüft wird höchstens, ob ein Wert oder Ordner vorhanden ist,
etwa `RSYNC_DESTINATION` und `DEPLOY_DIR` vor dem `rsync` in `samples.lib.sh`, nie
sein Inhalt. Das ist am Code gelesen; keine Prüfung hält es fest.

| Befehl | Stelle | Was verloren geht, woher der Wert kommt |
|---|---|---|
| `rsync --delete` | `samples.lib.sh`, `webapp.lib.sh` | Dateien am Ziel, die im Quellordner fehlen. Das Ziel `RSYNC_DESTINATION` kommt aus den gesourcten Einstellungen; `webapp.lib.sh` kennt zusätzlich einen Probelauf (`dry-run`) |
| `docker compose down --volumes` | `stopContainer` in `docker.lib.sh` | **Volumes, schon ohne Argumente:** Der zweite Parameter steht auf `clear`, erst `keep` oder `false` schont sie. Die Compose-Datei nennt der Aufrufer |
| `rm -rf "${DEPLOY_DIR}"` | `deploySamples` in `samples.lib.sh` | Der Ordner liegt im Beispielordner aus den Argumenten. `DEPLOY_DIR` setzt die Bibliothek, aber nicht `readonly`, also kann der Aufrufer es überschreiben. Das `cd` davor wird nicht geprüft; scheitert es, löscht der Befehl im aktuellen Ordner |
| `rm -rf .dart_tool`, `rm -f web/index.html.bak` | `deploySamples` in `samples.lib.sh` | feste Namen, im selben Ordner wie oben |
| `build_runner --delete-conflicting-outputs` | `samples.lib.sh` | erzeugte Dateien, die Dart-Werkzeuge entscheiden |
| `mv` auf den Zielordner | `syncToLocalDir` in `fs.lib.sh` | nichts: Der Ordner aus dem Argument wandert in den Backup-Ordner |
| `rm -f pyproject.toml.bak` | `version.lib.sh` | feste Sicherungsdatei von `sed` |
| `rm` in den Hooks | `.githooks/pre-commit`, `.githooks/post-commit` | nur eigene Dateien aus `mktemp` |

`rm -rf -- ${_venv}` in `ensurePythonVenv` ist nur ein angezeigter Hinweis und läuft
nicht. `stopContainer` und `deploySamples` führt kein Test aus; `stopContainer` ist
einmalig mit einem nachgebauten `docker` gemessen.

[↑ Übersicht](#übersicht)
