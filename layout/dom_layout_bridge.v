module layout

import dom
import css
import os

__global dom_layout_callbacks = dom.LayoutNodeCallbacks{
	find_matching_text_callback: find_matching_layout_text
	apply_style_callback: apply_style_to_layout_node
	apply_animated_style_callback: apply_animated_style_to_layout_node
	apply_color_style_callback: apply_inherited_color_style_to_layout_node
	clear_image_observers_callback: clear_layout_image_observers
	set_needs_layout_update_callback: set_layout_node_needs_layout_update
	invalidate_text_for_rendering_callback: invalidate_layout_text_for_rendering
	refresh_empty_text_fragment_callback: refresh_layout_empty_text_fragment
	view_transition_properties_callback: layout_view_transition_properties
}

// dom <-> layout bridge. The DOM keeps a per-node `dom.LayoutNode` placeholder (node.layout_node()); the
// layout tree is the real thing (layout.Node) but dom can't name it (dom can't import layout). After
// laying out, walk the layout tree and populate + attach a placeholder onto each DOM node, mirroring the
// layout node's data (dom_node / parent / is_anonymous / is_text_node / display) and stashing an opaque
// handle to the real layout.Node. This retires the DOM's Layout::Node boundary stubs.

fn attachment_parent_user_select(root &Node) css.UserSelect {
 if parent := root.parent() { return parent.user_select_used_value() }
 return .text
}

// Attach populated LayoutNode placeholders onto the DOM for the laid-out tree rooted at `root_box`.
pub fn attach_layout_nodes(root_box &Node) &dom.LayoutNode {
	mut placeholders := DOMLayoutAttachmentIndex.new(root_box)
	mut inline_pieces := map[u64][]InlineBoxPiece{}
	return attach_layout_node_recursive(root_box, none, none, attachment_parent_user_select(root_box), true, mut placeholders, mut inline_pieces, false, false)
}

pub fn attach_layout_nodes_with_state(root_box &Node, state &LayoutState) &dom.LayoutNode {
	mut placeholders := DOMLayoutAttachmentIndex.new(root_box)
	mut inline_pieces := map[u64][]InlineBoxPiece{}
	return attach_layout_node_recursive(root_box, none, state, attachment_parent_user_select(root_box), true, mut placeholders, mut inline_pieces, false, false)
}

// Formatting needs the complete DOM/layout association before geometry is
// available. innerText first updates layout and reads the final attachment, so
// its font/grapheme-aware text chunks need only be collected at that commit.
// Each typed layout node retains its live DOM boundary across geometry passes.
// Independent LayoutState and renderer snapshots keep earlier geometry and paint data.
struct PreparedDOMLayoutAttachment {
	root &dom.LayoutNode
}

$if test {
	fn attach_layout_nodes_before_layout(root_box &Node) &dom.LayoutNode {
		return prepare_dom_layout_attachment(root_box).root
	}
}

fn prepare_dom_layout_attachment(root_box &Node) PreparedDOMLayoutAttachment {
	mut placeholders := DOMLayoutAttachmentIndex.new(root_box)
	mut inline_pieces := map[u64][]InlineBoxPiece{}
	root := attach_layout_node_recursive(root_box, none, none, attachment_parent_user_select(root_box), false, mut placeholders,
		mut inline_pieces, true, false)
	return PreparedDOMLayoutAttachment{
		root: root
	}
}

fn commit_dom_layout_attachment(root_box &Node, state &LayoutState, prepared PreparedDOMLayoutAttachment) &dom.LayoutNode {
	assert prepared.root.layout_handle == voidptr(root_box)
	if viewport := root_box.as_viewport() {
		mut current := unsafe { &Viewport(viewport) }
		current.committed_geometry_state_ = state
	}
	// Keep a separate traversal map so continuation and containing-block links
	// follow the same tree order as a fresh attachment.
	mut placeholders := DOMLayoutAttachmentIndex.new(root_box)
	mut inline_pieces := map[u64][]InlineBoxPiece{}
	return attach_layout_node_recursive(root_box, none, state, attachment_parent_user_select(root_box), true, mut placeholders,
		mut inline_pieces, true, root_box.is_viewport())
}

fn collect_dom_text_visual_lines(box &Node, state &LayoutState) []dom.VisualLine {
	lines := collect_dom_visual_lines(box, state)
	if text := box.as_text_node() {
		if first := text.first_letter_ {
			mut all_lines := collect_dom_visual_lines(unsafe { &Node(first) }, state)
			all_lines << lines
			return all_lines
		}
	}
	return lines
}

