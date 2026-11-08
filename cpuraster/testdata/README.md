`bitmap-color.ttf` is an original Vox test asset: a bitmap-only sbix face with
one 16-by-16 RGBA pattern, mapped to U+E001 (glyph ID 1). It contains no external
font data. Regenerate it with `python3 make_bitmap_font.py` and fontTools.
The generator fixes the font timestamps for reproducible output.
