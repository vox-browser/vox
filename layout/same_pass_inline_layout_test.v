module layout

import css
import dom
import html
import platform

fn same_pass_inline_compare(mut state LayoutState, container &BlockContainer,
	space AvailableSpace) bool {
	styled := unsafe { &NodeWithStyle(container) }
	mut used := state.get_mutable(styled)
	width := used.content_width()
	height := used.content_height()
	definite_width := used.has_definite_width()
	definite_height := used.has_definite_height()
	width_constraint := used.width_constraint
	height_constraint := used.height_constraint
	offset := used.offset
	actual := run_inline_formatting_context_internal(mut state, container, mut used,
		.normal, space, none)
	lines := measurement_inline_lines(used.line_boxes)
	end := used.inline_end_static_position_rect()
	reused := used.line_boxes_are_shared_
	assert used.offset == offset
	// Cache-owned payloads must survive mutations by a normal layout caller.
	mut writable := state.get_mutable(styled)
	if writable.line_boxes.len > 0 && writable.line_boxes[0].fragments_.len > 0 {
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(777)
	}
	gc_collect()
	mut oracle := LayoutState.new()
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(width)
	expected.set_content_height(height)
	expected.set_has_definite_width(definite_width)
	expected.set_has_definite_height(definite_height)
	expected.width_constraint = width_constraint
	expected.height_constraint = height_constraint
	expected.offset = offset
	assert actual == run_uncached_inline_formatting_context_for_width(mut oracle, container,
		mut expected, .normal, space, none, false)
	assert lines == measurement_inline_lines(expected.line_boxes)
	assert end == expected.inline_end_static_position_rect()
	return reused
}

fn test_same_pass_inline_reuses_dirty_plain_nested_and_relative_text_with_copy_on_write() {
	for content in ['alpha beta gamma 😀 אבג and more words',
		'alpha <strong>nested styled 😀 text</strong> followed by more words',
		'<span style="position:relative">nested unshifted relative text</span> and more words'] {
		mut document := html.parse_document('<!doctype html><p id="same" style="position:relative;width:180px;font:16px/20px SerenitySans">${content}</p>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := retained_inline_handle(document, 'same')
		container := root.as_block_container()?
		mut state := LayoutState.new()
		mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
		used.set_content_width(CSSPixels.new(180))
		used.offset = css.CSSPixelPoint.from_values(19, 23)
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		assert !same_pass_inline_compare(mut state, container, space)
		mut dirty := unsafe { &Node(root) }
		dirty.set_needs_layout_update(true)
		for _ in 0 .. 3 {
			assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
		}
	}
}

fn test_same_pass_inline_keeps_all_incoming_size_questions_exact() {
	document := dom.Document.create(dom.url_about_blank())
	container := measurement_inline_fixture(document, '')
	styled := unsafe { &NodeWithStyle(container) }
	mut state := LayoutState.new()
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	assert !same_pass_inline_compare(mut state, container, space)
	for change in ['height', 'definite-height', 'definite-width', 'width-constraint', 'height-constraint', 'width'] {
		mut next := state.get_mutable(styled)
		match change {
			'height' { next.set_content_height(CSSPixels.new(90)) }
			'definite-height' { next.set_has_definite_height(true) }
			'definite-width' { next.set_has_definite_width(!next.has_definite_width()) }
			'width-constraint' { next.width_constraint = .min_content }
			'height-constraint' { next.height_constraint = .max_content }
			else { next.set_content_width(CSSPixels.new(93)) }
		}
		assert !same_pass_inline_compare(mut state, container, space)
		assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
	}
	other := AvailableSpace.new(space.width, AvailableSize.make_definite(CSSPixels.new(100)))
	assert !same_pass_inline_compare(mut state, container, other)
}

fn test_same_pass_inline_revalidates_live_dom_text_membership_and_style() {
	mut document := html.parse_document('<!doctype html><p id="same" style="width:180px;font:16px/20px SerenitySans">original <strong id="nested">nested words</strong> and trailing text</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'same')
	container := root.as_block_container()?
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !same_pass_inline_compare(mut state, container, space)
	assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
	mut element := document.get_element_by_id('same')?
	mut data := element.as_node().first_child()?.as_character_data()?
	data.set_data('different longer text with 😀 אבג ')
	assert !same_pass_inline_compare(mut state, container, space)
	assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
	mut root_node := unsafe { &Node(root) }
	old := root_node.first_child()?
	root_node.remove_child(old)
	root_node.append_child(unsafe { &Node(TextNode.new_generated(document, 'replacement')) })
	assign_layout_indexes(root_node)
	// Detached text must reject before inherited computed style is read.
	assert !same_pass_inline_compare(mut state, container, space)
}

fn test_same_pass_inline_rejects_font_environment_and_in_place_style_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut container := measurement_inline_fixture(document, '')
	styled := unsafe { &NodeWithStyle(container) }
	mut state := LayoutState.new()
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = same_pass_inline_compare(mut state, container, space)
	mut fonts := css.css_style_computer_for(document).font_computer()
	fonts.did_load_font('UnrelatedSamePassFace')
	assert !same_pass_inline_compare(mut state, container, space)
	document.bump_style_environment_version()
	assert !same_pass_inline_compare(mut state, container, space)
	mut element := document.create_element('p')!
	element.set_attribute_value('style', 'font:23px/29px SerenitySans;direction:rtl')
	container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	assert !same_pass_inline_compare(mut state, container, space)
	assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
}

fn test_same_pass_inline_preserves_clamp_context_state_and_excluded_children() {
	for extra in ['max-lines:1;continue:collapse', 'position:relative;top:2px'] {
		document := dom.Document.create(dom.url_about_blank())
		container := measurement_inline_fixture(document, extra)
		mut state := LayoutState.new()
		mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
		used.set_content_width(CSSPixels.new(180))
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		for _ in 0 .. 3 { assert !same_pass_inline_compare(mut state, container, space) }
	}
	document := dom.Document.create(dom.url_about_blank())
	container := measurement_inline_fixture(document, '')
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = same_pass_inline_compare(mut state, container, space)
	mut bfc := BlockFormattingContext{ is_line_clamp_container: true, max_lines: 1 }
	_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &bfc)
	assert bfc.line_clamp_reached()
	assert !used.line_boxes_are_shared_
}

