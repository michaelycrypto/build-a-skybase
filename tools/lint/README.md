# Lint Tools

Utility scripts for automated linting and code cleanup of Lua files.

## Scripts

### `fix_lint.py`
Python script that automatically fixes Selene `unused_variable` warnings by prefixing unused variables with `_` (the Lua convention for intentionally unused variables).

**Usage:**
```bash
cd /path/to/project
python3 tools/lint/fix_lint.py
```

**Features:**
- Parses Selene output automatically
- Handles both `local name =` and `function(name)` patterns
- Runs multiple iterations until no more fixes can be applied
- Verifies results with a final Selene run

### `fix_lint.sh`
Shell script wrapper for basic lint fixing. Less robust than the Python version.

### `fix_udim.py`
Python script to convert deprecated `UDim2.new` calls to the modern `UDim2.fromScale()` or `UDim2.fromOffset()` syntax as suggested by Selene's `roblox_manual_fromscale_or_fromoffset` lint.

## Configuration

The project uses `selene.toml` in the root directory to configure linting rules. See that file for current settings.

## Running Lints

```bash
# Run Selene on the entire src directory
selene src/

# Run with specific output format
selene src/ --display-style=rich
```
