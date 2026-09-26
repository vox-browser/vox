// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/InsertedContent.{h,cpp}.
module editing

import dom

pub enum ReplacementTopology {
	inline_
	block
}

fn start_boundary_of(node &dom.Node) dom.BoundaryPoint {
	if node.is_text() {
		return dom.BoundaryPoint{
			node: node
			offset: 0
		}
	}
	if first_child := node.first_child() {
		return start_boundary_of(first_child)
	}
	return dom.BoundaryPoint{
		node: node
		offset: 0
	}
}

@[heap]
pub struct InsertedContent {
mut:
	nodes_                               &InsertedNodes
	replacement_range_                   ?&MutationTrackedRange
	insertion_range_                     ?&MutationTrackedRange
	endpoints_                           ?&ReplacementEndpoints
	replacement_topology_                ?ReplacementTopology
	start_paragraph_was_integrated_       bool
	insertion_was_inside_paragraph_       bool
	insertion_was_after_whitespace_       bool
	replacement_was_inside_inline_content_ bool
	end_paragraph_was_integrated_         bool
	normalize_end_text_seam_              bool
}

pub fn InsertedContent.new(nodes []&dom.Node) &InsertedContent {
	return &InsertedContent{
		nodes_: InsertedNodes.new(nodes)
	}
}

pub fn (content &InsertedContent) is_empty() bool {
	return content.nodes_.is_empty()
}

pub fn (content &InsertedContent) first_node() ?&dom.Node {
	return content.nodes_.first_node()
}

pub fn (content &InsertedContent) nodes() []&dom.Node {
	return content.nodes_.connected_nodes()
}

pub fn (content &InsertedContent) last_node() ?&dom.Node {
	return content.nodes_.last_node()
}

pub fn (content &InsertedContent) text_nodes() []&dom.Text {
	return content.nodes_.connected_text_nodes()
}

pub fn (content &InsertedContent) contains(candidate &dom.Text) bool {
	return content.nodes_.contains(candidate)
}

pub fn (content &InsertedContent) start_boundary() ?dom.BoundaryPoint {
	endpoints := content.endpoints_ or { return none }
	return endpoints.start()
}

pub fn (content &InsertedContent) completion_start_boundary() ?dom.BoundaryPoint {
	replacement_range := content.replacement_range_ or { return content.start_boundary() }
	topology := content.replacement_topology_ or { return content.start_boundary() }
	mut completion_begins_with_text := content.nodes_.leading_content_kind() == .text_node
	if topology == .block {
		completion_begins_with_text = content.start_paragraph_was_integrated_
			&& content.nodes_.leading_content_kind() != .other
	}
	if completion_begins_with_text && content.replacement_was_inside_inline_content_ {
		return replacement_range.range().start()
	}
	return content.start_boundary()
}

pub fn (content &InsertedContent) insertion_boundary() ?dom.BoundaryPoint {
	insertion_range := content.insertion_range_ or { return none }
	return insertion_range.range().start()
}

pub fn (content &InsertedContent) end_boundary_after_atomic_content() ?dom.BoundaryPoint {
	last_atomic_node := content.nodes_.last_atomic_node() or { return none }
	if last_atomic_node.parent() == none {
		return none
	}
	return end_boundary_of_node(last_atomic_node)
}

pub fn (content &InsertedContent) end_boundary() ?dom.BoundaryPoint {
	if atomic_boundary := content.end_boundary_after_atomic_content() {
		return atomic_boundary
	}
	endpoints := content.endpoints_ or { return none }
	boundary := endpoints.end()
	if !boundary.node.is_text() && boundary.offset > 0 {
		if preceding_child := boundary.node.child_at_index(boundary.offset - 1) {
			return end_boundary_of_node(preceding_child)
		}
	}
	return boundary
}

fn (mut content InsertedContent) track_insertion_boundary(boundary dom.BoundaryPoint) {
	assert content.insertion_range_ == none
	// INTEROP: Completion treats a protected whitespace run before terminal atomic content differently inside a
	//          paragraph than at its boundary. Record that topology before insertion changes the visible positions.
	visible_position := VisiblePosition.create(boundary.node.document(), boundary)
	content.insertion_was_inside_paragraph_ = !visible_position.is_start_of_paragraph()
		&& !visible_position.is_end_of_paragraph()
	if previous_position := visible_position.previous() {
		previous_boundary := previous_position.deep_equivalent()
		if previous_boundary.node.is_text() {
			text := unsafe { &dom.Text(previous_boundary.node) }
			length := text.length_in_utf16_code_units()
			if length > 0 {
				// An upstream-equivalent position can be represented by the end of the preceding text node. In that case
				// the code unit before the boundary, rather than the out-of-range code unit at the boundary, is relevant.
				code_unit_offset := if previous_boundary.offset < length - 1 {
					previous_boundary.offset
				} else {
					length - 1
				}
				code_unit := text.substring_data(code_unit_offset, 1) or { '' }
				content.insertion_was_after_whitespace_ = code_unit.len > 0
					&& (is_ascii_space_character(code_unit.runes()[0]) || code_unit == '\u00a0')
			}
		}
	}
	// INTEROP: Blink retains the insertion position separately from the first inserted node. In particular, a block
	//          insertion can move or unwrap that node while the destination-side whitespace seam remains observable.
	range_ := dom.Range.create_from_boundary_points(boundary.node, boundary.offset, boundary.node,
		boundary.offset)
	content.insertion_range_ = MutationTrackedRange.new(range_)
}

