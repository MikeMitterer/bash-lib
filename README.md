<div align="center">

# BashLib

**Bash libraries for your own scripts: output, colors, tools, versions, Docker**

[Requirements](#requirements) · [Installation](#installation) ·
[Including](#including) · [Libraries](#libraries) ·
[License](#license) · [Development](docs/development.md)

English · [Deutsch](README.de.md)

</div>

BashLib is a collection of Bash libraries (`*.lib.sh`) that scripts include
with `source`. It provides colors and consistent help output, tool paths, date,
logging, network, Docker and version functions. Each library loads the
libraries it needs itself through the variable `BASH_LIBS`.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Including](#including)
- [Libraries](#libraries)
- [Help and hints in Makefiles](#help-and-hints-in-makefiles)
- [Colors and themes](#colors-and-themes)
- [Development](#development)
- [License](#license)

## Requirements

- **Bash 5.** The libraries require Bash 5; current Linux LTS releases ship
  5.2 or 5.3. macOS ships only 3.2 as `/bin/bash`; a current Bash comes with
  `brew install bash`. Scripts start with `#!/usr/bin/env bash` so that the
  Bash from the `PATH` runs. Under an older Bash, `cli.lib.sh` (and with it
  `tools.lib.sh`) stops right away: it prints `✗ Bash 5 nötig, läuft mit Bash
  <Version>` and `brew install bash` on stderr and exits with code 1, even
  when sourced.
- **`BASH_LIBS`** points to the `src` directory of this repository (see
  [Installation](#installation)). Without the variable no library finds its
  dependencies.
- **Single tools only for single functions.** When included, `apps.lib.sh`
  looks for `bat`, `jq`, `nmap`, `realpath`, `tree`, `ts` (moreutils), `txts`
  and `gfind`. If one is missing, the script still runs; only the function that
  needs the tool fails. `checkIfToolIsAvailable` reports a missing tool
  together with its install command.

[↑ Contents](#contents)

## Installation

```bash
git clone https://github.com/MikeMitterer/bash-lib.git ~/.local/share/bash-lib
```

Then set `BASH_LIBS` permanently, for example in `~/.bashrc` or `~/.zshrc`:

```bash
export BASH_LIBS="$HOME/.local/share/bash-lib/src"
```

**`BASH_LIBS` must be exported**, not just set: scripts run in a shell of
their own and see nothing of it otherwise. The location of the clone is up to
you; all that matters is that `BASH_LIBS` points to its `src`. Update with
`git -C ~/.local/share/bash-lib pull`.

### As a pip package

Tools that should bring BashLib along depend on it as a Python package, for
example in their `pyproject.toml`:

```toml
dependencies = ["mmit-bashlib @ git+https://github.com/MikeMitterer/bash-lib.git@v0.1.0"]
```

A direct install works as well:

```bash
pipx install 'git+https://github.com/MikeMitterer/bash-lib.git@v0.1.0'
export BASH_LIBS="$(bashlib-path)"
```

`bashlib-path` prints the directory of the installed libraries. With
`pip install -e <clone>` it points to the clone's `src`, so changes take
effect without reinstalling. `bashlib` shows usage, version and short
description, one line per command of the package and the options, in the
chosen CLI theme ([Colors and themes](#colors-and-themes));
`bashlib --version` prints only the version.

pipx creates new commands only when installing, also with `pip install -e`.
After an update of BashLib, install again:

```bash
make install    # in a clone: installs it editable with pipx
pipx install --force 'git+https://github.com/MikeMitterer/bash-lib.git@<release-tag>'
```

[↑ Contents](#contents)

## Including

Each library sets a guard variable when it loads (`__TOOLS_LIB__`,
`__COLORS_LIB__` …). It is included only while that variable is still empty;
this way each library loads at most once, even if several need it.

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ ! -r "${BASH_LIBS:-}/tools.lib.sh" ]]; then
    echo "BASH_LIBS does not point to BashLib/src: '${BASH_LIBS:-}'" >&2
    exit 1
fi
if [[ "${__TOOLS_LIB__:=""}" == "" ]]; then . "${BASH_LIBS}/tools.lib.sh"; fi

printThemeHeading "Options"
printThemeRow "-h | --help" "Show help"
printThemeStatus "✓" "Done" SUCCESS
```

`tools.lib.sh` brings `cli.lib.sh` (output in the CLI theme), `colors.lib.sh`,
`apps.lib.sh`, `dtime.lib.sh` and `version.lib.sh` along; for most scripts this one line is enough. Makefile recipes load `make.lib.sh` themselves; it brings `tools.lib.sh` along. This is a breaking change: scripts that used to get `showProjectVersion` or `showReleaseTags` through `tools.lib.sh` load `make.lib.sh` themselves (listed in the CHANGELOG under “Inkompatible Änderungen”). The guard
line of each library is in its file header under “Einbinden”.

**A script that should also run without BashLib** checks, as above, whether
`${BASH_LIBS}/tools.lib.sh` is readable and otherwise prints plain output
instead of aborting.

[↑ Contents](#contents)

## Libraries

| Library | Content | Loads |
|---|---|---|
| `tools.lib.sh` | General helpers (`trim`, `repeat`, `scriptToDoc`, `logFileStatus`, `showModuleLinks`); loads the libraries on the right | cli, apps, dtime, version |
| `cli.lib.sh` | Output in the CLI theme: theme from clitheme, `printThemeHeading`, `printThemeRow`, `printThemeValue`, `printThemeOption`, `printThemeExample`, `printThemeHint`, `printThemeStatus`, `usageLine`, `showMenu` | colors |
| `colors.lib.sh` | Fixed ANSI color palette (`RED`, `GREEN`, `NC` …) | – |
| `make.lib.sh` | Help and hints for Makefiles in the CLI theme (`printMakeHeading`, `printMakeValue`, `showMakeHeader`, `showMakeTargets`), setup check for test targets (`requireMakeSetup`), editable install with pipx (`installEditablePackage`), version and release tags (`showProjectVersion`, `showReleaseTags`) | tools |
| `apps.lib.sh` | Paths of the tools used, `checkIfToolIsAvailable`, missing command with hint (`requireCommand`) | logging, os, cli |
| `logging.lib.sh` | Logging for scripts | – |
| `os.lib.sh` | Detect the operating system | – |
| `dtime.lib.sh` | Date and time | os |
| `fs.lib.sh` | File and directory functions | – |
| `net.lib.sh` | IP and network functions, `isLocalPortOpen` | os |
| `docker.lib.sh` | Build and push Docker images (Docker Hub, GHCR, ECR) | colors |
| `version.lib.sh` | Read and bump versions, tag (`semVerBump`), next version without writing (`semVerNext`), release tag of a commit (`gitReleaseTag`), release tags as a list (`gitListReleaseTags`), package name and commands from `pyproject.toml` (`readPackageName`, `readPackageCommands`; one-line `key = "value"` only, no full TOML parser) | – |
| `build.lib.sh` | Helpers for build scripts | apps, tools |
| `assert.lib.sh` | Asserts for Bash tests (`assertEquals`, `assertContains`, `assertNotContains`, `finishTests`, `checkStatus`); replaces the former `test.lib.sh` | – |
| `samples.lib.sh` | Publish Dart samples | tools |
| `webapp.lib.sh` | Publish Node and TypeScript apps | colors, fs |
| `python.lib.sh` | Python venv with minimum version and packages (`ensurePythonVenv`) | tools |

[↑ Contents](#contents)

## Help and hints in Makefiles

`make.lib.sh` prints `make help`, `make info` and `make hints` in the CLI
theme, in the same columns as the help of a script. **One recipe line prints
one output line**, so the recipe reads like its output:

- **`printMakeHeading TEXT`** prints a heading, like `printThemeHeading`.
- **`printMakeValue LABEL [VALUE]`** prints a row label · value, like
  `printThemeValue`; the value never wraps.
- **`showMakeHeader NAME`** prints the header of the help, “Please use make
  &lt;target&gt; …” and “Project: NAME”, with target and name in the theme's
  group color. If the language is German (`LANGUAGE`, `LC_ALL`, `LC_MESSAGES`,
  `LANG`, with gettext's precedence), it reads “Verwende make &lt;target&gt; …”
  and “Projekt: NAME”. If none of these variables is set, for example when make
  runs from an IDE, macOS uses the first system language
  (`defaults read -g AppleLanguages`).
- **`showMakeTargets [--set NAME=VALUE]… FILE…`** reads `##@ Group` and
  `target: … ## Description` from the Makefiles. Server targets with `##R`
  (writing) and `##D` (destructive) are listed the same way, placeholders and
  “— Maintainer” included, with the target name in the theme's server or
  danger color. A description that ends in
  “— Maintainer” gets the mark **[Maintainer]**. `{version}`, `{major}`,
  `{minor}` and `{patch}` show the project version and the version before and
  after each release kind, for example “0.6.0 → 0.7.0”; `--set` fills further
  placeholders, unknown ones stay as they are.
- **`requireMakeSetup --hooks DIR` / `--make MAKE STAMP…`** fails with
  “Nicht eingerichtet” and `make setup` on stderr if `core.hooksPath` is not
  `DIR` or `MAKE -q` reports the stamp files as outdated; for example
  `requireMakeSetup --make "$(MAKE)" .venv/.installed`.
- **`installEditablePackage DIR`** installs the working copy `DIR` editable
  with pipx (`pipx install -e --force DIR`) and prints “✓ COMMANDS aus DIR”
  with the commands from `[project.scripts]`. Without pipx it fails with
  “pipx fehlt” and https://pipx.pypa.io, if pipx fails with its output; in
  both cases the exit code is 1. Call it again after an update, because pipx
  creates new commands only on install:

  ```makefile
  install: ## Befehle des Pakets aus dieser Arbeitskopie (pipx, editierbar)
  	@source "$${BASH_LIBS}/make.lib.sh" && installEditablePackage "$${WORKSPACE}"
  ```

`BASH_ENV` loads `make.lib.sh` into each recipe line of the display targets
only. Bash expands the value of `BASH_ENV`, so it names `$${BASH_LIBS}` rather
than the path itself. File names and values reach the recipe through the
environment (`$${VAR}`) and are only printed, never evaluated. The helpers
need BashLib; without `BASH_LIBS` the recipe lines fail with “command not
found”.

```makefile
SHELL := bash

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
PROJECT_NAME := $(shell basename -- $(WORKSPACE_SQ))
# Values from outside reach recipes only through the environment ("$${VAR}")
export WORKSPACE_SQ PROJECT_NAME
export HELP_FILES = $(value MAKEFILE_LIST)

# make.lib.sh in every recipe line of these targets; Bash expands BASH_ENV,
# so it refers to BASH_LIBS instead of holding the path
help hints: export BASH_ENV := $${BASH_LIBS}/make.lib.sh
# clitheme once for all recipe lines instead of once per line
clitheme_export = $(eval clitheme_export := $$(shell clitheme export --bash 2>/dev/null))$(clitheme_export)
help hints: export CLITHEME_EXPORT = $(clitheme_export)

.PHONY: help
help: ## Show this help
	@showMakeHeader "$${PROJECT_NAME}"
	@showMakeTargets $${HELP_FILES}

.PHONY: hints
hints: ## Commands to copy
	@printMakeHeading "Working copy"
	@printMakeValue   "Install" "pipx install -e $${WORKSPACE_SQ}"
	@echo
```

[↑ Contents](#contents)

## Colors and themes

The output helpers take colors and spacing from
[CLITheme](https://github.com/MikeMitterer/python-clitheme) (`clitheme export`),
like Python tools and Makefiles; only CLITheme reads the theme file.
`CLI_THEME` selects the theme (default `classic`); `clitheme install` creates
the templates. Without clitheme or a theme file there are no colors, nor with
`NO_COLOR`, in pipes or with `TERM=dumb`. Roles, spacing and fallback behavior
are described in [docs/themes.md](docs/themes.md). The theme exists since
BashLib 0.4.0; older releases have the built-in themes with `MAKE_THEME`.
Today it comes through `clitheme export` (CLITheme 0.5.0 or later).

A runnable example with help, info, hints, status lines and error messages is
in [examples/](examples/README.md): `./examples/cli-demo.sh --help`.

[↑ Contents](#contents)

## Development

Tests and the workflow for changes to BashLib are described in
[docs/development.md](docs/development.md).

[↑ Contents](#contents)

## License

Copyright © 2019–2026 Michael Mitterer. **MangoLila GmbH** is the provider and
licensor.

BashLib is licensed under the **[EUPL 1.2](LICENSE)**, version 1.2 only. It
permits personal and commercial use, changes, redistribution, sale and hosting
without a paid license.

If you redistribute BashLib or a changed version, or offer it as a network
service, keep the copyright and license notices, mark your changes and provide
the corresponding source under the license's copyleft rules.

The warranty and liability exclusions in EUPL Articles 7 and 8 also apply to
consumers, as far as the law permits. Mandatory rights remain unaffected,
including liability for intent, gross negligence, personal injury and product
liability. No additional guarantee is given.

Contact: **office@MangoLila.at**.

Details: [LICENSE](LICENSE) · [German license text](LICENSE.de.txt) ·
[Provider and consumer declaration](LICENSING.md)