fn materialize_dom_text_visual_lines(layout_handle voidptr) []dom.VisualLine {
	if layout_handle == unsafe { nil } { return []dom.VisualLine{} }
	box := unsafe { &Node(layout_handle) }
	viewport := box.root_viewport() or { return []dom.VisualLine{} }
	state := viewport.committed_geometry_state_
	if state == unsafe { nil } { return []dom.VisualLine{} }
	containing := box.containing_block() or { return []dom.VisualLine{} }
	styled := unsafe { &Node(containing) }.as_node_with_style() or { return []dom.VisualLine{} }
	used := state.try_get(styled) or { return []dom.VisualLine{} }
	if voidptr(used.node_) != voidptr(styled) { return []dom.VisualLine{} }
	return collect_dom_text_visual_lines(box, state)
}

struct VisualLineProjection {
mut:
	start_offset                        int
	end_offset                          int
	end_offset_with_trailing_whitespace int
	has_fragments                       bool
	owner_paintable                     u32
	line_index                          u32
	caret_stops                         []dom.VisualCaretStop
	physical_line_index                 int
	has_forced_break                    bool
	trailing_whitespace_width           f64
}

fn append_visual_caret_stop(mut stops []dom.VisualCaretStop, offset int,
	inline_coordinate f64) {
	for stop in stops {
		if stop.offset == offset {
			return
		}
	}
	stops << dom.VisualCaretStop{
		offset: offset
		inline_coordinate: inline_coordinate
	}
}

// Preserve the same grapheme-level cursor stops used by text hit testing. A
// shaped glyph may cover several UTF-16 code units (for example a ligature),
// so its advance is divided only at extended grapheme boundaries.
fn append_fragment_visual_caret_stops(fragment LineBoxFragment,
	mut stops []dom.VisualCaretStop) {
	fragment_start := fragment.source_start()
	fragment_length := fragment.length_in_code_units()
	inline_start := fragment.inline_offset().to_double()
	append_visual_caret_stop(mut stops, fragment_start, inline_start)
	if fragment_length <= 0 {
		return
	}
	text := fragment.text() or { '' }
	boundaries := text_grapheme_boundaries(text)
	if run := fragment.glyph_run() {
		mut cluster_start := 0
		mut width_before_cluster := f64(0)
		for glyph in run.glyphs() {
			if glyph.advance == 0 {
				continue
			}
			cluster_end := if cluster_start + glyph.length_in_code_units < fragment_length {
				cluster_start + glyph.length_in_code_units
			} else {
				fragment_length
			}
			if cluster_end <= cluster_start {
				continue
			}
			for boundary in boundaries {
				if boundary <= cluster_start || boundary > cluster_end {
					continue
				}
				progress := f64(boundary - cluster_start) / f64(cluster_end - cluster_start)
				source_boundary := fragment.source_offset_for_local_rendered(boundary)
				if text_node := fragment.layout_node_.as_text_node() {
					if text_node.rendered_text_offset_for_source_offset(source_boundary, .end) != fragment.start() + boundary {
						continue
					}
				}
				append_visual_caret_stop(mut stops, source_boundary, inline_start + width_before_cluster + f64(glyph.advance) * progress)
			}
			width_before_cluster += f64(glyph.advance)
			cluster_start = cluster_end
			if cluster_start >= fragment_length {
				break
			}
		}
	} else {
		for boundary in boundaries {
			if boundary <= 0 || boundary > fragment_length {
				continue
			}
			progress := f64(boundary) / f64(fragment_length)
			append_visual_caret_stop(mut stops,
				fragment.source_offset_for_local_rendered(boundary), inline_start + fragment.inline_length().to_double() * progress)
		}
	}
	append_visual_caret_stop(mut stops, fragment.source_end(), inline_start + fragment.inline_length().to_double())
}

fn visual_caret_coordinate_at(stops []dom.VisualCaretStop, offset int) ?f64 {
	for stop in stops {
		if stop.offset == offset {
			return stop.inline_coordinate
		}
	}
	return none
}

// Layout::RustFFI exposes this projection to VisualLines.cpp upstream. The V
// layout engine keeps the equivalent committed LineBox data, so materialize a
// cycle-safe copy on the DOM layout placeholder while that state is current.
fn collect_dom_visual_lines(box &Node, state &LayoutState) []dom.VisualLine {
	containing_block := box.containing_block() or { return []dom.VisualLine{} }
	if mut cached := state.inline_layouts_[u64(voidptr(containing_block))] {
		owner := containing_block.layout_index()
		key := u64(voidptr(box))
		if lines := cached.visual_lines_[key] {
			return copy_dom_visual_lines(lines, owner)
		}
		lines := collect_uncached_dom_visual_lines(box, state)
		cached.visual_lines_[key] = copy_dom_visual_lines(lines, owner)
		return lines
	}
	// A retained independent block also proves its descendants' local line
	// geometry. Atomic inlines prevent the closed-inline cache from covering
	// these contexts, but do not require rebuilding grapheme stops each pass.
	if mut cached := retained_block_visual_line_owner(unsafe { &Node(containing_block) }, state) {
		owner := containing_block.layout_index()
		key := u64(voidptr(box))
		if lines := cached.visual_lines_[key] {
			return copy_dom_visual_lines(lines, owner)
		}
		lines := collect_uncached_dom_visual_lines(box, state)
		cached.visual_lines_[key] = copy_dom_visual_lines(lines, owner)
		return lines
	}
	return collect_uncached_dom_visual_lines(box, state)
}

