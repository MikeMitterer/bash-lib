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


def overview() -> list[tuple[str, str, str]]:
    """Übersicht wie bei projecttools: Aufruf, Kurzbeschreibung, Befehle, Optionen, Umgebung.

    Die Befehle kommen aus [project.scripts]; bashlib selbst (Ziel bashlib:cli) fehlt darin.
    """
    own = f"{__name__}:cli"
    text = summary()
    rows = [("r", name, describe(target)) for name, target in commands() if target.replace(" ", "") != own]
    return [
        ("h", "Aufruf: bashlib [--version] [-h]", ""),
        ("t", f"BashLib {version()}{' – ' + text if text else ''}", ""),
        ("t", "Hilfe zu einem Befehl: <befehl> --help", ""),
        ("h", "Befehle", ""),
        *rows,
        ("h", "Optionen", ""),
        ("r", "     --version", "Zeigt die installierte Version."),
        ("r", "-h | --help", "Zeigt diese Hilfe."),
        ("h", "Umgebung", ""),
        ("r", "CLI_THEME", "Theme der Ausgabe (Standard classic; anlegen mit clitheme install)"),
        ("r", "NO_COLOR", "Ausgabe ohne Farben"),
    ]


def cli() -> int:
    """Version von BashLib und die Befehle des Pakets anzeigen"""
    arguments = sys.argv[1:]
    if arguments in ([], ["-h"], ["--help"]):
        return _render(overview())
    if arguments == ["--version"]:
        print(version())
        return 0
    # Eine bekannte Option mit Zusatz: den Zusatz nennen, nicht die Option.
    known = arguments[0] in ("-h", "--help", "--version")
    problem = f"Zu viele Argumente: {arguments[1]}" if known else f"Unbekanntes Argument {arguments[0]}"
    print(f"{problem}\nbashlib --help", file=sys.stderr)
    return 2
