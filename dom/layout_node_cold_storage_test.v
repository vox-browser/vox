module dom

import platform

fn test_layout_node_empty_cold_data_needs_no_payload() {
	mut node := &LayoutNode{}
	assert sizeof(LayoutNode) <= 344
	assert sizeof(LayoutRenderedTextChunks) == sizeof([]string)
	assert sizeof(LayoutVisualLines) == sizeof([]VisualLine)
	assert sizeof(LayoutNodeRareData) <= 64
	before := platform.thread_arena_usage().used
	for _ in 0 .. 64 {
		assert node.rendered_text_chunks().len == 0
		assert node.cached_visual_lines().len == 0
		assert node.continuation_of_node() == none
		assert node.continuation_next() == none
		assert node.generated_for_pseudo_element() == none
		assert node.pseudo_element_generator() == none
		node.set_rendered_text_chunks([]string{})
		node.set_visual_lines([]VisualLine{})
		node.set_rare_data(LayoutNodeRareData{})
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	assert node.rendered_text_chunks_data_ == unsafe { nil }
	assert node.visual_lines_data_ == unsafe { nil }
	assert node.rare_data_ == unsafe { nil }
}

fn test_layout_node_cold_replacement_preserves_value_copies_and_live_aliases() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	generator := document.create_element('div') or { panic(err) }
	first := &LayoutNode{}
	next := &LayoutNode{}
	mut node := &LayoutNode{}
	node.set_rendered_text_chunks(['A', 'bc'])
	node.set_visual_lines([VisualLine{ start_offset: 1, end_offset: 3, caret_stops: [VisualCaretStop{ offset: 2, inline_coordinate: 10 }] }])
	node.set_rare_data(LayoutNodeRareData{
		continuation_of_node:     first
		pseudo_element_generator: generator
		generated_for:            .before
	})
	old := *node
	mut alias := node
	alias.set_continuation_next(next)
	assert voidptr(node.continuation_next() or { panic('missing next') }) == voidptr(next)
	assert old.continuation_next() == none
	assert voidptr(node.continuation_of_node() or { panic('missing first') }) == voidptr(first)
	assert voidptr(node.pseudo_element_generator() or { panic('missing generator') }) == voidptr(generator)
	assert (node.generated_for_pseudo_element() or { panic('missing generated pseudo') }) == .before
	alias.set_rendered_text_chunks(['replacement'])
	alias.set_visual_lines([VisualLine{ start_offset: 7, end_offset: 9 }])
	alias.set_rare_data(LayoutNodeRareData{})
	gc_collect()
	assert old.rendered_text_chunks() == ['A', 'bc']
	assert old.cached_visual_lines()[0].start_offset == 1
	assert old.cached_visual_lines()[0].caret_stops[0].offset == 2
	assert (old.generated_for_pseudo_element() or { panic('missing old generated pseudo') }) == .before
	assert voidptr(old.pseudo_element_generator() or { panic('missing old generator') }) == voidptr(generator)
	assert node.rendered_text_chunks() == ['replacement']
	assert node.cached_visual_lines()[0].start_offset == 7
	assert node.rare_data_ == unsafe { nil }
	node.set_rendered_text_chunks([]string{})
	node.set_visual_lines([]VisualLine{})
	assert old.rendered_text_chunks().join('') == 'Abc'
	assert node.rendered_text_chunks_data_ == unsafe { nil }
	assert node.visual_lines_data_ == unsafe { nil }
}

struct ColdVisualLinesProvider {
mut:
	node  &LayoutNode
	calls int
}

fn materialize_cold_visual_lines(_ voidptr, context voidptr) []VisualLine {
	mut provider := unsafe { &ColdVisualLinesProvider(context) }
	provider.calls++
	assert provider.node.visual_lines_provider_ == unsafe { nil }
	assert provider.node.visual_lines()[0].start_offset == 1
	return [VisualLine{ start_offset: 4, end_offset: 8 }]
}

fn test_layout_node_lazy_visual_lines_publish_after_reentrant_provider() {
	mut node := &LayoutNode{}
	node.set_visual_lines([VisualLine{ start_offset: 1, end_offset: 2 }])
	old := *node
	mut provider := ColdVisualLinesProvider{ node: node }
	node.visual_lines_provider_ = LayoutVisualLinesProvider.new(voidptr(&provider), materialize_cold_visual_lines)
	assert node.visual_lines()[0].start_offset == 4
	assert node.visual_lines()[0].end_offset == 8
	assert provider.calls == 1
	assert old.cached_visual_lines()[0].start_offset == 1
}

fn test_layout_node_cold_headers_survive_entered_workspace_reset() {
	mut owner := platform.new_retained_arena('cold bridge test')
	mut entered := owner.enter()
	mut node := &LayoutNode{}
	chunks := ['retained']
	lines := [VisualLine{ start_offset: 3, end_offset: 7 }]
	first := &LayoutNode{}
	mut scratch := platform.new_arena('cold bridge scratch')
	entry := scratch.enter()
	node.set_rendered_text_chunks(chunks)
	node.set_visual_lines(lines)
	node.set_rare_data(LayoutNodeRareData{ continuation_of_node: first })
	node.visual_lines_provider_ = LayoutVisualLinesProvider.new(unsafe { nil }, fn (_ voidptr, _ voidptr) []VisualLine {
		return [VisualLine{ start_offset: 10, end_offset: 12 }]
	})
	scratch.leave(entry)
	scratch.reset()
	gc_collect()
	assert node.rendered_text_chunks() == ['retained']
	assert node.cached_visual_lines()[0].end_offset == 7
	assert voidptr(node.continuation_of_node() or { panic('lost continuation') }) == voidptr(first)
	assert node.visual_lines()[0].end_offset == 12
	scratch.release()
	entered.finish()
	owner.release()
}
