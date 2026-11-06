module layout

import css
import dom
import html
import platform

fn positioned_inline_expected_reuse() bool {
	return !disable_inline_measurement_reuse && !retain_positioned_inline_measurements
}

fn test_unshifted_relative_inline_measurements_survive_scratch_and_copy_on_write() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	container := measurement_inline_fixture(document, 'position:relative')
	root := unsafe { &Node(container) }
	// Ordinary transient workspace eligibility keeps its existing policy.
	assert !inline_layout_workspace_is_closed(root, true)
	assert inline_measurement_root_is_closed(root, none) == !retain_positioned_inline_measurements
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	defer { state.release_measurement_chunk_pool() }
	for mode in [LayoutMode.normal, .intrinsic_sizing] {
		for width in [AvailableSize.make_definite(CSSPixels.new(180)),
			AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
			space := AvailableSpace.new(width, AvailableSize.make_indefinite())
			assert !measurement_inline_compare(mut state, container, space, mode, !width.is_definite())
			for _ in 0 .. 3 {
				assert measurement_inline_compare(mut state, container, space, mode,
					!width.is_definite()) == positioned_inline_expected_reuse()
			}
		}
	}
}

fn test_relative_inline_committed_replay_preserves_root_geometry_and_owned_lines() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	container := measurement_inline_fixture(document, 'position:relative')
	styled := unsafe { &NodeWithStyle(container) }
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut producer := state.new_measurement_for_subtree(styled)
	mut measured := producer.get_mutable(styled)
	measured.set_content_width(CSSPixels.new(180))
	result := run_inline_formatting_context_for_width(mut producer, container, mut measured,
		.normal, space, none, false)
	mut snapshots := platform.enter_retained_allocations()
	lines := measurement_inline_lines(measured.line_boxes)
	snapshots.finish()
	end := measured.inline_end_static_position_rect()
	producer.release_measurement()
	gc_collect()
	mut used := state.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	used.offset = css.CSSPixelPoint.from_values(19, 23)
	actual := run_inline_formatting_context_for_width(mut state, container, mut used,
		.normal, space, none, false)
	assert actual == result
	assert measurement_inline_lines(used.line_boxes) == lines
	assert used.inline_end_static_position_rect() == end
	assert used.offset == css.CSSPixelPoint.from_values(19, 23)
	assert used.line_boxes_are_shared_ == (positioned_inline_expected_reuse()
		&& !disable_committed_inline_measurement_reuse)
	state.release_measurement_chunk_pool()
	gc_collect()
	assert measurement_inline_lines(used.line_boxes) == lines
	mut writable := state.get_mutable(styled)
	assert !writable.line_boxes_are_shared_
	writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(777)
	mut oracle := LayoutState.new()
	mut expected := oracle.get_mutable(styled)
	expected.set_content_width(CSSPixels.new(180))
	assert run_uncached_inline_formatting_context_for_width(mut oracle, container,
		mut expected, .normal, space, none, false) == result
	assert measurement_inline_lines(expected.line_boxes) == lines
}

fn test_relative_inline_rejects_shifted_out_of_flow_and_clamped_roots() {
	document := dom.Document.create(dom.url_about_blank())
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	for extra in ['position:relative;left:0px', 'position:relative;right:1px',
		'position:relative;top:1px', 'position:relative;bottom:0px', 'position:absolute',
		'position:fixed', 'position:sticky', 'position:relative;float:left',
		'position:relative;max-lines:1;continue:collapse'] {
		container := measurement_inline_fixture(document, extra)
		assert !inline_measurement_root_is_closed(unsafe { &Node(container) }, none)
		mut state := LayoutState.new()
		state.enable_measurement_chunk_pool()
		for _ in 0 .. 2 {
			assert !measurement_inline_compare(mut state, container, space, .normal, false)
		}
		assert state.measurement_chunk_pool_.inline_measurements_.len == 0
		state.release_measurement_chunk_pool()
	}
}

fn test_relative_inline_revalidates_style_insets_direction_and_dom_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut container := measurement_inline_fixture(document, 'position:relative')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	assert measurement_inline_compare(mut state, container, space, .normal, false) == positioned_inline_expected_reuse()
	for declarations in ['position:relative;top:3px', 'position:relative;direction:rtl',
		'position:relative;left:auto;top:auto;font-size:23px', 'position:static'] {
		mut element := document.create_element('div')!
		element.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;${declarations}')
		container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		assert !measurement_inline_compare(mut state, container, space, .normal, false)
	}
	mut relative := document.create_element('div')!
	relative.set_attribute_value('style', 'display:block;font:16px/20px SerenitySans;position:relative')
	container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(relative, none)))
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	mut text := container.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('A changed relative paragraph 😀 אבג')
	text.invalidate_text_for_rendering()
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	assert measurement_inline_compare(mut state, container, space, .normal, false) == positioned_inline_expected_reuse()
	old := container.children()[0]
	container.remove_child(old)
	container.append_child(unsafe { &Node(TextNode.new(document,
		document.create_text_node('another paragraph').as_node(), 'another paragraph')) })
	assign_layout_indexes(unsafe { &Node(container) })
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
}

fn test_relative_inline_revalidates_live_dom_text_without_manual_invalidation() {
	mut document := html.parse_document('<!doctype html><p id="relative" style="position:relative;width:180px;font:16px/20px SerenitySans">Original relative text with several words</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := retained_inline_handle(document, 'relative')
	container := root.as_block_container()?
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	assert measurement_inline_compare(mut state, container, space, .normal, false) == positioned_inline_expected_reuse()
	mut element := document.get_element_by_id('relative')?
	mut data := element.as_node().first_child()?.as_character_data()?
	data.set_data('Live replacement with different wrapping 😀 אבג')
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	assert measurement_inline_compare(mut state, container, space, .normal, false) == positioned_inline_expected_reuse()
}

fn test_relative_inline_keeps_width_font_environment_and_descendant_guards() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut container := measurement_inline_fixture(document, 'position:relative')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	_ = measurement_inline_compare(mut state, container, space, .normal, false)
	assert measurement_inline_compare(mut state, container, space, .normal, false) == positioned_inline_expected_reuse()
	narrow := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(91)), AvailableSize.make_indefinite())
	assert !measurement_inline_compare(mut state, container, narrow, .normal, false)
	mut fonts := css.css_style_computer_for(document).font_computer()
	fonts.did_load_font('UnrelatedRelativeMeasurementFont')
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	document.bump_style_environment_version()
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	mut child_element := document.create_element('span')!
	child_element.set_attribute_value('style', 'position:relative;display:inline')
	child_style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(child_element, none))
	child := NodeWithStyle.new(document, child_element.as_node(), child_style)
	container.append_child(unsafe { &Node(child) })
	assign_layout_indexes(unsafe { &Node(container) })
	assert !inline_measurement_root_is_closed(unsafe { &Node(container) }, none)
	assert !measurement_inline_compare(mut state, container, space, .normal, false)
	assert !inline_layout_workspace_is_closed(unsafe { &Node(container) }, true)
}