fn retained_block_visual_line_owner(containing_block &Node, state &LayoutState) ?&RetainedBlockLayout {
	mut current := ?&Node(containing_block)
	for current != none {
		node := current or { break }
		if cached := state.block_layouts_[u64(voidptr(node))] { return cached }
		current = node.parent()
	}
	return none
}

fn copy_dom_visual_lines(lines []dom.VisualLine, owner u32) []dom.VisualLine {
	mut result := []dom.VisualLine{cap: lines.len}
	for line in lines {
		result << dom.VisualLine{...line, owner_paintable: owner, caret_stops: line.caret_stops.clone()}
	}
	return result
}

fn collect_uncached_dom_visual_lines(box &Node, state &LayoutState) []dom.VisualLine {
	text_node := box.as_text_node() or { return []dom.VisualLine{} }
	containing_block := box.containing_block() or { return []dom.VisualLine{} }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or {
		return []dom.VisualLine{}
	}
	used := state.try_get(containing_styled) or { return []dom.VisualLine{} }
	text_length := if source_node := box.dom_node() {
		source_node.length()
	} else {
		utf16_length_for_line_box(text_node.text_for_rendering())
	}
	mut projections := []VisualLineProjection{}
	mut can_own_following_empty_line := false
	mut empty_line_offset := 0
	for physical_line_index, line in used.line_boxes {
		mut matching_fragments := []LineBoxFragment{}
		for fragment in line.fragments_ {
			if !fragment.is_fully_truncated() && !fragment.is_block_ellipsis()
				&& layout_nodes_same(fragment.layout_node(), box) {
				matching_fragments << fragment
			}
		}
		if matching_fragments.len == 0 {
			// A preserved newline has no text fragment. Retain its empty line
			// when the preceding line belonged to this Text node; consecutive
			// newlines repeat this branch one UTF-16 unit at a time.
			if can_own_following_empty_line && line.fragments_.len == 0
				&& empty_line_offset < text_length {
				empty_line_offset++
				projections << VisualLineProjection{
					start_offset: empty_line_offset
					end_offset: empty_line_offset
					end_offset_with_trailing_whitespace: empty_line_offset
					owner_paintable: containing_styled.layout_index()
					line_index: u32(physical_line_index)
					physical_line_index: physical_line_index
					has_forced_break: line.has_forced_break_
				}
				can_own_following_empty_line = line.has_forced_break_
				continue
			}
			can_own_following_empty_line = false
			continue
		}

		mut start_offset := matching_fragments[0].source_start()
		mut end_offset := matching_fragments[0].source_end()
		mut trailing_whitespace_width := f64(0)
		mut caret_stops := []dom.VisualCaretStop{}
		for fragment in matching_fragments {
			if fragment.source_start() < start_offset {
				start_offset = fragment.source_start()
			}
			fragment_end := fragment.source_end()
			if fragment_end > end_offset {
				end_offset = fragment_end
				trailing_whitespace_width = 0
			}
			append_fragment_visual_caret_stops(fragment, mut caret_stops)
			if fragment_end == end_offset && fragment.has_trailing_whitespace() {
				if run := fragment.glyph_run() {
					trailing_whitespace_width = f64(run.glyph_width(u16(` `)))
				}
			}
		}
		caret_stops.sort(a.offset < b.offset)
		projections << VisualLineProjection{
			start_offset: start_offset
			end_offset: end_offset
			end_offset_with_trailing_whitespace: end_offset
			has_fragments: true
			owner_paintable: containing_styled.layout_index()
			line_index: u32(physical_line_index)
			caret_stops: caret_stops
			physical_line_index: physical_line_index
			has_forced_break: line.has_forced_break_
			trailing_whitespace_width: trailing_whitespace_width
		}
		empty_line_offset = end_offset
		can_own_following_empty_line = line.has_forced_break_ && end_offset < text_length
	}

	for index := 0; index < projections.len; index++ {
		if !projections[index].has_fragments || projections[index].has_forced_break {
			continue
		}
		mut trailing_end := projections[index].end_offset
		if index + 1 < projections.len
			&& projections[index + 1].physical_line_index == projections[index].physical_line_index + 1
			&& projections[index + 1].start_offset >= projections[index].end_offset {
			trailing_end = projections[index + 1].start_offset
		} else if projections[index].trailing_whitespace_width > 0
			&& projections[index].end_offset < text_length {
			trailing_end = projections[index].end_offset + 1
		}
		projections[index].end_offset_with_trailing_whitespace = trailing_end
		if trailing_end > projections[index].end_offset {
			coordinate := visual_caret_coordinate_at(projections[index].caret_stops, projections[index].end_offset) or { continue }
			append_visual_caret_stop(mut projections[index].caret_stops, trailing_end, coordinate + projections[index].trailing_whitespace_width)
			projections[index].caret_stops.sort(a.offset < b.offset)
		}
	}

	mut result := []dom.VisualLine{cap: projections.len}
	for projection in projections {
		result << dom.VisualLine{
			start_offset: projection.start_offset
			end_offset: projection.end_offset
			end_offset_with_trailing_whitespace: projection.end_offset_with_trailing_whitespace
			has_fragments: projection.has_fragments
			owner_paintable: projection.owner_paintable
			line_index: projection.line_index
			caret_stops: projection.caret_stops
		}
	}
	return result
}

