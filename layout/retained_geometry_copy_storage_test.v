module layout

import css
import dom
import platform

fn test_retained_line_copies_own_one_fragment_and_marker_buffer_per_line() {
	fragments := []LineBoxFragment{len: 128, init: LineBoxFragment{
		inline_offset_: CSSPixels.new(7)
		block_ellipsis_text_: 'retained …'
	}}
	markers := []StaticPositionMarker{len: 4, init: StaticPositionMarker{
		inline_offset: CSSPixels.new(11)
	}}
	lines := []LineBox{len: 64, init: LineBox{
		fragments_: fragments
		static_position_markers_: markers
	}}
	mut storage := platform.new_arena('retained line copy budget')
	entry := storage.enter()
	mut copied := copy_retained_inline_lines(lines)
	storage.leave(entry)
	$if prealloc {
		payload := i64(sizeof(LineBox)) * 64 + i64(sizeof(LineBoxFragment)) * 64 * 128
			+ i64(sizeof(StaticPositionMarker)) * 64 * 4
		assert storage.usage().used < payload + payload / 4 + 4096
	}
	copied[0].fragments_[0].inline_offset_ = CSSPixels.new(19)
	copied[0].static_position_markers_[0].inline_offset = CSSPixels.new(23)
	assert lines[0].fragments_[0].inline_offset_.to_double() == 7
	assert copied[1].fragments_[0].inline_offset_.to_double() == 7
	assert lines[0].static_position_markers_[0].inline_offset.to_double() == 11
	assert copied[1].static_position_markers_[0].inline_offset.to_double() == 11
	assert copied[0].fragments_[0].block_ellipsis_text_? == 'retained …'
	storage.release()
}

fn test_retained_geometry_snapshots_do_not_allocate_an_extra_boxed_used_values_record() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	mut values := state.get_mutable(node)
	values.set_content_width(CSSPixels.new(31))
	mut storage := platform.new_arena('retained geometry snapshot budget')
	entry := storage.enter()
	mut inline_snapshots := []RetainedInlineValues{cap: 256}
	mut block_snapshots := []RetainedBlockValues{cap: 256}
	for _ in 0 .. 256 {
		append_retained_inline_snapshot(mut inline_snapshots, node, values)
		append_retained_block_snapshot(mut block_snapshots, node, values)
	}
	storage.leave(entry)
	$if prealloc {
		payload := i64(sizeof(RetainedInlineValues) + sizeof(RetainedBlockValues)) * 256
		assert storage.usage().used < payload + payload / 4 + 4096
	}
	values.set_content_width(CSSPixels.new(37))
	assert inline_snapshots[0].values.content_width().to_double() == 31
	assert block_snapshots[255].values.content_width().to_double() == 31
	storage.release()
}

fn test_retained_block_snapshot_preserves_owned_geometry_after_source_storage_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut parent := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	node.set_layout_index(1)
	parent.set_layout_index(2)
	mut source_storage := platform.new_arena('retained geometry source')
	source_entry := source_storage.enter()
	mut state := LayoutState.new()
	mut values := state.get_mutable(node)
	values.set_containing_block_used_values(state.get_mutable(parent))
	values.set_content_width(CSSPixels.new(41))
	values.set_grid_template_columns([CSSPixels.new(43)])
	values.line_boxes = [LineBox{
		fragments_: [LineBoxFragment{inline_offset_: CSSPixels.new(47)}]
		static_position_markers_: [StaticPositionMarker{inline_offset: CSSPixels.new(53)}]
	}]
	source_storage.leave(source_entry)
	mut storage := platform.new_arena('retained geometry result')
	entry := storage.enter()
	mut snapshots := []RetainedBlockValues{cap: 1}
	append_retained_block_snapshot(mut snapshots, node, values)
	storage.leave(entry)
	source_storage.release()
	snapshot := unsafe { &snapshots[0] }
	assert voidptr(snapshot.containing?) == voidptr(parent)
	assert snapshot.values.containing_block_used_values() == none
	assert snapshot.values.content_width().to_double() == 41
	assert snapshot.values.grid_template_columns()[0].to_double() == 43
	assert snapshot.values.line_boxes[0].fragments_[0].inline_offset_.to_double() == 47
	assert snapshot.values.line_boxes[0].static_position_markers_[0].inline_offset.to_double() == 53
	storage.release()
}
