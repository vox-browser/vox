"""Build the small, original sbix font used by portable color-glyph tests.

Requires fontTools only when regenerating the checked-in test fixture.
"""
from pathlib import Path
import struct
import zlib
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables.sbixStrike import Strike
from fontTools.ttLib.tables.sbixGlyph import Glyph


def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))


def png():
    rows = bytearray()
    for y in range(16):
        rows.append(0)
        for x in range(16):
            alpha = 0 if x in (0, 15) or y in (0, 15) else 96 + (x * 7 + y * 11) % 160
            rows.extend((x * 17, y * 17, (15 - x) * 17, alpha))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', 16, 16, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))


def main():
    builder = FontBuilder(1000, isTTF=True)
    names = ['.notdef', 'icon']
    builder.setupGlyphOrder(names)
    builder.setupCharacterMap({0xE001: 'icon'})
    builder.setupGlyf({name: TTGlyphPen(None).glyph() for name in names})
    builder.setupHorizontalMetrics({name: (1000, 0) for name in names})
    builder.setupHorizontalHeader(ascent=800, descent=-200)
    builder.setupNameTable(dict(familyName='Vox Bitmap Fixture', styleName='Regular',
                               uniqueFontIdentifier='VoxBitmapFixture-Regular',
                               fullName='Vox Bitmap Fixture Regular',
                               psName='VoxBitmapFixture-Regular'))
    builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
    builder.setupPost()
    builder.setupMaxp()
    font = builder.font
    # A bitmap-only TrueType container: no outline tables.
    del font['glyf']
    del font['loca']
    sbix = newTable('sbix')
    sbix.flags = 1
    strike = Strike(ppem=16, resolution=72)
    strike.glyphs = {'.notdef': Glyph(glyphName='.notdef'),
                     'icon': Glyph(glyphName='icon', originOffsetX=-2, originOffsetY=-3,
                                   graphicType='png ', imageData=png())}
    sbix.strikes = {16: strike}
    font['sbix'] = sbix
    font['head'].created = font['head'].modified = 2082844800
    font.recalcTimestamp = False
    font.save(Path(__file__).with_name('bitmap-color.ttf'))


if __name__ == '__main__':
    main()
