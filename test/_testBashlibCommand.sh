#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Prüft die Befehle bashlib und bashlib-path (Bash-Skripte unter bin/) ohne
# Installation. Eine nachgebaute venv stellt das Paket wie nach pipx install
# bereit, mit Links wie in ~/.local/bin und einem toten bin/python wie nach einem
# Python-Wechsel von Homebrew: Beide Befehle laufen trotzdem. Das dist-info nennt
# die Befehle aus pyproject.toml und ein zusätzliches bashlib-demo: Es muss ohne
# zweite Pflegestelle in der Ausgabe erscheinen. Dazu bashlib-path in einer
# editierbaren venv (direct_url.json), auch unter /bin/bash, und ohne Paket.
# Aufruf: bash test/_testBashlibCommand.sh (auch über testAll.sh).
# Python steuert den Test und das Pseudoterminal; die Befehle laufen ohne.
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
import shutil
import subprocess
import sys
import tempfile

root = Path(os.environ['BASHLIB_TEST_ROOT'])
files = re.search(r'^script-files = \[(.*)\]$', (root / 'pyproject.toml').read_text(), re.M)
scripts = re.findall(r'"([^"]+)"', files.group(1))
names = [Path(script).name for script in scripts]
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
    base = Path(scratch).resolve()
    # venv wie nach pipx install aus dem Wheel: Skripte in bin/, Bibliotheken im Paket, dist-info
    # mit RECORD; bin/python zeigt ins Leere (Interpreter entfernt)
    venv = base / 'venv'
    site = venv / 'lib' / 'python3.99' / 'site-packages'
    (site / 'bashlib').mkdir(parents=True)
    (site / 'bashlib' / 'lib').symlink_to(root / 'src', target_is_directory=True)
    (venv / 'bin').mkdir()
    (venv / 'bin' / 'python').symlink_to(base / 'entfernt' / 'python3.99')
    for script in scripts:
        shutil.copy(root / script, venv / 'bin')
    demo = venv / 'bin' / 'bashlib-demo'
    demo.write_text('#!/usr/bin/env bash\n# Für Agenten (bashlib --skill):\n#     Zweck:   Nur im Test vorhanden.\n'
                    '#     Wirkung: liest\n#     Wann:    nur im Test.\n#\n#     Zweite: zählt nicht.\n')
    demo.chmod(0o755)
    info = site / 'mmit_bashlib-9.8.7.dist-info'
    info.mkdir()
    (info / 'METADATA').write_text('Metadata-Version: 2.1\nName: mmit-bashlib\nVersion: 9.8.7\nSummary: Testpaket\n')
    (info / 'RECORD').write_text(''.join(f'../../../bin/{name},sha256=x,1\n' for name in names + ['bashlib-demo'])
                                 + 'bashlib/__init__.py,sha256=x,1\n')
    # Links wie pipx in ~/.local/bin
    links = base / 'local-bin'
    links.mkdir()
    for name in names + ['bashlib-demo']:
        (links / name).symlink_to(venv / 'bin' / name)
    (base / 'clitheme').mkdir()
    (base / 'clitheme' / 'probe.theme').write_text(theme)
    env = {'PATH': os.environ['PATH'], 'HOME': str(base), 'XDG_CONFIG_HOME': str(base),
           'XDG_CACHE_HOME': str(base / 'cache'), 'TERM': 'xterm-256color'}
    command = [str(links / 'bashlib')]

    def run(*args, terminal=False, extra=None, code=0, cwd=None, command=command):
        settings = dict(env, **(extra or {}))
        if not terminal:
            result = subprocess.run(command + list(args), env=settings, capture_output=True, text=True,
                                    timeout=10, cwd=cwd)
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
    assert lines[:4] == ['', '  Aufruf: bashlib [--version] [--skill] [-h]', '       BashLib 9.8.7 – Testpaket',
                         '       Hilfe zu einem Befehl: <befehl> --help'], out
    headings = [line.strip() for line in lines if line.startswith('  ') and not line.startswith('   ')]
    assert headings == ['Aufruf: bashlib [--version] [--skill] [-h]', 'Befehle', 'Optionen', 'Umgebung'], headings
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
    options = section('Optionen')[:3]
    assert options == ['            --version         Zeigt die installierte Version.',
                       '            --skill           Beschreibt Befehle und Bibliotheken für KI-Agenten (Markdown).',
                       '       -h | --help            Zeigt diese Hilfe.'], options
    assert out.endswith('\n\n'), repr(out)
    for option in ('-h', '--help'):
        assert run(option)[0] == out, option

    # Mit Theme-Datei am Terminal: Farben und Abstände aus der Datei, Platzhalter in C_ACC.
    out, _ = run(terminal=True, extra={'CLI_THEME': 'probe'})
    assert '\x1b[1;38;5;5mAufruf: bashlib [--version] [--skill] [-h]\x1b[0m' in out, out
    assert '\x1b[1;38;5;5mBefehle\x1b[0m' in out, out
    assert '\n   \x1b[38;5;6mbashlib-path\x1b[0m     \x1b[38;5;7m' in out, out
    # Nach dem Platzhalter erst zurücksetzen, dann wieder C_HINT (dim setzt keine Vordergrundfarbe)
    assert '\x1b[38;5;9m<befehl>\x1b[0m\x1b[2m --help' in out, out
    plain, _ = run(terminal=True, extra={'CLI_THEME': 'probe', 'NO_COLOR': ''})
    assert '\x1b' not in plain and '\n   bashlib-path     ' in plain, plain

    # --skill: Markdown für Agenten nach der Vorgabe im tools-Skill, Befehle aus den Metadaten,
    # Bibliotheken aus dem Kopf jeder *.lib.sh; schreibt nichts, auch am Terminal ohne Farben.
    work = base / 'work'
    work.mkdir()
    out, err = run('--skill', cwd=work)
    assert not err and list(work.iterdir()) == [], (err, list(work.iterdir()))
    lines = out.splitlines()
    assert out.startswith('# bashlib\n\n') and 'Version 9.8.7' in out.split('\n## ')[0], out[:200]
    assert [line for line in lines if line.startswith('## ')] == \
        ['## Befehle', '## Beispiele', '## Bibliotheken', '## Voraussetzungen'], out
    assert len(lines) < 60, len(lines)
    block = lambda title: [line for line in out.split(f'## {title}\n', 1)[1].split('\n## ', 1)[0].splitlines() if line]
    effects = {'liest', 'schreibt', 'beendet', 'git', 'veröffentlicht'}
    listed = []
    for line in block('Befehle'):
        match = re.fullmatch(r'- `([a-z-]+)` \(([^)]+)\): [^.].*[^.]\. Wann: .+[^.]\.', line)
        assert match and set(match[2].split(', ')) <= effects, line
        listed.append(match[1])
    assert sorted(listed) == sorted([name for name in names if name != 'bashlib'] + ['bashlib-demo']), listed
    assert '- `bashlib-demo` (liest): Nur im Test vorhanden. Wann: nur im Test.' in lines, out
    libraries = []
    for line in block('Bibliotheken'):
        match = re.fullmatch(r'- `([a-z]+\.lib\.sh)`: .+[^.]\. Wann: .+[^.]\. Wichtig: (`\w+`(?:, `\w+`)*)', line)
        assert match, line
        source = (root / 'src' / match[1]).read_text()
        for name in re.findall(r'`(\w+)`', match[2]):
            # Funktion oder Variable, die in genau dieser Bibliothek definiert ist.
            assert re.search(rf'^(?:function\s+)?{name}\(\)|(?:^\s*|\breadonly\s+|\bexport\s+){name}=', source, re.M), \
                (match[1], name)
        libraries.append(match[1])
    assert libraries == sorted(path.name for path in (root / 'src').glob('*.lib.sh')), libraries
    assert '```sh' in block('Beispiele') and 'bashlib-path' in out.split('## Beispiele', 1)[1], out
    tty, _ = run('--skill', terminal=True, extra={'CLI_THEME': 'probe'})
    assert tty == out and '\x1b' not in tty, repr(tty[:200])

    # Version und Fehler.
    assert run('--version')[0] == '9.8.7\n'
    out, err = run('--unbekannt', code=2)
    assert not out and err == 'Unbekanntes Argument --unbekannt\nbashlib --help\n', err
    for option in ('--version', '--skill', '-h', '--help'):
        out, err = run(option, 'x', code=2)
        assert not out and err == 'Zu viele Argumente: x\nbashlib --help\n', (option, err)

    # bashlib-path: Bibliotheken im Paket, auch über den Link und mit totem Interpreter.
    assert run(command=[str(links / 'bashlib-path')])[0] == f'{site}/bashlib/lib\n'
    assert not (venv / 'bin' / 'python').exists()
    out, err = run('-h', command=[str(links / 'bashlib-path')])
    assert not out and err == 'Aufruf: bashlib-path  (gibt das Verzeichnis der *.lib.sh aus)\n', err
    run('x', code=2, command=[str(links / 'bashlib-path')])

    # Editierbar (pipx install -e): direct_url.json nennt den Klon als file://-URL, hier mit
    # Leerzeichen im Pfad; bashlib-path liefert dessen src/, auch unter /bin/bash (macOS 3.2).
    clone = base / 'Klon mit Leerzeichen'
    (clone / 'bin').mkdir(parents=True)
    (clone / 'src').symlink_to(root / 'src', target_is_directory=True)
    shutil.copy(root / 'pyproject.toml', clone)
    for script in scripts:
        shutil.copy(root / script, clone / 'bin')
    editable = base / 'venv-e'
    (editable / 'bin').mkdir(parents=True)
    (editable / 'bin' / 'python').symlink_to(base / 'entfernt' / 'python3.99')
    for script in scripts:
        shutil.copy(root / script, editable / 'bin')
    info_e = editable / 'lib' / 'python3.99' / 'site-packages' / 'mmit_bashlib-0.0.1.dist-info'
    info_e.mkdir(parents=True)
    (info_e / 'METADATA').write_text('Metadata-Version: 2.1\nName: mmit-bashlib\nVersion: 0.0.1\n')
    (info_e / 'direct_url.json').write_text(f'{{"dir_info": {{"editable": true}}, "url": "{clone.as_uri()}"}}')
    assert '%20' in clone.as_uri()
    for shell in (['bash'], ['/bin/bash']):
        assert run(command=[*shell, str(editable / 'bin' / 'bashlib-path')])[0] == f'{clone}/src\n', shell
    # Die Kopie von bashlib in der venv stammt vom Installieren; es gilt der Stand im Klon.
    stale = editable / 'bin' / 'bashlib'
    stale.write_text(stale.read_text().replace('Zeigt diese Hilfe.', 'Alter Stand.'))
    assert 'Zeigt diese Hilfe.' in run(command=[str(stale)])[0]

    # Ohne Paket neben dem Skript: Exit 1 mit Grund.
    (base / 'leer' / 'bin').mkdir(parents=True)
    shutil.copy(root / 'bin' / 'bashlib-path', base / 'leer' / 'bin')
    out, err = run(code=1, command=[str(base / 'leer' / 'bin' / 'bashlib-path')])
    assert not out and 'keine tools.lib.sh' in err, err

    # Im Checkout (nicht installiert): Version und Befehle aus pyproject.toml.
    version = re.search(r'^version = "(.*)"$', (root / 'pyproject.toml').read_text(), re.M).group(1)
    out, _ = run(command=[str(root / 'bin' / 'bashlib')])
    summary = re.search(r'^description = "(.*)"$', (root / 'pyproject.toml').read_text(), re.M).group(1)
    assert f'       BashLib {version} – {summary}\n' in out, out
    assert 'bashlib-path' in out and 'bashlib-demo' not in out and '       bashlib ' not in out, out
    print('bashlib, bashlib-path: ohne Python, Version, Befehle aus einer Quelle, Theme, Hilfe, --skill bestanden')
PY
