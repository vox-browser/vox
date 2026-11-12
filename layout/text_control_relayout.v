module layout

import css
import dom
import os

// Typing into a textarea or text input dirties only the control's internal
// editor, yet an ordinary document pass lays out every ancestor again: none
// of their retained caches survive an edited descendant. When every layout
// invalidation since the previous committed pass originated inside text
// controls, this pass instead restores the previous geometry and repeats only
// each control's final inner layout. It is accepted only if the control
// reports the same automatic size and baselines, so no ancestor could have
// laid out differently; otherwise the complete pass runs.
const disable_text_control_relayout = os.getenv('VOX_DISABLE_TEXT_CONTROL_RELAYOUT') != ''
const text_control_relayout_diagnostics = os.getenv('VOX_TEXT_CONTROL_RELAYOUT_DIAGNOSTICS') != ''
// Also runs the complete pass and reports any geometry difference (testing).
const verify_text_control_relayout = os.getenv('VOX_VERIFY_TEXT_CONTROL_RELAYOUT') != ''

__global text_control_relayout_passes u64

// Accepted text-control passes in this process (tests and diagnostics).
pub fn text_control_relayout_pass_count() u64 {
	return text_control_relayout_passes
}

// The last committed inner layout of a text control: the control's used
// values just before that call, its available space and its result.
struct TextControlInnerLayout {
	before UsedValues
	space  AvailableSpace
	result FormattingContextResult
}

// Facts about a committed pass that the next pass must match.
struct CommittedLayoutPass {
	viewport_width     f64
	viewport_height    f64
	coordinate_scale   f64
	font_generation    u64
	font_policy        dom.FontRenderingPolicy
	style_environment  u64
	replaced_signature u64
}

fn text_control_host(node &Node) bool {
	return node.is_textarea_box() || node.is_text_input_box()
}

// The text control whose internal editor contains `node`, if any.
fn text_control_containing(node &Node) ?&Node {
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if text_control_host(current) { return current }
		ancestor = current.parent()
	}
	return none
}

// Called for every layout invalidation, before the already-dirty early exit:
// a node first dirtied by propagation can later change itself.
fn note_layout_invalidation_origin(node &Node) {
	if node.document_ == unsafe { nil } { return }
	result := document_layout_result(node.document_) or { return }
	if result.state == unsafe { nil } { return }
	mut state := unsafe { &LayoutState(result.state) }
	note_incremental_layout_origin(mut state, node)
	if disable_text_control_relayout || state.general_layout_invalidation_ { return }
	if control := text_control_containing(node) {
		for existing in state.dirty_text_controls_ {
			if voidptr(existing) == voidptr(control) { return }
		}
		state.dirty_text_controls_ << control
		return
	}
	state.general_layout_invalidation_ = true
}

fn record_text_control_inner_layout(mut state LayoutState, box &Node, before &UsedValues,
	space AvailableSpace, result FormattingContextResult) {
	if disable_text_control_relayout || state.subtree_root != none || !text_control_host(box) { return }
	styled := box.as_node_with_style() or { return }
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	mut snapshot := *before
	snapshot.line_boxes = []LineBox{}
	snapshot.line_boxes_are_shared_ = false
	if rare := before.rare_ {
		snapshot.rare_ = rare.clone()
		snapshot.rare_is_shared_ = false
	}
	state.text_control_layouts_[styled.layout_index()] = TextControlInnerLayout{
		before: snapshot
		space: space
		result: result
	}
}

fn committed_layout_pass(document &dom.Document, viewport_width f64, viewport_height f64,
	replaced_signature u64) CommittedLayoutPass {
	return CommittedLayoutPass{
		viewport_width: viewport_width
		viewport_height: viewport_height
		coordinate_scale: document.layout_coordinate_scale()
		font_generation: css.css_style_computer_for(document).font_computer().environment_generation()
		font_policy: document.font_rendering_policy()
		style_environment: document.style_environment_version()
		replaced_signature: replaced_signature
	}
}

fn mix_signature(hash u64, value u64) u64 {
	return (hash ^ value) * u64(0x100000001b3)
}

