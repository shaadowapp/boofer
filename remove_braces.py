import os
import re

def remove_added_braces(directory):
    # This specifically targets the pattern added by the previous script
    pattern = re.compile(r'if\s*\(([^)]+)\)\s+{\s+([^{;]+;)\s+}', re.MULTILINE)
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for the map literal case specifically if possible
                # e.g. if (cond) { 'key': 'value', }
                # But it also messed up normal code
                
                new_content = pattern.sub(r'if (\1) \2', content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Removed braces in {path}")

if __name__ == "__main__":
    remove_added_braces('c:\\Users\\surya\\AndroidStudioProjects\\boofer\\lib')
