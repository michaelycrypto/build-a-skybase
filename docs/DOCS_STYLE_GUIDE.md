# Documentation Style Guide

## Purpose

Consistent, skimmable, and linkable docs across the repository.

## Required Structure (per document)

1. Title (single `#`)
2. Short one-line summary (optional but recommended)
3. `## Overview`
4. `## Table of Contents` (links to main sections)
5. Main content sections (pick what fits):
   - `## Architecture` or `## Core Components`
   - `## Usage` / `## Examples`
   - `## Configuration` / `## API`
   - `## Integration` / `## Integration Points`
   - `## Troubleshooting` (if relevant)
   - `## Future Enhancements` (if relevant)
6. `## Related Docs` (cross-links)

## Writing Conventions

- Use sentence case for headings.
- Prefer concise paragraphs and bullet lists.
- Use fenced code blocks with language tags (```lua, ```bash).
- Use relative links to other repo docs. Do not paste bare URLs; use markdown links.
- When listing files, wrap names in backticks (e.g., `src/ServerScriptService/Server/Services`).
- Optional emojis are fine in titles if used consistently and sparingly.

## Tables of Contents

- Keep TOCs short (5–10 items max), linking to second-level sections.
- Example link format: `[Usage](#usage)`.

## Cross-linking

- Add a `## Related Docs` section at the end with links to closely related documents.

## Examples

```markdown
# My System Title

Short summary sentence.

## Overview
One or two paragraphs.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Related Docs](#related-docs)

## Architecture
...

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
```


