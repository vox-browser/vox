module layout

// CSS Text Decoration 3, section 5.1: underline, overline, glyphs, then
// line-through. Translucent decorations can overlap antialiased glyph edges
// even when the skip-ink stripe does not intersect their outlines.
// https://www.w3.org/TR/css-text-decor-3/#painting-order
// Keep the translated LibWeb profile's existing order.
enum TextDecorationPaintPhase {
	all_
	underline
	overline
	line_through
}

fn (phase TextDecorationPaintPhase) includes(line string) bool {
	return match phase {
		.all_ { true }
		.underline { line in ['underline', 'spelling-error', 'grammar-error'] }
		.overline { line == 'overline' }
		.line_through { line == 'line-through' }
	}
}

fn text_decorations_before_glyphs(fragment TextFragment, opacity f64) []PaintCommand {
	if !fragment.chromium_decorations { return []PaintCommand{} }
	mut commands := paint_text_decoration_for_phase(fragment, opacity, .underline)
	commands << paint_text_decoration_for_phase(fragment, opacity, .overline)
	return commands
}

fn text_decorations_after_glyphs(fragment TextFragment, opacity f64) []PaintCommand {
	if !fragment.chromium_decorations { return decoration_commands(fragment, opacity) }
	return paint_text_decoration_for_phase(fragment, opacity, .line_through)
}
