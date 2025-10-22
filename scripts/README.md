# Scripts Directory

This directory contains utility scripts for development and validation.

## Available Scripts

### `validate_api_usage.lua`
Validates API usage in the codebase to prevent common mistakes.

**Usage:**
```bash
lua scripts/validate_api_usage.lua
```

**What it checks:**
- Invalid EventManager method usage (like `RegisterServerEvent`)
- Common API mistakes
- Non-existent method calls

**Common fixes:**
- Use `EventManager:RegisterEventHandler()` instead of `RegisterServerEvent()`
- Use `EventManager:RegisterEventHandler()` instead of `RegisterClientEvent()`

## Pre-commit Hook

The `.git/hooks/pre-commit` script automatically runs API validation before each commit.

**To disable temporarily:**
```bash
git commit --no-verify -m "your message"
```

**To re-enable:**
```bash
chmod +x .git/hooks/pre-commit
```

## Manual Validation

You can run validation manually anytime:

```bash
# From project root
lua scripts/validate_api_usage.lua

# Or make it executable and run directly
chmod +x scripts/validate_api_usage.lua
./scripts/validate_api_usage.lua
```

## Common API Mistakes

### ❌ Wrong EventManager Usage
```lua
-- These methods DON'T EXIST
EventManager:RegisterServerEvent("EventName", handler)
EventManager:RegisterClientEvent("EventName", handler)
```

### ✅ Correct EventManager Usage
```lua
-- Use this method for ALL event registration
EventManager:RegisterEventHandler("EventName", handler)
```

## Need Help?

1. Check `docs/API_REFERENCE.md` for correct method names
2. Look at existing working code for examples
3. Check the console for specific error messages
4. Use IDE autocomplete to see available methods
