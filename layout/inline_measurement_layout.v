module layout

import css
import dom
import os
import platform

const disable_inline_measurement_reuse = os.getenv('VOX_DISABLE_INLINE_MEASUREMENT_REUSE') != ''
const inline_measurement_diagnostics = os.getenv('VOX_INLINE_MEASUREMENT_DIAGNOSTICS') != ''

__global inline_measurement_reuse_reported bool

struct InlineMeasurementKey {
	mode LayoutMode
	width_only bool
	space AvailableSpace
	width CSSPixels
	height CSSPixels
	definite_width bool
	definite_height bool
	width_constraint SizeConstraint
	height_constraint SizeConstraint
}

// Only the measurement pool owns these entries. The producer's UsedValues and
// scratch arena can retire before a sibling probe asks the same question.
@[heap]
struct InlineMeasurementLayout {
	key InlineMeasurementKey
	inputs []RetainedInlineInput
	font_generation u64
	font_policy dom.FontRenderingPolicy
	style_environment u64
	lines []LineBox
	inline_end ?StaticPositionRect
	result InlineFormattingResult
}

fn inline_measurement_key(used &UsedValues, mode LayoutMode, space AvailableSpace,
	width_only bool) InlineMeasurementKey {
	return InlineMeasurementKey{
		mode: mode
		width_only: width_only
		space: space
		width: used.content_width()
		height: used.content_height()
		definite_width: used.has_definite_width()
		definite_height: used.has_definite_height()
		width_constraint: used.width_constraint
		height_constraint: used.height_constraint
	}
}

fn inline_measurement_root_is_closed(root &Node, context ?&BlockFormattingContext) bool {
	if root.child_count() == 0 || !inline_layout_workspace_is_closed(root, true) {
		return false
	}
	for child in root.children() {
		if !child.is_text_node() { return false }
	}
	if bfc := context {
		if bfc.floating_boxes.len != 0 || bfc.has_line_clamp()
			|| bfc.laying_out_invisible_clamped_content
			|| (!bfc.margin_state.has_block_container_waiting_for_final_y_position()
				&& bfc.margin_state.current_collapsed_margin() != 0) {
			return false
		}
	}
	return true
}

fn inline_measurement_inputs_are_current(inputs []RetainedInlineInput) bool {
	// A dirty bit remains set throughout this pass. Compare the actual inputs
	// rather than treating that bit as a mutation between two intrinsic probes.
	for index, input in inputs {
		computed := input.node.computed_values()
		if voidptr(computed) != voidptr(input.style)
			|| computed.mutation_revision() != input.style_revision
			|| computed.has_animated_properties()
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

fn run_inline_formatting_context_for_width(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext, width_only bool) InlineFormattingResult {
	root := unsafe { &Node(containing_block) }
	mut pool := state.measurement_chunk_pool_
	if disable_inline_measurement_reuse || state.subtree_root == none
		|| pool == unsafe { nil } || pool.closed
		|| !inline_measurement_root_is_closed(root, context) {
		return run_uncached_inline_formatting_context_for_width(mut state, containing_block,
			mut used, mode, space, context, width_only)
	}
	key := inline_measurement_key(used, mode, space, width_only)
	node_key := u64(voidptr(root))
	font_generation := css.css_style_computer_for(root.document()).font_computer().environment_generation()
	previous := pool.inline_measurements_[node_key] or { []&InlineMeasurementLayout{} }
	for cached in previous {
		if cached.key == key && cached.font_generation == font_generation
			&& cached.font_policy == root.document().font_rendering_policy()
			&& cached.style_environment == root.document().style_environment_version()
			&& inline_measurement_inputs_are_current(cached.inputs) {
			used.borrow_retained_line_boxes(cached.lines)
			if !width_only {
				if position := cached.inline_end { used.set_inline_end_static_position_rect(position) }
			}
			if mut bfc := context {
				assert bfc.commit_pending_margin_before_inline_content().raw_value() == 0
			}
			if inline_measurement_diagnostics && !inline_measurement_reuse_reported {
				inline_measurement_reuse_reported = true
				eprintln('Vox inline measurement: reused closed text layout within pass')
			}
			return cached.result
		}
	}
	result := run_uncached_inline_formatting_context_for_width(mut state, containing_block,
		mut used, mode, space, context, width_only)
	// The ordinary text shaping caches retain their own payloads. Copy line
	// fragments and glyph runs explicitly; none may point into this probe's arena.
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut inputs := []RetainedInlineInput{}
	if !collect_retained_inline_inputs(root, true, mut inputs) { return result }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	for input in inputs {
		owned_inputs << RetainedInlineInput{ ...input, text: input.text.clone() }
	}
	cached := &InlineMeasurementLayout{
		key: key
		inputs: owned_inputs
		font_generation: css.css_style_computer_for(root.document()).font_computer().environment_generation()
		font_policy: root.document().font_rendering_policy()
		style_environment: root.document().style_environment_version()
		lines: own_inline_layout_lines(used.line_boxes)
		inline_end: used.inline_end_static_position_rect()
		result: result
	}
	mut entries := pool.inline_measurements_[node_key] or { []&InlineMeasurementLayout{} }
	if entries.len == 4 { entries.delete(0) }
	entries << cached
	pool.inline_measurements_[node_key] = entries
	return result
}
