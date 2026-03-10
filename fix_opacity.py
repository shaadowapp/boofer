import os
import re

def replace_with_opacity(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace withOpacity(0.X) with withValues(alpha: 0.X)
                # We need to be careful with nested parentheses but most usages are simple
                new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {path}")

if __name__ == "__main__":
    replace_with_opacity('c:\\Users\\surya\\AndroidStudioProjects\\boofer\\lib')
