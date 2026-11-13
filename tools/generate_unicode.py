#!/usr/bin/env python3
"""Generate Vox's immutable Unicode 17 tables from official Unicode text files.

Usage: python3 tools/generate_unicode.py /path/to/unpacked/UCD
Also place LICENSE (unicode.org/license.txt), IdnaMappingTable.txt and
IdnaTestV2.txt (unicode.org/Public/17.0.0/idna/), and emoji-sequences.txt and
emoji-zwj-sequences.txt (unicode.org/Public/emoji/17.0/) in that directory. No ICU or other third-party Python packages are used.
"""
from pathlib import Path
import argparse
import hashlib
import struct
from collections import defaultdict
from unicode_schema import ALIASES
import re


def records(path):
    for line in path.read_text().splitlines():
        line = line.split('#')[0].strip()
        if line:
            yield [x.strip() for x in line.split(';')]


def bounds(s):
    a = s.split('..')
    return int(a[0], 16), int(a[-1], 16)


def generate_idna_tests(source, destination):
    def unescape(text):
        if text == '\"\"':
            return ''
        return re.sub(r'\\u([0-9A-Fa-f]{4})|\\x\{([0-9A-Fa-f]+)\}',
                      lambda match: chr(int(match[1] or match[2], 16)), text)
    rows = ['# Unicode 17 IdnaTestV2.txt SHA256 '+hashlib.sha256(source.read_bytes()).hexdigest(),
            '# source WTF-8 hex; ASCII output hex; strict validity; nonstrict validity']
    for fields in records(source):
        original = unescape(fields[0])
        unicode_text = unescape(fields[1]) if fields[1] else original
        ascii_text = unescape(fields[3]) if fields[3] else unicode_text
        errors = set((fields[4] or fields[2]).strip('[]').replace(' ', '').split(',')) - {''}
        strict = not errors and bool(ascii_text)
        loose = not (errors - {'U1','V2','V3','A4_1','A4_2','X4_2'}) and bool(ascii_text)
        rows.append('\t'.join([original.encode('utf-8','surrogatepass').hex(),
                               ascii_text.encode('utf-8','surrogatepass').hex(),
                               str(int(strict)), str(int(loose))]))
    destination.parent.mkdir(exist_ok=True)
    destination.write_text('\n'.join(rows)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ucd', type=Path)
    args = parser.parse_args()
    src = args.ucd
    root = Path(__file__).resolve().parent.parent / 'vunicode'
    dest = root / 'data'
    dest.mkdir(exist_ok=True)
    used = {'ReadMe.txt', 'LICENSE'}

    def read(name):
        used.add(name)
        return records(src / name)

    def save(name, rows):
        (dest / (name + '.bin')).write_bytes(b''.join(struct.pack('<' + 'I'*len(r), *r) for r in rows))

    def ranges(name, values, default=0):
        rows = []
        start = 0
        for i in range(1, len(values)+1):
            if i == len(values) or values[i] != values[start]:
                if values[start] != default:
                    rows.append((start, i-1, values[start]))
                start = i
        save(name, rows)

    def maps(name, mapping):
        pool = []
        rows = []
        for point, mapped in sorted(mapping.items()):
            rows.append((point, point, len(pool), len(mapped)))
            pool.extend(mapped)
        save(name, rows)
        save(name+'_pool', [(p,) for p in pool])

    if 'Unicode17.0.0' not in (src / 'ReadMe.txt').read_text():
        raise ValueError('Expected the Unicode 17.0.0 UCD')
    n = 0x110000
    cat = [0]*n
    ccc = [0]*n
    bidi = [0]*n
    upper, lower, title, decomp, compat = {}, {}, {}, {}, set()
    cats = {a[1]: i for i,a in enumerate(ALIASES[0][:30])}
    bidis = 'L R EN ES ET AN CS B S WS ON LRE LRO AL RLE RLO PDF NSM BN FSI LRI RLI PDI'.split()
    # Extracted files include @missing values for unassigned RTL blocks.
    used.add('extracted/DerivedBidiClass.txt')
    for line in (src/'extracted/DerivedBidiClass.txt').read_text().splitlines():
        if '@missing:' in line:
            r, b = line.split('@missing:')[1].strip().split(';')
            b = {'Left_To_Right':'L','Right_To_Left':'R','Arabic_Letter':'AL','European_Terminator':'ET'}.get(b.strip(),b.strip())
            a,z=bounds(r.strip());bidi[a:z+1]=[bidis.index(b)]*(z-a+1)
    for f in read('extracted/DerivedBidiClass.txt'):
        a,z=bounds(f[0]);bidi[a:z+1]=[bidis.index(f[1])]*(z-a+1)
    first=0
    for f in read('UnicodeData.txt'):
        p=int(f[0],16)
        if f[1].endswith(', First>'):
            first=p;continue
        a=first if f[1].endswith(', Last>') else p
        cat[a:p+1]=[cats[f[2]]]*(p-a+1)
        ccc[a:p+1]=[int(f[3])]*(p-a+1)
        for index,mapping in [(12,upper),(13,lower),(14,title)]:
            if f[index]:mapping[p]=[int(f[index],16)]
        if f[5]:
            d=f[5].split()
            if d[0].startswith('<'):compat.add(p);d=d[1:]
            decomp[p]=[int(x,16) for x in d]
    for p,m in upper.items():title.setdefault(p,m)
    for f in read('SpecialCasing.txt'):
        if len(f)<5 or not f[4]:
            p=int(f[0],16)
            for index,mapping in [(1,lower),(2,title),(3,upper)]:mapping[p]=[int(x,16) for x in f[index].split()]
    fold, fullfold = {}, {}
    for f in read('CaseFolding.txt'):
        p=int(f[0],16);m=[int(x,16) for x in f[2].split()]
        if f[1] in ['C','S']:fold[p]=m
        if f[1] in ['C','F']:fullfold[p]=m
    for name,values in [('category',cat),('ccc',ccc),('bidi',bidi)]:ranges(name,values)
    for name,mapping in [('upper',upper),('lower',lower),('title',title),('fold',fold),('decomp',decomp)]:maps(name,mapping)
    save('compat',[(p,p,1) for p in sorted(compat)])
    props=defaultdict(set)
    for name in ['PropList.txt','DerivedCoreProperties.txt','DerivedNormalizationProps.txt','emoji/emoji-data.txt']:
        for f in read(name):
            if len(f)>2 and f[2]!='Y':continue
            a,z=bounds(f[0]);props[f[1]].update(range(a,z+1))
    composition=[]
    for p,m in sorted(decomp.items()):
        if p not in compat and len(m)==2 and p not in props['Full_Composition_Exclusion']:
            composition.append((m[0],m[1],p))
    save('compose',sorted(composition))
    # Case closure uses full folding, including the inverse mapping (ß/ẞ).
    groups=defaultdict(list)
    for p in set(fullfold)|set(fold):groups[tuple(fullfold.get(p,[p]))].append(p)
    closure={}
    for key,points in groups.items():
        if len(key)==1:points.append(key[0])
        points=sorted(set(points))
        for p in points:closure[p]=points
    maps('closure',closure)
    script_ids={alias:i for i,aliases in enumerate(ALIASES[2]) for alias in aliases if alias}
    scripts=[script_ids['Unknown']]*n
    for f in read('Scripts.txt'):
        a,z=bounds(f[0]);scripts[a:z+1]=[script_ids[f[1]]]*(z-a+1)
    ranges('script',scripts,script_ids['Unknown'])
    extensions={}
    for f in read('ScriptExtensions.txt'):
        a,z=bounds(f[0])
        for p in range(a,z+1):extensions[p]=[script_ids[s] for s in f[1].split()]
    maps('script_extensions',extensions)
    # Sequence order matches the UnicodeSet lexicographic code-point order.
    sequences=defaultdict(set)
    for name in ['emoji-sequences.txt','emoji-zwj-sequences.txt']:
        for f in read(name):
            if '..' in f[0]:
                a,z=bounds(f[0]);sequences[f[1]].update((p,) for p in range(a,z+1))
            else:sequences[f[1]].add(tuple(int(x,16) for x in f[0].split()))
    sequences['RGI_Emoji']=set().union(*sequences.values())
    for prop,items in sequences.items():
        props[prop].update(s[0] for s in items if len(s)==1)
        pool=[]
        for item in sorted((s for s in items if len(s)>1), key=lambda s: ''.join(map(chr,s)).encode('utf-16-be')):pool.extend([len(item),*item])
        save('strings_'+prop,[(p,) for p in pool])
    mirrored=set()
    for f in read('UnicodeData.txt'):
        if f[9]=='Y':mirrored.add(int(f[0],16))
    props['Bidi_Mirrored']=mirrored
    props['Grapheme_Link']={i for i,c in enumerate(ccc) if c==9}
    props['alnum']=props['Alphabetic']|{i for i,c in enumerate(cat) if c==9}
    props['blank']={9}|{i for i,c in enumerate(cat) if c==12}
    props['graph']={i for i,c in enumerate(cat) if c not in [0,12,13,14,15,18]}
    props['print']=props['graph'] | (props['blank']-{9})
    props['xdigit']=props['Hex_Digit']|{i for i,c in enumerate(cat) if c==9}
    props['Case_Sensitive']=set(upper)|set(lower)|set(title)|{v for m in [upper,lower,title] for vs in m.values() for v in vs}
    def decomposition(p, compatibility):
        if 0xac00 <= p < 0xd7a4:
            s=p-0xac00
            return [0x1100+s//588,0x1161+(s%588)//28]+([0x11a7+s%28] if s%28 else [])
        if p not in decomp or (not compatibility and p in compat):return [p]
        return [q for x in decomp[p] for q in decomposition(x,compatibility)]
    segment_nonstarters = {q for p in decomp if p not in compat for q in decomposition(p,False)[1:]}
    segment_nonstarters.update(range(0x1161,0x1176))
    segment_nonstarters.update(range(0x11a8,0x11c3))
    composition_starters={a for a,b,p in composition}
    composition_seconds={b for a,b,p in composition}
    compositions={(a,b):p for a,b,p in composition}
    def nfc_sequence(decomposed):
        ordered=[]
        for p in decomposed:
            i=len(ordered)
            while ccc[p] and i and ccc[ordered[i-1]]>ccc[p]:i-=1
            ordered.insert(i,p)
        output=[];starter=0;last_class=0
        for p in ordered:
            c=ccc[p]
            if output and (last_class==0 or last_class<c):
                a=output[starter]
                composite=compositions.get((a,p))
                if 0x1100<=a<0x1113 and 0x1161<=p<0x1176:composite=0xac00+((a-0x1100)*21+p-0x1161)*28
                if 0xac00<=a<0xd7a4 and (a-0xac00)%28==0 and 0x11a7<p<0x11c3:composite=a+p-0x11a7
                if composite is not None:output[starter]=composite;continue
            if c==0:starter=len(output)
            output.append(p);last_class=c
        return output
    for p in range(n):
        d=decomposition(p,False)
        kd=decomposition(p,True)
        if ccc[p]==0 and d==[p]:props['NFD_Inert'].add(p)
        if ccc[p]==0 and kd==[p]:props['NFKD_Inert'].add(p)
        if ccc[p]==0 and p not in segment_nonstarters:props['Segment_Starter'].add(p)
        hangul_interacts=(0x1100<=p<0x1113 or 0x1161<=p<0x1176 or 0x11a8<=p<0x11c3 or (0xac00<=p<0xd7a4 and (p-0xac00)%28==0))
        if ccc[p] or p in composition_starters or p in composition_seconds or d[0] in composition_seconds or hangul_interacts or p in props['Full_Composition_Exclusion']:continue
        # A composed starter is inert only if an intervening mark cannot
        # select a different composition from one of its decomposition prefixes.
        inert=d==[p] or all(nfc_sequence(d+decomposition(q,False))==[p,q] for q in composition_seconds)
        if inert:
            props['NFC_Inert'].add(p)
            if kd==d:props['NFKC_Inert'].add(p)
    metadata=['// Generated by tools/generate_unicode.py; Unicode 17.0.0.','module vunicode','']
    for kind,name in enumerate(['category','property','script']):
        metadata.append('pub const '+name+'_aliases = [')
        metadata.extend("\t['"+"', '".join(a)+"']!," for a in ALIASES[kind])
        metadata.append(']\n')
    metadata.append('const property_data = [')
    for i,aliases in enumerate(ALIASES[1]):
        name=aliases[0]
        ranges('property_'+str(i),[int(p in props[name]) for p in range(n)])
        metadata.append("\t$embed_file('data/property_"+str(i)+".bin').to_string(),")
    metadata.append(']\n')
    metadata.append('const string_data = [')
    for i in range(65,72):metadata.append("\t$embed_file('data/strings_"+ALIASES[1][i][0]+".bin').to_string(),")
    metadata.append(']\n')
    (root/'tables.v').write_text('\n'.join(metadata))
    # IDNA range records reference a shared mapping pool; statuses are stable.
    pool=[];rows=[]
    statuses=['valid','ignored','mapped','deviation','disallowed','disallowed_STD3_valid','disallowed_STD3_mapped']
    for f in read('IdnaMappingTable.txt'):
        a,z=bounds(f[0]);m=[int(x,16) for x in f[2].split()] if len(f)>2 and f[2] else []
        rows.append((a,z,statuses.index(f[1]),len(pool),len(m)));pool.extend(m)
    save('idna',rows);save('idna_pool',[(p,) for p in pool])
    for name,file,default in [('line','LineBreak.txt','XX'),('word','auxiliary/WordBreakProperty.txt','Other'),('east_asian','EastAsianWidth.txt','N'),('joining','extracted/DerivedJoiningType.txt','U')]:
        values=[0]*n;labels=[default]
        for f in read(file):
            if f[1] not in labels:labels.append(f[1])
            a,z=bounds(f[0]);values[a:z+1]=[labels.index(f[1])]*(z-a+1)
        ranges(name,values)
        metadata='module vunicode\n\npub const '+name+'_names = '+repr(labels).replace('"',"'")+'\n'
        (root/(name+'_names.v')).write_text(metadata)
    save('brackets',[(int(f[0],16),int(f[0],16),int(f[1],16),int(f[2]=='o')) for f in read('BidiBrackets.txt')])
    manifest=['Unicode 17.0.0 input SHA-256 (unicode.org/Public/17.0.0/ucd/, plus idna/17.0.0/):']
    for name in sorted(used):manifest.append(hashlib.sha256((src/name).read_bytes()).hexdigest()+'  '+name)
    for name in ['NormalizationTest.txt','auxiliary/LineBreakTest.txt','auxiliary/WordBreakTest.txt','BidiCharacterTest.txt']:
        (root/'testdata'/Path(name).name).write_bytes((src/name).read_bytes())
        manifest.append(hashlib.sha256((src/name).read_bytes()).hexdigest()+'  '+name)
    generate_idna_tests(src/'IdnaTestV2.txt', root.parent/'url/testdata/idna-unicode17.tsv')
    manifest.append(hashlib.sha256((src/'IdnaTestV2.txt').read_bytes()).hexdigest()+'  IdnaTestV2.txt')
    (dest/'SOURCES').write_text('\n'.join(manifest)+'\n')
    (dest/'LICENSE').write_bytes((src/'LICENSE').read_bytes())
    print('Generated Unicode 17 tables:',sum(p.stat().st_size for p in dest.iterdir()),'bytes')


if __name__=='__main__':main()