fn attach_layout_node_recursive(box &Node, parent_placeholder ?&dom.LayoutNode, state ?&LayoutState, parent_user_select css.UserSelect, collect_text_chunks bool, mut placeholders DOMLayoutAttachmentIndex, mut inline_pieces map[u64][]InlineBoxPiece, retain_live_nodes bool, lazy_visual_lines bool) &dom.LayoutNode {
	mut visibility := dom.CSSVisibility_.visible
	mut content_visibility := dom.CSSContentVisibility_.visible
	mut overflow_x := dom.CSSOverflow_.visible
	user_select := box.user_select_used_value_with_parent(parent_user_select)
	if styled := box.as_node_with_style() {
		visibility = visibility_to_dom_for_layout(styled.computed_values().visibility())
		content_visibility = content_visibility_to_dom_for_layout(styled.computed_values().content_visibility())
		overflow_x = overflow_to_dom_for_layout(styled.computed_values().overflow_x())
	}
	mut placeholder := unsafe { &dom.LayoutNode(nil) }
	if retain_live_nodes && box.dom_layout_node_ != unsafe { nil }
		&& box.dom_layout_node_.layout_handle == voidptr(box) {
		placeholder = box.dom_layout_node_
	}
	if placeholder == unsafe { nil } {
		placeholder = &dom.LayoutNode{}
	}
	// The boundary is live, but renderer and LayoutState snapshots own their
	// separate geometry. Clear removed child slots before reusing this storage.
	mut retained_children := unsafe { placeholder.children_ }
	for index in 0 .. retained_children.len {
		retained_children[index] = unsafe { nil }
	}
	retained_children.clear()
	retained_paintables := unsafe { placeholder.paintables_ }
	// Reset stale geometry in place before publishing current tree metadata.
	unsafe {
		*placeholder = dom.LayoutNode{
			children_: retained_children
			paintables_: retained_paintables
		}
	}
	placeholder.dom_node_ = box.dom_node()
	placeholder.parent_ = parent_placeholder
	placeholder.is_anonymous_ = box.is_anonymous()
	placeholder.is_text_node_ = box.is_text_node()
	placeholder.is_atomic_inline_ = box.is_atomic_inline()
	placeholder.is_replaced_box_ = box.is_replaced_box()
	placeholder.display_ = layout_node_display(box)
	mut rare := dom.LayoutNodeRareData{
		pseudo_element_generator: box.pseudo_element_generator()
		generated_for: dom_pseudo_element_for_layout_node(box.generated_for_pseudo_element())
	}
	placeholder.is_viewport_ = box.is_viewport()
	placeholder.is_positioned_ = box.is_positioned()
	placeholder.is_sticky_position_ = box.is_sticky_position()
	placeholder.is_fixed_position_ = box.is_fixed_position()
	placeholder.is_scroll_container_ = box.is_scroll_container()
	placeholder.establishes_fixed_positioning_containing_block_ = box.establishes_a_fixed_positioning_containing_block()
	placeholder.overflow_x_ = overflow_x
	placeholder.visibility_ = visibility
	placeholder.content_visibility_ = content_visibility
	placeholder.user_select_none_ = user_select == .none_
	placeholder.white_space_collapse_is_not_collapse_ = box.computed_values().white_space_collapse() != .collapse
	placeholder.layout_handle = voidptr(box)
	placeholder.callbacks_ = &dom_layout_callbacks
	if retain_live_nodes {
		mut mutable_box := unsafe { &Node(box) }
		mutable_box.dom_layout_node_ = placeholder
	}
	if text_node := box.as_text_node() {
		mut chunks := []string{}
		placeholder.text_has_source_range_ = text_node.source_range_length_ != none
		// DOM::Node::name_or_description() reads TextNode::text_for_rendering()
		// directly. Keep that value separate from the ChunkIterator output used
		// by HTMLElement::rendered_text_collection_steps().
		placeholder.rendered_text_ = text_node.text_for_rendering()
		if first := text_node.first_letter_ {
			placeholder.rendered_text_ = first.text_for_rendering() + placeholder.rendered_text_
			if collect_text_chunks {
				collected := collect_dom_rendered_text(first)
				if collected != '' { chunks << collected }
			}
		}
		// innerText consumes the concatenated no-wrap text after the remaining
		// collapsible-space processing; font and grapheme chunks are unnecessary.
		if collect_text_chunks {
			collected := collect_dom_rendered_text(text_node)
			if collected != '' { chunks << collected }
		}
		placeholder.set_rendered_text_chunks(chunks)
	}
	placeholders.set(box, placeholder)
	if metrics := box.as_node_with_style_and_box_model_metrics() {
		if previous := metrics.continuation_of_node() {
			if previous_placeholder := placeholders.get(unsafe { &Node(previous) }) {
				rare = dom.LayoutNodeRareData{ ...rare, continuation_of_node: previous_placeholder }
				mut mutable_previous_placeholder := unsafe { &dom.LayoutNode(previous_placeholder) }
				mutable_previous_placeholder.set_continuation_next(placeholder)
			}
		}
	}
	placeholder.set_rare_data(rare)
	if containing_block := box.containing_block() {
		if containing_block_placeholder := placeholders.get(unsafe { &Node(containing_block) }) {
			placeholder.containing_block_ = containing_block_placeholder
		}
	}
	if layout_state := state {
		if box.is_text_node() {
			if lazy_visual_lines {
				placeholder.visual_lines_callback = materialize_dom_text_visual_lines
			} else {
				placeholder.set_visual_lines(collect_dom_text_visual_lines(box, layout_state))
			}
		}
		if box.is_inline_node() {
			if geometry := inline_box_absolute_geometry_cached(box, layout_state, mut inline_pieces) {
				placeholder.has_geometry_ = true
				placeholder.border_box_ = dom.Rect{
					x: geometry.border_rect.x.to_double()
					y: geometry.border_rect.y.to_double()
					width: geometry.border_rect.width.to_double()
					height: geometry.border_rect.height.to_double()
				}
				placeholder.content_width_ = geometry.content_rect.width.to_double()
				placeholder.content_height_ = geometry.content_rect.height.to_double()
				if node_with_style := box.as_node_with_style() {
					if used := layout_state.try_get(node_with_style) {
						copy_used_box_model_to_dom_layout_node(mut placeholder, used)
					}
				}
			}
		} else if node_with_style := box.as_node_with_style() {
			if used := layout_state.try_get(node_with_style) {
				offset := paint_cumulative_offset(box, layout_state, used)
				placeholder.has_geometry_ = true
				placeholder.border_box_ = dom.Rect{
					x: offset.x().to_double() - used.border_box_left().to_double()
					y: offset.y().to_double() - used.border_box_top().to_double()
					width: used.border_box_width().to_double()
					height: used.border_box_height().to_double()
				}
				placeholder.content_width_ = used.content_width().to_double()
				placeholder.content_height_ = used.content_height().to_double()
				copy_used_box_model_to_dom_layout_node(mut placeholder, used)
			}
		}
		materialize_dom_paintables(box, layout_state, mut placeholder)
	}
	if parent := parent_placeholder {
		unsafe {
			parent.children_ << placeholder
		}
	}
	if dom_node := box.dom_node() {
		// A DOM element has one primary layout node. Inline continuations carry
		// the same DOM node but point back to that primary node.
		is_continuation := if metrics := box.as_node_with_style_and_box_model_metrics() {
			metrics.continuation_of_node() != none
		} else {
			false
		}
		attach_text := if text := box.as_text_node() { text.attach_to_dom_node_ } else { true }
		if !is_continuation && attach_text {
			mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
			mutable_dom_node.set_layout_node(placeholder)
		}
	}
	if generated := box.generated_for_pseudo_element() {
		if generated in [.first_letter, .before, .after] {
			if owner := box.pseudo_element_generator() {
				dom_generated := dom_pseudo_element_for_layout_node(generated) or { dom.PseudoElement.first_letter }
				mut mutable_owner := unsafe { &dom.Element(owner) }
				mutable_owner.set_pseudo_element_node(int(dom_generated), &dom.LayoutNodeWithStyle_{
					layout_node_:        placeholder
					applied_properties_: dom.AbstractElement.new(owner, dom_generated).computed_properties()
					kind_:               if box.is_inline_node() {
						.inline_node
					} else {
						.block_container
					}
				})
			}
		}
	}
	for child in box.children() {
		attach_layout_node_recursive(child, placeholder, state, user_select, collect_text_chunks, mut placeholders, mut inline_pieces, retain_live_nodes, lazy_visual_lines)
	}
	return placeholder
}

