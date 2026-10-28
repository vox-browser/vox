module layout

import css
import dom
import platform

fn borrow_test_container(document &dom.Document, text string, extra string) &BlockContainer {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:20px/24px Arial;overflow-wrap:anywhere;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	container.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(text).as_node(), text)) })
	assign_layout_indexes(unsafe { &Node(container) })
	return container
}

// Covers line-end kerning, signed spacing, preserved breaks, fallback faces,
// bidi chunks, indentation and paths ineligible for disposable measurement.
fn test_borrowed_intrinsic_width_matches_full_geometry() {
	for text in ['AVATAR ffi To Wa Y word  ', 'Кириллица слова 😀 á', 'אבג xyz العربية',
		'a\tb\nAV To', '', ' \t\n '] {
		for extra in ['', 'letter-spacing:-40px;word-spacing:1.25px', 'white-space:pre-wrap',
			'direction:rtl', 'writing-mode:vertical-rl', 'text-align:justify',
			'text-indent:13px', 'text-indent:13px hanging each-line', 'text-align:center'] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			container := borrow_test_container(document, text, extra)
			for width in [AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
				space := AvailableSpace.new(width, AvailableSize.make_indefinite())
				mut reference_state := LayoutState.new()
				mut reference := reference_state.get_mutable(unsafe { &NodeWithStyle(container) })
				reference.set_indefinite_content_width()
				oracle := run_inline_formatting_context(mut reference_state, container, mut reference, .intrinsic_sizing, space)
				mut state := LayoutState.new()
				mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
				used.set_indefinite_content_width()
				assert measure_disposable_inline_width(mut state, container, mut used, space) == oracle.automatic_content_width
				published := run_inline_formatting_context(mut state, container, mut used, .intrinsic_sizing, space)
				assert published.automatic_content_width == oracle.automatic_content_width
				assert published.automatic_content_height == oracle.automatic_content_height
				for line in used.line_boxes {
					assert !line.intrinsic_width_only_
					for fragment in line.fragments_ { assert isnil(fragment.intrinsic_glyph_runs_) }
				}
			}
		}
	}
}

fn test_borrowed_runs_merge_without_modifying_source_glyphs() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container := borrow_test_container(document, 'a  ', '')
	text_node := container.first_child() or { panic('missing text node') }
	font := &platform.Font{ family: 'Test', point_size: 16 }
	first := platform.GlyphRun.new(font, .ltr, [platform.Glyph{ code_point: u32(`a`), advance: 8 },
		platform.Glyph{ code_point: u32(` `), advance: 4 }])
	second := platform.GlyphRun.new(font, .ltr, [platform.Glyph{ code_point: u32(` `), advance: 5 }])
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.intrinsic_width_only_ = true
	line.add_fragment_with_trailing_whitespace(text_node, 0, 2, CSSPixels.new(0), CSSPixels.new(0),
		CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(12), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0),
		first, TrailingWhitespace{ length_in_code_units: 1, inline_size: CSSPixels.new(4) })
	line.add_fragment_with_trailing_whitespace(text_node, 2, 1, CSSPixels.new(0), CSSPixels.new(0),
		CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(5), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0),
		second, TrailingWhitespace{ length_in_code_units: 1, inline_size: CSSPixels.new(5) })
	assert line.fragments_.len == 1
	assert line.fragments_[0].intrinsic_glyph_runs_.runs.len == 2
	assert line.inline_length_.to_double() == 17
	assert line.fragments_[0].trailing_whitespace_advance(line.fragments_[0].trailing_whitespace_) == ?f64(9)
	line.trim_trailing_whitespace()
	assert line.inline_length_.to_double() == 8
	assert line.fragments_[0].length_in_code_units_ == 1
	assert first.glyphs_.len == 2
	assert first.glyphs_[0].position.x == 0
	assert second.glyphs_.len == 1
	assert second.glyphs_[0].position.x == 0
}
