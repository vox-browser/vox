module layout

import platform

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

// This is called only after the retained-inline eligibility walk succeeds.
// Other contexts retain their existing allocation and mutation boundaries.
fn run_closed_inline_layout(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, mode LayoutMode, space AvailableSpace,
	context ?&BlockFormattingContext) InlineFormattingResult {
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
	used.line_boxes = own_inline_layout_lines(used.line_boxes)
	return result
}