// LayoutState::commit() creates each Layout::Node's paintables, transfers the
// visibility/scroll/stacking state required by DOM, and makes the last one the
// DOM node's primary paintable. Painting's renderer-independent objects are
// retained elsewhere; these wrappers are the cycle boundary consumed by DOM.
fn materialize_dom_paintables(box &Node, state &LayoutState, mut placeholder dom.LayoutNode) {
	attach_text := if text := box.as_text_node() { text.attach_to_dom_node_ } else { true }
	if dom_node := box.dom_node() {
		if attach_text {
		mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
		mutable_dom_node.clear_paintable()
		}
	}
	// The attachment already resolved inline geometry through its shared
	// per-container piece cache. Recomputing it for every empty/nested inline
	// repeats the complete container traversal and its temporary allocations.
	count := layout_debug_paintable_count_with_inline_geometry(box, state,
		placeholder.has_geometry_)
	previous_count := placeholder.paintables_.len
	class_name := layout_debug_paintable_class(box)
	for index in 0 .. count {
		previous := if index < previous_count {
			placeholder.paintables_[index]
		} else {
			unsafe { &dom.Paintable(nil) }
		}
		mut paintable := unsafe { &dom.Paintable(nil) }
		if layout_debug_paintable_is_box(class_name) {
			mut snapped_areas_x := []dom.ScrollSnapAreaReference_{}
			mut snapped_areas_y := []dom.ScrollSnapAreaReference_{}
			if dom_node := box.dom_node() {
				if element := dom_node.as_element() {
					snapped_areas_x = element.snapped_scroll_areas_x()
					snapped_areas_y = element.snapped_scroll_areas_y()
				}
			}
			mut paintable_box := unsafe { &dom.PaintableBox(nil) }
			if previous != unsafe { nil } && previous.is_box && previous.layout_handle == voidptr(box) {
				paintable_box = unsafe { &dom.PaintableBox(previous) }
			} else {
				paintable_box = &dom.PaintableBox{}
			}
			unsafe {
				*paintable_box = dom.PaintableBox{
					layout_handle: voidptr(box)
					dom_node_: box.dom_node() or { nil }
					snap_areas_: dom.retained_paintable_snap_areas(snapped_areas_x, snapped_areas_y)
				}
			}
			paintable_box.is_box = true
			paintable_box.visible = placeholder.visibility_ == .visible
				&& placeholder.content_visibility_ != .hidden
			paintable_box.scrollable = box.is_scroll_container()
			paintable_box.stacking_context = box.establishes_stacking_context()
			if styled := box.as_node_with_style() {
				if used := state.try_get(styled) {
					paintable_box.has_scrollable_overflow_ = used.has_scrollable_overflow()
					position := layout_offset_in_svg_user_space(box, state, used)
					paintable_box.padding_box_x_ = position.x().minus(used.padding_left).to_double()
					paintable_box.padding_box_y_ = position.y().minus(used.padding_top).to_double()
					paintable_box.padding_box_width_ = used.content_width().to_double() + used.padding_left.to_double() + used.padding_right.to_double()
					paintable_box.padding_box_height_ = used.content_height().to_double() + used.padding_top.to_double() + used.padding_bottom.to_double()
					if overflow := used.scrollable_overflow_rect() {
						computed := styled.computed_values()
						paintable_box.wheel_scrolls_horizontal_ = computed.overflow_x() in [
							.auto_,
							.scroll]
							&& overflow.width.to_double() > paintable_box.padding_box_width_
						paintable_box.wheel_scrolls_vertical_ = computed.overflow_y() in [
							.auto_,
							.scroll]
							&& overflow.height.to_double() > paintable_box.padding_box_height_
						paintable_box.scrollable_overflow_rect_ = dom.CSSPixelRect_{
							x_: overflow.x.to_double()
							y_: overflow.y.to_double()
							width_: overflow.width.to_double()
							height_: overflow.height.to_double()
						}
					}
				}
			}
			// DOM scrolling and scroll bounds are CSS-pixel APIs. The paint tree
			// retains physical geometry independently of this boundary record.
			scale := box.document().layout_coordinate_scale()
			if scale != 1 {
				paintable_box.padding_box_x_ /= scale
				paintable_box.padding_box_y_ /= scale
				paintable_box.padding_box_width_ /= scale
				paintable_box.padding_box_height_ /= scale
				if overflow := paintable_box.scrollable_overflow_rect_ {
					paintable_box.scrollable_overflow_rect_ = dom.CSSPixelRect_{
						x_: overflow.x_ / scale
						y_: overflow.y_ / scale
						width_: overflow.width() / scale
						height_: overflow.height() / scale
					}
				}
			}
			paintable = unsafe { &dom.Paintable(paintable_box) }
		} else {
			if previous != unsafe { nil } && !previous.is_box && previous.layout_handle == voidptr(box) {
				paintable = previous
			} else {
				paintable = &dom.Paintable{}
			}
			unsafe { *paintable = dom.Paintable{ layout_handle: voidptr(box) } }
		}
		if index < previous_count {
			placeholder.paintables_[index] = paintable
		} else {
			placeholder.paintables_ << paintable
		}
		if dom_node := box.dom_node() {
			if attach_text {
				mut mutable_dom_node := unsafe { &dom.Node(dom_node) }
			mutable_dom_node.set_paintable(paintable)
			}
		}
	}
	for index in count .. previous_count {
		placeholder.paintables_[index] = unsafe { nil }
	}
	placeholder.paintables_.trim(count)
}

