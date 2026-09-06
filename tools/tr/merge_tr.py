# -*- coding: utf-8 -*-
"""Elle yazilan ceviri yamalarini assets/data/tr/<kind>_tr.json icine isler.

  python tools/tr/merge_tr.py magicitems patch.json

Yama semasi hedef dosyayla ayni: {"<kayit anahtari>": {"desc": "..."}}.
Var olan bir alanin uzerine yazmaz; kayit sirasi Ingilizce pakete gore
normalize edilir.
"""
import gzip
import json
import sys


def main():
    kind, patch_path = sys.argv[1], sys.argv[2]
    bundle = json.load(gzip.open(f'assets/data/{kind}.json.gz', 'rt', encoding='utf-8'))
    path = f'assets/data/tr/{kind}_tr.json'
    existing = json.load(open(path, encoding='utf-8'))
    patch = json.load(open(patch_path, encoding='utf-8'))

    keys = {row['key'] for row in bundle}
    unknown = [k for k in patch if k not in keys]
    if unknown:
        sys.exit(f'pakette olmayan anahtar: {unknown[:5]}')

    added = 0
    for key, fields in patch.items():
        entry = existing.setdefault(key, {})
        for field, text in fields.items():
            if field not in entry:
                entry[field] = text
                added += 1

    ordered = {'_comment': existing['_comment']}
    for row in bundle:
        if row['key'] in existing:
            ordered[row['key']] = existing[row['key']]
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'{added} alan eklendi; {kind} toplam {len(ordered) - 1} kayit.')


if __name__ == '__main__':
    main()
