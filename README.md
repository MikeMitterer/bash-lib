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
  Bash from the `PATH` runs.
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

`tools.lib.sh` brings `colors.lib.sh`, `apps.lib.sh`, `dtime.lib.sh` and
`version.lib.sh` along; for most scripts this one line is enough. The guard
line of each library is in its file header under “Einbinden”.

**A script that should also run without BashLib** checks, as above, whether
`${BASH_LIBS}/tools.lib.sh` is readable and otherwise prints plain output
instead of aborting.

[↑ Contents](#contents)

## Libraries

| Library | Content | Loads |
|---|---|---|
| `tools.lib.sh` | Output helpers (`printThemeHeading`, `printThemeRow`, `printThemeStatus`, `usageLine`), version and release tags (`showProjectVersion`, `showReleaseTags`), ports, strings | colors, apps, dtime, version |
| `colors.lib.sh` | ANSI colors, CLI theme and column layout | – |
| `make.lib.sh` | Help and hints for Makefiles in the CLI theme (`showMakeHelp`, `showMakeHints`) | tools |
| `apps.lib.sh` | Paths of the tools used, `checkIfToolIsAvailable` | logging, os |
| `logging.lib.sh` | Logging for scripts | – |
| `os.lib.sh` | Detect the operating system | – |
| `dtime.lib.sh` | Date and time | os |
| `fs.lib.sh` | File and directory functions | – |
| `net.lib.sh` | IP and network functions | os |
| `docker.lib.sh` | Build and push Docker images (Docker Hub, GHCR, ECR) | colors |
| `version.lib.sh` | Read and bump versions, tag (`semVerBump`), next version without writing (`semVerNext`), release tag of a commit (`gitReleaseTag`), release tags as a list (`gitListReleaseTags`) | – |
| `build.lib.sh` | Helpers for build scripts | apps, tools |
| `styles.lib.sh` | Globally defined output styles | colors |
| `assert.lib.sh` | Asserts for Bash tests (`assertEquals`, `assertContains`, `assertNotContains`, `finishTests`, `checkStatus`); replaces the former `test.lib.sh` | – |
| `samples.lib.sh` | Publish Dart samples | tools |
| `webapp.lib.sh` | Publish Node and TypeScript apps | colors, fs |

[↑ Contents](#contents)

## Help and hints in Makefiles

`make.lib.sh` prints `make help` and `make hints` in the CLI theme, in the same
columns as the help of a script:

- **`showMakeHelp [--set NAME=VALUE]… FILE…`** reads `##@ Group` and
  `target: … ## Description` from the Makefiles. A description that ends in
  “— Maintainer” gets the mark **[Maintainer]**; `{NAME}` is replaced by the
  value from `--set`, unknown placeholders stay as they are.
- **`showMakeHints`** reads from stdin: `## Title` becomes a heading,
  `Label<TAB>Value` a row whose value never wraps.

File names and values reach the recipe through the environment (`$${VAR}`) and
are only printed, never evaluated. Like all theme helpers, neither wraps; a
long description stays one line. Without BashLib the Makefile shows a plain
list:

```makefile
SHELL := bash

WORKSPACE    := $(CURDIR)
WORKSPACE_SQ := '$(subst ','\'',$(WORKSPACE))'
# Values from outside reach recipes only through the environment ("$${VAR}")
export WORKSPACE_SQ
export HELP_FILES = $(value MAKEFILE_LIST)

.PHONY: help
help: ## Show this help
	@if [[ -r "$${BASH_LIBS:-}/make.lib.sh" ]]; then \
		source "$${BASH_LIBS}/make.lib.sh" && showMakeHelp $${HELP_FILES}; \
	else grep -hE '^[a-zA-Z0-9_-]+:.*## ' $${HELP_FILES}; fi

.PHONY: hints
hints: ## Commands to copy
	@rows() { printf '## %s\n' 'Working copy'; \
		printf '%s\t%s\n' 'Install' "pipx install -e $${WORKSPACE_SQ}"; }; \
	if [[ -r "$${BASH_LIBS:-}/make.lib.sh" ]]; then \
		source "$${BASH_LIBS}/make.lib.sh" && rows | showMakeHints; \
	else rows | expand -t 24; fi
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
