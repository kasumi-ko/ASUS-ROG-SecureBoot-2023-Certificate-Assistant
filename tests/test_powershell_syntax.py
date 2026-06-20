from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_powershell

ROOT = Path(__file__).resolve().parents[1]
LANG = Language(tree_sitter_powershell.language())
PARSER = Parser(LANG)


def validate(path: Path):
    code = path.read_bytes()
    tree = PARSER.parse(code)
    errors = []
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == 'ERROR' or node.is_missing:
            errors.append((node.type, node.start_point, node.end_point, code[node.start_byte:node.end_byte][:160]))
        stack.extend(node.children)
    assert not tree.root_node.has_error and not errors, f'{path.name}: PowerShell grammar errors: {errors[:10]}'

    def text(node):
        return code[node.start_byte:node.end_byte].decode('utf-8-sig', errors='replace').strip()

    duplicates = []
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == 'hash_literal_body':
            seen = {}
            for entry in (c for c in node.children if c.type == 'hash_entry'):
                key_expr = next((c for c in entry.children if c.type == 'key_expression'), None)
                if key_expr is None:
                    continue
                key = text(key_expr).strip('"\'').casefold()
                if key in seen:
                    duplicates.append((key, seen[key], entry.start_point))
                else:
                    seen[key] = entry.start_point
        stack.extend(node.children)
    assert not duplicates, f'{path.name}: duplicate hashtable keys: {duplicates[:10]}'


paths = sorted(ROOT.glob('*.ps1'))
assert paths, 'No PowerShell files found.'
for path in paths:
    validate(path)
print(f'POWERSHELL_TREE_SITTER_OK ({len(paths)} files)')