// Same-binary control: script transform/opacity updates rebuild the snapshot.
const disable_compositor_style_updates = os.getenv('VOX_DISABLE_COMPOSITOR_STYLE_UPDATES') != ''

fn apply_style_to_layout_node(layout_handle voidptr, css_computed_properties_handle voidptr) {
	if layout_handle == unsafe { nil } || css_computed_properties_handle == unsafe { nil } {
		return
	}
	node := unsafe { &Node(layout_handle) }
	styled := node.as_node_with_style() or { return }
	computed := unsafe { &css.ComputedProperties(css_computed_properties_handle) }
	can_refresh_locally := paint_style_update_can_be_local(node, styled.computed_values(), computed)
	compositor_only := !can_refresh_locally && !disable_compositor_style_updates
		&& paint_style_update_is_compositor_only(node, styled.computed_values(), computed)
	if paint_refresh_diagnostics && !can_refresh_locally && !compositor_only {
		report_paint_refresh_style(node, styled.computed_values(), computed)
	}
	mut mutable_styled := unsafe { &NodeWithStyle(styled) }
	mutable_styled.apply_style(computed)
	if mut result := document_layout_result(node.document()) {
		result.paint_tree_needs_style_update = true
		if compositor_only {
			result.paint_style_update_handles.add(u64(layout_handle))
			result.paint_style_update_compositor_handles.add(u64(layout_handle))
			return
		}
		result.paint_style_update_requires_full_refresh = result.paint_style_update_requires_full_refresh || !can_refresh_locally
		result.paint_style_update_handles.add(u64(layout_handle))
		result.paint_style_update_text_handles.add(u64(layout_handle))
	}
}

