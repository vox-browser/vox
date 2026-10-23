module layout

import css
import dom

struct RetainedInlineInput {
	node           &Node
	style          &css.ComputedValues
	style_revision u64
	child_count    int
	parent_id      u64
	sibling_index  int
	text           string
}

struct RetainedInlineValues {
	node   &NodeWithStyle
	values UsedValues
}

fn append_retained_inline_snapshot(mut snapshots []RetainedInlineValues,
	node &NodeWithStyle, values &UsedValues) {
	// Write into the final vector slot. A by-value UsedValues local is boxed
	// by current V even though it is immediately copied into this record.
	snapshots << RetainedInlineValues{ node: node, values: *values }
	mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
	snapshot.containing_block_used_values_ = none
	if rare := snapshot.rare_ { snapshot.rare_ = rare.clone() }
}

@[heap]
struct RetainedInlineLayout {
	inputs            []RetainedInlineInput
	values            []RetainedInlineValues
	space             AvailableSpace
	font_generation   u64
	font_policy       dom.FontRenderingPolicy
	style_environment u64
	content_width     CSSPixels
	lines             []LineBox
	inline_end        StaticPositionRect
	result            InlineFormattingResult
mut:
	paint_lines_  []TextLine
	paint_origin_ css.CSSPixelPoint
	paint_ready_  bool
	visual_lines_ map[u64][]dom.VisualLine
}

// Reusing line layout requires a closed inline context: no floats, atomic
// children, positioned content, first-letter splits or clamp side effects.
// Other contexts continue through the ordinary formatting algorithm.
fn collect_retained_inline_inputs(node &Node, root bool, mut inputs []RetainedInlineInput) bool {
	if node.is_generated_for_pseudo_element() || node.is_generated_text_node()
		|| node.is_in_ua_internal_shadow_tree() || node.is_svg_box() || node.is_replaced_box()
		|| node.is_floating() || node.is_positioned() || node.is_list_item_box()
		|| node.is_list_item_marker_box() {
		return false
	}
	if !root && !node.is_text_node() && (!node.is_inline_node() || node.is_break_node()) {
		return false
	}
	if root && (!node.display().is_flow_inside()
		|| node.computed_values().writing_mode() != .horizontal_tb) {
		return false
	}
	if node.computed_values().has_animated_properties()
		|| node.computed_values().mutation_revision() == 0 {
		return false
	}
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	mut text := ''
	if value := node.as_text_node() {
		if value.first_letter_ != none || value.source_range_length_ != none
			|| value.is_empty_editable_ || value.produces_line_box_fragment_when_empty_ {
			return false
		}
		text = value.text_for_rendering()
	}
	inputs << RetainedInlineInput{
		node:           node
		style:          node.computed_values()
		style_revision: node.computed_values().mutation_revision()
		child_count:    node.child_count()
		parent_id:      if root {
			u64(0)
		} else if parent := node.parent() {
			u64(voidptr(parent))
		} else {
			0
		}
		sibling_index:  node.index_in_parent_
		text:           text
	}
	for child in node.children() {
		if !collect_retained_inline_inputs(child, false, mut inputs) { return false }
	}
	return true
}

fn retained_inline_inputs_are_current(inputs []RetainedInlineInput) bool {
	for index, input in inputs {
		if input.node.needs_layout_update()
			|| voidptr(input.node.computed_values()) != voidptr(input.style)
			|| input.node.computed_values().mutation_revision() != input.style_revision
			|| input.node.computed_values().has_animated_properties()
			|| input.node.child_count() != input.child_count {
			return false
		}
		if index > 0 {
			parent := input.node.parent() or { return false }
			if u64(voidptr(parent)) != input.parent_id
				|| input.node.index_in_parent_ != input.sibling_index {
				return false
			}
		}
		if text := input.node.as_text_node() {
			if text.text_for_rendering() != input.text { return false }
		}
	}
	return true
}

fn copy_retained_inline_lines(lines []LineBox) []LineBox {
	mut result := []LineBox{cap: lines.len}
	for index in 0 .. lines.len {
		line := unsafe { &lines[index] }
		// Appending a local record makes V derive a second deep clone of its
		// arrays. A literal preserves exactly these two explicit buffer copies.
		result << LineBox{
			...line
			fragments_:               line.fragments_.clone()
			static_position_markers_: line.static_position_markers_.clone()
		}
	}
	return result
}

