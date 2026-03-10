import os
import re

def add_curly_braces(directory):
    # This is a bit complex for regex, but let's try simple cases
    # if (condition) statement; -> if (condition) { statement; }
    # Also for, while
    
    patterns = [
        # if (condition) statement;
        (r'if\s*\(([^)]+)\)\s+([^{;]+;)', r'if (\1) {\n      \2\n    }'),
        # for (init; cond; step) statement;
        (r'for\s*\(([^)]+)\)\s+([^{;]+;)', r'for (\1) {\n      \2\n    }'),
    ]
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content
                # This simple regex might match multiline statements poorly, but let's see
                # We should only apply if it's a single line statement
                for pattern, repl in patterns:
                    new_content = re.sub(pattern, repl, new_content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Added braces in {path}")

if __name__ == "__main__":
    add_curly_braces('c:\\Users\\surya\\AndroidStudioProjects\\boofer\\lib')
