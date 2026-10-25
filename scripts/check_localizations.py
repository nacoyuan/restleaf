#!/usr/bin/env python3
"""Validate source string keys and both language catalogs without extra packages."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
entry = re.compile(r'^("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");$')

def read(code):
    result = {}
    for line in (root / 'Resources' / (code + '.lproj') / 'Localizable.strings').read_text().splitlines():
        match = entry.fullmatch(line)
        assert match, 'Invalid .strings entry: ' + line
        key, value = map(json.loads, match.groups())
        assert key not in result and value, 'Duplicate key or empty value: ' + key
        result[key] = value
    return result

en, zh = read('en'), read('zh-Hans')
assert en.keys() == zh.keys(), 'Catalog keys differ'
for key in en:
    assert sorted(re.findall(r'%[0-9]*\$?[ds@]', en[key])) == sorted(re.findall(r'%[0-9]*\$?[ds@]', zh[key])), key
used = set()
for path in (root / 'Sources').glob('*.swift'):
    used.update(re.findall(r'\bL\("([^"\n]+)"', path.read_text()))
assert used <= en.keys(), 'Missing keys: ' + repr(used - en.keys())
assert zh['away_action'] == '离开' and zh['resume_timer'] == '恢复计时' and zh['restart'] == '重新开始'
print('PASS:', len(en), 'bilingual strings; all source keys and format placeholders match')
