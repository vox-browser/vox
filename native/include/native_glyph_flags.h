#pragma once

// The low nibble selects smoothing. Bits 4..7 already select Chromium
// coverage, readable backdrop, synthetic italics and disabled synthetic bold.
// Keep the private bitmap publication capability outside that occupied range.
enum { VOX_GLYPH_PRIVATE_BITMAP = 1 << 8 };
