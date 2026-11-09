module dom

import platform

// Published headers are immutable: replacing a live bridge must leave its
// previous value copies with the same optional links and array headers.
pub struct LayoutRenderedTextChunks {
pub:
	values []string
}

pub struct LayoutVisualLines {
pub:
	values []VisualLine
}

pub struct LayoutNodeRareData {
pub:
	is_table_wrapper bool
	continuation_of_node     ?&LayoutNode
	continuation_next        ?&LayoutNode
	pseudo_element_generator ?&Element
	generated_for            ?PseudoElement
}

pub fn (node &LayoutNode) rendered_text_chunks() []string {
	if node.rendered_text_chunks_data_ == unsafe { nil } { return []string{} }
	return node.rendered_text_chunks_data_.values
}

pub fn (mut node LayoutNode) set_rendered_text_chunks(values []string) {
	if values.len == 0 {
		node.rendered_text_chunks_data_ = unsafe { nil }
		return
	}
	mut allocations := platform.enter_retained_allocations()
	defer { allocations.finish() }
	node.rendered_text_chunks_data_ = &LayoutRenderedTextChunks{ values: values }
}

// Unlike visual_lines(), this does not invoke the pending geometry provider.
pub fn (node &LayoutNode) cached_visual_lines() []VisualLine {
	if node.visual_lines_data_ == unsafe { nil } { return []VisualLine{} }
	return node.visual_lines_data_.values
}

pub fn (mut node LayoutNode) set_visual_lines(values []VisualLine) {
	if values.len == 0 {
		node.visual_lines_data_ = unsafe { nil }
		return
	}
	mut allocations := platform.enter_retained_allocations()
	defer { allocations.finish() }
	node.visual_lines_data_ = &LayoutVisualLines{ values: values }
}

pub fn (mut node LayoutNode) set_rare_data(data LayoutNodeRareData) {
	if data.continuation_of_node == none && data.continuation_next == none
		&& data.pseudo_element_generator == none && data.generated_for == none && !data.is_table_wrapper {
		node.rare_data_ = unsafe { nil }
		return
	}
	mut allocations := platform.enter_retained_allocations()
	defer { allocations.finish() }
	node.rare_data_ = &LayoutNodeRareData{ ...data }
}

pub fn (node &LayoutNode) continuation_of_node() ?&LayoutNode {
	if node.rare_data_ == unsafe { nil } { return none }
	return node.rare_data_.continuation_of_node
}

pub fn (node &LayoutNode) continuation_next() ?&LayoutNode {
	if node.rare_data_ == unsafe { nil } { return none }
	return node.rare_data_.continuation_next
}

pub fn (mut node LayoutNode) set_continuation_next(next ?&LayoutNode) {
	previous := if node.rare_data_ == unsafe { nil } {
		LayoutNodeRareData{}
	} else {
		*node.rare_data_
	}
	node.set_rare_data(LayoutNodeRareData{ ...previous, continuation_next: next })
}

pub fn (node &LayoutNode) pseudo_element_generator() ?&Element {
	if node.rare_data_ == unsafe { nil } { return none }
	return node.rare_data_.pseudo_element_generator
}

pub fn (node &LayoutNode) generated_for_pseudo_element() ?PseudoElement {
	if node.rare_data_ == unsafe { nil } { return none }
	return node.rare_data_.generated_for
}

pub fn (node &LayoutNode) is_table_wrapper() bool {
 if node.rare_data_ == unsafe { nil } { return false }
 return node.rare_data_.is_table_wrapper
}
