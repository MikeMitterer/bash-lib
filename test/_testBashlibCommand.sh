#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Prüft den Befehl bashlib (Version und Befehle des pip-Pakets) ohne Installation.
# Ein nachgebautes dist-info-Verzeichnis stellt die Metadaten wie nach
# pip install bereit, mit den Befehlen aus pyproject.toml und einem zusätzlichen
# bashlib-demo: Er muss ohne zweite Pflegestelle in der Ausgabe erscheinen.
# Aufruf: bash test/_testBashlibCommand.sh (auch über testAll.sh).
# Python wird für den Befehl selbst und für das Pseudoterminal benötigt.
#------------------------------------------------------------------------------
set -euo pipefail
BASHLIB_TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export BASHLIB_TEST_ROOT
python3 - <<'PY'
import errno
import os
from pathlib import Path
import pty
import re
import subprocess
import sys
import tempfile

root = Path(os.environ['BASHLIB_TEST_ROOT'])
scripts = re.search(r'^\[project\.scripts\]\n((?:[a-z].*\n)+)', (root / 'pyproject.toml').read_text(), re.M)
entries = [line.replace('"', '') for line in scripts.group(1).splitlines()]  # wie pip in entry_points.txt
names = [line.split('=')[0].strip() for line in entries]
assert 'bashlib' in names and 'bashlib-path' in names, names
theme = '''C_HEAD=bold+5
C_KEY=6
C_TEXT=7
C_VAL=8
C_HINT=dim
C_ACC=9
C_OK=2
C_WARN=3
C_ERR=1
C_MARK=4
I_HEAD=1
I_ROW=3
I_HINT=3
W_KEY=14
GAP=3
WIDTH=80
SPACE=1
'''
with tempfile.TemporaryDirectory(prefix='bashlib-command-') as scratch:
    base = Path(scratch)
    info = base / 'site' / 'mmit_bashlib-9.8.7.dist-info'
    info.mkdir(parents=True)
    (info / 'METADATA').write_text('Metadata-Version: 2.1\nName: mmit-bashlib\nVersion: 9.8.7\nSummary: Testpaket\n')
    (info / 'entry_points.txt').write_text('[console_scripts]\n' + '\n'.join(entries) + '\nbashlib-demo = demo:run\n')
    (base / 'site' / 'demo.py').write_text('def run():\n    """Nur im Test vorhanden.\n\n    Zweite Zeile zählt nicht."""\n')
    (base / 'cli-theme').mkdir()
    (base / 'cli-theme' / 'probe.theme').write_text(theme)
    env = {'PATH': os.environ['PATH'], 'HOME': str(base), 'XDG_CONFIG_HOME': str(base),
           'PYTHONPATH': f"{base / 'site'}:{root / 'python'}", 'TERM': 'xterm-256color'}
    command = [sys.executable, '-S', '-c', 'import sys; from bashlib import cli; sys.exit(cli())']

    def run(*args, terminal=False, extra=None, code=0):
        settings = dict(env, **(extra or {}))
        if not terminal:
            result = subprocess.run(command + list(args), env=settings, capture_output=True, text=True, timeout=10)
            assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
            return result.stdout, result.stderr
        master, slave = pty.openpty()
        child = subprocess.Popen(command + list(args), env=settings, stdout=slave, stderr=slave)
        os.close(slave)
        chunks = []
        try:
            while True:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                chunks.append(chunk)
        finally:
            os.close(master)
        assert child.wait(timeout=10) == code
        return b''.join(chunks).decode().replace('\r\n', '\n'), ''

    # Ohne Theme-Datei: classic-Abstände, keine Farben, Version und Beschreibung aus den Metadaten.
    out, err = run()
    assert not err, err
    assert '\x1b' not in out
    lines = out.splitlines()
    assert lines[:4] == ['', '  Aufruf: bashlib [--version] [-h]', '       BashLib 9.8.7 – Testpaket',
                         '       Hilfe zu einem Befehl: <befehl> --help'], out
    headings = [line.strip() for line in lines if line.startswith('  ') and not line.startswith('   ')]
    assert headings == ['Aufruf: bashlib [--version] [-h]', 'Befehle', 'Optionen', 'Umgebung'], headings
    section = lambda title: lines[lines.index('  ' + title) + 1:]
    commands = []
    for line in section('Befehle'):
        if not line.strip():
            break
        commands.append(line)
    rows = {line.split()[0]: line for line in commands}
    assert sorted(rows) == sorted([name for name in names if name != 'bashlib'] + ['bashlib-demo']), rows
    assert 'bashlib' not in rows, 'bashlib steht nicht in der eigenen Befehlsliste'
    for name, line in rows.items():
        assert line.startswith('       ' + name + ' '), line
        assert line.index(line.split(None, 1)[1]) == 30, line
    assert rows['bashlib-demo'].endswith('Nur im Test vorhanden.'), rows['bashlib-demo']
    options = section('Optionen')[:2]
    assert options == ['            --version         Zeigt die installierte Version.',
                       '       -h | --help            Zeigt diese Hilfe.'], options
    assert out.endswith('\n\n'), repr(out)
    for option in ('-h', '--help'):
        assert run(option)[0] == out, option

    # Mit Theme-Datei am Terminal: Farben und Abstände aus der Datei, Platzhalter in C_ACC.
    out, _ = run(terminal=True, extra={'CLI_THEME': 'probe'})
    assert '\x1b[1;38;5;5mAufruf: bashlib [--version] [-h]\x1b[0m' in out, out
    assert '\x1b[1;38;5;5mBefehle\x1b[0m' in out, out
    assert '\n   \x1b[38;5;6mbashlib-path\x1b[0m     \x1b[38;5;7m' in out, out
    assert '\x1b[38;5;9m<befehl>\x1b[2m --help' in out, out
    plain, _ = run(terminal=True, extra={'CLI_THEME': 'probe', 'NO_COLOR': ''})
    assert '\x1b' not in plain and '\n   bashlib-path     ' in plain, plain

    # Version und Fehler.
    assert run('--version')[0] == '9.8.7\n'
    out, err = run('--unbekannt', code=2)
    assert not out and err == 'Unbekanntes Argument --unbekannt\nbashlib --help\n', err
    for option in ('--version', '-h', '--help'):
        out, err = run(option, 'x', code=2)
        assert not out and err == 'Zu viele Argumente: x\nbashlib --help\n', (option, err)

    # Ohne Metadaten (nicht installiert): Version aus pyproject.toml.
    (info / 'METADATA').unlink()
    (info / 'entry_points.txt').unlink()
    info.rmdir()
    version = re.search(r'^version = "(.*)"$', (root / 'pyproject.toml').read_text(), re.M).group(1)
    out, _ = run()
    summary = re.search(r'^description = "(.*)"$', (root / 'pyproject.toml').read_text(), re.M).group(1)
    assert f'       BashLib {version} – {summary}\n' in out, out
    assert 'bashlib-path' in out and 'bashlib-demo' not in out and '       bashlib ' not in out, out
    print('bashlib: Version, Befehle aus einer Quelle, Theme, Hilfe bestanden')
PY
