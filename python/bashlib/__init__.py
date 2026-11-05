"""BashLib als Python-Paket: Ort der *.lib.sh fuer BASH_LIBS und Ueberblick ueber das Paket."""

from __future__ import annotations

import importlib
import os
import re
import subprocess
import sys
from importlib import metadata
from pathlib import Path

PACKAGE = "mmit-bashlib"

# Gibt Ueberschriften und Zeilen mit den Theme-Helfern aus tools.lib.sh aus.
# Argumente: je Eintrag Art (h oder r), Text links, Text rechts.
RENDER = """
source "${BASH_LIBS}/tools.lib.sh" || exit 1
while (( $# >= 3 )); do
    if [[ $1 == h ]]; then printThemeHeading "$2"; else printThemeRow "$2" "$3"; fi
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
    """Verzeichnis der *.lib.sh ausgeben, etwa für export BASH_LIBS=…"""
    if len(sys.argv) > 1:
        print("Aufruf: bashlib-path  (gibt das Verzeichnis der *.lib.sh aus)", file=sys.stderr)
        return 0 if sys.argv[1] in ("-h", "--help") else 2
    print(lib_dir())
    return 0


def _pyproject() -> str:
    """pyproject.toml der Arbeitskopie, wenn das Paket nicht installiert ist; sonst leer."""
    path = Path(__file__).resolve().parents[2] / "pyproject.toml"
    return path.read_text(encoding="utf-8") if path.is_file() else ""


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


def describe(target: str) -> str:
    """Erste Zeile des Docstrings der Funktion hinter modul:funktion; leer, wenn keiner da ist."""
    module, _, attribute = target.partition(":")
    try:
        found = importlib.import_module(module.strip())
        for part in attribute.strip().split("."):
            found = getattr(found, part)
    except (ImportError, AttributeError):
        return ""
    return ((found.__doc__ or "").strip().splitlines() or [""])[0]


def _render(entries: list[tuple[str, str, str]]) -> int:
    """Gibt die Einträge über colors.lib.sh im gewählten CLI-Theme aus."""
    environment = dict(os.environ, BASH_LIBS=str(lib_dir()))
    arguments = [value for entry in entries for value in entry]
    return subprocess.run(["bash", "-c", RENDER, "bashlib", *arguments], env=environment).returncode


def cli() -> int:
    """Version von BashLib und die Befehle des Pakets anzeigen"""
    arguments = sys.argv[1:]
    if arguments in (["-h"], ["--help"]):
        return _render([
            ("h", "Aufruf: bashlib [-h | --help | --version]", ""),
            ("r", "(ohne Argument)", "Version von BashLib und die Befehle des Pakets anzeigen"),
            ("r", "--version", "Nur die Version ausgeben"),
            ("r", "-h | --help", "Diese Hilfe anzeigen"),
            ("h", "Umgebung", ""),
            ("r", "CLI_THEME", "Theme der Ausgabe (Standard classic; anlegen mit cli-theme install)"),
            ("r", "NO_COLOR", "Ausgabe ohne Farben"),
        ])
    if arguments == ["--version"]:
        print(version())
        return 0
    if arguments:
        # Eine bekannte Option mit Zusatz: den Zusatz nennen, nicht die Option.
        known = arguments[0] in ("-h", "--help", "--version")
        problem = f"Zu viele Argumente: {arguments[1]}" if known else f"Unbekanntes Argument {arguments[0]}"
        print(f"{problem}\nbashlib --help", file=sys.stderr)
        return 2
    rows = [("r", name, describe(target)) for name, target in commands()]
    return _render([("h", f"BashLib {version()}", ""), *rows])
