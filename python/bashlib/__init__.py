"""BashLib als Python-Paket: Ort der *.lib.sh fuer BASH_LIBS und Ueberblick ueber das Paket."""

from __future__ import annotations

import importlib
import inspect
import os
import re
import subprocess
import sys
from importlib import metadata
from pathlib import Path

PACKAGE = "mmit-bashlib"

# Gibt die Übersicht mit den Theme-Helfern aus tools.lib.sh aus. Argumente: je
# Eintrag Art (h Überschrift, r Zeile, t Hinweistext), Text links, Text rechts.
# In Hinweistexten stehen Platzhalter wie <befehl> in der Rolle C_ACC.
RENDER = """
source "${BASH_LIBS}/tools.lib.sh" || exit 1
while (( $# >= 3 )); do
    case "$1" in
        h) printThemeHeading "$2" ;;
        r) printThemeRow "$2" "$3" ;;
        t)
            rest="$2" text=""
            while [[ ${rest} =~ ^([^<]*)(<[^>]*>)(.*)$ ]]; do
                text+="${BASH_REMATCH[1]}$(themeAccent "${BASH_REMATCH[2]}" "${THEME_COLOR_HINT}")"
                rest="${BASH_REMATCH[3]}"
            done
            printThemeHint "${text}${rest}"
            ;;
    esac
    shift 3
done
echo
"""


def lib_dir() -> Path:
    """Verzeichnis mit den *.lib.sh: im Paket, bei -e die Arbeitskopie (src/)."""
    here = Path(__file__).resolve().parent
    bundled = here / "lib"
    if (bundled / "tools.lib.sh").is_file():
        return bundled
    return here.parents[1] / "src"


def main() -> int:
    """Verzeichnis der Bibliotheken ausgeben (Wert für BASH_LIBS)

    Wirkung: liest
    Wann: eigene Skripte sollen BashLib einbinden, `BASH_LIBS` setzen oder eine Bibliothek nachlesen
    """
    if len(sys.argv) > 1:
        print("Aufruf: bashlib-path  (gibt das Verzeichnis der *.lib.sh aus)", file=sys.stderr)
        return 0 if sys.argv[1] in ("-h", "--help") else 2
    print(lib_dir())
    return 0


def _pyproject() -> str:
    """pyproject.toml der Arbeitskopie, wenn das Paket nicht installiert ist; sonst leer."""
    path = Path(__file__).resolve().parents[2] / "pyproject.toml"
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def summary() -> str:
    """Kurzbeschreibung des Pakets aus den Metadaten, ohne Installation aus pyproject.toml."""
    try:
        return metadata.metadata(PACKAGE).get("Summary") or ""
    except metadata.PackageNotFoundError:
        found = re.search(r'^description = "([^"]+)"$', _pyproject(), re.M)
        return found.group(1) if found else ""


def version() -> str:
    """Version aus den Paket-Metadaten, ohne Installation aus pyproject.toml."""
    try:
        return metadata.version(PACKAGE)
    except metadata.PackageNotFoundError:
        found = re.search(r'^version = "([^"]+)"$', _pyproject(), re.M)
        return found.group(1) if found else "unbekannt"


def commands() -> list[tuple[str, str]]:
    """Befehle des Pakets (Name, Ziel modul:funktion) aus [project.scripts].

    Installiert kommen sie aus den Metadaten, sonst aus pyproject.toml; so gibt es
    keine zweite Liste, die gepflegt werden muss.
    """
    try:
        entries = metadata.distribution(PACKAGE).entry_points
        return [(entry.name, entry.value) for entry in entries if entry.group == "console_scripts"]
    except metadata.PackageNotFoundError:
        block = re.search(r"^\[project\.scripts\]\n(.*?)(?:^\[|\Z)", _pyproject(), re.M | re.S)
        lines = re.findall(r'^([A-Za-z0-9._-]+)\s*=\s*"([^"]+)"', block.group(1) if block else "", re.M)
        return list(lines)


def _docstring(target: str) -> str:
    """Docstring der Funktion hinter modul:funktion, ohne Einrückung; leer, wenn keiner da ist."""
    module, _, attribute = target.partition(":")
    try:
        found = importlib.import_module(module.strip())
        for part in attribute.strip().split("."):
            found = getattr(found, part)
    except (ImportError, AttributeError):
        return ""
    return inspect.cleandoc(found.__doc__ or "")


def describe(target: str) -> str:
    """Erste Zeile des Docstrings der Funktion hinter modul:funktion; leer, wenn keiner da ist."""
    return (_docstring(target).splitlines() or [""])[0]


def _fields(lines: list[str], prefix: str = "") -> dict[str, str]:
    """Felder „Name: Wert“ aus Zeilen, die mit prefix beginnen, etwa Wirkung und Wann."""
    found = (re.fullmatch(rf"{re.escape(prefix)}\s*(\w+):\s+(.+)", line.rstrip()) for line in lines)
    return {match[1]: match[2] for match in found if match}


def library_fields(path: Path) -> dict[str, str]:
    """Zweck, Wann und Wichtig aus dem Block „Für Agenten (bashlib --skill):“ im Kopf einer *.lib.sh."""
    lines = path.read_text(encoding="utf-8").splitlines()
    marker = "# Für Agenten (bashlib --skill):"
    if marker not in lines:
        return {}
    block = []
    for line in lines[lines.index(marker) + 1 :]:
        if not re.match(r"#\s+\w+:\s", line):
            break
        block.append(line)
    return _fields(block, "#")


