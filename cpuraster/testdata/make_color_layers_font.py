"""Generate original overlapping COLRv0 outlines for portable raster checks."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.colorLib.builder import buildCOLR, buildCPAL


def main():
    names = ['.notdef', 'icon', 'block', 'curve', 'foreground']
    b = FontBuilder(1000, isTTF=True)
    b.setupGlyphOrder(names)
    b.setupCharacterMap({0xE001: 'icon'})
    outlines = {}
    p = TTGlyphPen(None)
    outlines['.notdef'] = p.glyph()
    outlines['icon'] = TTGlyphPen(None).glyph()
    p = TTGlyphPen(None)
    p.moveTo((-100, -120)); p.lineTo((760, -120)); p.lineTo((760, 800)); p.lineTo((-100, 800)); p.closePath()
    outlines['block'] = p.glyph()
    p = TTGlyphPen(None)
    p.moveTo((100, 100)); p.qCurveTo((150, 1150), (980, 650)); p.qCurveTo((1000, -200), (100, 100)); p.closePath()
    outlines['curve'] = p.glyph()
    p = TTGlyphPen(None)
    p.moveTo((250, -50)); p.lineTo((500, 750)); p.lineTo((950, -50)); p.closePath()
    outlines['foreground'] = p.glyph()
    b.setupGlyf(outlines)
    b.setupHorizontalMetrics({n: (1000, 0) for n in names})
    b.setupHorizontalHeader(ascent=1200, descent=-300)
    b.setupNameTable(dict(familyName='Vox COLRv0 Fixture', styleName='Regular',
                         uniqueFontIdentifier='VoxCOLRv0Fixture-Regular',
                         fullName='Vox COLRv0 Fixture Regular', psName='VoxCOLRv0Fixture-Regular'))
    b.setupOS2(sTypoAscender=1200, sTypoDescender=-300, usWinAscent=1200, usWinDescent=300)
    b.setupPost(); b.setupMaxp()
    b.font['COLR'] = buildCOLR({'icon': [('block', 0), ('curve', 1), ('foreground', 0xffff)]}, version=0)
    b.font['CPAL'] = buildCPAL([[(0.9, 0.1, 0.2, 0.6), (0.1, 0.5, 0.9, 0.8)]])
    b.font['head'].created = b.font['head'].modified = 2082844800
    b.font.recalcTimestamp = False
    b.font.save(Path(__file__).with_name('color-layers.ttf'))


if __name__ == '__main__':
    main()