fn mix_optional_pixels(hash u64, value ?CSSPixels) u64 {
	if pixels := value { return mix_signature(mix_signature(hash, 1), u64(u32(pixels.raw_value()))) }
	return mix_signature(hash, 0)
}

// Live natural sizes (images, video metadata, embedded documents) are read
// during layout rather than invalidated through layout nodes.
fn mix_replaced_natural_size(hash u64, node &Node) u64 {
	if !node.is_replaced_box() { return hash }
	box := node.as_box() or { return hash }
	size := box.natural_size()
	mut result := mix_optional_pixels(mix_optional_pixels(mix_signature(hash, u64(voidptr(node))),
		size.width), size.height)
	if ratio := size.aspect_ratio {
		result = mix_signature(mix_signature(result, u64(u32(ratio.numerator_.raw_value()))),
			u64(u32(ratio.denominator_.raw_value())))
	}
	return result
}

struct TextControlBaselines {
	first        CSSPixels
	last         CSSPixels
	inline_first CSSPixels
	inline_last  CSSPixels
}

fn layout_box_baselines(state &LayoutState, box &Node) TextControlBaselines {
	return TextControlBaselines{
		first: layout_box_baseline_in_context(state, box, .first, false, false)
		last: layout_box_baseline_in_context(state, box, .last, false, false)
		inline_first: layout_box_baseline_in_context(state, box, .first, true, true)
		inline_last: layout_box_baseline_in_context(state, box, .last, true, true)
	}
}

fn text_control_relayout_reject(reason string) {
	if text_control_relayout_diagnostics { eprintln('VOX_TEXT_CONTROL_RELAYOUT result=full reason=${reason}') }
}

fn subtree_has_out_of_flow_or_float(node &Node) bool {
	for child in node.children() {
		if child.is_absolutely_positioned() || child.is_floating() || child.is_fixed_position() { return true }
		if subtree_has_out_of_flow_or_float(child) { return true }
	}
	return false
}

fn collect_layout_subtree_indices(node &Node, mut indices map[u32]bool) {
	for child in node.children() {
		if styled := child.as_node_with_style() { indices[styled.layout_index()] = true }
		collect_layout_subtree_indices(child, mut indices)
	}
}

fn clear_subtree_scrollable_overflow(mut state LayoutState, node &Node) {
	if styled := node.as_node_with_style() {
		if mut used := state.try_get(styled) {
			used.scrollable_overflow_rect_ = none
			used.has_scrollable_overflow_ = false
		}
	}
	for child in node.children() { clear_subtree_scrollable_overflow(mut state, child) }
}

