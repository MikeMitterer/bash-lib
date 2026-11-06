#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Prüft, wie colors.lib.sh das Theme von clitheme übernimmt, und die echte
# Terminalausgabe in einer isolierten Umgebung.
#
# Die meisten Fälle laufen mit einem nachgebauten clitheme (test/clitheme-fake),
# das eine vorgegebene Ausgabe von `clitheme export --bash` liefert. Ist das echte
# clitheme installiert, prüft ein Vertragstest es mit eigenem XDG_CONFIG_HOME.
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
import shlex
import shutil
import subprocess
import tempfile

root = Path(os.environ['THEME_TEST_ROOT'])
ESC = '\x1b'
# Ausgabe von clitheme export --bash für classic, wie clitheme 0.5.0 sie liefert
CLASSIC = {
    'THEME_NAME': 'classic', 'THEME_ORIGIN': 'default', 'THEME_NOTICE': '',
    'THEME_COLOR_GROUP': ESC + '[1;38;5;11m', 'THEME_COLOR_TARGET': ESC + '[38;5;33m',
    'THEME_COLOR_DESC': ESC + '[38;5;10m', 'THEME_COLOR_VALUE': ESC + '[38;5;10m',
    'THEME_COLOR_HINT': ESC + '[2m', 'THEME_COLOR_ACCENT': ESC + '[38;5;14m',
    'THEME_COLOR_SUCCESS': ESC + '[38;5;10m', 'THEME_COLOR_WARNING': ESC + '[38;5;208m',
    'THEME_COLOR_DANGER': ESC + '[1;38;5;196m', 'THEME_COLOR_SERVER': ESC + '[38;5;13m',
    'THEME_INDENT_GROUP': '  ', 'THEME_INDENT_TARGET': '       ', 'THEME_INDENT_HINT': '       ',
    'THEME_WIDTH_TARGET': '21', 'THEME_COLUMN_GAP': '2', 'THEME_WIDTH_HELP': '120',
    'THEME_GROUP_SPACING': '1',
}
bash_dir = os.path.dirname(shutil.which('bash'))
real_clitheme = shutil.which('clitheme')

with tempfile.TemporaryDirectory(prefix='bashlib-theme-') as scratch:
    base = Path(scratch)
    fake_bin = base / 'bin'
    fake_bin.mkdir()
    (fake_bin / 'clitheme').symlink_to(root / 'test' / 'clitheme-fake')
    export = base / 'export.sh'

    def write_export(**changes):
        values = dict(CLASSIC, THEME_SOURCE=str(base / 'clitheme' / 'classic.theme'), **changes)
        export.write_text('# clitheme export --bash\n' + ''.join(
            f'{name}={shlex.quote(value)}\n' for name, value in values.items()))

    # Ohne ~/.local/bin: nur das nachgebaute clitheme; die Bash aus dem PATH vor /bin/bash
    with_fake = f'{fake_bin}:{bash_dir}:/usr/bin:/bin'
    without = f'{bash_dir}:/usr/bin:/bin'
    env = {'PATH': with_fake, 'HOME': str(base), 'XDG_CONFIG_HOME': str(base),
           'XDG_CACHE_HOME': str(base / 'cache'), 'BASH_LIBS': str(root / 'src'),
           'TERM': 'xterm-256color', 'FAKE_CLITHEME_EXPORT': str(export)}

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

    write_export()

    # Werte aus clitheme export; Farben als Escape-Text wie die Palette
    assert run('printf "%s|%s|%s|%s" "$THEME_NAME" "$THEME_ORIGIN" "$THEME_WIDTH_TARGET" "${#THEME_INDENT_TARGET}"') \
        == 'classic|default|21|7'
    assert run('printf "%s|%s|%s" "$THEME_COLOR_GROUP" "$THEME_COLOR_SERVER" "$C_OFF"') \
        == r'\x1B[1;38;5;11m|\x1B[38;5;13m|\x1B[0m'
    assert run('printf "%s" "$THEME_SOURCE"') == str(base / 'clitheme' / 'classic.theme')
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

    # Befund von clitheme (etwa fehlende Theme-Datei): einmal am Terminal, nicht in der Pipe.
    write_export(THEME_NOTICE='Theme file missing: /x/classic.theme\nclitheme install',
                 **{name: '' for name in CLASSIC if name.startswith('THEME_COLOR_')})
    missing = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True)
    assert missing.count('clitheme install') == 1 and '\x1b' not in missing, missing
    assert run('printThemeRow opt Text') == '       opt                    Text\n'

    # Werte von clitheme werden nie ausgeführt, auch nicht im Hinweis.
    write_export(THEME_NOTICE=f'$(touch {base}/executed) `touch {base}/executed`\nclitheme show')
    assert '$(touch' in run('printThemeRow opt Text', terminal=True)
    assert not (base / 'executed').exists()
    write_export()

    # Ohne clitheme im PATH oder wenn clitheme scheitert: keine Farben, Ersatzabstände,
    # einmal ein Hinweis mit Installationsbefehl am Terminal, in der Pipe nichts auf stderr.
    for extra in ({'PATH': without}, {'FAKE_CLITHEME_FAIL': '1'}):
        assert run('printf "%s|%s|%s" "$THEME_COLOR_GROUP" "$THEME_WIDTH_TARGET" "$THEME_COLUMN_GAP"', extra=extra) \
            == '|21|2'
        assert run('printThemeRow opt Text', extra=extra) == '       opt                    Text\n'
        plain = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True, extra=extra)
        assert '\x1b' not in plain and plain.count('pipx install git+https://github.com/MikeMitterer/python-clitheme.git') == 1, plain

    # Vertrag mit dem echten clitheme: gleiche Werte wie oben, Auswahl über CLI_THEME.
    if real_clitheme is None:
        print('Theme: clitheme nicht installiert, Vertragstest übersprungen')
    else:
        real_bin = base / 'real-bin'
        real_bin.mkdir()
        (real_bin / 'clitheme').symlink_to(real_clitheme)
        real = {'PATH': f'{real_bin}:{bash_dir}:/usr/bin:/bin'}
        subprocess.run([real_clitheme, 'install'], env=dict(env, **real), capture_output=True, check=True, timeout=30)
        assert run('printf "%s|%s" "$THEME_COLOR_GROUP" "$THEME_SOURCE"', extra=real) \
            == r'\x1B[1;38;5;11m|' + str(base / 'clitheme' / 'classic.theme')
        assert run('printThemeRow opt Text', extra=real) == '       opt                    Text\n'
        assert '\x1b[1;38;5;15mTitel' in run('printThemeHeading Titel', terminal=True, extra=dict(real, CLI_THEME='mono'))
        assert run('printf "%s|%s" "$THEME_NAME" "$THEME_ORIGIN"', extra=dict(real, CLI_THEME='mono')) == 'mono|CLI_THEME'
        print('Theme: Vertrag mit clitheme bestanden')
    print('Theme: Übernahme aus clitheme export, eigene Werte, Fehlerfälle und PTY-Ausgabe bestanden')
PY
