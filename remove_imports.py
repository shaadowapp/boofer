import os
import re

def remove_unnecessary_imports(directory):
    files_to_fix = {
        'lib/main.dart': ["import 'package:flutter/foundation.dart';"],
        'lib/screens/about_screen.dart': ["import 'package:flutter/services.dart';"],
        'lib/screens/appearance_settings_screen.dart': ["import 'dart:ui';"],
        'lib/services/media_service.dart': ["import 'dart:typed_data';"],
        'lib/services/supabase_service.dart': ["import 'dart:typed_data';"],
        'lib/services/virgil_e2ee_service.dart': ["import 'dart:typed_data';"],
        'lib/widgets/fast_profile_switcher.dart': ["import 'package:flutter/services.dart';"],
        'lib/widgets/message_bubble.dart': ["import 'dart:ui';"],
        'lib/widgets/unified_friend_card.dart': ["import 'package:flutter/services.dart';"],
    }
    
    for relative_path, imports_to_remove in files_to_fix.items():
        path = os.path.join(directory, relative_path.replace('/', os.sep))
        if not os.path.exists(path):
            print(f"File not found: {path}")
            continue
            
        with open(path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        new_lines = []
        for line in lines:
            should_remove = False
            for imp in imports_to_remove:
                if imp in line:
                    should_remove = True
                    break
            if not should_remove:
                new_lines.append(line)
        
        if len(new_lines) != len(lines):
            with open(path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f"Fixed imports in {path}")

if __name__ == "__main__":
    remove_unnecessary_imports('c:\\Users\\surya\\AndroidStudioProjects\\boofer')
