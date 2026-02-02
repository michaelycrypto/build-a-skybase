#!/bin/bash
# Fix unused variable warnings by prefixing with _

echo "Fixing unused_variable warnings..."

# Run selene and extract file:line:variable patterns for unused_variable
selene src/ 2>&1 | grep -A1 "warning\[unused_variable\]" | while read -r warn_line; do
    read -r loc_line

    if [[ "$warn_line" =~ \`([a-zA-Z_][a-zA-Z0-9_]*)\` ]]; then
        var="${BASH_REMATCH[1]}"

        # Skip if already has underscore prefix
        if [[ "$var" == _* ]]; then
            continue
        fi

        if [[ "$loc_line" =~ ├─\ *([^:]+):([0-9]+) ]] || [[ "$loc_line" =~ ┌─\ *([^:]+):([0-9]+) ]]; then
            file="${BASH_REMATCH[1]}"
            line="${BASH_REMATCH[2]}"

            echo "Fixing: $var in $file:$line"

            # Use sed to prefix the variable with _ on that specific line
            # Handle different patterns:
            # 1. local var = -> local _var =
            # 2. for var, -> for _,
            # 3. for _, var in -> for _, _ in
            # 4. function(var) -> function(_var)

            sed -i "${line}s/\bfor ${var},/for _,/; ${line}s/\blocal ${var} =/local _${var} =/; ${line}s/\blocal ${var}$/local _${var}/; ${line}s/, ${var},/, _${var},/; ${line}s/, ${var})/, _${var})/; ${line}s/(${var},/(_${var},/; ${line}s/(${var})/(${var})/; ${line}s/function(${var})/function(_${var})/" "$file" 2>/dev/null || true
        fi
    fi
done

echo "Done. Running selene to verify..."
selene src/ 2>&1 | tail -5
