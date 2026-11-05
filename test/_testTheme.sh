#!/usr/bin/env bash
#------------------------------------------------------------------------------
# Prüft Theme-Dateien und echte Terminalausgabe in einer isolierten Umgebung.
# Aufruf: bash test/_testTheme.sh (auch über testAll.sh).
# Python wird nur für den Testtreiber und dessen Pseudoterminal benötigt.
#------------------------------------------------------------------------------
set -euo pipefail
THEME_TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export THEME_TEST_ROOT
python3 - <<'PY'
import errno
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile

root = Path(os.environ['THEME_TEST_ROOT'])
classic = '''C_HEAD=bold+11
C_KEY=33
C_TEXT=10
C_VAL=10
C_HINT=dim
C_ACC=14
C_OK=10
C_WARN=208
C_ERR=bold+196
C_MARK=13
I_HEAD=2
I_ROW=7
I_HINT=7
W_KEY=21
GAP=2
WIDTH=120
SPACE=1
'''
with tempfile.TemporaryDirectory(prefix='bashlib-theme-') as scratch:
    base = Path(scratch)
    folder = base / 'cli-theme'
    folder.mkdir()
    theme = folder / 'classic.theme'
    theme.write_text(classic)
    (folder / 'mono.theme').write_text(classic.replace('bold+11', 'bold').replace('C_KEY=33', 'C_KEY='))
    env = {'PATH': os.environ['PATH'], 'HOME': str(base), 'XDG_CONFIG_HOME': str(base),
           'BASH_LIBS': str(root / 'src'), 'TERM': 'xterm-256color'}
    def run(code, *, terminal=False, extra=None, setup=''):
        command = ['bash', '-euo', 'pipefail', '-c', setup + '\nsource "$BASH_LIBS/tools.lib.sh"\n' + code]
        settings = dict(env, **(extra or {}))
        if not terminal:
            result = subprocess.run(command, env=settings, capture_output=True, text=True, timeout=5)
            assert result.returncode == 0, (code, result.stderr)
            assert not result.stderr, result.stderr
            return result.stdout
        master, slave = pty.openpty()
        child = subprocess.Popen(command, env=settings, stdout=slave, stderr=slave)
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
        assert child.wait(timeout=5) == 0
        return b''.join(chunks).decode().replace('\r\n', '\n')

    assert run('printf "%s|%s|%s|%s" "${C_HEAD-}" "${W_KEY-}" "${GAP-}" "${WIDTH-}"') == 'bold+11|21|2|120', 'Theme-Datei wurde nicht geladen'
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    assert run('printThemeHeading Titel') == '\n  Titel\n'
    colored = run('printThemeHeading Titel; printThemeRow opt Text; printThemeStatus + Gut OK; printThemeStatus ! Warn WARN; printThemeStatus x Fehler ERR', terminal=True)
    assert '\x1b[1;38;5;11mTitel\x1b[0m' in colored
    for value in ('38;5;33', '38;5;10', '38;5;208', '1;38;5;196'):
        assert f'\x1b[{value}m' in colored, value
    assert '\x1b[1mTitel' in run('printThemeHeading Titel', terminal=True, extra={'CLI_THEME': 'mono'})
    assert '\x1b[1mTitel' in run('printThemeHeading Titel', terminal=True, extra={'MAKE_THEME': 'mono'})
    assert run('printf "%s|%s" "$THEME_NAME" "$THEME_SOURCE"', extra={'MAKE_THEME': 'mono'}) == f'mono|{folder}/mono.theme'
    assert run('printf "%s|%s" "$THEME_NAME" "$THEME_SOURCE"') == f'classic|{theme}'
    assert '\x1b[1;38;5;11m' in run('printThemeHeading Titel', terminal=True, extra={'CLI_THEME': 'classic', 'MAKE_THEME': 'mono'})
    for extra in ({'NO_COLOR': ''}, {'TERM': 'dumb'}):
        assert '\x1b' not in run('usageLine "${RED}opt${NC}" "${GREEN}Text${NC}"', terminal=True, extra=extra)
    assert run('usageLine "${RED}opt${NC}" Text yes') == '       opt                        Text\n'
    assert run('usageLine opt Text intend') == run('usageLine opt Text 4')
    assert run('printThemeRow opt Text', setup='THEME_INDENT_TARGET=""; THEME_WIDTH_TARGET=5; THEME_COLUMN_GAP=3') == 'opt     Text\n'
    assert '\x1b[35mTitel' in run('printThemeHeading Titel', terminal=True, setup="THEME_COLOR_GROUP='\\033[35m'")
    # Geerbte, exportierte THEME_*-Werte (etwa von MakeLib aus make) zählen nicht, die Datei gilt.
    inherited = {'THEME_WIDTH_TARGET': '5', 'THEME_COLUMN_GAP': '3', 'THEME_INDENT_TARGET': '',
                 'THEME_COLOR_GROUP': '\\033[35m', 'THEME_GROUP_SPACING': '3'}
    assert run('printThemeRow opt Text', extra=inherited) == '       opt                    Text\n'
    assert '\x1b[1;38;5;11mTitel' in run('printThemeHeading Titel', terminal=True, extra=inherited)
    assert run('printThemeHeading Titel', extra=inherited) == '\n  Titel\n'
    # Ein eigener Wert mit x (Escape wie die Palette) gilt nicht als exportiert.
    assert '\x1b[35mTitel' in run('printThemeHeading Titel', terminal=True, setup="THEME_COLOR_GROUP='\\x1B[35m'")
    palette = run('printf "%s|%s|%s" "$RED" "$NC" "$GREP_COLOR_GREEN"')
    assert palette == r'\x1B[38;5;196m|\x1B[0m|38;5;10'
    # Loading happens once; deleting the file after source must not change output.
    assert 'bold+11' == run('rm "$XDG_CONFIG_HOME/cli-theme/classic.theme"; printf "%s" "$C_HEAD"; printThemeRow a b >/dev/null')
    missing = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True)
    assert missing.count('cli-theme install') == 1 and '\x1b' not in missing
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    assert run('printf "%s" "$RED"') == palette.split('|')[0]
    # Invalid inputs must fall back atomically, never execute shell expressions.
    bad_entries = ['C_HEAD=256', 'C_KEY=bold+256', 'C_TEXT="10"', 'C_VAL=$(touch "' + str(base / 'executed') + '")',
                   'UNKNOWN=1', 'GAP=-1', 'SPACE=1+1', 'C_HEAD =11']
    for entry in bad_entries:
        theme.write_text(classic + entry + '\n')
        result = run('printThemeHeading Titel; printThemeRow opt Text', terminal=True)
        assert '\x1b' not in result and result.count('cli-theme show') == 1, (entry, result)
        assert ':18:' in result, result
        assert run('printf "%s|%s" "$C_HEAD" "$W_KEY"') == '|21'
    assert not (base / 'executed').exists()
    theme.write_text(classic.replace('C_KEY=33\n', ''))
    assert 'C_KEY' in run('printThemeRow opt Text', terminal=True)
    theme.write_text(' # Kommentar\r\n' + classic.replace('GAP=2', 'GAP=002 # Abstand').rstrip('\n'))
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    for name in ('../escape', '_invalid', '-invalid', 'with space'):
        result = run('printThemeRow opt Text', terminal=True, extra={'CLI_THEME': name})
        assert '\x1b' not in result and 'cli-theme show' in result
    theme.unlink()
    theme.symlink_to(folder / 'mono.theme')
    assert 'cli-theme show' in run('printThemeRow opt Text', terminal=True)
    theme.unlink()
    os.mkfifo(theme)
    assert run('printThemeRow opt Text') == '       opt                    Text\n'
    theme.unlink()
    theme.mkdir()
    assert 'cli-theme show' in run('printThemeRow opt Text', terminal=True)
    theme.rmdir()
    folder.rename(base / 'actual')
    folder.symlink_to(base / 'actual', target_is_directory=True)
    assert 'cli-theme show' in run('printThemeRow opt Text', terminal=True)
    folder.unlink()
    (base / 'actual').rename(folder)
    # Rollen werden zu THEME_*; C_OFF beendet eine Farbe.
    theme.write_text(classic)
    assert run('printf "%s|%s|%s|%s|%s" "$THEME_COLOR_GROUP" "$THEME_COLOR_SERVER" "$THEME_WIDTH_TARGET" "${#THEME_INDENT_TARGET}" "$C_OFF"') \
        == r'\x1B[1;38;5;11m|\x1B[38;5;13m|21|7|\x1B[0m'
    # Vertrag mit CLITheme: jede mitgelieferte Vorlage liest sich wie in cli-theme,
    # die classic-Abstände in colors.lib.sh entsprechen der Vorlage.
    tool = shutil.which('cli-theme')
    if tool is None:
        print('Theme: cli-theme nicht installiert, Vergleich mit den Vorlagen übersprungen')
    else:
        python = Path(tool).read_text().splitlines()[0].removeprefix('#!').split()[0]
        reference = subprocess.run([python, '-I', '-c', '''
import json
from pathlib import Path
from cli_theme.theme import parse_theme, template_names, template_text
print(json.dumps({name: (lambda t: [t.colors, t.spacing])(parse_theme(template_text(name), Path(name)))
                  for name in template_names()}))
'''], capture_output=True, text=True, check=True, timeout=10)
        templates = json.loads(reference.stdout)
        script = 'for n in $THEME_ROLES $THEME_SPACING; do printf "%s=%s\\n" "$n" "${!n}"; done'
        for name, (colors, spacing) in templates.items():
            (folder / f'{name}.theme').write_text(subprocess.run(
                [python, '-I', '-c', f'from cli_theme.theme import template_text; print(template_text({name!r}), end="")'],
                capture_output=True, text=True, check=True, timeout=10).stdout)
            expected = {f'C_{role.upper()}': value for role, value in colors.items()}
            expected.update({key.upper(): str(value) for key, value in spacing.items()})
            actual = dict(line.split('=', 1) for line in run(script, extra={'CLI_THEME': name}).splitlines())
            assert actual == expected, (name, actual, expected)
        classic_spacing = ' '.join(f'{key.upper()}={value}' for key, value in templates['classic'][1].items())
        assert run('printf "%s" "$THEME_CLASSIC_SPACING"') == classic_spacing
        print(f'Theme: {len(templates)} Vorlagen von cli-theme gleich gelesen')
    print('Theme: Parser, Kompatibilität, Fehlerfälle und PTY-Ausgabe bestanden')
PY
