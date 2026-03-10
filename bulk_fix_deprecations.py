import os
import re

def bulk_replace(directory):
    replacements = [
        (r'\.surfaceVariant', r'.surfaceContainerHighest'),
        (r'onBackground:', r'onSurface:'),
        # (r'background:', r'surface:'), # Too risky to do blindly
    ]
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content
                for pattern, repl in replacements:
                    new_content = re.sub(pattern, repl, new_content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {path}")

if __name__ == "__main__":
    bulk_replace('c:\\Users\\surya\\AndroidStudioProjects\\boofer\\lib')
