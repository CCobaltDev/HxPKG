# HxPKG

Installs packages locally from a `.hxpkg` file

Inspired by [hmm](https://github.com/andywhite37/hmm)

## Installation

- `haxelib --global install hxpkg` - Install HxPKG globally
- `haxelib --global run hxpkg setup` - Install command alias
- `hxpkg install` - Install from `.hxpkg`

## Usage

- `hxpkg [command] [flags]`

### Commands

- `hxpkg install` - Installs all packages from the .hxpkg file
- `hxpkg add` - Adds a package to the .hxpkg file
  - `hxpkg add [name] [version/git link] [branch/hash] profile [profile]`
    - Only `name` is required
- `hxpkg remove` - Removes a package from the .hxpkg file
- `hxpkg clear` - Removes all packages from the .hxpkg file
- `hxpkg uninstall` - Removes all packages installed by the .hxpkg file
  - Does not remove dependencies
- `hxpkg list` - Lists all packages in the .hxpkg file
- `hxpkg upgrade` - Updates the .hxpkg file to the new format
  - Also happens when attempting to add a package profile in the old format
- `hxpkg compact` - Compacts the .hxpkg file
- `hxpkg setup` - Installs the command alias for hxpkg. Use `haxelib --global run hxpkg setup` to install
- `hxpkg help` - Shows help information

### Flags:

- `--quiet`: Silent Install/Uninstall
- `--force`: Installs/Uninstalls even if .haxelib exists

- `install`:
  - `--global`: Installs packages globally
  - `--update`: Updates installed packages to the latest version
- `uninstall`:
  - `--remove-all`: Removes the local repo
