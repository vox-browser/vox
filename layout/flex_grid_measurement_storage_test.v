module layout

import css
import dom
import svg

fn test_published_measurement_outlives_its_layout_pass() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	mut pool := state.measurement_chunk_pool_
	pool.scratch_enabled_ = true
	mut probe := state.new_measurement_for_subtree(node)
	mut measured := probe.get_mutable(node)
	measured.line_boxes << LineBox.new(.ltr, .horizontal_tb)
	measured.line_boxes[0].inline_length_ = CSSPixels.new(80)
	measured.set_grid_line_names([['start'], ['end']], [[]string{}])
	measured.set_inline_end_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(7, 8, 9, 10)})
	mut rare := measured.ensure_rare_data()
	rare.computed_svg_path_ = svg.Path{
		instructions: [svg.PathInstruction{type_: .move, data: [f64(7), 8]}]
	}
	mut entry := pool.enter_flex_grid_measurement_cache()
	mut snapshots := []RetainedBlockValues{cap: 1}
	append_owned_measurement_values(mut snapshots, node, measured)
	entry.finish()
	probe.release_measurement()
	if pool.flex_grid_measurement_cache_ != unsafe { nil } {
		assert pool.flex_grid_measurement_cache_.contains(snapshots[0].values.line_boxes.data)
	}
	snapshot := unsafe { &snapshots[0] }
	state.restore_flex_grid_measurement_values(snapshot, none, pool.flex_grid_measurement_cache_ != unsafe { nil })
	state.release_measurement_chunk_pool()
	result := state.try_get(node) or { panic('missing published geometry') }
	assert result.line_boxes[0].inline_length_.raw_value() == CSSPixels.new(80).raw_value()
	assert result.grid_column_line_names()[0][0] == 'start'
	position := result.inline_end_static_position_rect() or { panic('missing inline end') }
	assert position.rect.left_value() == 7
	path := result.computed_svg_path() or { panic('missing SVG geometry') }
	assert path.instructions[0].data[0] == 7
}

fn test_published_measurement_reuses_exact_previous_lines() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut previous := LayoutState.new()
	mut published := previous.get_mutable(node)
	published.line_boxes << LineBox.new(.ltr, .horizontal_tb)
	published.line_boxes[0].inline_length_ = CSSPixels.new(80)
	for width in [80, 81] {
		mut state := LayoutState.new()
		state.previous_state_ = previous
		state.enable_measurement_chunk_pool()
		mut pool := state.measurement_chunk_pool_
		pool.scratch_enabled_ = true
		mut probe := state.new_measurement_for_subtree(node)
		mut measured := probe.get_mutable(node)
		measured.line_boxes << LineBox.new(.ltr, .horizontal_tb)
		measured.line_boxes[0].inline_length_ = CSSPixels.new(width)
		mut entry := pool.enter_flex_grid_measurement_cache()
		mut snapshots := []RetainedBlockValues{cap: 1}
		append_owned_measurement_values(mut snapshots, node, measured)
		entry.finish()
		probe.release_measurement()
		state.restore_flex_grid_measurement_values(unsafe { &snapshots[0] }, none, true)
		state.release_measurement_chunk_pool()
		result := state.try_get(node) or { panic('missing published geometry') }
		assert result.line_boxes[0].inline_length_.raw_value() == CSSPixels.new(width).raw_value()
		assert (result.line_boxes.data == published.line_boxes.data) == (width == 80)
		mut writable := state.get_mutable(node)
		writable.line_boxes[0].inline_length_ = CSSPixels.new(99)
		assert published.line_boxes[0].inline_length_.raw_value() == CSSPixels.new(80).raw_value()
	}
}