fn test_same_pass_inline_retained_native_geometry_survives_context_and_pool_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	container := measurement_inline_fixture(document, 'position:relative')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(180))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = same_pass_inline_compare(mut state, container, space)
	state.release_measurement_chunk_pool()
	gc_collect()
	assert same_pass_inline_compare(mut state, container, space) == !disable_same_pass_inline_reuse
}

// Keep these checks outside assert: they also run under literal -prod, which
// removes assertions in implementation helpers and must preserve state changes.
fn test_retained_inline_margin_commit_survives_literal_production_mode() {
	for previous_pass in [false, true] {
		document := dom.Document.create(dom.url_about_blank())
		container := measurement_inline_fixture(document, '')
		root := unsafe { &Node(container) }
		styled := unsafe { &NodeWithStyle(container) }
		mut state := LayoutState.new()
		mut used := state.get_mutable(styled)
		used.set_content_width(CSSPixels.new(180))
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, none)
		key := u64(voidptr(root))
		cached := state.inline_layouts_[key] or { panic('missing retained inline fixture') }
		if previous_pass {
			mut clean := unsafe { &Node(root) }
			clean.reset_needs_layout_update()
			for child in root.children() {
				mut clean_child := unsafe { &Node(child) }
				clean_child.reset_needs_layout_update()
			}
			state.previous_inline_layouts_[key] = cached
			state.inline_layouts_.clear()
		}
		mut bfc := BlockFormattingContext{}
		bfc.margin_state.add_margin(13)
		bfc.margin_state.register_block_container_y_position_update(used, 0)
		_ = run_inline_formatting_context_internal(mut state, container, mut used, .normal, space, &bfc)
		if bfc.margin_state.has_block_container_waiting_for_final_y_position()
			|| bfc.margin_state.current_collapsed_margin() != 0
			|| used.offset.y() != CSSPixels.new(13) {
			panic('retained inline replay failed to commit its pending collapsed margin')
		}
		if (previous_pass || !disable_same_pass_inline_reuse) && !used.line_boxes_are_shared_ {
			panic('expected retained inline geometry was not reused')
		}
	}
}

fn test_measurement_inline_margin_commit_survives_literal_production_mode() {
	document := dom.Document.create(dom.url_about_blank())
	container := measurement_inline_fixture(document, '')
	styled := unsafe { &NodeWithStyle(container) }
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut producer := source.new_measurement_for_subtree(styled)
	mut first := producer.get_mutable(styled)
	first.set_content_width(CSSPixels.new(180))
	_ = run_inline_formatting_context_for_width(mut producer, container, mut first, .normal, space, none, false)
	producer.release_measurement()
	mut replay := source.new_measurement_for_subtree(styled)
	defer { replay.release_measurement() }
	mut used := replay.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	mut bfc := BlockFormattingContext{}
	bfc.margin_state.add_margin(17)
	bfc.margin_state.register_block_container_y_position_update(used, 0)
	_ = run_inline_formatting_context_for_width(mut replay, container, mut used, .normal, space, &bfc, false)
	if bfc.margin_state.has_block_container_waiting_for_final_y_position()
		|| bfc.margin_state.current_collapsed_margin() != 0
		|| used.offset.y() != CSSPixels.new(17) || !used.line_boxes_are_shared_ {
		panic('measurement inline replay failed to commit its pending collapsed margin')
	}
}
