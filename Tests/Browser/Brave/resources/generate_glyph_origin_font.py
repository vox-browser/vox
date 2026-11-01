"""Generate the original, CC0 font for glyph-document-origin.html.

Requires fonttools. At 15px, I + m advances by exactly 16.875 ideal pixels;
truncating each advance to HarfBuzz's 16.16 format leaves it just below that
quarter-mask boundary. The fixture must preserve those advances when cropping.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

builder = FontBuilder(1000, isTTF=True)
order = ['.notdef', 'space', 'I', 'm']
builder.setupGlyphOrder(order)
builder.setupCharacterMap({32: 'space', 73: 'I', 109: 'm'})
glyphs = {}
for name in order:
    pen = TTGlyphPen(None)
    boxes = {
        'space': [], '.notdef': [(50, 0, 550, 700)], 'I': [(50, 0, 150, 700)],
        'm': [(50, 0, 150, 500), (375, 0, 475, 500), (700, 0, 800, 500),
              (150, 400, 700, 500)],
    }[name]
    for left, bottom, right, top in boxes:
        pen.moveTo((left, bottom)); pen.lineTo((left, top))
        pen.lineTo((right, top)); pen.lineTo((right, bottom)); pen.closePath()
    glyphs[name] = pen.glyph()
builder.setupGlyf(glyphs)
builder.setupHorizontalMetrics({'.notdef': (600, 50), 'space': (250, 0),
                                'I': (234, 50), 'm': (891, 50)})
builder.setupHorizontalHeader(ascent=800, descent=-200)
builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
builder.setupNameTable({'familyName': 'Vox Glyph Origin Test', 'styleName': 'Regular',
    'uniqueFontIdentifier': 'VoxGlyphOriginTest-Regular',
    'fullName': 'Vox Glyph Origin Test Regular', 'psName': 'VoxGlyphOriginTest-Regular',
    'copyright': 'CC0; original Vox test outlines'})
builder.setupPost()
builder.setupMaxp()
builder.font['head'].created = builder.font['head'].modified = 2082844800
builder.save(Path(__file__).with_name('glyph-origin.ttf'))
