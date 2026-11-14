module layout

import css
import dom
import os

// Incremental layout. Every change since the previous committed pass is
// reported through Node.set_needs_layout_update(), which also dirties every
// ancestor; changed natural sizes are compared at the start of a pass. Two
// mechanisms then avoid laying out unchanged content again:
//
// Subtree reuse (every pass, including tree rebuilds that keep clean
// subtrees): when a box establishing an independent formatting context has a
// clean subtree and its parent hands it the same inputs as in the previous
// pass, its committed inner layout and every descendant's committed values
// are restored instead of laid out.
//
// Bounded relayout (passes on the same layout tree): instead of laying out the
// document from its root, restore the previous geometry and repeat only the
// inner layout of the nearest relayout root above each changed node, a box
// whose committed inner layout was recorded and whose content no ancestor
// measured. A root is accepted only if it reports the same automatic size and
// baselines as before, so no ancestor could lay out differently; otherwise the
// next root above it is tried, and finally the complete pass runs (with
// subtree reuse). text_control_relayout.v is the special case for edits inside
// text controls, which are measured by their parents.
const disable_incremental_layout = os.getenv('VOX_DISABLE_INCREMENTAL_LAYOUT') != ''
const incremental_layout_diagnostics = os.getenv('VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS') != ''
// Also runs the complete pass and reports any geometry difference (testing).
const verify_incremental_layout = os.getenv('VOX_VERIFY_INCREMENTAL_LAYOUT') != ''
// With the above: compare two complete passes instead (determinism control).
const verify_incremental_layout_control = os.getenv('VOX_VERIFY_INCREMENTAL_LAYOUT_CONTROL') != ''
// More separate changes than this run the complete pass.
const incremental_layout_max_origins = 64
// Each rejected root may be replaced by the next one above it this many times.
const incremental_layout_max_escalations = 4

__global incremental_layout_passes u64

// Accepted incremental passes in this process (tests and diagnostics).
pub fn incremental_layout_pass_count() u64 {
	return incremental_layout_passes
}

// Geometry differences observed by the optional complete-pass verifier.
pub fn incremental_layout_verification_mismatch_count() u64 {
	return incremental_layout_verify_mismatches
}

// The committed inner layout of an independent formatting context: its used
// values just before and just after FormattingContext::layout_inside() (the
// latter without line boxes, which the committed values keep), the available
// space and the result.
struct RelayoutRecord {
	node   &Node = unsafe { nil }
	before UsedValues
	after  UsedValues
	space  AvailableSpace
	result FormattingContextResult
}

enum SubtreeLayoutDecision as u8 {
	fresh = 1
	reused
}

struct ReplacedSizeEntry {
	node &Node = unsafe { nil }
	hash u64
}

fn mark_sized_by_ancestor_measurement(node &Node) {
	if node.sized_by_ancestor_measurement_ { return }
	mut mutable := unsafe { &Node(node) }
	mutable.sized_by_ancestor_measurement_ = true
}

// The root element's automatic size does not report how the viewport sizes
// it, and it is clean only when the whole document is.
fn relayout_root_candidate(box &Node) bool {
	return !disable_incremental_layout && !box.is_viewport() && !box.is_root_element()
		&& box.as_node_with_style() != none
}

fn layout_record_snapshot(values &UsedValues) UsedValues {
	mut snapshot := *values
	snapshot.line_boxes = []LineBox{}
	snapshot.line_boxes_are_shared_ = false
	if rare := values.rare_ {
		snapshot.rare_ = rare.clone()
		snapshot.rare_is_shared_ = false
	}
	return snapshot
}

fn record_relayout_root(mut state LayoutState, box &Node, before &UsedValues, after &UsedValues,
	space AvailableSpace, result FormattingContextResult) {
	styled := box.as_node_with_style() or { return }
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	state.relayout_records_[styled.layout_index()] = RelayoutRecord{
		node:   box
		before: layout_record_snapshot(before)
		after:  layout_record_snapshot(after)
		space:  space
		result: result
	}
}

fn note_incremental_layout_origin(mut state LayoutState, node &Node) {
	if state.layout_invalidation_unbounded_ { return }
	for existing in state.layout_invalidation_origins_ {
		if voidptr(existing) == voidptr(node) { return }
	}
	if state.layout_invalidation_origins_.len >= incremental_layout_max_origins {
		state.layout_invalidation_unbounded_ = true
		state.layout_invalidation_origins_ = []&Node{}
		return
	}
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	state.layout_invalidation_origins_ << unsafe { &Node(node) }
}

// ImagePaintable::reset_for_relayout() for every image, with each replaced
// box's natural-size signature and their combination for this pass. Natural
// sizes are read during layout rather than invalidated through layout nodes.
fn reset_images_and_sign_replaced_sizes_by_node(node &Node, hash u64, mut sizes map[u32]ReplacedSizeEntry) u64 {
	if image_box := node.as_image_box() {
		mut mutable_image_box := unsafe { &ImageBox(image_box) }
		mutable_image_box.reset_for_relayout()
	}
	mut result := hash
	if node.is_replaced_box() {
		own := mix_replaced_natural_size(u64(0xcbf29ce484222325), node)
		if styled := node.as_node_with_style() {
			sizes[styled.layout_index()] = ReplacedSizeEntry{
				node: node
				hash: own
			}
		}
		result = mix_replaced_natural_size(result, node)
	}
	for child in node.children() {
		result = reset_images_and_sign_replaced_sizes_by_node(child, result, mut sizes)
	}
	return result
}

