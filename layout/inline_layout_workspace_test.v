module layout

import css
import dom
import html
import platform

fn inline_workspace_fixture(document &dom.Document, source string, extra string) (&BlockContainer, &LayoutState, &UsedValues) {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;width:180px;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text := TextNode.new(document, document.create_text_node(source).as_node(), source)
	container.append_child(unsafe { &Node(text) })
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	return container, state, used
}

fn inline_workspace_run_fingerprint(run &platform.GlyphRun) string {
	return '${u64(voidptr(run.font()))} ${run.text_type()} ${run.face()} ${run.width()} ${run.space_width} ${run.glyphs()} ${run.glyph_indices()} ${run.glyph_positions()} ${run.bounding_box()}'
}

fn inline_workspace_lines_fingerprint(lines []LineBox) []string {
	mut result := []string{}
	for line_index in 0 .. lines.len {
		line := unsafe { &lines[line_index] }
		result << '${line.width().raw_value()} ${line.height().raw_value()} ${line.baseline().raw_value()}'
		for fragment_index in 0 .. line.fragments_.len {
			fragment := unsafe { &line.fragments_[fragment_index] }
			result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.inline_offset().raw_value()} ${fragment.block_offset().raw_value()} ${fragment.inline_length().raw_value()}'
			if run := fragment.glyph_run() {
				assert run.bounding_box() == platform.glyph_run_bounding_box(run.font(), run.glyphs(), run.face())
				result << inline_workspace_run_fingerprint(run)
			}
		}
	}
	return result
}

fn test_inline_workspace_export_owns_nested_payloads_and_preserves_run_aliases() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	font := &platform.Font{ family: 'SerenitySans', point_size: 16 }
	mut scratch := platform.begin_thread_scratch('inline export source test')
	mut source_run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`a`), glyph_index: 1, advance: 7 },
		platform.Glyph{ code_point: u32(` `), glyph_index: 2, advance: 4, should_paint: false },
	])
	other_run := source_run.clone_for_layout()
	mut source := [LineBox{
		inline_length_:           CSSPixels.new(22)
		static_position_markers_: [StaticPositionMarker{ inline_offset: CSSPixels.new(3) }]
		fragments_:               [
			LineBoxFragment{ glyph_run_: source_run, block_ellipsis_text_: '.'.repeat(3) },
			LineBoxFragment{ glyph_run_: source_run },
			LineBoxFragment{ glyph_run_: other_run },
			LineBoxFragment{},
		]
	}]
	owned := own_inline_layout_lines(source)
	first := owned[0].fragments_[0].glyph_run_?
	second := owned[0].fragments_[1].glyph_run_?
	third := owned[0].fragments_[2].glyph_run_?
	assert voidptr(first) == voidptr(second)
	assert voidptr(first) != voidptr(third)
	assert voidptr(first) != voidptr(source_run)
	assert voidptr(first.glyphs_.data) != voidptr(source_run.glyphs_.data)
	assert voidptr(first.glyph_indices_.data) != voidptr(source_run.glyph_indices_.data)
	assert voidptr(first.glyph_positions_.data) != voidptr(source_run.glyph_positions_.data)
	assert voidptr(owned.data) != voidptr(source.data)
	assert voidptr(owned[0].fragments_.data) != voidptr(source[0].fragments_.data)
	assert voidptr(owned[0].static_position_markers_.data) != voidptr(source[0].static_position_markers_.data)
	assert owned[0].fragments_[3].glyph_run_ == none
	source_run.glyphs_[0].position.x = 900
	source_run.glyph_indices_[0] = 99
	source_run.glyph_positions_[0] = 900
	source[0].static_position_markers_[0].inline_offset = CSSPixels.new(900)
	scratch.finish()
	assert first.glyphs_[0].position.x == 0
	assert first.glyph_indices_ == [u16(1)]
	assert first.glyph_positions_ == [f64(0), 0]
	assert voidptr(first.font()) == voidptr(font)
	assert first.width() == 11
	assert owned[0].static_position_markers_[0].inline_offset == CSSPixels.new(3)
	assert owned[0].fragments_[0].block_ellipsis_text_? == '...'
	$if prealloc {
		arena := document.native_storage().arena
		assert arena.contains(voidptr(owned.data))
		assert arena.contains(voidptr(owned[0].fragments_.data))
		assert arena.contains(voidptr(owned[0].static_position_markers_.data))
		assert arena.contains(voidptr(first))
		assert arena.contains(voidptr(first.glyphs_.data))
		assert arena.contains(voidptr(first.glyph_indices_.data))
		assert arena.contains(voidptr(first.glyph_positions_.data))
		ellipsis := owned[0].fragments_[0].block_ellipsis_text_?
		assert arena.contains(voidptr(ellipsis.str))
	}
}

