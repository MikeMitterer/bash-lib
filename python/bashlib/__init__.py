"""BashLib als Python-Paket: Ort der *.lib.sh fuer BASH_LIBS.

Die Befehle bashlib und bashlib-path sind Bash-Skripte unter bin/ (script-files in
pyproject.toml). Dieses Modul bleibt fuer Python-Werkzeuge, die BashLib als
Abhaengigkeit haben und BASH_LIBS mit lib_dir() setzen (etwa ProjectTools).
"""

from __future__ import annotations

from pathlib import Path


def lib_dir() -> Path:
    """Verzeichnis mit den *.lib.sh: im Paket, bei -e die Arbeitskopie (src/)."""
    here = Path(__file__).resolve().parent
    bundled = here / "lib"
    if (bundled / "tools.lib.sh").is_file():
        return bundled
    return here.parents[1] / "src"