// Natural sizes are read during layout rather than reported through layout
// nodes. Dirty each replaced box whose size changed since the previous pass,
// so subtree reuse cannot restore its old geometry.
fn mark_changed_replaced_sizes(previous &LayoutState, replaced map[u32]ReplacedSizeEntry) {
	for _, entry in replaced {
		styled := entry.node.as_node_with_style() or { continue }
		lookup := committed_values_lookup(previous, styled)
		if lookup.values == unsafe { nil } { continue }
		prior := previous.replaced_sizes_[lookup.index] or { continue }
		if prior.hash != entry.hash && voidptr(prior.node) == voidptr(entry.node) {
			mut node := unsafe { &Node(entry.node) }
			node.set_needs_layout_update(true)
		}
	}
}

fn incremental_layout_reject(reason string) {
	if incremental_layout_diagnostics {
		eprintln('VOX_INCREMENTAL_LAYOUT result=full reason=${reason}')
	}
}

fn committed_layout_environment_matches(a CommittedLayoutPass, b CommittedLayoutPass) bool {
	return a.viewport_width == b.viewport_width && a.viewport_height == b.viewport_height
		&& a.coordinate_scale == b.coordinate_scale && a.font_generation == b.font_generation
		&& a.font_policy == b.font_policy && a.style_environment == b.style_environment
}

// The nearest proper ancestor of `node` that can bound its relayout.
fn incremental_relayout_root_above(previous &LayoutState, node &Node) ?&Node {
	mut ancestor := node.parent()
	mut candidate := ?&Node(none)
	for ancestor != none {
		current := ancestor or { break }
		// An intrinsic measurement may have returned a cache without entering
		// its descendants. A boundary below that measured ancestor cannot hide
		// changes to the inputs of the measurement.
		if current.sized_by_ancestor_measurement_ { candidate = none }
		if current.is_viewport() || current.is_root_element() { return candidate }
		if candidate == none && !current.sized_by_ancestor_measurement_ {
			if styled := current.as_node_with_style() {
				if record := previous.relayout_records_[styled.layout_index()] {
					if voidptr(record.node) == voidptr(current) && previous.try_get(styled) != none {
						candidate = current
					}
				}
			}
		}
		ancestor = current.parent()
	}
	return candidate
}

fn node_is_inclusive_ancestor(ancestor &Node, node &Node) bool {
	mut current := ?&Node(node)
	for current != none {
		candidate := current or { break }
		if voidptr(candidate) == voidptr(ancestor) { return true }
		current = candidate.parent()
	}
	return false
}

// Adds `root` unless an included root contains it, dropping included roots it
// contains.
fn add_incremental_relayout_root(mut roots []&Node, root &Node) {
	for existing in roots {
		if node_is_inclusive_ancestor(existing, root) { return }
	}
	roots = roots.filter(!node_is_inclusive_ancestor(root, it))
	roots << unsafe { &Node(root) }
}

fn clear_scrollable_overflow_in_state(mut state LayoutState) {
	for page in state.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for entry in page.entries {
			if entry == unsafe { nil } { continue }
			mut values := unsafe { &UsedValues(entry) }
			values.scrollable_overflow_rect_ = none
			values.has_scrollable_overflow_ = false
		}
	}
}

// The geometry half of an incremental pass. Returns none when a complete pass
// is required; nothing outside the returned state has been modified then.
fn relayout_incrementally(document &dom.Document, root &Node, previous &LayoutState,
	pass CommittedLayoutPass, replaced map[u32]ReplacedSizeEntry) ?&LayoutState {
	if disable_incremental_layout { return none }
	if previous.layout_invalidation_unbounded_ {
		incremental_layout_reject('too-many-changes')
		return none
	}
	if previous.resolved_anchor_positions_ {
		incremental_layout_reject('anchor-positioning')
		return none
	}
	if !committed_layout_environment_matches(previous.committed_pass_, pass) {
		incremental_layout_reject('environment')
		return none
	}
	mut origins := previous.layout_invalidation_origins_.clone()
	if previous.committed_pass_.replaced_signature != pass.replaced_signature {
		for key, entry in replaced {
			prior := previous.replaced_sizes_[key] or {
				origins << entry.node
				continue
			}
			if prior.hash != entry.hash || voidptr(prior.node) != voidptr(entry.node) {
				origins << entry.node
			}
		}
	}
	if origins.len == 0 {
		incremental_layout_reject('unrecorded-change')
		return none
	}
	if origins.len > incremental_layout_max_origins {
		incremental_layout_reject('too-many-changes')
		return none
	}
	mut roots := []&Node{}
	for origin in origins {
		relayout_root := incremental_relayout_root_above(previous, origin) or {
			incremental_layout_reject('no-root')
			return none
		}
		add_incremental_relayout_root(mut roots, relayout_root)
	}
	for _ in 0 .. incremental_layout_max_escalations + 1 {
		attempt := try_incremental_relayout(document, root, previous, pass, roots)
		if attempt.state != unsafe { nil } {
			return attempt.state
		}
		if attempt.failed == unsafe { nil } { return none }
		rejected := attempt.failed
		next := incremental_relayout_root_above(previous, rejected) or {
			incremental_layout_reject('no-root-above')
			return none
		}
		roots = roots.filter(voidptr(it) != voidptr(rejected))
		add_incremental_relayout_root(mut roots, next)
	}
	incremental_layout_reject('escalations')
	return none
}

