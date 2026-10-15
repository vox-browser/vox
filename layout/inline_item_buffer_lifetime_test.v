module layout

import css
import dom
import platform

fn retained_inline_buffer_result(text string, extra string, mode LayoutMode) &UsedValues {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;width:75px;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	dom_text := document.create_text_node(text)
	text_node := TextNode.new(document, dom_text.as_node(), text)
	container.append_child(unsafe { &Node(text_node) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(75))
	run_inline_formatting_context(mut state, container, mut used, mode,
		AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(75)), AvailableSize.make_indefinite()))
	return used
}

fn retained_inline_buffer_fingerprint(used &UsedValues) []string {
	mut result := []string{}
	for line in used.line_boxes {
		result << 'line ${line.width().raw_value()} ${line.height().raw_value()}'
		for fragment in line.fragments_ {
			result << '${fragment.text() or { "" }} ${fragment.start()} ${fragment.length_in_code_units()} ${fragment.inline_offset().raw_value()} ${fragment.inline_length().raw_value()}'
			if run := fragment.glyph_run() {
				assert run.bounding_box() == platform.glyph_run_bounding_box(run.font(), run.glyphs(), run.face())
				assert run.glyph_positions().len == run.glyphs().len * 2
				for glyph in run.glyphs() {
					result << '${glyph.code_point} ${glyph.position.x} ${glyph.position.y} ${glyph.advance}'
				}
			}
		}
	}
	return result
}

fn test_published_inline_fragments_survive_item_buffer_reuse_and_collection() {
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		retained := retained_inline_buffer_result('abcádefghij 😀 abc אבג xyz', 'overflow-wrap:anywhere', mode)
		assert retained.line_boxes.len > 1
		expected := retained_inline_buffer_fingerprint(retained)
		for _ in 0 .. 64 {
			other := retained_inline_buffer_result('different source with many separate words', '', mode)
			assert other.line_boxes.len > 0
		}
		gc_collect()
		assert retained_inline_buffer_fingerprint(retained) == expected
	}
}

fn test_published_ellipsis_glyphs_survive_later_inline_runs_and_collection() {
	retained := retained_inline_buffer_result('This long retained text gets an ellipsis', 'white-space:nowrap;overflow:hidden;text-overflow:ellipsis', .normal)
	assert retained.line_boxes.len == 1
	run := retained.line_boxes[0].fragments_[0].glyph_run() or { panic('missing ellipsis glyphs') }
	assert run.glyphs().last().code_point == u32(0x2026)
	expected := retained_inline_buffer_fingerprint(retained)
	for _ in 0 .. 64 {
		_ = retained_inline_buffer_result('discarded text', '', .normal)
	}
	gc_collect()
	assert retained_inline_buffer_fingerprint(retained) == expected
}
