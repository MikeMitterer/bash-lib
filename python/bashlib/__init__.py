"""BashLib als Python-Paket: Ort der *.lib.sh fuer BASH_LIBS."""

from __future__ import annotations

import sys
from pathlib import Path


def lib_dir() -> Path:
    """Verzeichnis mit den *.lib.sh: im Paket, bei -e die Arbeitskopie (src/)."""
    here = Path(__file__).resolve().parent
    bundled = here / "lib"
    if (bundled / "tools.lib.sh").is_file():
        return bundled
    return here.parents[1] / "src"


def main() -> int:
    """bashlib-path: gibt das Verzeichnis aus, etwa fuer export BASH_LIBS=..."""
    if len(sys.argv) > 1:
        print("Aufruf: bashlib-path  (gibt das Verzeichnis der *.lib.sh aus)", file=sys.stderr)
        return 0 if sys.argv[1] in ("-h", "--help") else 2
    print(lib_dir())
    return 0