pub fn (mut content InsertedContent) insert_before(parent &dom.Node, reference_node ?&dom.Node) {
	insertion_offset := if reference := reference_node { reference.index() } else { parent.child_count() }
	content.track_insertion_boundary(dom.BoundaryPoint{
		node: parent
		offset: insertion_offset
	})
	for node in content.nodes_.connected_nodes() {
		insert_node_before(node, parent, reference_node)
	}
}

pub fn (mut content InsertedContent) insert_into_range(mut range_ dom.Range, fragment &dom.DocumentFragment) ! {
	content.track_insertion_boundary(range_.start())
	insert_node_into_range(range_, fragment.as_node())!
}

pub fn (mut content InsertedContent) track_replacement_boundary(boundary dom.BoundaryPoint, topology ReplacementTopology) {
	if content.replacement_range_ != none || content.replacement_topology_ != none {
		return
	}
	content.replacement_topology_ = topology
	range_ := dom.Range.create_from_boundary_points(boundary.node, boundary.offset, boundary.node,
		boundary.offset)
	content.replacement_range_ = MutationTrackedRange.new(range_)
	for ancestor := ?&dom.Node(boundary.node); ancestor != none;  {
		current := ancestor or { break }
		if is_block_node(current) {
			break
		}
		if current.as_element() != none {
			content.replacement_was_inside_inline_content_ = true
			break
		}
		ancestor = current.parent()
	}
}

pub fn (mut content InsertedContent) begin_tracking_content_boundaries() {
	if content.endpoints_ != none {
		return
	}
	first := content.nodes_.first_node() or { return }
	last := content.nodes_.last_node() or { return }
	content.endpoints_ = ReplacementEndpoints.new(start_boundary_of(first),
		end_boundary_of_node(last))
}

pub fn (mut content InsertedContent) begin_completion(end dom.BoundaryPoint) {
	mut endpoints := unsafe { &ReplacementEndpoints(content.endpoints_ or { return }) }
	start := content.completion_start_boundary() or { return }
	endpoints.set_start(start)
	endpoints.set_end(end)
}

pub fn (mut content InsertedContent) did_replace_node(node &dom.Node, replacement &dom.Node) {
	mut nodes := unsafe { &InsertedNodes(content.nodes_) }
	nodes.did_replace_node(node, replacement)
}

pub fn (mut content InsertedContent) did_replace_node_range(node &dom.Node, first_replacement &dom.Node, last_replacement &dom.Node) {
	mut nodes := unsafe { &InsertedNodes(content.nodes_) }
	nodes.did_replace_node_range(node, first_replacement, last_replacement)
}

pub fn (mut content InsertedContent) did_move_start_paragraph(start dom.BoundaryPoint) {
	mut endpoints := unsafe { &ReplacementEndpoints(content.endpoints_ or { return }) }
	content.start_paragraph_was_integrated_ = true
	endpoints.set_start(start)
}

pub fn (mut content InsertedContent) will_integrate_end_paragraph(paragraph &dom.Node) {
	endpoints := content.endpoints_ or { return }
	content.end_paragraph_was_integrated_ = true
	if content.start_paragraph_was_integrated_
		&& paragraph.is_inclusive_ancestor_of(endpoints.start().node) {
		content.normalize_end_text_seam_ = true
	}
}

pub fn (content &InsertedContent) replacement_topology() ?ReplacementTopology {
	return content.replacement_topology_
}

pub fn (content &InsertedContent) insertion_was_inside_paragraph() bool {
	return content.insertion_was_inside_paragraph_
}

pub fn (content &InsertedContent) insertion_was_after_whitespace() bool {
	return content.insertion_was_after_whitespace_
}

pub fn (content &InsertedContent) end_paragraph_was_integrated() bool {
	return content.end_paragraph_was_integrated_
}

pub fn (content &InsertedContent) endpoints() &ReplacementEndpoints {
	return content.endpoints_ or { panic('inserted content is not tracking endpoints') }
}

pub fn (mut content InsertedContent) require_end_text_seam_normalization() {
	content.normalize_end_text_seam_ = true
}

pub fn (content &InsertedContent) should_normalize_end_text_seam() bool {
	return content.normalize_end_text_seam_
}

pub fn (mut content InsertedContent) release() {
	if tracked := content.replacement_range_ {
		mut mutable_tracked := unsafe { &MutationTrackedRange(tracked) }
		mutable_tracked.release()
		content.replacement_range_ = none
	}
	if tracked := content.insertion_range_ {
		mut mutable_tracked := unsafe { &MutationTrackedRange(tracked) }
		mutable_tracked.release()
		content.insertion_range_ = none
	}
	if endpoints := content.endpoints_ {
		mut mutable_endpoints := unsafe { &ReplacementEndpoints(endpoints) }
		mutable_endpoints.release()
		content.endpoints_ = none
	}
}