fn apply_animated_style_to_layout_node(layout_handle voidptr, css_computed_properties_handle voidptr) bool {
	if layout_handle == unsafe { nil } || css_computed_properties_handle == unsafe { nil } { return false }
	node := unsafe { &Node(layout_handle) }
	if !compositor_style_refresh_supports_node(node) {
		apply_style_to_layout_node(layout_handle, css_computed_properties_handle)
		return false
	}
	styled := node.as_node_with_style() or { return false }
	computed := unsafe { &css.ComputedProperties(css_computed_properties_handle) }
	mut mutable_styled := unsafe { &NodeWithStyle(styled) }
	mutable_styled.apply_style(computed)
	if mut result := document_layout_result(node.document()) {
		result.paint_tree_needs_style_update = true
		result.paint_style_update_handles.add(u64(layout_handle))
		result.paint_style_update_compositor_handles.add(u64(layout_handle))
		// The retained compositor refresh owns this sample's paint invalidation:
		// box phase commands keep their local geometry, and paint/hit-test plans
		// are rebuilt only when opacity or invertibility changes their membership.
		return true
	}
	return false
}

fn apply_inherited_color_style_to_layout_node(layout_handle voidptr, style voidptr) bool {
	if layout_handle == unsafe { nil } || style == unsafe { nil } { return false }
	node := unsafe { &Node(layout_handle) }
	styled := node.as_node_with_style() or { return false }
	computed := unsafe { &css.ComputedProperties(style) }
	// CSS calls this only after checking that colors are the only change,
	// including for sampled colors.
	if !local_paint_style_refresh_supports_box(node)
		|| !computed.filter().is_none() || !computed.backdrop_filter().is_none() {
		return false
	}
	mut mutable_styled := unsafe { &NodeWithStyle(styled) }
	mutable_styled.apply_style(computed)
	if mut result := document_layout_result(node.document()) {
		result.paint_tree_needs_style_update = true
		result.paint_style_update_handles.add(u64(layout_handle))
		if !css.animated_background_only_update() {
			result.paint_style_update_text_handles.add(u64(layout_handle))
		}
	}
	return true
}

fn clear_layout_image_observers(layout_handle voidptr) {
	if layout_handle == unsafe { nil } { return }
	node := unsafe { &Node(layout_handle) }
	if styled := node.as_node_with_style() {
		mut mutable_styled := unsafe { &NodeWithStyle(styled) }
		mutable_styled.clear_image_observers()
	}
}

fn set_layout_node_needs_layout_update(layout_handle voidptr, needs_layout_update bool) {
	if layout_handle == unsafe { nil } {
		return
	}
	mut node := unsafe { &Node(layout_handle) }
	node.set_needs_layout_update(needs_layout_update)
}