fn test_closed_inline_workspace_preserves_old_lines_and_intrinsic_cache_owners() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, mut state, mut used := inline_workspace_fixture(document,
		'alpha beta gamma 😀 á אבג and more text to wrap across lines', 'overflow-wrap:anywhere')
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = run_inline_formatting_context(mut state, container, mut used, .intrinsic_sizing, space)
	text := container.children()[0].as_text_node()?
	assert text.cached_intrinsic_text_shapes_.len > 0
	mut old_runs := []&platform.GlyphRun{}
	mut old_fingerprints := []string{}
	for index in 0 .. text.cached_intrinsic_text_shapes_.len {
		run := text.cached_intrinsic_text_shapes_[index].glyph_run
		old_runs << run
		old_fingerprints << inline_workspace_run_fingerprint(run)
	}
	old_lines := unsafe { used.line_boxes }
	old_lines_fingerprint := inline_workspace_lines_fingerprint(old_lines)
	_ = run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
	assert used.line_boxes.len > 1
	$if prealloc {
		assert voidptr(used.line_boxes.data) != voidptr(old_lines.data)
	}
	assert inline_workspace_lines_fingerprint(old_lines) == old_lines_fingerprint
	for index, run in old_runs {
		assert inline_workspace_run_fingerprint(run) == old_fingerprints[index]
	}
	expected := inline_workspace_lines_fingerprint(used.line_boxes)
	for _ in 0 .. 8 {
		_ = run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
	}
	gc_collect()
	assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
	assert inline_workspace_lines_fingerprint(old_lines) == old_lines_fingerprint
	for index, run in old_runs {
		assert inline_workspace_run_fingerprint(run) == old_fingerprints[index]
	}
}

fn test_closed_inline_workspace_retires_builders_and_intermediate_shaping_storage() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, mut state, mut used := inline_workspace_fixture(document,
		'one two three four five six seven eight '.repeat(64), '')
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	// Prime font, text segmentation, shape caches and scratch bookkeeping before
	// comparing the same final layout from two fresh line vectors.
	_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, none)
	_ = run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
	used.line_boxes = []LineBox{}
	before_reference := document.native_storage().arena.usage().used
	_ = run_uncached_inline_formatting_context(mut state, container, mut used, .normal, space, none)
	reference_bytes := document.native_storage().arena.usage().used - before_reference
	expected := inline_workspace_lines_fingerprint(used.line_boxes)
	used.line_boxes = []LineBox{}
	before_owned := document.native_storage().arena.usage().used
	_ = run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
	owned_bytes := document.native_storage().arena.usage().used - before_owned
	assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
	assert reference_bytes > 4096
	assert owned_bytes < reference_bytes * 9 / 10, 'owned=${owned_bytes} reference=${reference_bytes}'
}

fn test_closed_inline_workspace_matches_uncached_unicode_wrapping_and_ellipsis() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	for extra in ['', 'overflow-wrap:anywhere', 'white-space:pre-wrap',
		'white-space:nowrap;overflow:hidden;text-overflow:ellipsis'] {
		container, mut state, mut used := inline_workspace_fixture(document,
			'Latin 😀 á אבג العربية longwordwithoutbreaks and trailing words  ', extra)
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		reference := run_uncached_inline_formatting_context(mut state, container, mut used, .normal,
			space, none)
		expected := inline_workspace_lines_fingerprint(used.line_boxes)
		assert expected.len > 1
		actual := run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
		assert actual == reference
		assert inline_workspace_lines_fingerprint(used.line_boxes) == expected
	}
}

fn test_native_inline_workspace_keeps_cached_lines_and_retired_paint_snapshots_readable() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><p id="stable" style="width:190px;font:16px/20px SerenitySans">Unicode 😀 á <strong>nested inline text</strong> wraps over several retained lines.</p>')
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	element := document.get_element_by_id('stable')?
	root := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	previous := document_layout_result(document)?
	cached := previous.state.inline_layouts_[u64(voidptr(root))] or { panic('uncached paragraph') }
	assert cached.lines.len > 1
	mut glyph_count := 0
	for line in cached.lines {
		for fragment in line.fragments_ {
			if run := fragment.glyph_run_ { glyph_count += run.glyphs().len }
		}
	}
	assert glyph_count > 0
	expected := inline_workspace_lines_fingerprint(cached.lines)
	old_commands := record_retained_display_list(mut document)?
	old_dump := old_commands.dump()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new preceding content</p>')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	reused := current.state.inline_layouts_[u64(voidptr(root))] or { panic('lost paragraph') }
	assert voidptr(reused) == voidptr(cached)
	mut stable := document.get_element_by_id('stable')?
	stable.set_attribute_value('style', 'width:100px;font:20px/24px SerenityMono;overflow-wrap:anywhere')
	document.update_layout(.debugging)
	rewrapped := document.record_display_list()?.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert document.record_display_list()?.dump() == rewrapped
	gc_collect()
	assert inline_workspace_lines_fingerprint(cached.lines) == expected
	assert old_commands.dump() == old_dump
}

fn test_closed_inline_workspace_empty_return_restores_geometry_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	container, mut state, mut used := inline_workspace_fixture(document, '   ', '')
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	depth := document_geometry_depth
	result := run_closed_inline_layout(mut state, container, mut used, .normal, space, none)
	assert result.automatic_content_height.raw_value() == 0
	assert used.line_boxes.len == 0
	assert document_geometry_depth == depth
	assert !platform.transient_arena_entered()
}
