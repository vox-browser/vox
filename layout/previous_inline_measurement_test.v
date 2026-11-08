module layout

import css
import dom
import platform

fn previous_inline_measurement_lines(lines []LineBox) []i64 {
	mut owner := platform.enter_retained_allocations()
	defer { owner.finish() }
	mut values := []i64{}
	for line in lines {
		values << line.width().raw_value()
		values << line.height().raw_value()
		values << line.baseline().raw_value()
		for fragment in line.fragments_ {
			values << fragment.start()
			values << fragment.length_in_code_units()
			values << fragment.inline_length().raw_value()
		}
	}
	return values
}

fn test_previous_inline_measurements_keep_owned_lines_and_reject_changed_inputs() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut element := document.create_element('div')!
	element.set_attribute_value('style', 'display:block;font:16px/20px sans-serif')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text_value := 'alpha beta gamma with several words that wrap across lines'
	mut data := document.create_text_node(text_value)
	mut text := TextNode.new(document, data.as_node(), text_value)
	container.append_child(unsafe { &Node(text) })
	assign_layout_indexes(unsafe { &Node(container) })
	styled := unsafe { &NodeWithStyle(container) }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
	mut previous := LayoutState.new()
	mut previous_values := previous.get_mutable(styled)
	previous_values.set_content_width(CSSPixels.new(180))
	expected_result := run_inline_formatting_context(mut previous, container, mut previous_values, .normal, space)
	expected_lines := previous_inline_measurement_lines(previous_values.line_boxes)
	assert previous.inline_layouts_.len == 1
	mut current := LayoutState.new()
	current.previous_inline_layouts_ = unsafe { previous.inline_layouts_ }
	current.enable_measurement_chunk_pool()
	current.measurement_chunk_pool_.scratch_enabled_ = true
	defer { current.release_measurement_chunk_pool() }
	mut probe := current.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_content_width(CSSPixels.new(180))
	actual := run_inline_formatting_context_for_width(mut probe, container, mut used,
		.normal, space, none, false)
	assert actual == expected_result
	assert previous_inline_measurement_lines(used.line_boxes) == expected_lines
	assert used.line_boxes_are_shared_ == !disable_previous_inline_measurements
	assert current.inline_layouts_.len == 0
	if used.line_boxes_are_shared_ {
		mut writable := probe.get_mutable(styled)
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
	}
	probe.release_measurement()
	gc_collect()
	assert previous_inline_measurement_lines(previous_values.line_boxes) == expected_lines
	data.set_data('replacement words with different geometry and a changed source')
	text.invalidate_text_for_rendering()
	mut changed := current.new_measurement_for_subtree(styled)
	mut changed_values := changed.get_mutable(styled)
	changed_values.set_content_width(CSSPixels.new(180))
	_ = run_inline_formatting_context_for_width(mut changed, container, mut changed_values,
		.normal, space, none, false)
	assert !changed_values.line_boxes_are_shared_
	assert previous_inline_measurement_lines(changed_values.line_boxes) != expected_lines
	changed.release_measurement()
}