fn refresh_layout_empty_text_fragment(layout_handle voidptr) bool {
	node := unsafe { &Node(layout_handle) }
	if mut text := node.as_text_node() {
		return text.update_produces_line_box_fragment_when_empty_flag()
	}
	return false
}

fn invalidate_layout_text_for_rendering(layout_handle voidptr) {
	if layout_handle == unsafe { nil } {
		return
	}
	node := unsafe { &Node(layout_handle) }
	text_node := node.as_text_node() or { return }
	mut mutable_text_node := unsafe { &TextNode(text_node) }
	mutable_text_node.invalidate_text_for_rendering()
}

// Mirror LayoutState::UsedValues onto DOM's module-cycle boundary object. CSSOM's
// resolved-value algorithm consumes exactly these used box-model values, just as
// CSSStyleProperties.cpp reads them from Painting::PaintableBox::box_model().
fn copy_used_box_model_to_dom_layout_node(mut placeholder dom.LayoutNode, used &UsedValues) {
	placeholder.set_box_model(dom.LayoutBoxModel{
		margin_left: used.margin_left.to_double()
		margin_right: used.margin_right.to_double()
		margin_top: used.margin_top.to_double()
		margin_bottom: used.margin_bottom.to_double()
		border_left: used.border_left.to_double()
		border_right: used.border_right.to_double()
		border_top: used.border_top.to_double()
		border_bottom: used.border_bottom.to_double()
		padding_left: used.padding_left.to_double()
		padding_right: used.padding_right.to_double()
		padding_top: used.padding_top.to_double()
		padding_bottom: used.padding_bottom.to_double()
		inset_left: used.inset_left.to_double()
		inset_right: used.inset_right.to_double()
		inset_top: used.inset_top.to_double()
		inset_bottom: used.inset_bottom.to_double()
	})
	grid_template_columns := used.grid_template_columns()
	mut used_columns := []f64{cap: grid_template_columns.len}
	for size in grid_template_columns {
		used_columns << size.to_double()
	}
	grid_template_rows := used.grid_template_rows()
	mut used_rows := []f64{cap: grid_template_rows.len}
	for size in grid_template_rows {
		used_rows << size.to_double()
	}
	placeholder.set_used_grid_data(dom.LayoutGridData{
		columns: used_columns
		rows: used_rows
		column_line_names: used.grid_column_line_names().clone()
		row_line_names: used.grid_row_line_names().clone()
		columns_are_subgrid: used.grid_columns_are_subgrid()
		rows_are_subgrid: used.grid_rows_are_subgrid()
	})
}

fn dom_pseudo_element_for_layout_node(pseudo_element ?css.PseudoElement) ?dom.PseudoElement {
	type_ := pseudo_element or { return none }
	return match type_ {
		.before { dom.PseudoElement.before }
		.after { dom.PseudoElement.after }
		.first_line { dom.PseudoElement.first_line }
		.first_letter { dom.PseudoElement.first_letter }
		.marker { dom.PseudoElement.marker }
		.placeholder { dom.PseudoElement.placeholder }
		.selection { dom.PseudoElement.selection }
		.backdrop { dom.PseudoElement.backdrop }
		else { none }
	}
}

// The layout node's computed display as the DOM-side CSSDisplay_ (mirrored from CSS::Display, like the
// css computed-properties bridge). Anonymous boxes (no NodeWithStyle) get the empty default.
fn layout_node_display(box &Node) dom.CSSDisplay_ {
	node_with_style := box.as_node_with_style() or { return dom.CSSDisplay_{} }
	display := node_with_style.computed_values().display()
	return dom.CSSDisplay_{
		is_none_: display.is_none()
		is_list_item_: display.is_list_item()
		is_contents_: display.is_contents()
		is_inline_outside_: display.is_inline_outside()
		is_flow_inside_: display.is_flow_inside()
		is_flex_inside_: display.is_flex_inside()
		is_grid_inside_: display.is_grid_inside()
		is_block_outside_: display.is_block_outside()
		is_table_caption_: display.is_table_caption()
		is_table_cell_: display.is_table_cell()
		is_table_row_: display.is_table_row()
	}
}

fn visibility_to_dom_for_layout(value css.Visibility) dom.CSSVisibility_ {
	return match value {
		.visible { .visible }
		.hidden { .hidden }
		.collapse { .collapse }
	}
}

fn content_visibility_to_dom_for_layout(value css.ContentVisibility) dom.CSSContentVisibility_ {
	return match value {
		.visible { .visible }
		.hidden { .hidden }
		.auto_ { .auto_ }
	}
}

fn overflow_to_dom_for_layout(value css.Overflow) dom.CSSOverflow_ {
	return match value {
		.visible { .visible }
		.hidden { .hidden }
		.clip { .clip }
		.scroll { .scroll }
		.auto_ { .auto_ }
	}
}
