# -*- coding: utf-8 -*-
"""Cevrilmemis sonraki kayitlari dokumek icin yardimci.

  python tools/tr/next_batch.py magicitems 20
  python tools/tr/next_batch.py creatures 6
"""
import gzip
import io
import json
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

SECTIONS = ('traits', 'actions', 'legendary_actions', 'bonus_actions', 'reactions')


def main():
    kind = sys.argv[1]
    limit = int(sys.argv[2])
    skip = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    bundle = json.load(gzip.open(f'assets/data/{kind}.json.gz', 'rt', encoding='utf-8'))
    tr = json.load(open(f'assets/data/tr/{kind}_tr.json', encoding='utf-8'))

    out = []
    for row in bundle:
        if row['key'] in tr:
            continue
        if kind == 'creatures':
            rows = [
                (('actions' if s != 'traits' else 'traits'), e)
                for s in SECTIONS
                for e in (row.get(s) or [])
                if isinstance(e, dict) and e.get('desc')
            ]
            if not rows:
                continue
            body = '\n'.join(f'  [{sec}/{e.get("name")}] {e["desc"]}' for sec, e in rows)
        elif kind == 'spells':
            # Buyu kartinda `desc` ile birlikte "Ust Seviye Buyu Yuvasiyla"
            # paragrafi da goruluyor; ikisi ayni partide cevrilmeli.
            if not (row.get('desc') or '').strip():
                continue
            body = '  [desc] ' + row['desc']
            if (row.get('higher_level') or '').strip():
                body += '\n  [higher_level] ' + row['higher_level']
        else:
            if not (row.get('desc') or '').strip():
                continue
            body = '  [desc] ' + row['desc']
        out.append(f'### {row["key"]}  ({row["name"]})\n{body}')

    chunk = out[skip:skip + limit]
    print(f'--- kalan {len(out)}, bu parti {len(chunk)}\n')
    print('\n\n'.join(chunk))


if __name__ == '__main__':
    main()