def _render(entries: list[tuple[str, str, str]]) -> int:
    """Gibt die Einträge über colors.lib.sh im gewählten CLI-Theme aus."""
    environment = dict(os.environ, BASH_LIBS=str(lib_dir()))
    arguments = [value for entry in entries for value in entry]
    return subprocess.run(["bash", "-c", RENDER, "bashlib", *arguments], env=environment).returncode


def overview() -> list[tuple[str, str, str]]:
    """Übersicht wie bei projecttools: Aufruf, Kurzbeschreibung, Befehle, Optionen, Umgebung.

    Die Befehle kommen aus [project.scripts]; bashlib selbst (Ziel bashlib:cli) fehlt darin.
    """
    own = f"{__name__}:cli"
    text = summary()
    rows = [("r", name, describe(target)) for name, target in commands() if target.replace(" ", "") != own]
    return [
        ("h", "Aufruf: bashlib [--version] [--skill] [-h]", ""),
        ("t", f"BashLib {version()}{' – ' + text if text else ''}", ""),
        ("t", "Hilfe zu einem Befehl: <befehl> --help", ""),
        ("h", "Befehle", ""),
        *rows,
        ("h", "Optionen", ""),
        ("r", "     --version", "Zeigt die installierte Version."),
        ("r", "     --skill", "Beschreibt Befehle und Bibliotheken für KI-Agenten (Markdown)."),
        ("r", "-h | --help", "Zeigt diese Hilfe."),
        ("h", "Umgebung", ""),
        ("r", "CLI_THEME", "Theme der Ausgabe (Standard classic; anlegen mit clitheme install)"),
        ("r", "NO_COLOR", "Ausgabe ohne Farben"),
    ]


# Typische Aufrufe für --skill: vollständig und so lauffähig, Aufruf und Kommentar.
EXAMPLES = (
    ('export BASH_LIBS="$(bashlib-path)"', "Bibliotheken für eigene Skripte bereitstellen"),
    (
        'if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi',
        "im Skript: Ausgabe im CLI-Theme und Grundbibliotheken laden",
    ),
    ("grep -n -B20 '^semVerBump()' \"$(bashlib-path)/version.lib.sh\"", "Beschreibung einer Funktion lesen"),
    ("bashlib --version", "installierte Version"),
)


def skill_text() -> str:
    """--skill: Befehle und Bibliotheken als Markdown für Agenten, nach der Vorgabe im tools-Skill.

    Befehle kommen wie in der Übersicht aus [project.scripts], Wirkung und Wann aus dem
    Docstring ihrer Funktion; jede Bibliothek beschreibt sich im eigenen Dateikopf."""
    text = summary()
    lines = [
        "# bashlib",
        "",
        f"{text or 'BashLib'}. Installierte Version {version()}. Die Bibliotheken liegen im Verzeichnis, das "
        "`bashlib-path` ausgibt; die meisten Funktionen beschreibt der Kommentar über ihnen. "
        "Alle Optionen eines Befehls: `<befehl> --help`.",
        "",
        "## Befehle",
        "",
    ]
    own = f"{__name__}:cli"
    for name, target in commands():
        if target.replace(" ", "") == own:
            continue
        doc = _docstring(target).splitlines()
        fields = _fields(doc)
        lines.append(
            f"- `{name}` ({fields.get('Wirkung', '?')}): {(doc or [''])[0].rstrip('.')}. "
            f"Wann: {fields.get('Wann', '?').rstrip('.')}."
        )
    width = max(len(call) for call, _ in EXAMPLES)
    lines += ["", "## Beispiele", "", "```sh"]
    lines += [f"{call.ljust(width)}  # {comment}" for call, comment in EXAMPLES]
    lines += ["```", "", "## Bibliotheken", ""]
    for path in sorted(lib_dir().glob("*.lib.sh")):
        fields = library_fields(path)
        important = ", ".join(f"`{entry.strip()}`" for entry in fields.get("Wichtig", "").split(",") if entry.strip())
        lines.append(
            f"- `{path.name}`: {fields.get('Zweck', 'ohne Beschreibung im Dateikopf').rstrip('.')}. "
            f"Wann: {fields.get('Wann', '?').rstrip('.')}. Wichtig: {important}"
        )
    lines += [
        "",
        "## Voraussetzungen",
        "",
        "- Bash 5; `BASH_LIBS` exportiert und auf das Verzeichnis von `bashlib-path` gesetzt.",
        "- Jede Bibliothek über ihre Wächterzeile aus dem Dateikopf („Einbinden“) laden; "
        "`tools.lib.sh` bringt cli, colors, apps, dtime und version mit.",
    ]
    return "\n".join(lines) + "\n"


def cli() -> int:
    """Version von BashLib und die Befehle des Pakets anzeigen"""
    arguments = sys.argv[1:]
    if arguments in ([], ["-h"], ["--help"]):
        return _render(overview())
    if arguments == ["--version"]:
        print(version())
        return 0
    if arguments == ["--skill"]:
        sys.stdout.write(skill_text())
        return 0
    # Eine bekannte Option mit Zusatz: den Zusatz nennen, nicht die Option.
    known = arguments[0] in ("-h", "--help", "--version", "--skill")
    problem = f"Zu viele Argumente: {arguments[1]}" if known else f"Unbekanntes Argument {arguments[0]}"
    print(f"{problem}\nbashlib --help", file=sys.stderr)
    return 2