// Cache-owned buffers are immutable. A public mutable UsedValues handle must
// detach both the line headers and their mutable fragments before exposing them.
fn (mut used UsedValues) borrow_retained_line_boxes(lines []LineBox) {
	unsafe { used.line_boxes = lines }
	used.line_boxes_are_shared_ = lines.len > 0
}

fn (mut used UsedValues) ensure_mutable_line_boxes() {
	if !used.line_boxes_are_shared_ { return }
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	used.line_boxes = copy_retained_inline_lines(used.line_boxes)
	used.line_boxes_are_shared_ = false
}

fn (mut used UsedValues) clear_line_boxes() {
	if used.line_boxes_are_shared_ {
		used.line_boxes = []LineBox{}
		used.line_boxes_are_shared_ = false
	} else {
		used.line_boxes.clear()
	}
}

fn run_inline_formatting_context_internal(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext) InlineFormattingResult {
	// Lines and glyph runs are published by this operation. Keep their entire
	// construction durable while the surrounding block/flex workspace retires.
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	root := unsafe { &Node(containing_block) }
	mut eligible := mode == .normal && state.subtree_root == none && space.width.is_definite()
	if bfc := context {
		eligible = eligible && bfc.floating_boxes.len == 0 && !bfc.has_line_clamp()
			&& !bfc.laying_out_invisible_clamped_content
			&& (bfc.margin_state.has_block_container_waiting_for_final_y_position()
				|| bfc.margin_state.current_collapsed_margin() == 0)
	}
	if !eligible {
		return run_uncached_inline_formatting_context(mut state, containing_block, mut used, mode,
			space, context)
	}
	font_generation :=
		css.css_style_computer_for(root.document()).font_computer().environment_generation()
	key := u64(voidptr(root))
	if cached := state.previous_inline_layouts_[key] {
		if cached.space == space && cached.font_generation == font_generation
			&& cached.font_policy == root.document().font_rendering_policy()
			&& cached.style_environment == root.document().style_environment_version()
			&& cached.content_width == used.content_width()
			&& retained_inline_inputs_are_current(cached.inputs) {
			used.borrow_retained_line_boxes(cached.lines)
			used.set_inline_end_static_position_rect(cached.inline_end)
			containing_values := state.get(unsafe { &NodeWithStyle(containing_block) })
			for index in 0 .. cached.values.len {
				entry := unsafe { &cached.values[index] }
				_ = state.restore_retained_values(entry.node, &entry.values, containing_values)
			}
			if mut bfc := context {
				// The ordinary line builder consumes this pending margin before
				// its first content. The eligibility guard makes its local delta zero.
				assert bfc.commit_pending_margin_before_inline_content().raw_value() == 0
			}
			state.inline_layouts_[key] = cached
			return cached.result
		}
	}
	mut inputs := []RetainedInlineInput{}
	if !collect_retained_inline_inputs(root, true, mut inputs) {
		if inline_layout_workspace_is_closed(root, true) {
			return run_closed_inline_layout(mut state, containing_block, mut used, mode,
				space, context)
		}
		return run_uncached_inline_formatting_context(mut state, containing_block, mut used, mode,
			space, context)
	}
	result := run_closed_inline_layout(mut state, containing_block, mut used, mode,
		space, context)
	if used.line_boxes.len == 0 || !used.line_boxes.any(it.fragments_.len > 0) { return result }
	mut snapshots := []RetainedInlineValues{cap: inputs.len - 1}
	for input in inputs[1..] {
		styled := input.node.as_node_with_style() or { continue }
		if values := state.try_get(styled) {
			append_retained_inline_snapshot(mut snapshots, styled, values)
		}
	}
	state.inline_layouts_[key] = &RetainedInlineLayout{
		inputs:            inputs
		values:            snapshots
		space:             space
		font_generation:   font_generation
		font_policy:       root.document().font_rendering_policy()
		style_environment: root.document().style_environment_version()
		content_width:     used.content_width()
		lines:             copy_retained_inline_lines(used.line_boxes)
		inline_end:        used.inline_end_static_position_rect() or { StaticPositionRect{} }
		result:            result
	}
	return result
}
