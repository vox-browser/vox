module layout

import css

// FontPlatformData::SetupSkFont() on macOS disables hinting for
// -webkit-font-smoothing: antialiased and for text-rendering:
// geometricPrecision, and Skia's CoreText scaler only smooths hinted glyphs.
// Both therefore rasterize as unsmoothed grayscale text.
fn chromium_glyph_font_smoothing(node &Node, computed &css.ComputedValues) css.FontSmoothing {
	smoothing := computed.font_smoothing()
	if smoothing in [.auto_, .subpixel_antialiased] && computed.text_rendering() == .geometricprecision
		&& node.document().font_rendering_policy() == .chromium {
		return .antialiased
	}
	return smoothing
}
