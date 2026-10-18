module layout

import css
import dom
import html

fn test_retained_line_buffers_detach_before_public_mutation_and_measurement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.fragments_ << LineBoxFragment{inline_length_: CSSPixels.new(31)}
	lines := [line]
	mut state := LayoutState.new()
	mut used := state.get_mutable(node)
	used.borrow_retained_line_boxes(lines)
	assert state.get(node).line_boxes.data == lines.data
	mut probe := LayoutState.new_for_subtree(node)
	mut copied := probe.populate_node_from(mut state, node)
	copied.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(62)
	assert lines[0].fragments_[0].inline_length_ == CSSPixels.new(31)
	probe.release_measurement()
	mut mutable_used := state.try_get_mutable(node)?
	assert mutable_used.line_boxes.data != lines.data
	assert mutable_used.line_boxes[0].fragments_.data != lines[0].fragments_.data
	mutable_used.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(93)
	assert lines[0].fragments_[0].inline_length_ == CSSPixels.new(31)
	used.borrow_retained_line_boxes(lines)
	mut second := state.get_mutable(node)
	second.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(124)
	assert lines[0].fragments_[0].inline_length_ == CSSPixels.new(31)
	used.borrow_retained_line_boxes(lines)
	used.clear_line_boxes()
	assert used.line_boxes.len == 0
	assert lines.len == 1 && lines[0].fragments_.len == 1
}

fn test_retained_block_lines_stay_shared_across_replays_until_mutation() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable" style="overflow:hidden;width:180px"><p id="text">Several unchanged words wrap onto multiple lines in this comment.</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	root := unsafe { &Node(stable.as_node().unsafe_layout_node()?.real_layout_handle()) }
	initial := document_layout_result(document)?
	cache := initial.state.block_layouts_[u64(voidptr(root))] or { panic('missing cache') }
	mut changed := document.get_element_by_id('changed')?
	for contents in ['<p>First</p>', '<p>Second<br>line</p>'] {
		changed.set_inner_html(contents)!
		document.update_layout(.debugging)
		current := document_layout_result(document)?
		assert voidptr(current.state.block_layouts_[u64(voidptr(root))]) == voidptr(cache)
		mut shared_count := 0
		for entry in cache.values {
			if entry.values.line_boxes.len == 0 { continue }
			read := current.state.try_get(entry.node)?
			assert read.line_boxes.data == entry.values.line_boxes.data
			assert read.line_boxes[0].fragments_.data == entry.values.line_boxes[0].fragments_.data
			shared_count++
		}
		assert shared_count > 0
	}
	current := document_layout_result(document)?
	for entry in cache.values {
		if entry.values.line_boxes.len == 0 { continue }
		old_length := entry.values.line_boxes[0].fragments_[0].inline_length_
		mut used := current.state.try_get_mutable(entry.node)?
		used.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(777)
		assert entry.values.line_boxes[0].fragments_[0].inline_length_ == old_length
	}
	gc_collect()
	for entry in cache.values {
		if entry.values.line_boxes.len == 0 { continue }
		assert entry.values.line_boxes[0].fragments_[0].inline_length_ != CSSPixels.new(777)
	}
}
