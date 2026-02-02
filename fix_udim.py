import re
import sys
import os

def fix_content(content):
    # UDim2.new(sx, 0, sy, 0) -> UDim2.fromScale(sx, sy)
    # SX can be a number, a variable, or a call. Handling this perfectly in regex is hard, 
    # but we can try common cases.
    # Simple cases first: literal numbers or simple variables
    
    # Matching UDim2.new(x, 0, y, 0) where x and y are not 0 (0 would match Offset too, but Scale is fine)
    # We use a non-greedy match for the arguments
    
    # pattern for UDim2.fromScale
    # UDim2.new(expr, 0, expr, 0)
    # We need to be careful about nested parentheses.
    
    # For now, let's use a simplified approach for common patterns seen in UI code.
    
    # This regex looks for UDim2.new( ..., 0, ..., 0 )
    # It attempts to capture the two non-zero arguments.
    content = re.sub(r'UDim2\.new\s*\(([^,]+),\s*0,\s*([^,]+),\s*0\)', r'UDim2.fromScale(\1, \2)', content)
    
    # This regex looks for UDim2.new( 0, ..., 0, ... )
    content = re.sub(r'UDim2\.new\s*\(0,\s*([^,]+),\s*0,\s*([^,]+)\)', r'UDim2.fromOffset(\1, \2)', content)
    
    # UDim.new(s, 0) -> UDim.fromScale(s)
    content = re.sub(r'UDim\.new\s*\(([^,]+),\s*0\)', r'UDim.fromScale(\1)', content)
    
    # UDim.new(0, o) -> UDim.fromOffset(o)
    content = re.sub(r'UDim\.new\s*\(0,\s*([^,]+)\)', r'UDim.fromOffset(\1)', content)
    
    return content

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_udim.py <file1> <file2> ...")
        sys.exit(1)
        
    for filename in sys.argv[1:]:
        if not os.path.exists(filename):
            continue
        with open(filename, 'r') as f:
            old_content = f.read()
            
        new_content = fix_content(old_content)
        
        if old_content != new_content:
            with open(filename, 'w') as f:
                f.writelines(new_content)
            print(f"Fixed {filename}")
