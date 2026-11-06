module layout

import platform

// Allocation lifetime is independent of line-cache reuse. Generated text,
// shadow content and ordinary breaks can use a closed workspace even when
// their inputs cannot be retained as a reusable layout-cache entry.
fn inline_layout_workspace_is_closed(node &Node, root bool) bool {
	if node.is_svg_box() || node.is_replaced_box() || node.is_atomic_inline()
		|| node.is_floating() || node.is_positioned() || node.is_list_item_box()
		|| node.is_list_item_marker_box() {
		return false
	}
	if root {
		if !node.display().is_flow_inside()
			|| node.computed_values().writing_mode() != .horizontal_tb
			|| line_clamp_is_active(node.computed_values()) {
			return false
		}
	} else if !node.is_text_node() && !node.is_inline_node() && !node.is_break_node() {
		return false
	}
	if node.is_break_node() && node.computed_values().clear() != .none_ {
		return false
	}
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	if text := node.as_text_node() {
		if text.first_letter_ != none || text.source_range_length_ != none
			|| text.is_empty_editable_ || text.produces_line_box_fragment_when_empty_ {
			return false
		}
	}
	for child in node.children() {
		if !inline_layout_workspace_is_closed(child, false) { return false }
	}
	return true
}

// The closed inline algorithm only publishes lines, fragments and glyph runs.
// Nodes and fonts already have their own retained owners. Collect run identities
// before entering that owner so the temporary deduplication table stays local.
fn own_inline_layout_lines(lines []LineBox) []LineBox {
	mut run_indexes := map[u64]int{}
	mut source_runs := []&platform.GlyphRun{}
	for line_index in 0 .. lines.len {
		line := unsafe { &lines[line_index] }
		for fragment_index in 0 .. line.fragments_.len {
			fragment := unsafe { &line.fragments_[fragment_index] }
			if run := fragment.glyph_run_ {
				key := u64(voidptr(run))
				if key !in run_indexes {
					run_indexes[key] = source_runs.len
					source_runs << run
				}
			}
		}
	}
	mut owned_runs := []&platform.GlyphRun{len: source_runs.len, init: unsafe { nil }}
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	for index in 0 .. source_runs.len {
		owned_runs[index] = source_runs[index].clone_for_layout()
	}
	mut result := []LineBox{cap: lines.len}
	for line_index in 0 .. lines.len {
		line := unsafe { &lines[line_index] }
		result << LineBox{
			...line
			fragments_:               []LineBoxFragment{cap: line.fragments_.len}
			static_position_markers_: line.static_position_markers_.clone()
		}
		mut owned_line := unsafe { &result[result.len - 1] }
		for fragment_index in 0 .. line.fragments_.len {
			fragment := unsafe { &line.fragments_[fragment_index] }
			mut run := ?&platform.GlyphRun(none)
			if source := fragment.glyph_run_ {
				run = owned_runs[run_indexes[u64(voidptr(source))]]
			}
			mut ellipsis := ?string(none)
			if text := fragment.block_ellipsis_text_ { ellipsis = text.clone() }
			owned_line.fragments_ << LineBoxFragment{
				...fragment
				glyph_run_:           run
				block_ellipsis_text_: ellipsis
			}
		}
	}
	return result
}

// Both callers prove a closed ownership boundary. The separate cache-input
// walk additionally decides whether the completed result can be reused.
fn run_closed_inline_layout(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext) InlineFormattingResult {
	return run_owned_inline_layout_in_workspace(mut state, containing_block, mut used,
		mode, space, context, false)
}

fn run_owned_inline_layout_in_workspace(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext, clamped bool) InlineFormattingResult {
	document := unsafe { &Node(containing_block) }.document()
	if geometry_measurement_depth != 0 || !cache_uses_entered_document_storage(document) {
		return run_uncached_inline_formatting_context(mut state, containing_block, mut used, mode,
			space, context)
	}
	mut workspace := begin_document_geometry_scratch(document)
	if !workspace.active {
		return run_uncached_inline_formatting_context(mut state, containing_block, mut used, mode,
			space, context)
	}
	defer { workspace.finish() }
	// clear_line_boxes() may reuse a previous private vector. The workspace must
	// never append to that vector or mutate an older retained geometry snapshot.
	used.line_boxes = []LineBox{}
	used.line_boxes_are_shared_ = false
	result := run_uncached_inline_formatting_context(mut state, containing_block, mut used, mode,
		space, context)
	// A measurement-cache hit already borrows immutable, document-owned lines
	// and glyph runs. Keep that owner and the normal writable-detachment guard.
	if !used.line_boxes_are_shared_ {
		used.line_boxes = own_inline_layout_lines(used.line_boxes)
	}
	if clamped { report_clamped_inline_workspace() }
	return result
}