// The geometry half of a text-control pass. Returns none when a complete pass
// is required; nothing outside the returned state has been modified then.
fn relayout_dirty_text_controls(document &dom.Document, root &Node, previous &LayoutState,
	pass CommittedLayoutPass) ?&LayoutState {
	if disable_text_control_relayout { return none }
	if previous.general_layout_invalidation_ {
		text_control_relayout_reject('general-invalidation')
		return none
	}
	if previous.dirty_text_controls_.len == 0 { return none }
	if previous.committed_pass_ != pass {
		text_control_relayout_reject('environment')
		return none
	}
	controls := previous.dirty_text_controls_.clone()
	mut skipped := map[u32]bool{}
	for control in controls {
		styled := control.as_node_with_style() or { return none }
		computed := control.computed_values()
		if computed.overflow_x() == .visible || computed.overflow_y() == .visible {
			text_control_relayout_reject('visible-overflow')
			return none
		}
		if subtree_has_out_of_flow_or_float(control) {
			text_control_relayout_reject('out-of-flow-content')
			return none
		}
		if styled.layout_index() !in previous.text_control_layouts_ || previous.try_get(styled) == none {
			text_control_relayout_reject('unrecorded-control')
			return none
		}
		collect_layout_subtree_indices(control, mut skipped)
	}
	mut state := LayoutState.new()
	unsafe {
		state.previous_inline_layouts_ = previous.inline_layouts_
		state.previous_block_layouts_ = previous.block_layouts_
	}
	state.block_layouts_ = previous.block_layouts_.clone()
	state.inline_layouts_ = previous.inline_layouts_.clone()
	state.text_control_layouts_ = previous.text_control_layouts_.clone()
	state.relayout_records_ = previous.relayout_records_.clone()
	state.resolved_anchor_positions_ = previous.resolved_anchor_positions_
	state.subgrid_storage_ = previous.subgrid_storage_
	state.begin_retained_block_backoff_pass(previous.block_layout_backoff_)
	state.previous_state_ = unsafe { &LayoutState(previous) }
	state.committed_pass_ = pass
	// Restore every committed value except the controls' internal editors,
	// which start fresh as in a complete pass.
	for page in previous.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for entry in page.entries {
			if entry == unsafe { nil } { continue }
			values := unsafe { &UsedValues(entry) }
			node := values.node_
			if node == unsafe { nil } || node.layout_index() in skipped { continue }
			mut containing := ?&UsedValues(none)
			if parent := values.containing_block_used_values_ {
				containing = state.get(parent.node_)
			}
			_ = state.restore_retained_values(node, values, containing)
		}
	}
	state.enable_measurement_chunk_pool()
	$if prealloc {
		state.measurement_chunk_pool_.scratch_enabled_ = document.native_storage() != unsafe { nil }
	}
	defer { state.release_measurement_chunk_pool() }
	mut geometry_scratch := begin_document_geometry_scratch(document)
	mut accepted := true
	for control in controls {
		styled := control.as_node_with_style() or { accepted = false; break }
		record := previous.text_control_layouts_[styled.layout_index()] or { accepted = false; break }
		committed := previous.try_get(styled) or { accepted = false; break }
		// The recorded call must be the one that produced the committed size.
		if !record.space.width.is_definite() || record.space.width.to_px_or_zero() != committed.content_width() {
			text_control_relayout_reject('recorded-width')
			accepted = false
			break
		}
		if record.space.height.is_definite() && record.space.height.to_px_or_zero() != committed.content_height() {
			text_control_relayout_reject('recorded-height')
			accepted = false
			break
		}
		old_baselines := layout_box_baselines(previous, control)
		mut used := state.get(styled)
		final_values := *used
		final_rare := used.rare_
		unsafe { *used = record.before }
		used.containing_block_used_values_ = final_values.containing_block_used_values_
		if rare := record.before.rare_ { used.rare_ = rare.clone() }
		result := layout_inside_independent_formatting_context(mut state, control, mut used, record.space)
		// With a definite inline size, parents consume only the automatic block
		// size; the widest line of a definite-width editor changes while typing.
		width_matters := !record.before.has_definite_width_
		if result.automatic_content_height != record.result.automatic_content_height
			|| (width_matters && result.automatic_content_width != record.result.automatic_content_width) {
			text_control_relayout_reject('automatic-size')
			accepted = false
			break
		}
		// The parent's final sizing and placement follow the inner layout.
		used.content_width_ = final_values.content_width_
		used.content_height_ = final_values.content_height_
		used.has_definite_width_ = final_values.has_definite_width_
		used.has_definite_height_ = final_values.has_definite_height_
		used.width_constraint = final_values.width_constraint
		used.height_constraint = final_values.height_constraint
		used.offset = final_values.offset
		used.margin_left = final_values.margin_left
		used.margin_right = final_values.margin_right
		used.margin_top = final_values.margin_top
		used.margin_bottom = final_values.margin_bottom
		used.border_left = final_values.border_left
		used.border_right = final_values.border_right
		used.border_top = final_values.border_top
		used.border_bottom = final_values.border_bottom
		used.padding_left = final_values.padding_left
		used.padding_right = final_values.padding_right
		used.padding_top = final_values.padding_top
		used.padding_bottom = final_values.padding_bottom
		used.inset_left = final_values.inset_left
		used.inset_right = final_values.inset_right
		used.inset_top = final_values.inset_top
		used.inset_bottom = final_values.inset_bottom
		used.containing_line_box_fragment = final_values.containing_line_box_fragment
		if rare := final_rare {
			used.rare_ = rare.clone()
			used.rare_is_shared_ = false
		} else {
			used.rare_ = none
		}
		if layout_box_baselines(state, control) != old_baselines {
			text_control_relayout_reject('baseline')
			accepted = false
			break
		}
		for child in control.children() { resolve_relative_insets(mut state, child) }
	}
	if !accepted {
		geometry_scratch.finish()
		state.previous_state_ = unsafe { nil }
		return none
	}
	coordinates := begin_paint_coordinate_session(state)
	for control in controls {
		clear_subtree_scrollable_overflow(mut state, control)
		mut contained := ContainedLayoutBoxes{}
		collect_contained_layout_boxes(control, state, mut contained)
		measure_scrollable_overflow_for_subtree(mut state, control, contained)
	}
	coordinates.finish()
	geometry_scratch.finish()
	state.previous_inline_layouts_ = map[u64]&RetainedInlineLayout{}
	state.previous_block_layouts_ = map[u64]&RetainedBlockLayout{}
	state.previous_state_ = unsafe { nil }
	text_control_relayout_passes++
	if text_control_relayout_diagnostics {
		eprintln('VOX_TEXT_CONTROL_RELAYOUT result=controls count=${controls.len}')
	}
	return state
}

