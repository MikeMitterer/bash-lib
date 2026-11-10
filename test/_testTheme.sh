#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Prüft, wie colors.lib.sh das Theme von clitheme übernimmt, und die echte
# Terminalausgabe in einer isolierten Umgebung: echtes clitheme mit eigenem
# XDG_CONFIG_HOME und XDG_CACHE_HOME; ohne clitheme schlägt der Test fehl.
# Aufruf: bash test/_testTheme.sh (auch über testAll.sh).
# Python wird nur für den Testtreiber und dessen Pseudoterminal benötigt.
#------------------------------------------------------------------------------
set -euo pipefail
THEME_TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export THEME_TEST_ROOT
python3 - <<'PY'
import errno
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile

root = Path(os.environ['THEME_TEST_ROOT'])
bash_dir = os.path.dirname(shutil.which('bash'))
clitheme = shutil.which('clitheme')
assert clitheme, 'clitheme fehlt: pipx install git+https://github.com/MikeMitterer/python-clitheme.git'

with tempfile.TemporaryDirectory(prefix='bashlib-theme-') as scratch:
    base = Path(scratch)
    # Eigenes bin nur mit clitheme; die Bash aus dem PATH vor /bin/bash
    tool_bin = base / 'bin'
    tool_bin.mkdir()
    (tool_bin / 'clitheme').symlink_to(clitheme)
    with_clitheme = f'{tool_bin}:{bash_dir}:/usr/bin:/bin'
    without = f'{bash_dir}:/usr/bin:/bin'
    env = {'PATH': with_clitheme, 'HOME': str(base), 'XDG_CONFIG_HOME': str(base),
           'XDG_CACHE_HOME': str(base / 'cache'), 'BASH_LIBS': str(root / 'src'),
           'TERM': 'xterm-256color'}
    subprocess.run(['clitheme', 'install'], env=env, capture_output=True, check=True, timeout=30)
    theme = base / 'clitheme' / 'classic.theme'

    def run(code, *, terminal=False, extra=None, setup='', stderr_ok=False):
        command = ['bash', '-euo', 'pipefail', '-c', setup + '\nsource "$BASH_LIBS/tools.lib.sh"\n' + code]
        settings = dict(env, **(extra or {}))
        if not terminal:
            result = subprocess.run(command, env=settings, capture_output=True, text=True, timeout=10)
            assert result.returncode == 0, (code, result.stderr)
            assert stderr_ok or not result.stderr, result.stderr
            return result.stdout
        master, slave = pty.openpty()
        child = subprocess.Popen(command, env=settings, stdin=subprocess.DEVNULL, stdout=slave, stderr=slave)
        os.close(slave)
        chunks = []
        try:
            while True:
                try:
                    chunk = os.read(master, 65536)
                    if not chunk:
                        break
                    chunks.append(chunk)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
        finally:
            os.close(master)
        assert child.wait(timeout=10) == 0
        return b''.join(chunks).decode().replace('\r\n', '\n')

    # Werte aus clitheme export; Farben als Escape-Text wie die Palette
    assert run('printf "%s|%s|%s|%s" "$THEME_NAME" "$THEME_ORIGIN" "$THEME_WIDTH_TARGET" "${#THEME_INDENT_TARGET}"') \
        == 'classic|default|21|7'
    assert run('printf "%s|%s|%s" "$THEME_COLOR_GROUP" "$THEME_COLOR_SERVER" "$C_OFF"') \
        == r'\x1B[1;38;5;11m|\x1B[38;5;13m|\x1B[0m'
    assert run('printf "%s" "$THEME_SOURCE"') == str(theme)
    assert '\x1b[1;38;5;15mTitel' in run('printThemeHeading Titel', terminal=True, extra={'CLI_THEME': 'mono'})
    assert run('printf "%s|%s" "$THEME_NAME" "$THEME_ORIGIN"', extra={'CLI_THEME': 'mono'}) == 'mono|CLI_THEME'
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    assert run('printThemeHeading Titel') == '\n  Titel\n'
    colored = run('printThemeHeading Titel; printThemeRow opt Text; printThemeStatus + Gut OK; '
                  'printThemeStatus ! Warn WARN; printThemeStatus x Fehler ERR', terminal=True)
    assert '\x1b[1;38;5;11mTitel\x1b[0m' in colored
    for value in ('38;5;33', '38;5;10', '38;5;208', '1;38;5;196'):
        assert f'\x1b[{value}m' in colored, value

    # themeAccent liefert Escape-Text: über themeStyle umgesetzt bzw. entfernt, mit echo roh.
    accent = 'themeStyle "x $(themeAccent N) y" "$THEME_COLOR_DESC"'
    assert run(accent) == 'x N y'
    assert '\x1b[38;5;10mx \x1b[38;5;14mN\x1b[0m\x1b[38;5;10m y\x1b[0m' in run(accent, terminal=True)
    assert run('echo "$(themeAccent N)"') == '\\x1B[38;5;14mN\\x1B[0m\\x1B[38;5;10m\n'
    for extra in ({'NO_COLOR': ''}, {'TERM': 'dumb'}):
        assert '\x1b' not in run('usageLine "${RED}opt${NC}" "${GREEN}Text${NC}"', terminal=True, extra=extra)
    assert run('usageLine "${RED}opt${NC}" Text yes') == '       opt                        Text\n'
    assert run('usageLine opt Text intend') == run('usageLine opt Text 4')

    # Eigene THEME_*-Werte des Skripts gewinnen; geerbte, exportierte zählen nicht.
    assert run('printThemeRow opt Text', setup='THEME_INDENT_TARGET=""; THEME_WIDTH_TARGET=5; THEME_COLUMN_GAP=3') \
        == 'opt     Text\n'
    assert '\x1b[35mTitel' in run('printThemeHeading Titel', terminal=True, setup="THEME_COLOR_GROUP='\\033[35m'")
    assert '\x1b[35mTitel' in run('printThemeHeading Titel', terminal=True, setup="THEME_COLOR_GROUP='\\x1B[35m'")
    inherited = {'THEME_WIDTH_TARGET': '5', 'THEME_COLUMN_GAP': '3', 'THEME_INDENT_TARGET': '',
                 'THEME_COLOR_GROUP': '\\033[35m', 'THEME_GROUP_SPACING': '3'}
    assert run('printThemeRow opt Text', extra=inherited) == '       opt                    Text\n'
    assert '\x1b[1;38;5;11mTitel' in run('printThemeHeading Titel', terminal=True, extra=inherited)
    assert run('printThemeHeading Titel', extra=inherited) == '\n  Titel\n'
    palette = run('printf "%s|%s|%s" "$RED" "$NC" "$GREP_COLOR_GREEN"')
    assert palette == r'\x1B[38;5;196m|\x1B[0m|38;5;10'

    # Kein eigener Theme-Leser mehr: Funktionen und MAKE_THEME entfallen.
    assert run('declare -F themeRead themeSgr || true') == ''
    assert run('printf "%s" "${C_HEAD-unset}|${W_KEY-unset}|${THEME_CLASSIC_SPACING-unset}"') == 'unset|unset|unset'
    assert run('printf "%s" "$THEME_COLOR_GROUP"', extra={'MAKE_THEME': 'mono'}) == r'\x1B[1;38;5;11m'

    # Befund von clitheme (fehlende Theme-Datei): einmal am Terminal, nicht in der Pipe.
    classic = theme.read_text()
    theme.unlink()
    missing = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True)
    assert missing.count('clitheme install') == 1 and '\x1b' not in missing, missing
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    theme.write_text(classic)

    # Werte von clitheme werden nie ausgeführt: ein Pfad mit $(…) und Backticks im Befund.
    hostile = base / '$(touch executed) `touch executed`'
    hostile.mkdir()
    result = run('printThemeRow opt Text', terminal=True,
                 extra={'XDG_CONFIG_HOME': str(hostile), 'XDG_CACHE_HOME': str(hostile / 'cache')})
    assert '$(touch executed)' in result, result
    assert not (base / 'executed').exists() and not Path('executed').exists()

    # Geerbter Export (CLITHEME_EXPORT, aus Make mit Leerzeichen statt Zeilenumbrüchen):
    # übernommen ohne clitheme-Aufruf; mit fremdem Namen, einer Farbe, die keine SGR-Folge
    # ist, oder einem Hinweis gilt er nicht, dann fragt themeLoad clitheme selbst.
    exported = subprocess.run(['clitheme', 'export', '--bash'], env=dict(env, CLI_THEME='mono'),
                              capture_output=True, text=True, check=True, timeout=30).stdout
    collapsed = exported.replace('\n', ' ').strip()
    show = 'printf "%s|%s" "$THEME_NAME" "$THEME_COLOR_GROUP"'
    assert run(show, extra={'PATH': without, 'CLITHEME_EXPORT': collapsed}) == r'mono|\x1B[1;38;5;15m'
    assert run(show, extra={'CLITHEME_EXPORT': exported}) == r'mono|\x1B[1;38;5;15m'
    for refused in (collapsed + ' PATH=/nowhere', collapsed + ' THEME_EVIL=x',
                    collapsed.replace("THEME_COLOR_GROUP='\x1b[1;38;5;15m'", "THEME_COLOR_GROUP='\x1b]0;x\x07'"),
                    collapsed.replace("THEME_COLOR_GROUP='\x1b[1;38;5;15m'", ''),
                    collapsed.replace('THEME_ORIGIN=CLI_THEME', "THEME_ORIGIN='\x1b]0;x\x07'"),
                    collapsed.replace("THEME_NOTICE=''", "THEME_NOTICE='Befund clitheme install'")):
        assert refused != collapsed
        assert run(show, extra={'CLITHEME_EXPORT': refused}) == r'classic|\x1B[1;38;5;11m', refused
    origin = collapsed.replace('THEME_ORIGIN=CLI_THEME', "THEME_ORIGIN='$(touch executed) `touch executed`'")
    assert origin != collapsed
    assert run('printf "%s" "$THEME_ORIGIN"', extra={'CLITHEME_EXPORT': origin}) == '$(touch executed) `touch executed`'
    assert not (base / 'executed').exists() and not Path('executed').exists()

    # Ohne clitheme im PATH: keine Farben, Ersatzabstände, einmal ein Hinweis mit
    # Installationsbefehl am Terminal, in der Pipe nichts auf stderr.
    extra = {'PATH': without}
    assert run('printf "%s|%s|%s" "$THEME_COLOR_GROUP" "$THEME_WIDTH_TARGET" "$THEME_COLUMN_GAP"', extra=extra) \
        == '|21|2'
    assert run('printThemeRow opt Text', extra=extra) == '       opt                    Text\n'
    plain = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True, extra=extra)
    assert '\x1b' not in plain and plain.count('pipx install git+https://github.com/MikeMitterer/python-clitheme.git') == 1, plain

    # Installiert, aber export scheitert: eigener Hinweis mit dem Aufruf, der den Grund zeigt.
    # Das echte clitheme scheitert auch mit kaputter Theme-Datei nicht; den Fehlerfall stellt
    # deshalb `false` unter dem Namen clitheme her (einziger Nachbau, L-200).
    broken_bin = base / 'broken-bin'
    broken_bin.mkdir()
    (broken_bin / 'clitheme').symlink_to(shutil.which('false'))
    extra = {'PATH': f'{broken_bin}:{without}'}
    assert run('printf "%s|%s" "$THEME_COLOR_GROUP" "$THEME_WIDTH_TARGET"', extra=extra) == '|21'
    broken = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True, extra=extra)
    assert '\x1b' not in broken and broken.count('clitheme export gescheitert') == 1, broken
    assert '\n       clitheme export --bash\n' in broken and 'pipx install' not in broken, broken

    print('Theme: Übernahme aus clitheme export, eigene Werte, Fehlerfälle und PTY-Ausgabe bestanden')
PY
