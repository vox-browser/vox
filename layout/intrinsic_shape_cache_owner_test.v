module layout

import css
import dom
import platform

fn intrinsic_cache_owner_fingerprint(run &platform.GlyphRun) string {
	return '${u64(voidptr(run.font()))} ${run.text_type()} ${run.face()} ${run.width()} ${run.space_width} ${run.glyphs()} ${run.glyph_indices()} ${run.glyph_positions()} ${run.bounding_box()}'
}

fn intrinsic_cache_owner_container(texts []string) (&BlockContainer, &LayoutState, &UsedValues) {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;width:180px;overflow-wrap:anywhere')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	for text in texts {
		dom_text := document.create_text_node(text)
		container.append_child(unsafe { &Node(TextNode.new(document, dom_text.as_node(), text)) })
	}
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	return container, state, used
}

fn test_intrinsic_shape_miss_and_hit_consumers_keep_cached_owner_immutable() {
	container, _, _ := intrinsic_cache_owner_container(['abc'])
	text_node := container.children()[0].as_text_node() or { panic('text') }
	font := text_node.font_for_rendering()
	iterator := &InlineLevelIterator{ layout_mode: .intrinsic_sizing }
	for text in ['plain', 'אבג', '😀 á', '\t word  '] {
		for direction in [platform.GlyphRunTextType.ltr, .rtl] {
			shaped := iterator.shape_text_for_layout(text_node, 7.5, 1.25, 2, text, font, direction)
			oracle := platform.shape_text_with_spacing(7.5, 1.25, 2, text, font, direction)
			assert intrinsic_cache_owner_fingerprint(shaped.glyph_run) == intrinsic_cache_owner_fingerprint(oracle.glyph_run)
			assert shaped.trailing_whitespace == oracle.trailing_whitespace
			cached := text_node.cached_intrinsic_text_shapes_.last().glyph_run
			expected := intrinsic_cache_owner_fingerprint(cached)
			assert voidptr(cached) != voidptr(shaped.glyph_run)
			mut first := shaped.glyph_run
			first.invalidate_replay_data()
			first.glyphs_[0].position.x += 9
			first.glyphs_ << platform.Glyph{ code_point: u32(`z`), glyph_index: 3, advance: 2 }
			first.refresh_replay_data()
			assert intrinsic_cache_owner_fingerprint(cached) == expected
			second := iterator.shape_text_for_layout(text_node, 7.5, 1.25, 2, text, font, direction)
			assert intrinsic_cache_owner_fingerprint(second.glyph_run) == expected
			assert second.trailing_whitespace == shaped.trailing_whitespace
		}
	}
}

fn test_intrinsic_cache_owners_and_published_lines_survive_merging_and_collection() {
	container, mut state, mut used := intrinsic_cache_owner_container([
		'alpha beta gamma delta ',
		'אבג xyz العربية ',
		'😀 á final',
	])
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	result := run_inline_formatting_context(mut state, container, mut used, .intrinsic_sizing, space)
	assert result.automatic_content_height.raw_value() > 0
	mut retained := []&platform.GlyphRun{}
	mut expected := []string{}
	for line in used.line_boxes {
		for fragment in line.fragments() {
			if run := fragment.glyph_run() {
				retained << run
				expected << intrinsic_cache_owner_fingerprint(run)
			}
		}
	}
	assert retained.len > 0
	for child in container.children() {
		mut text_node := child.as_text_node() or { panic('text') }
		assert text_node.cached_intrinsic_text_shapes_.len > 0
		for cached in text_node.cached_intrinsic_text_shapes_ {
			oracle := platform.shape_text_with_spacing(cached.initial_x, cached.letter_spacing, cached.word_spacing, cached.text, cached.font, cached.text_type)
			assert intrinsic_cache_owner_fingerprint(cached.glyph_run) == intrinsic_cache_owner_fingerprint(oracle.glyph_run)
			assert cached.trailing_whitespace == oracle.trailing_whitespace
		}
		text_node.invalidate_text_for_rendering()
		assert text_node.cached_intrinsic_text_shapes_.len == 0
	}
	gc_collect()
	for index, run in retained {
		assert intrinsic_cache_owner_fingerprint(run) == expected[index]
		assert run.bounding_box() == platform.glyph_run_bounding_box(run.font(), run.glyphs(), run.face())
	}
}