fn used_values_geometry_differs(a &UsedValues, b &UsedValues) bool {
	if a.offset != b.offset || a.content_width_ != b.content_width_ || a.content_height_ != b.content_height_
		|| a.margin_left != b.margin_left || a.margin_right != b.margin_right
		|| a.margin_top != b.margin_top || a.margin_bottom != b.margin_bottom
		|| a.padding_left != b.padding_left || a.padding_right != b.padding_right
		|| a.padding_top != b.padding_top || a.padding_bottom != b.padding_bottom
		|| a.border_left != b.border_left || a.border_right != b.border_right
		|| a.border_top != b.border_top || a.border_bottom != b.border_bottom
		|| a.scrollable_overflow_rect_ != b.scrollable_overflow_rect_
		|| a.line_boxes.len != b.line_boxes.len {
		return true
	}
	for index, line in a.line_boxes {
		other := b.line_boxes[index]
		if line.fragments_.len != other.fragments_.len || line.bottom() != other.bottom()
			|| line.baseline() != other.baseline() { return true }
		for fragment_index, fragment in line.fragments_ {
			peer := other.fragments_[fragment_index]
			if fragment.offset() != peer.offset() || fragment.width() != peer.width()
				|| fragment.height() != peer.height() { return true }
		}
	}
	return false
}

// VOX_VERIFY_TEXT_CONTROL_RELAYOUT: compare the accepted state with a
// complete pass over the same inputs.
fn verify_text_control_geometry(fast &LayoutState, full &LayoutState) {
	mut checked := 0
	mut mismatches := 0
	for page in full.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for entry in page.entries {
			if entry == unsafe { nil } { continue }
			expected := unsafe { &UsedValues(entry) }
			node := expected.node_
			if node == unsafe { nil } { continue }
			checked++
			actual := fast.try_get(node) or {
				mismatches++
				if mismatches <= 8 { eprintln('VOX_TEXT_CONTROL_RELAYOUT_VERIFY missing ${layout_debug_class_name(unsafe { &Node(node) })} <${layout_debug_tag(unsafe { &Node(node) })}>') }
				continue
			}
			if used_values_geometry_differs(actual, expected) {
				mismatches++
				if mismatches <= 8 {
					eprintln('VOX_TEXT_CONTROL_RELAYOUT_VERIFY differs ${layout_debug_class_name(unsafe { &Node(node) })} <${layout_debug_tag(unsafe { &Node(node) })}> offset=${actual.offset}/${expected.offset} size=${actual.content_width_.to_double()}x${actual.content_height_.to_double()}/${expected.content_width_.to_double()}x${expected.content_height_.to_double()} lines=${actual.line_boxes.len}/${expected.line_boxes.len}')
				}
			}
		}
	}
	eprintln('VOX_TEXT_CONTROL_RELAYOUT_VERIFY checked=${checked} mismatches=${mismatches}')
}
