"""Regenerate the original, CC0 font used by cyrillic-context.html.

Requires fonttools. The small outlines and legacy kern pair deliberately make
shaping across a soft hyphen break visible without a downloaded font.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0

builder = FontBuilder(1000, isTTF=True)
order = ['.notdef', 'space', 'hyphen', 'Te', 'te', 'o']
builder.setupGlyphOrder(order)
builder.setupCharacterMap({32: 'space', 45: 'hyphen', 0x422: 'Te', 0x442: 'te', 0x43e: 'o'})
glyphs = {}
for name in order:
    pen = TTGlyphPen(None)
    boxes = {
        '.notdef': [(50, 0, 550, 700)], 'space': [],
        'hyphen': [(40, 280, 360, 360)],
        'Te': [(40, 600, 560, 700), (250, 0, 350, 600)],
        'te': [(40, 400, 560, 500), (250, 0, 350, 400)],
        'o': [(50, 0, 150, 500), (450, 0, 550, 500),
              (150, 0, 450, 100), (150, 400, 450, 500)],
    }[name]
    for left, bottom, right, top in boxes:
        pen.moveTo((left, bottom)); pen.lineTo((left, top))
        pen.lineTo((right, top)); pen.lineTo((right, bottom)); pen.closePath()
    glyphs[name] = pen.glyph()
builder.setupGlyf(glyphs)
builder.setupHorizontalMetrics({name: (300 if name == 'space' else 400 if name == 'hyphen' else 600, 0) for name in order})
builder.setupHorizontalHeader(ascent=800, descent=-200)
builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
builder.setupNameTable({'familyName': 'Vox Cyrillic Context Test', 'styleName': 'Regular',
    'uniqueFontIdentifier': 'VoxCyrillicContextTest-Regular',
    'fullName': 'Vox Cyrillic Context Test Regular',
    'psName': 'VoxCyrillicContextTest-Regular', 'copyright': 'CC0; original Vox test outlines'})
builder.setupPost()
builder.setupMaxp()
builder.font['head'].created = builder.font['head'].modified = 2082844800
kern = newTable('kern'); kern.version = 0
subtable = KernTable_format_0(); subtable.version = 0; subtable.coverage = 1
subtable.kernTable = {('hyphen', 'te'): -180}
kern.kernTables = [subtable]; builder.font['kern'] = kern
builder.save(Path(__file__).with_name('cyrillic-context.ttf'))
