#!/usr/bin/env python3
"""
Fix Selene unused_variable warnings by prefixing variables with underscore.
"""

import re
import subprocess
import os

def run_selene():
    result = subprocess.run(
        ['selene', 'src/'],
        capture_output=True,
        text=True,
        cwd='/home/roblox/tds'
    )
    return result.stdout + result.stderr

def get_warnings():
    """Parse selene output line by line."""
    output = run_selene()
    warnings = []

    lines = output.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]

        # Look for warning line: warning[unused_variable]: varname is assigned/defined...
        match = re.match(r'warning\[unused_variable\]:\s+(\w+)\s+is\s+(assigned|defined)', line)
        if match:
            var_name = match.group(1)

            # Next line has file:line info - look for "src/" pattern
            if i + 1 < len(lines):
                file_match = re.search(r'(src/[^:]+):(\d+)', lines[i + 1])
                if file_match:
                    filepath = file_match.group(1)
                    line_num = int(file_match.group(2))
                    warnings.append({
                        'var': var_name,
                        'file': filepath,
                        'line': line_num
                    })
        i += 1

    return warnings

def fix_warnings(warnings):
    """Fix warnings by file."""

    # Group by file
    by_file = {}
    for w in warnings:
        filepath = w['file']
        if filepath not in by_file:
            by_file[filepath] = []
        by_file[filepath].append(w)

    total_fixed = 0

    for filepath, file_warnings in by_file.items():
        if not os.path.exists(filepath):
            print(f"  [SKIP] File not found: {filepath}")
            continue

        with open(filepath, 'r') as f:
            lines = f.readlines()

        modified = False

        # Sort by line descending to fix from bottom up
        file_warnings.sort(key=lambda x: x['line'], reverse=True)

        for w in file_warnings:
            line_idx = w['line'] - 1
            if line_idx >= len(lines):
                continue

            var = w['var']
            line = lines[line_idx]

            # Skip if already prefixed
            if f'_{var}' in line or var.startswith('_'):
                continue

            new_line = line
            fixed = False

            # Pattern 1: local var = value
            pattern1 = rf'\blocal\s+{re.escape(var)}\s*='
            if re.search(pattern1, line):
                new_line = re.sub(rf'\blocal\s+{re.escape(var)}(\s*=)', rf'local _{var}\1', line, count=1)
                if new_line != line:
                    fixed = True

            # Pattern 2: for var in / for var,
            if not fixed:
                pattern2 = rf'\bfor\s+{re.escape(var)}\s*[,\s]'
                if re.search(pattern2, line):
                    new_line = re.sub(rf'\bfor\s+{re.escape(var)}(\s*[,\s])', r'for _\1', line, count=1)
                    if new_line != line:
                        fixed = True

            # Pattern 3: for _, var in (or for x, var in)
            if not fixed:
                pattern3 = rf'\bfor\s+\w+\s*,\s*{re.escape(var)}\s+in'
                if re.search(pattern3, line):
                    new_line = re.sub(rf'(\bfor\s+\w+\s*,\s*){re.escape(var)}(\s+in)', r'\1_\2', line, count=1)
                    if new_line != line:
                        fixed = True

            # Pattern 4: function parameters - function name(var) or function(var, ...)
            if not fixed:
                pattern4 = rf'function\s*[\w:\.]*\s*\([^)]*\b{re.escape(var)}\b'
                if re.search(pattern4, line):
                    # Replace var with _var, being careful to only match in parameter list
                    # Use lookahead to make sure we're before the closing paren
                    new_line = re.sub(rf'\b{re.escape(var)}\b(?=[^(]*\))', f'_{var}', line, count=1)
                    if new_line != line:
                        fixed = True

            # Pattern 5: local a, var = or local a, var, c = (multi-variable declaration)
            if not fixed:
                pattern5 = rf'\blocal\s+\w+[\w\s,]*,\s*{re.escape(var)}'
                if re.search(pattern5, line):
                    # Replace the specific var in the list
                    new_line = re.sub(rf',\s*{re.escape(var)}\b', f', _{var}', line, count=1)
                    if new_line != line:
                        fixed = True

            if fixed and new_line != line:
                lines[line_idx] = new_line
                modified = True
                total_fixed += 1
                print(f"  [FIXED] {var} in {filepath}:{w['line']}")

        if modified:
            with open(filepath, 'w') as f:
                f.writelines(lines)

    return total_fixed

def main():
    iteration = 0
    max_iterations = 5

    while iteration < max_iterations:
        iteration += 1
        print(f"\n{'='*50}")
        print(f"Iteration {iteration}")
        print("="*50)

        print("Parsing selene warnings...")
        warnings = get_warnings()
        print(f"Found {len(warnings)} unused_variable warnings")

        if not warnings:
            print("No more warnings to fix!")
            break

        print("\nFixing warnings...")
        fixed = fix_warnings(warnings)
        print(f"\nFixed {fixed} warnings this iteration")

        if fixed == 0:
            print("No fixes applied - remaining warnings may need manual intervention")
            break

    # Final verification
    print("\n" + "="*50)
    print("Final verification with selene...")
    result = subprocess.run(
        ['selene', 'src/'],
        capture_output=True,
        text=True,
        cwd='/home/roblox/tds'
    )
    output = result.stdout + result.stderr
    for line in output.split('\n')[-10:]:
        if line.strip():
            print(line)

if __name__ == '__main__':
    main()