// An accepted state, or the root whose result changed.
struct IncrementalRelayoutAttempt {
	state  &LayoutState = unsafe { nil }
	failed &Node        = unsafe { nil }
}

// Restores every committed value outside `roots` and repeats their inner
// layouts.
fn try_incremental_relayout(document &dom.Document, root &Node, previous &LayoutState,
	pass CommittedLayoutPass, roots []&Node) IncrementalRelayoutAttempt {
	mut skipped := map[u32]bool{}
	for relayout_root in roots {
		collect_layout_subtree_indices(relayout_root, mut skipped)
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
	state.subgrid_storage_ = previous.subgrid_storage_
	state.begin_retained_block_backoff_pass(previous.block_layout_backoff_)
	state.previous_state_ = unsafe { &LayoutState(previous) }
	state.subtree_reuse_source_ = unsafe { &LayoutState(previous) }
	state.committed_pass_ = pass
	// Every committed value except the roots' descendants, which start fresh
	// as in a complete pass.
	for page in previous.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for entry in page.entries {
			if entry == unsafe { nil } { continue }
			values := unsafe { &UsedValues(entry) }
			node := values.node_
			if node == unsafe { nil } || node.layout_index() in skipped { continue }
			mut containing := ?&UsedValues(none)
			if parent := committed_geometry_parent(unsafe { &Node(node) }, values) {
				containing = state.get(parent)
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
	for relayout_root in roots {
		if !relayout_root_inner_layout(mut state, previous, relayout_root) {
			geometry_scratch.finish()
			state.previous_state_ = unsafe { nil }
			state.subtree_reuse_source_ = unsafe { nil }
			return IncrementalRelayoutAttempt{
				failed: relayout_root
			}
		}
	}
	// The complete pass positions absolute boxes and aligns block contents
	// after every formatting context, then applies relative insets. Repeat
	// both inside the roots, whose descendants are fresh; restored boxes
	// already carry theirs.
	state.absolute_layout_status.clear()
	for relayout_root in roots {
		align_block_contents(mut state, relayout_root)
		for child in relayout_root.children() {
			layout_absolutely_positioned_subtree(mut state, child)
		}
	}
	for relayout_root in roots {
		for child in relayout_root.children() {
			resolve_relative_insets(mut state, child)
		}
	}
	// A root's visible overflow reaches its ancestors' scrollable overflow.
	coordinates := begin_paint_coordinate_session(state)
	clear_scrollable_overflow_in_state(mut state)
	measure_document_scrollable_overflow(mut state, root)
	coordinates.finish()
	state.subtree_layout_decisions_ = map[u64]SubtreeLayoutDecision{}
	geometry_scratch.finish()
	state.previous_inline_layouts_ = map[u64]&RetainedInlineLayout{}
	state.previous_block_layouts_ = map[u64]&RetainedBlockLayout{}
	state.previous_state_ = unsafe { nil }
	state.subtree_reuse_source_ = unsafe { nil }
	state.block_layout_rejections_ = map[u64]bool{}
	incremental_layout_passes++
	if incremental_layout_diagnostics {
		eprintln('VOX_INCREMENTAL_LAYOUT result=incremental roots=${roots.len} relaid=${skipped.len}')
	}
	return IncrementalRelayoutAttempt{
		state: state
	}
}

// Repeats one root's committed inner layout. False when its automatic size,
// baselines or recorded inputs show that its parent could lay out differently.
fn relayout_root_inner_layout(mut state LayoutState, previous &LayoutState, relayout_root &Node) bool {
	styled := relayout_root.as_node_with_style() or { return false }
	record := previous.relayout_records_[styled.layout_index()] or { return false }
	committed := previous.try_get(styled) or { return false }
	// The recorded call must be the one that produced the committed size.
	if !record.space.width.is_definite() || record.space.width.to_px_or_zero() != committed.content_width() {
		incremental_layout_reject('recorded-width')
		return false
	}
	if record.space.height.is_definite() && record.space.height.to_px_or_zero() != committed.content_height() {
		incremental_layout_reject('recorded-height')
		return false
	}
	old_baselines := layout_box_baselines(previous, relayout_root)
	mut used := state.get(styled)
	final_values := *used
	final_rare := used.rare_
	unsafe { *used = record.before }
	used.containing_block_used_values_ = final_values.containing_block_used_values_
	if rare := record.before.rare_ { used.rare_ = rare.clone() }
	result := layout_inside_independent_formatting_context(mut state, relayout_root, mut used,
		record.space)
	// The parent consumes an automatic inline size only when it left that axis
	// indefinite before this inner layout. A definite block size before the
	// inner layout does not prove the parent ignores the automatic one (the
	// root element's is definite, yet it grows with its content); only a fixed
	// computed height does.
	width_matters := !record.before.has_definite_width_
	height_matters := !(record.before.has_definite_height_
		&& positioned_image_size_is_definite(relayout_root.computed_values().height(), false))
	if (height_matters && result.automatic_content_height != record.result.automatic_content_height)
		|| (width_matters && result.automatic_content_width != record.result.automatic_content_width) {
		incremental_layout_reject('automatic-size')
		return false
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
	if relayout_root_baselines_matter(relayout_root)
		&& layout_box_baselines(state, relayout_root) != old_baselines {
		incremental_layout_reject('baseline')
		return false
	}
	return true
}

// Subtree layout reuse. When nothing in `box`'s subtree changed since the
// reuse source was committed and its parent hands it the same inputs, its
// inner layout would reproduce the committed one: restore that instead,
// with every descendant's committed values. The complete pass's later steps
// (absolute positioning, block-content alignment and relative insets) have
// already been applied to those values; they skip reused subtrees.
// A layout-tree rebuild that keeps clean subtrees assigns new layout indices,
// so a retained node's committed values may be stored under its previous
// index. `conflict`: an entry exists there but belongs to another node.
struct CommittedValuesLookup {
	values   &UsedValues = unsafe { nil }
	index    u32
	conflict bool
}

fn committed_values_lookup(previous &LayoutState, styled &NodeWithStyle) CommittedValuesLookup {
	mut conflict := false
	for index in [styled.layout_index(), styled.previous_layout_index_] {
		values := previous.used_values_store.get(index) or { continue }
		if voidptr(values.node_) == voidptr(styled) {
			return CommittedValuesLookup{
				values: values
				index:  index
			}
		}
		conflict = true
	}
	return CommittedValuesLookup{
		conflict: conflict
	}
}

fn reuse_committed_subtree_layout(mut state LayoutState, box &Node, mut box_state UsedValues,
	space AvailableSpace) ?FormattingContextResult {
	previous := state.subtree_reuse_source_
	if previous == unsafe { nil } || box.needs_layout_update() || box.descendant_needs_layout_update_ {
		if incremental_layout_diagnostics {
			if previous == unsafe { nil } { incremental_layout_fresh_counts[0]++ } else { incremental_layout_fresh_counts[1]++ }
		}
		return none
	}
	// A face that loads during this pass changes text metrics everywhere; the
	// stabilization pass that follows lays out against it.
	if css.css_style_computer_for(box.document()).font_computer().environment_generation() !=
		previous.committed_pass_.font_generation {
		return none
	}
	styled := box.as_node_with_style() or { return none }
	lookup := committed_values_lookup(previous, styled)
	if lookup.values == unsafe { nil } {
		if incremental_layout_diagnostics { incremental_layout_fresh_counts[2]++ }
		return none
	}
	committed := lookup.values
	record := previous.relayout_records_[lookup.index] or {
		if incremental_layout_diagnostics { incremental_layout_fresh_counts[3]++ }
		return none
	}
	if voidptr(record.node) != voidptr(box) || record.space != space
		|| !subtree_layout_inputs_match(&record.before, box_state) {
		if incremental_layout_diagnostics {
			incremental_layout_fresh_counts[4]++
			parent_display := if parent := box.parent() { parent.display().to_string() } else { '' }
			eprintln('VOX_INCREMENTAL_LAYOUT reuse=rejected tag=${layout_debug_tag(box)} same_node=${voidptr(record.node) == voidptr(box)} space_matches=${record.space == space} differs=${subtree_layout_inputs_difference(&record.before, box_state)} recorded_height=${record.before.content_height_.to_double()}/${record.before.has_definite_height_} now_height=${box_state.content_height_.to_double()}/${box_state.has_definite_height_} after_height=${record.after.content_height_.to_double()} display=${box.display().to_string()} parent_display=${parent_display}')
		}
		return none
	}
	if block_contents_need_alignment(box) || subtree_reuse_blocked(previous, box, box) {
		if incremental_layout_diagnostics { incremental_layout_fresh_counts[5]++ }
		return none
	}
	mut retained := retain_geometry_allocations()
	defer { retained.finish() }
	apply_recorded_inner_layout(mut box_state, &record.before, &record.after)
	box_state.borrow_retained_line_boxes(committed.line_boxes)
	for child in box.children() {
		restore_committed_layout_node(mut state, previous, child)
	}
	carry_committed_layout_records(mut state, previous, box)
	state.subtree_layout_decisions_[u64(voidptr(box))] = .reused
	incremental_layout_reused_subtrees++
	return record.result
}

// The parent sets some of a box's values (its offset, margins, insets) before
// the inner layout and keeps them. Apply only what the recorded inner layout
// changed from its recorded inputs; the matched inputs make the rest equal.
fn apply_recorded_inner_layout(mut values UsedValues, before &UsedValues, after &UsedValues) {
	if after.content_width_ != before.content_width_ {
		values.content_width_ = after.content_width_
	}
	if after.content_height_ != before.content_height_ {
		values.content_height_ = after.content_height_
	}
	if after.has_definite_width_ != before.has_definite_width_ {
		values.has_definite_width_ = after.has_definite_width_
	}
	if after.has_definite_height_ != before.has_definite_height_ {
		values.has_definite_height_ = after.has_definite_height_
	}
	if after.width_constraint != before.width_constraint {
		values.width_constraint = after.width_constraint
	}
	if after.height_constraint != before.height_constraint {
		values.height_constraint = after.height_constraint
	}
	if after.offset != before.offset { values.offset = after.offset }
	if after.margin_left != before.margin_left { values.margin_left = after.margin_left }
	if after.margin_right != before.margin_right { values.margin_right = after.margin_right }
	if after.margin_top != before.margin_top { values.margin_top = after.margin_top }
	if after.margin_bottom != before.margin_bottom { values.margin_bottom = after.margin_bottom }
	if after.border_left != before.border_left { values.border_left = after.border_left }
	if after.border_right != before.border_right { values.border_right = after.border_right }
	if after.border_top != before.border_top { values.border_top = after.border_top }
	if after.border_bottom != before.border_bottom { values.border_bottom = after.border_bottom }
	if after.padding_left != before.padding_left { values.padding_left = after.padding_left }
	if after.padding_right != before.padding_right { values.padding_right = after.padding_right }
	if after.padding_top != before.padding_top { values.padding_top = after.padding_top }
	if after.padding_bottom != before.padding_bottom {
		values.padding_bottom = after.padding_bottom
	}
	if after.inset_left != before.inset_left { values.inset_left = after.inset_left }
	if after.inset_right != before.inset_right { values.inset_right = after.inset_right }
	if after.inset_top != before.inset_top { values.inset_top = after.inset_top }
	if after.inset_bottom != before.inset_bottom { values.inset_bottom = after.inset_bottom }
	if after.containing_line_box_fragment != before.containing_line_box_fragment {
		values.containing_line_box_fragment = after.containing_line_box_fragment
	}
	if voidptr(after.inline_end_static_position_snapshot_) != voidptr(before.inline_end_static_position_snapshot_) {
		values.inline_end_static_position_snapshot_ = after.inline_end_static_position_snapshot_
		values.inline_end_snapshot_arena_ = after.inline_end_snapshot_arena_
	}
	// Parent-set rare inputs matched; take the rest from the inner layout.
	if rare := after.rare_ {
		values.rare_ = rare.clone()
	} else {
		values.rare_ = none
	}
	values.rare_is_shared_ = false
}

__global incremental_layout_reused_subtrees u64
// VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS: why committed subtrees were laid out
// again (no source, dirty, no committed values, no record, changed inputs,
// blocked), cumulative.
__global incremental_layout_fresh_counts [6]u64

fn report_incremental_layout_pass(same_tree bool) {
	report_retained_flow_rejections()
	if !incremental_layout_diagnostics { return }
	eprintln('VOX_INCREMENTAL_LAYOUT pass same_tree=${same_tree} reused=${incremental_layout_reused_subtrees} no_source=${incremental_layout_fresh_counts[0]} dirty=${incremental_layout_fresh_counts[1]} uncommitted=${incremental_layout_fresh_counts[2]} unrecorded=${incremental_layout_fresh_counts[3]} changed_inputs=${incremental_layout_fresh_counts[4]} blocked=${incremental_layout_fresh_counts[5]}')
}

// Reused subtree roots in this process (tests and diagnostics).
pub fn incremental_layout_reused_subtree_count() u64 {
	return incremental_layout_reused_subtrees
}

// Table rows, groups, columns and captions can be positioned relative to the
// principal table instead of their CSS containing block (its wrapper). Preserve
// that coordinate parent while it is still an ancestor in the current tree.
// Other boxes, and replaced ancestors, rebind to the current containing block.
fn committed_geometry_parent(node &Node, values &UsedValues) ?&NodeWithStyle {
	if parent := values.containing_block_used_values_ {
		parent_node := unsafe { &Node(parent.node_) }
		if parent_node.display().is_table_inside()
			&& node_is_inclusive_ancestor(parent_node, node) {
			return parent.node_
		}
	}
	containing := node.containing_block() or { return none }
	return unsafe { &Node(containing) }.as_node_with_style()
}

fn restore_committed_layout_node(mut state LayoutState, previous &LayoutState, node &Node) {
	if styled := node.as_node_with_style() {
		lookup := committed_values_lookup(previous, styled)
		if lookup.values != unsafe { nil } {
			values := lookup.values
			mut containing := ?&UsedValues(none)
			if parent := committed_geometry_parent(node, values) {
				containing = state.get(parent)
			}
			mut restored := state.restore_retained_values(styled, values, containing)
			restored.scrollable_overflow_rect_ = none
			restored.has_scrollable_overflow_ = false
		}
		carry_committed_layout_records(mut state, previous, node)
	}
	for child in node.children() {
		restore_committed_layout_node(mut state, previous, child)
	}
}

// Per-node records of the reuse source that a later pass may consult.
fn carry_committed_layout_records(mut state LayoutState, previous &LayoutState, node &Node) {
	styled := node.as_node_with_style() or { return }
	lookup := committed_values_lookup(previous, styled)
	if lookup.values != unsafe { nil } {
		index := styled.layout_index()
		old_index := lookup.index
		if record := previous.relayout_records_[old_index] {
			if voidptr(record.node) == voidptr(node) { state.relayout_records_[index] = record }
		}
		if record := previous.text_control_layouts_[old_index] {
			state.text_control_layouts_[index] = record
		}
		if previous.subgrid_storage_ != unsafe { nil } {
			if subgrid := previous.subgrid_storage_.values[old_index] {
				mut storage := state.ensure_subgrid_storage()
				storage.values[index] = subgrid
			}
		}
	}
	key := u64(voidptr(node))
	if cache := previous.block_layouts_[key] {
		state.block_layouts_[key] = cache
	}
	if cache := previous.inline_layouts_[key] {
		state.inline_layouts_[key] = cache
	}
}

fn subtree_optional_pixels_equal(a ?CSSPixels, b ?CSSPixels) bool {
	if x := a {
		if y := b { return x == y }
		return false
	}
	return b == none
}

// The values a parent sets before FormattingContext::layout_inside() that the
// inner layout reads. Offsets and margins only place the box.
fn subtree_layout_inputs_match(a &UsedValues, b &UsedValues) bool {
	if a.content_width_ != b.content_width_ || a.content_height_ != b.content_height_
		|| a.has_definite_width_ != b.has_definite_width_ || a.has_definite_height_ != b.has_definite_height_
		|| a.width_constraint != b.width_constraint || a.height_constraint != b.height_constraint
		|| a.padding_left != b.padding_left || a.padding_right != b.padding_right
		|| a.padding_top != b.padding_top || a.padding_bottom != b.padding_bottom
		|| a.border_left != b.border_left || a.border_right != b.border_right
		|| a.border_top != b.border_top || a.border_bottom != b.border_bottom {
		return false
	}
	x := a.rare_ or { &UsedValuesRareData{} }
	y := b.rare_ or { &UsedValuesRareData{} }
	if x.override_borders_data_ != none || y.override_borders_data_ != none {
		return false
	}
	return x.static_position_rect_ == y.static_position_rect_
		&& subtree_optional_pixels_equal(x.box_model_percentage_basis_, y.box_model_percentage_basis_)
		&& subtree_optional_pixels_equal(x.collapsed_flow_margin_bottom_, y.collapsed_flow_margin_bottom_)
		&& x.abspos_containing_block_rect_ == y.abspos_containing_block_rect_
		&& x.table_cell_coordinates_ == y.table_cell_coordinates_
		&& x.uses_collapsing_borders_model_ == y.uses_collapsing_borders_model_
		&& x.is_collapsed_borders_table_box_ == y.is_collapsed_borders_table_box_
		&& x.hidden_by_collapsed_columns_ == y.hidden_by_collapsed_columns_
		&& x.has_line_clamp_point_ == y.has_line_clamp_point_
		&& x.is_invisible_for_line_clamp_ == y.is_invisible_for_line_clamp_
}

// The first input that differs, for VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS.
fn subtree_layout_inputs_difference(a &UsedValues, b &UsedValues) string {
	if a.content_width_ != b.content_width_ { return 'content-width' }
	if a.content_height_ != b.content_height_ { return 'content-height' }
	if a.has_definite_width_ != b.has_definite_width_ { return 'definite-width' }
	if a.has_definite_height_ != b.has_definite_height_ { return 'definite-height' }
	if a.width_constraint != b.width_constraint { return 'width-constraint' }
	if a.height_constraint != b.height_constraint { return 'height-constraint' }
	if a.padding_left != b.padding_left || a.padding_right != b.padding_right
		|| a.padding_top != b.padding_top || a.padding_bottom != b.padding_bottom {
		return 'padding'
	}
	if a.border_left != b.border_left || a.border_right != b.border_right || a.border_top != b.border_top
		|| a.border_bottom != b.border_bottom {
		return 'border'
	}
	x := a.rare_ or { &UsedValuesRareData{} }
	y := b.rare_ or { &UsedValuesRareData{} }
	if x.override_borders_data_ != none || y.override_borders_data_ != none { return 'override-borders' }
	if x.static_position_rect_ != y.static_position_rect_ { return 'static-position' }
	if !subtree_optional_pixels_equal(x.box_model_percentage_basis_, y.box_model_percentage_basis_) {
		return 'percentage-basis'
	}
	if !subtree_optional_pixels_equal(x.collapsed_flow_margin_bottom_, y.collapsed_flow_margin_bottom_) {
		return 'collapsed-margin'
	}
	if x.abspos_containing_block_rect_ != y.abspos_containing_block_rect_ { return 'abspos-rect' }
	if x.table_cell_coordinates_ != y.table_cell_coordinates_ { return 'table-cell' }
	if subtree_layout_inputs_match(a, b) { return '' }
	return 'other-rare'
}

// align_block_contents() would move the box's children after layout.
fn block_contents_need_alignment(node &Node) bool {
	if !node.is_block_container()
		|| (!node.display().is_flow_inside() && !node.display().is_flow_root_inside() && !node.display().is_table_caption())
		|| node.is_replaced_box() || node.is_viewport() || node.is_table_wrapper()
		|| node.computed_values().writing_mode() != .horizontal_tb
		|| node.computed_values().establishes_multi_column_container() {
		return false
	}
	text := block_content_alignment_text(node)
	align := if text == 'last baseline' { 'end' } else { text.split(' ').last() }
	return align in ['center', 'end', 'flex-end', 'flow-end', 'space-around', 'space-evenly']
}

// Same-binary control: treat every list item and generated box as dependent
// on content outside a reused subtree.
const retain_static_generated_blocking = os.getenv('VOX_RETAIN_STATIC_GENERATED_BLOCKING') != ''

// Whether `node` is a marker, list item or generated box whose content a
// counter or the quote depth produces. Generated text belongs to the marker
// or pseudo-element box that contains it, which is examined as its parent.
fn generated_box_depends_on_document_order(node &Node) bool {
	if node.is_generated_text_node() { return false }
	if node.is_list_item_marker_box() { return !retained_flow_marker_box_is_static(node) }
	if node.is_list_item_box() { return !retained_flow_list_item_box_is_static(node) }
	if node.is_generated_for_pseudo_element() { return generated_content_uses_document_state(node) }
	return false
}

// An out-of-flow descendant positioned against a box outside `boundary`
// depends on geometry the subtree does not own. Layout indices are not unique
// across trees laid out in one state, so each committed value must belong to
// its node.
fn subtree_reuse_blocked(previous &LayoutState, node &Node, boundary &Node) bool {
	// Counter-generated content can depend on preceding siblings outside the
	// boundary. Its text and marker sizing must run through layout again.
	// Bullets, authored strings and other content that no counter or quote
	// depth produces depend on nothing outside their box.
	if retain_static_generated_blocking {
		if node.is_list_item_box() || node.is_list_item_marker_box()
			|| node.is_generated_text_node() || node.is_generated_for_pseudo_element() {
			return true
		}
	} else if generated_box_depends_on_document_order(node) {
		return true
	}
	for child in node.children() {
		if child.is_absolutely_positioned() || child.is_fixed_position() {
			containing := child.containing_block() or { return true }
			if !node_is_inclusive_ancestor(boundary, unsafe { &Node(containing) }) { return true }
		}
		if styled := child.as_node_with_style() {
			lookup := committed_values_lookup(previous, styled)
			if lookup.values == unsafe { nil } && lookup.conflict {
				if incremental_layout_diagnostics {
					eprintln('VOX_INCREMENTAL_LAYOUT reuse=rejected tag=${layout_debug_tag(child)} reason=index-conflict')
				}
				return true
			}
		}
		if subtree_reuse_blocked(previous, child, boundary) { return true }
	}
	return false
}

// Whether `node` lies in a subtree that this pass restored from the reuse
// source: its nearest independent formatting context (`node` itself when
// `inclusive`) was reused rather than laid out.
fn (state &LayoutState) in_reused_subtree(node &Node, inclusive bool) bool {
	if state.subtree_layout_decisions_.len == 0 { return false }
	mut current := if inclusive { ?&Node(node) } else { node.parent() }
	for current != none {
		candidate := current or { break }
		if decision := state.subtree_layout_decisions_[u64(voidptr(candidate))] {
			return decision == .reused
		}
		current = candidate.parent()
	}
	return false
}

// Whether `node`'s descendants were restored by subtree reuse, given whether
// its own nearest independent formatting context above was.
fn subtree_layout_reused_below(state &LayoutState, node &Node, parent_reused bool) bool {
	if state.subtree_layout_decisions_.len == 0 { return false }
	if decision := state.subtree_layout_decisions_[u64(voidptr(node))] {
		return decision == .reused
	}
	return parent_reused
}

// A block's baselines reach its parent's geometry only through baseline
// alignment: as an atomic inline in a line box, a flex or grid item, or a table
// cell, or through an ancestor that is one of those. Ordinary blocks above it
// stack by their margin boxes.
fn relayout_root_baselines_matter(relayout_root &Node) bool {
	mut current := ?&Node(relayout_root)
	for current != none {
		node := current or { break }
		if node.is_viewport() { return false }
		display := node.display()
		if node.is_flex_item() || node.is_grid_item() || display.is_inline_outside()
			|| display.is_table_cell() || node.is_atomic_inline() {
			return true
		}
		current = node.parent()
	}
	return false
}

// A face loaded during either pass changes the inputs of the comparison.
fn verify_incremental_layout_geometry_for(document &dom.Document, pass CommittedLayoutPass,
	fast &LayoutState, full &LayoutState) {
	if css.css_style_computer_for(document).font_computer().environment_generation() != pass.font_generation {
		eprintln('VOX_INCREMENTAL_LAYOUT_VERIFY skipped: fonts changed during the pass')
		return
	}
	verify_incremental_layout_geometry(fast, full)
}

// VOX_VERIFY_INCREMENTAL_LAYOUT: compare the accepted state with a complete
// pass over the same inputs.
fn verify_incremental_layout_geometry(fast &LayoutState, full &LayoutState) {
	mut checked := 0
	mut mismatches := 0
	mut overflow_only := 0
	mut last := []string{}
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
				if mismatches <= 8 {
					eprintln('VOX_INCREMENTAL_LAYOUT_VERIFY missing ${layout_debug_class_name(unsafe { &Node(node) })} <${layout_debug_tag(unsafe { &Node(node) })}>')
				}
				continue
			}
			if used_values_geometry_differs(actual, expected) {
				fields := used_values_differing_fields(actual, expected)
				if fields.starts_with('overflow:') && !fields.contains(' ') {
					overflow_only++
				}
				mismatches++
				line := 'VOX_INCREMENTAL_LAYOUT_VERIFY differs ${layout_debug_class_name(unsafe { &Node(node) })} <${layout_debug_tag(unsafe { &Node(node) })}> index=${node.layout_index()} fields=${fields}'
				if mismatches <= 4 {
					eprintln(line)
				} else {
					last << line
					if last.len > 8 { last.delete(0) }
				}
			}
		}
	}
	for line in last { eprintln(line) }
	for page in fast.used_values_store.pages {
		if page == unsafe { nil } { continue }
		for entry in page.entries {
			if entry == unsafe { nil } { continue }
			values := unsafe { &UsedValues(entry) }
			node := values.node_
			if node == unsafe { nil } || full.try_get(node) != none { continue }
			mismatches++
			eprintln('VOX_INCREMENTAL_LAYOUT_VERIFY extra ${layout_debug_class_name(unsafe { &Node(node) })} <${layout_debug_tag(unsafe { &Node(node) })}> index=${node.layout_index()}')
		}
	}
	incremental_layout_verify_mismatches += u64(mismatches)
	eprintln('VOX_INCREMENTAL_LAYOUT_VERIFY checked=${checked} mismatches=${mismatches} overflow_only=${overflow_only}')
}

fn pixel_point_text(point css.CSSPixelPoint) string {
	return '${point.x().to_double()},${point.y().to_double()}'
}

fn used_values_differing_fields(a &UsedValues, b &UsedValues) string {
	mut fields := []string{}
	if a.offset != b.offset {
		fields << 'offset:${pixel_point_text(a.offset)}/${pixel_point_text(b.offset)}'
	}
	if a.content_width_ != b.content_width_ || a.content_height_ != b.content_height_ {
		fields << 'size:${a.content_width_.to_double()}x${a.content_height_.to_double()}/${b.content_width_.to_double()}x${b.content_height_.to_double()}'
	}
	if a.margin_left != b.margin_left || a.margin_right != b.margin_right || a.margin_top != b.margin_top
		|| a.margin_bottom != b.margin_bottom {
		fields << 'margin'
	}
	if a.padding_left != b.padding_left || a.padding_right != b.padding_right
		|| a.padding_top != b.padding_top || a.padding_bottom != b.padding_bottom {
		fields << 'padding'
	}
	if a.border_left != b.border_left || a.border_right != b.border_right || a.border_top != b.border_top
		|| a.border_bottom != b.border_bottom {
		fields << 'border'
	}
	if a.scrollable_overflow_rect_ != b.scrollable_overflow_rect_ {
		x := a.scrollable_overflow_rect_ or { css.CSSPixelRect{} }
		y := b.scrollable_overflow_rect_ or { css.CSSPixelRect{} }
		fields << 'overflow:${a.scrollable_overflow_rect_ != none}:${x.x.to_double()},${x.y.to_double()},${x.width.to_double()}x${x.height.to_double()}/${b.scrollable_overflow_rect_ != none}:${y.x.to_double()},${y.y.to_double()},${y.width.to_double()}x${y.height.to_double()}'
	}
	if a.line_boxes.len != b.line_boxes.len {
		fields << 'lines:${a.line_boxes.len}/${b.line_boxes.len}'
	} else {
		for index, line in a.line_boxes {
			other := b.line_boxes[index]
			if line.fragments_.len != other.fragments_.len || line.bottom() != other.bottom()
				|| line.baseline() != other.baseline() {
				fields << 'line${index}'
				break
			}
			for fragment_index, fragment in line.fragments_ {
				peer := other.fragments_[fragment_index]
				if fragment.offset() != peer.offset() || fragment.width() != peer.width()
					|| fragment.height() != peer.height() {
					fields << 'line${index}fragment${fragment_index}'
					break
				}
			}
		}
	}
	return fields.join(' ')
}

// Process-wide mismatch count of VOX_VERIFY_INCREMENTAL_LAYOUT (tests).
__global incremental_layout_verify_mismatches u64
