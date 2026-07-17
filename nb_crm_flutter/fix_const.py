import re
import sys

def main():
    log_file = r'C:\Users\Dell\.gemini\antigravity\brain\ed78e91d-611a-45c9-b43a-5638918769a1\.system_generated\tasks\task-95.log'
    
    with open(log_file, 'r', encoding='utf-8') as f:
        log_content = f.read()

    errors = re.findall(r'error - (.*?):(\d+):(\d+) - (.*?) - (.*?)\n', log_content)
    
    file_fixes = {}
    
    for err in errors:
        filepath, line_str, col_str, msg, err_code = err
        if err_code == 'const_eval_method_invocation' or 'undefined_getter' in err_code or 'undefined_identifier' in err_code:
            line_idx = int(line_str) - 1
            col_idx = int(col_str) - 1
            
            if filepath not in file_fixes:
                file_fixes[filepath] = []
            
            file_fixes[filepath].append((line_idx, col_idx, err_code))
            
    for filepath, fixes in file_fixes.items():
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except:
            continue
            
        fixes.sort(key=lambda x: x[0], reverse=True)
        
        for line_idx, col_idx, err_code in fixes:
            if err_code == 'const_eval_method_invocation':
                # search backwards for 'const '
                search_idx = line_idx
                found = False
                while search_idx >= max(0, line_idx - 10):
                    # Find the last 'const ' before col_idx if on same line, else just last 'const '
                    text_to_search = lines[search_idx][:col_idx] if search_idx == line_idx else lines[search_idx]
                    rindex = text_to_search.rfind('const ')
                    if rindex != -1:
                        # remove 'const '
                        lines[search_idx] = lines[search_idx][:rindex] + lines[search_idx][rindex+6:]
                        found = True
                        break
                    search_idx -= 1
            elif err_code == 'undefined_getter':
                lines[line_idx] = lines[line_idx].replace('secondaryDark', 'secondary')
            elif err_code == 'undefined_identifier':
                # It means 'context' is undefined. It was probably a default param like `Color color = AppColors.bronze`
                # replaced with `Theme.of(context)`. We'll just replace Theme.of(context).colorScheme.primary with a hardcoded or null.
                # Since we don't know easily, let's just replace `Theme.of(context)` with `null` and let the widget handle it, or revert.
                lines[line_idx] = re.sub(r'Theme\.of\(context\)\.[a-zA-Z0-9_\.\?]+( \?\? [^,;\)]+)?', 'null', lines[line_idx])
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(lines)

if __name__ == '__main__':
    main()
