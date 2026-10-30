module platform

// Font matching still uses the requested style and weight. These bits only
// prohibit manufacturing a face or glyph variant that the matched font lacks.
pub const font_synthesis_weight_disabled = u8(1)
pub const font_synthesis_style_disabled = u8(2)
pub const font_synthesis_small_caps_disabled = u8(4)
pub const font_synthesis_position_disabled = u8(8)
