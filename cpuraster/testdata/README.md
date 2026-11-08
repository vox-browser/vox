`bitmap-color.ttf` is an original Vox test asset: a bitmap-only sbix face with
one 16-by-16 RGBA pattern, mapped to U+E001 (glyph ID 1). It contains no external
font data. Regenerate it with `python3 make_bitmap_font.py` and fontTools.
The generator fixes the font timestamps for reproducible output.

`color-layers.ttf` is an original COLRv0 face whose U+E001 (glyph ID 1)
combines overlapping rectangle, quadratic and triangle outlines. Its palette
has two translucent colors, and the final layer uses the current text color.
Regenerate it with `python3 make_color_layers_font.py` and fontTools.
