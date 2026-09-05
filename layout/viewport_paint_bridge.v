module layout

import css
import dom
import math
import painting
import strings

// The concrete painting state owned by a committed DocumentLayoutResult is
// exposed to DOM through ViewportPaintable callbacks. This mirrors the
// upstream DOM -> Painting ownership boundary without making DOM import the
// downstream layout or painting modules.
fn install_document_painting_bridge(document &dom.Document, result &DocumentLayoutResult) {
	target := voidptr(result)
	paintable := &dom.ViewportPaintable{
		target: target
		set_needs_to_refresh_scroll_state_callback: viewport_set_needs_to_refresh_scroll_state
		refresh_scroll_state_callback: viewport_refresh_scroll_state
		assign_accumulated_visual_contexts_callback: viewport_assign_accumulated_visual_contexts
		selection_callback: viewport_selection
		recompute_selection_states_callback: viewport_recompute_selection_states
		set_needs_repaint_callback: viewport_set_needs_repaint
		document_set_needs_repaint_callback: viewport_document_set_needs_repaint
		invalidate_all_paint_caches_callback: viewport_invalidate_all_paint_caches
		record_display_list_callback: viewport_record_display_list
		build_stacking_context_tree_callback: viewport_build_stacking_context_tree
		stacking_context_callback: viewport_stacking_context
		invalidate_stacking_context_callback: viewport_invalidate_stacking_context
		hit_test_callback: viewport_hit_test
		hit_test_all_callback: viewport_hit_test_all
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_paintable(paintable)
	if viewport := document.layout_node() {
		if root := viewport.root_layout_node() {
			install_layout_paintable_repaint_callbacks(root, result)
		}
	}
}

fn install_layout_paintable_repaint_callbacks(node &dom.LayoutNode, result &DocumentLayoutResult) {
	for paintable in node.paintables() {
		mut mutable_paintable := unsafe { &dom.Paintable(paintable) }
		mutable_paintable.repaint_callback_target = voidptr(result)
		mutable_paintable.set_needs_repaint_callback = layout_paintable_set_needs_repaint
	}
	for child in node.children_ {
		install_layout_paintable_repaint_callbacks(child, result)
	}
}

fn viewport_layout_result(target voidptr) &DocumentLayoutResult {
	return unsafe { &DocumentLayoutResult(target) }
}

fn viewport_set_needs_to_refresh_scroll_state(target voidptr, value bool) {
	mut result := viewport_layout_result(target)
	result.needs_to_refresh_scroll_state = value
}

fn viewport_refresh_scroll_state(target voidptr) {
	mut result := viewport_layout_result(target)
	if !result.needs_to_refresh_scroll_state {
		return
	}
	// Sticky frames are refreshed before ordinary frames, in creation/tree
	// order. A nested sticky can therefore consume its parent's current offset.
	for index in result.scroll_state.sticky_frame_indices() {
		nearest_scrolling_ancestor := result.scroll_state.nearest_scrolling_ancestor(index)
		constraints := result.scroll_state.frames[index].sticky_constraints or {
			result.scroll_state.frames[index].own_offset = painting.Point{}
			continue
		}
		if nearest_scrolling_ancestor == 0 {
			result.scroll_state.frames[index].own_offset = painting.Point{}
			continue
		}

		mut parent_sticky_offset := painting.Point{}
		parent_index := result.scroll_state.frames[index].parent_index
		if parent_index > 0 && result.scroll_state.frames[parent_index].is_sticky {
			parent_sticky_offset = result.scroll_state.cumulative_offset(parent_index)
		}
		sticky_position := constraints.position_relative_to_scroll_ancestor.add(parent_sticky_offset)
		mut containing_region := constraints.containing_block_region
		if constraints.needs_parent_offset_adjustment {
			containing_region = containing_region.translated(parent_sticky_offset)
		}
		minimum := painting.Point{containing_region.x, containing_region.y}
		maximum := painting.Point{
			x: containing_region.right() - constraints.border_box_size.width
			y: containing_region.bottom() - constraints.border_box_size.height
		}
		live_scroll := compatibility_live_scroll_offset(result, result.scroll_state.frames[nearest_scrolling_ancestor])
		scrollport := painting.Rect{
			x: live_scroll.x
			y: live_scroll.y
			width: constraints.scrollport_size.width
			height: constraints.scrollport_size.height
		}
		mut sticky_offset_x := 0.0
		mut sticky_offset_y := 0.0
		if top := constraints.insets.top {
			if scrollport.y > sticky_position.y - top {
				sticky_offset_y = math.min(scrollport.y + top, maximum.y) - sticky_position.y
			}
		}
		if left := constraints.insets.left {
			if scrollport.x > sticky_position.x - left {
				sticky_offset_x = math.min(scrollport.x + left, maximum.x) - sticky_position.x
			}
		}
		if bottom := constraints.insets.bottom {
			if scrollport.bottom() < sticky_position.y + constraints.border_box_size.height + bottom {
				sticky_offset_y = math.max(scrollport.bottom() - constraints.border_box_size.height - bottom, minimum.y) - sticky_position.y
			}
		}
		if right := constraints.insets.right {
			if scrollport.right() < sticky_position.x + constraints.border_box_size.width + right {
				sticky_offset_x = math.max(scrollport.right() - constraints.border_box_size.width - right, minimum.x) - sticky_position.x
			}
		}
		result.scroll_state.frames[index].own_offset = painting.Point{sticky_offset_x, sticky_offset_y}
	}

	// ViewportPaintable::refresh_scroll_state() then snapshots the negated live
	// PaintableBox offsets. Display-list phase commands do not change when a
	// scroller moves; replay combines them with this state instead.
	for index in result.scroll_state.scrolling_frame_indices() {
		live := compatibility_live_scroll_offset(result, result.scroll_state.frames[index])
		result.scroll_state.frames[index].own_offset = painting.Point{-live.x, -live.y}
	}
	result.needs_to_refresh_scroll_state = false
}

fn compatibility_live_scroll_offset(result &DocumentLayoutResult, frame painting.ScrollFrame) painting.Point {
	if frame.paintable_id == 'viewport' {
		viewport := result.document.viewport_rect()
		return painting.Point{viewport.x, viewport.y}
	}
	node_id := frame.paintable_id.i64()
	if node_id != 0 {
		if node := dom.Node.from_unique_id(dom.UniqueNodeID(node_id)) {
			if paintable := node.paintable_box() {
				live := paintable.scroll_offset()
				return painting.Point{live.x(), live.y()}
			}
		}
	}
	return painting.Point{}
}

fn collect_compatibility_boxes(mut box BlockBox, mut boxes_by_layout map[u64]&BlockBox) {
	if box.layout_handle != unsafe { nil } {
		boxes_by_layout[u64(box.layout_handle)] = unsafe { &box }
	}
	for child_index := 0; child_index < box.children.len; child_index++ {
		mut child := unsafe { &box.children[child_index] }
		collect_compatibility_boxes(mut child, mut boxes_by_layout)
	}
}

fn nearest_compatibility_scroll_frame(box &BlockBox, boxes_by_layout map[u64]&BlockBox) int {
	if box.layout_handle == unsafe { nil } {
		return 0
	}
	node := unsafe { &Node(box.layout_handle) }
	mut containing_block := node.containing_block()
	for containing_block != none {
		ancestor := containing_block or { break }
		if ancestor_box := boxes_by_layout[u64(voidptr(ancestor))] {
			if ancestor_box.own_scroll_frame_index > 0 {
				return ancestor_box.own_scroll_frame_index
			}
		}
		containing_block = ancestor.containing_block()
	}
	return 0
}

fn compatibility_sticky_insets(box &BlockBox, scrollport_size painting.Size) painting.StickyInsets {
	if box.layout_handle == unsafe { nil } {
		return painting.StickyInsets{}
	}
	node := unsafe { &Node(box.layout_handle) }
	styled := node.as_node_with_style() or { return painting.StickyInsets{} }
	computed := styled.computed_values()
	inset := computed.inset()
	context := computed.length_resolution_context()
	mut top := ?f64(none)
	mut right := ?f64(none)
	mut bottom := ?f64(none)
	mut left := ?f64(none)
	if !inset.top().is_auto() {
		top = inset.top().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport_size.height)).to_double()
	}
	if !inset.right().is_auto() {
		right = inset.right().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport_size.width)).to_double()
	}
	if !inset.bottom().is_auto() {
		bottom = inset.bottom().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport_size.height)).to_double()
	}
	if !inset.left().is_auto() {
		left = inset.left().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport_size.width)).to_double()
	}
	return painting.StickyInsets{top, right, bottom, left}
}

fn compatibility_scrollport_rect(box &BlockBox) LayoutRect {
	if box.is_viewport_scroller {
		return LayoutRect{
			width: box.viewport_width
			height: box.viewport_height
		}
	}
	return LayoutRect{
		x: box.x
		y: box.y
		width: box.width
		height: box.height
	}
}

fn precompute_compatibility_sticky_constraints(mut box BlockBox, sticky_frame_index int, boxes_by_layout map[u64]&BlockBox, boxes_by_scroll_frame map[int]&BlockBox, mut state painting.ScrollState) {
	nearest_scrolling_ancestor := state.nearest_scrolling_ancestor(sticky_frame_index)
	if nearest_scrolling_ancestor == 0 {
		return
	}
	scroll_ancestor := boxes_by_scroll_frame[nearest_scrolling_ancestor] or { return }
	scrollport_rect := compatibility_scrollport_rect(scroll_ancestor)
	sticky_border_box := box.border_box()
	scrollport_size := painting.Size{scrollport_rect.width, scrollport_rect.height}
	mut containing_region := LayoutRect{}
	mut needs_parent_offset_adjustment := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if containing_block := node.containing_block() {
			if containing_box := boxes_by_layout[u64(voidptr(containing_block))] {
				if voidptr(containing_box) == voidptr(scroll_ancestor) {
					overflow := scroll_ancestor.scrollable_overflow or {
						LayoutRect{ width: scroll_ancestor.width, height: scroll_ancestor.height }
					}
					containing_region = LayoutRect{ width: overflow.width, height: overflow.height }
				} else {
					containing_border_box := containing_box.border_box()
					containing_region = LayoutRect{
						x: containing_border_box.x - scrollport_rect.x
						y: containing_border_box.y - scrollport_rect.y
						width: containing_border_box.width
						height: containing_border_box.height
					}
					needs_parent_offset_adjustment = true
				}
			}
		}
	}
	state.frames[sticky_frame_index].sticky_constraints = painting.StickyConstraints{
		position_relative_to_scroll_ancestor: painting.Point{
			x: sticky_border_box.x - scrollport_rect.x
			y: sticky_border_box.y - scrollport_rect.y
		}
		border_box_size: painting.Size{sticky_border_box.width, sticky_border_box.height}
		scrollport_size: scrollport_size
		containing_block_region: painting.Rect{
			x: containing_region.x
			y: containing_region.y
			width: containing_region.width
			height: containing_region.height
		}
		needs_parent_offset_adjustment: needs_parent_offset_adjustment
		insets: compatibility_sticky_insets(box, scrollport_size)
	}
}

fn assign_compatibility_scroll_frames(mut box BlockBox, boxes_by_layout map[u64]&BlockBox, mut boxes_by_scroll_frame map[int]&BlockBox, mut state painting.ScrollState) {
	box.own_scroll_frame_index = 0
	box.sticky_scroll_frame_index = 0
	parent_index := nearest_compatibility_scroll_frame(box, boxes_by_layout)
	if box.sticky_position {
		sticky_frame_index := state.create_sticky_frame(box.node_id.str(), parent_index)
		box.sticky_scroll_frame_index = sticky_frame_index
		box.own_scroll_frame_index = sticky_frame_index
		boxes_by_scroll_frame[sticky_frame_index] = unsafe { &box }
		precompute_compatibility_sticky_constraints(mut box, sticky_frame_index, boxes_by_layout, boxes_by_scroll_frame, mut state)
	}
	if box.has_scrollable_overflow || box.is_viewport_scroller {
		scroll_parent_index := if box.sticky_scroll_frame_index > 0 {
			box.sticky_scroll_frame_index
		} else {
			parent_index
		}
		paintable_id := if box.is_viewport_scroller { 'viewport' } else { box.node_id.str() }
		box.own_scroll_frame_index = state.create_scroll_frame(paintable_id, scroll_parent_index)
		boxes_by_scroll_frame[box.own_scroll_frame_index] = unsafe { &box }
	}
	for child_index := 0; child_index < box.children.len; child_index++ {
		mut child := unsafe { &box.children[child_index] }
		assign_compatibility_scroll_frames(mut child, boxes_by_layout, mut boxes_by_scroll_frame, mut state)
	}
}

fn compatibility_painting_affine(matrix [6]f64) painting.Affine {
	resolved := normalized_affine(matrix)
	return painting.Affine{
		a: resolved[0]
		b: resolved[1]
		c: resolved[2]
		d: resolved[3]
		e: resolved[4]
		f: resolved[5]
	}
}

fn compatibility_enclosing_int_rect(rect LayoutRect) painting.IntRect {
	left := int(math.floor(rect.x))
	top := int(math.floor(rect.y))
	right := int(math.ceil(rect.x + rect.width))
	bottom := int(math.ceil(rect.y + rect.height))
	return painting.IntRect{left, top, right - left, bottom - top}
}

fn compatibility_rounded_int_rect(rect LayoutRect) painting.IntRect {
	// DevicePixelConverter::rounded_device_rect() rounds the four edges, rather
	// than flooring the origin and ceiling the far edge.
	left := int(math.round(rect.x))
	top := int(math.round(rect.y))
	right := int(math.round(rect.x + rect.width))
	bottom := int(math.round(rect.y + rect.height))
	return painting.IntRect{left, top, right - left, bottom - top}
}

fn compatibility_corner_radii(radii BoxRadii) painting.CornerRadii {
	return painting.CornerRadii{
		top_left: painting.CornerRadius{int(math.floor(radii.top_left.x)), int(math.floor(radii.top_left.y))}
		top_right: painting.CornerRadius{int(math.floor(radii.top_right.x)), int(math.floor(radii.top_right.y))}
		bottom_right: painting.CornerRadius{int(math.floor(radii.bottom_right.x)), int(math.floor(radii.bottom_right.y))}
		bottom_left: painting.CornerRadius{int(math.floor(radii.bottom_left.x)), int(math.floor(radii.bottom_left.y))}
	}
}

fn assign_compatibility_visual_contexts(mut box BlockBox, visual_parent ?&BlockBox, boxes_by_layout map[u64]&BlockBox, mut tree painting.AccumulatedVisualContextTree) {
	mut inherited_state := 0
	mut fixed_to_viewport := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if node.is_fixed_position() {
			inherited_state = 0
			fixed_to_viewport = true
		} else if node.is_absolutely_positioned() {
			if containing_block := node.containing_block() {
				if containing_box := boxes_by_layout[u64(voidptr(containing_block))] {
					inherited_state = containing_box.accumulated_visual_context_for_descendants_idx
					fixed_to_viewport = containing_box.fixed_to_viewport
				}
			}
		} else if parent := visual_parent {
			inherited_state = parent.accumulated_visual_context_for_descendants_idx
			fixed_to_viewport = parent.fixed_to_viewport
		}
	} else if parent := visual_parent {
		inherited_state = parent.accumulated_visual_context_for_descendants_idx
		fixed_to_viewport = parent.fixed_to_viewport
	}
	box.fixed_to_viewport = fixed_to_viewport

	mut own_state := inherited_state
	if box.sticky_scroll_frame_index > 0 {
		own_state = tree.append(painting.ScrollVisualData{
			scroll_frame_index: box.sticky_scroll_frame_index
			is_sticky: true
		}, own_state)
	}
	if filter := box.filter.to_gfx_filter(1.0) {
		own_state = tree.append(painting.EffectsVisualData{
			filter: filter
		}, own_state)
	}
	if !affine_is_compact_identity(box.own_paint_transform) {
		own_state = tree.append(painting.TransformVisualData{
			matrix: compatibility_painting_affine(box.own_paint_transform)
		}, own_state)
	}
	if css_clip := box.css_clip {
		own_state = tree.append(painting.ClipVisualData{
			rect: compatibility_rounded_int_rect(css_clip)
		}, own_state)
	}
	if clip_path := box.clip_path {
		own_state = tree.append(clip_path, own_state)
	}
	if svg_mask := box.svg_mask {
		own_state = tree.append(svg_mask, own_state)
	}
	if svg_clip := box.svg_clip {
		own_state = tree.append(svg_clip, own_state)
	}
	box.accumulated_visual_context_index = own_state

	mut descendants_state := own_state
	if clip := box.overflow_clip {
		descendants_state = tree.append(painting.ClipVisualData{
			rect: compatibility_rounded_int_rect(clip.rect)
			corner_radii: compatibility_corner_radii(clip.corner_radii)
		}, descendants_state)
	}
	if box.own_scroll_frame_index > 0
		&& box.own_scroll_frame_index != box.sticky_scroll_frame_index {
		descendants_state = tree.append(painting.ScrollVisualData{
			scroll_frame_index: box.own_scroll_frame_index
		}, descendants_state)
	}
	box.accumulated_visual_context_for_descendants_idx = descendants_state

	for child_index := 0; child_index < box.children.len; child_index++ {
		mut child := unsafe { &box.children[child_index] }
		assign_compatibility_visual_contexts(mut child, unsafe { box }, boxes_by_layout, mut tree)
	}
}

fn viewport_assign_accumulated_visual_contexts(target voidptr) {
	mut result := viewport_layout_result(target)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut result.paint_tree, mut boxes_by_layout)
	result.scroll_state = painting.ScrollState{}
	mut boxes_by_scroll_frame := map[int]&BlockBox{}
	assign_compatibility_scroll_frames(mut result.paint_tree, boxes_by_layout, mut boxes_by_scroll_frame, mut result.scroll_state)
	result.visual_context_tree = painting.new_accumulated_visual_context_tree()
	assign_compatibility_visual_contexts(mut result.paint_tree, none, boxes_by_layout, mut result.visual_context_tree)
	result.needs_to_refresh_scroll_state = true
	viewport_refresh_scroll_state(target)
	result.needs_accumulated_visual_contexts = false
}

fn viewport_selection(target voidptr) ?&dom.Selection {
	return viewport_layout_result(target).document.get_selection()
}

fn reset_layout_selection_states(node &dom.LayoutNode) {
	for paintable in node.paintables() {
		mut mutable_paintable := unsafe { &dom.Paintable(paintable) }
		mutable_paintable.set_selection_state(.none)
	}
	for child in node.children_ {
		reset_layout_selection_states(child)
	}
}

fn set_node_selection_state(node &dom.Node, state dom.SelectionState) {
	if paintable := node.unsafe_paintable() {
		mut mutable_paintable := unsafe { &dom.Paintable(paintable) }
		mutable_paintable.set_selection_state(state)
	}
}

// Painting::ViewportPaintable::recompute_selection_states(), translated in
// source order. The DOM paintable handles point at the paintables committed by
// LayoutState, including the exact text-node endpoints used by Range.
fn viewport_recompute_selection_states(target voidptr, range &dom.Range) {
	result := viewport_layout_result(target)
	viewport := result.document.layout_node() or { return }
	root := viewport.root_layout_node() or { return }
	reset_layout_selection_states(root)

	start_container := range.start_container()
	end_container := range.end_container()
	if start_container == end_container {
		if range.start_offset() == range.end_offset() {
			return
		}
		if start_container.is_text() && !start_container.is_inert() {
			set_node_selection_state(start_container, .start_and_end)
			return
		}
	}

	if !start_container.is_inert() {
		set_node_selection_state(start_container, if start_container.is_text() {
			.start
		} else {
			.full
		})
	}

	mut start_at := start_container.child_at_index(range.start_offset())
	if start_at == none {
		if last_child := start_container.last_child() {
			start_at = last_child.next_in_pre_order(none)
		} else {
			start_at = start_container.next_in_pre_order(none)
		}
	}
	stop_at := end_container.child_at_index(range.end_offset())
	mut current := start_at
	for current != none {
		node := current or { break }
		if stop_node := stop_at {
			if node == stop_node {
				break
			}
		}
		if node == end_container && !end_container.has_children() {
			break
		}
		if !node.is_inert() {
			set_node_selection_state(node, .full)
		}
		current = node.next_in_pre_order(end_container)
	}

	if !end_container.is_inert() && end_container.is_text() {
		set_node_selection_state(end_container, .end)
	}
}

fn viewport_set_needs_repaint(target voidptr) {
	mut result := viewport_layout_result(target)
	result.needs_repaint = true
	// ViewportPaintable inherits PaintableBox upstream. Its repaint override
	// invalidates its own phase vectors (and anonymous paintable children) before
	// forwarding to Document. Keep document-level repaint separate: that path
	// preserves every PaintableBox cache.
	viewport_invalidate_box_paint_cache(mut result, result.paint_tree)
	mut document := unsafe { &dom.Document(result.document) }
	document.invalidate_display_list()
}

fn viewport_document_set_needs_repaint(target voidptr) {
	mut result := viewport_layout_result(target)
	result.needs_repaint = true
}

// Paintable::set_needs_repaint() forwards through Document, while the
// PaintableBox override first clears its own phase cache and those of direct
// anonymous paintable children. DOM's wrapper retains the source Layout::Node
// identity so this downstream callback can perform the same targeted work.
fn layout_paintable_set_needs_repaint(target voidptr, layout_handle voidptr, should_invalidate_display_list dom.InvalidateDisplayList) {
	mut result := viewport_layout_result(target)
	result.needs_repaint = true
	if should_invalidate_display_list == .yes {
		if layout_handle != unsafe { nil } {
			source_node := unsafe { &Node(layout_handle) }
			mut invalid_layout_handles := map[u64]bool{}
			if source_node.is_box() {
				invalid_layout_handles[u64(layout_handle)] = true
			}
			if containing_block := source_node.containing_block() {
				invalid_layout_handles[u64(voidptr(unsafe { &Node(containing_block) }))] = true
			}
			for entry in result.paint_order {
				if u64(entry.box.layout_handle) in invalid_layout_handles {
					viewport_invalidate_box_paint_cache(mut result, entry.box)
				}
			}
		}
	}
	// Paintable::set_needs_repaint() always forwards to Document. The enum only
	// controls retained phase-command invalidation; even `No` must discard the
	// assembled list so a new scroll snapshot is replayed.
	mut document := unsafe { &dom.Document(result.document) }
	document.needs_repaint = true
	document.invalidate_display_list()
}

fn collect_box_and_anonymous_descendants(box &BlockBox, mut targets map[u64]bool) {
	targets[u64(voidptr(box))] = true
	for child_index := 0; child_index < box.children.len; child_index++ {
		child := unsafe { &box.children[child_index] }
		if child.node_id == 0 {
			collect_box_and_anonymous_descendants(child, mut targets)
		}
	}
}

fn viewport_invalidate_box_paint_cache(mut result DocumentLayoutResult, box &BlockBox) {
	if !result.paint_phase_cache_valid || result.paint_phase_entry_valid.len != result.paint_order.len {
		return
	}
	mut targets := map[u64]bool{}
	collect_box_and_anonymous_descendants(box, mut targets)
	for index, entry in result.paint_order {
		if u64(voidptr(entry.box)) !in targets || !result.paint_phase_entry_valid[index] {
			continue
		}
		for phase in 0 .. compatibility_paint_phase_count {
			bucket := index * compatibility_paint_phase_count + phase
			result.paint_phase_command_count -= result.paint_phase_commands[bucket].len
			result.paint_phase_commands[bucket].clear()
		}
		result.paint_phase_entry_valid[index] = false
	}
}

fn viewport_invalidate_all_paint_caches(target voidptr) {
	mut result := viewport_layout_result(target)
	result.display_list_commands.clear()
	result.display_list = unsafe { nil }
	result.paint_phase_commands.clear()
	result.paint_phase_command_count = 0
	result.paint_phase_cache_valid = false
	result.paint_phase_entry_valid.clear()
	result.needs_repaint = true
}

struct CompatibilityFlattenedVisualContext {
mut:
	transform  [6]f64 = [f64(1), 0, 0, 1, 0, 0]!
	has_clip   bool
	clip       LayoutRect
	clips      []PaintClip
	clip_list  &PaintClipList = unsafe { nil }
	layers     []PaintVisualLayer
	layer_list &PaintVisualLayerList = unsafe { nil }
}

fn compatibility_affine_map_rect(matrix [6]f64, rect LayoutRect) LayoutRect {
	resolved := normalized_affine(matrix)
	points := [
		[resolved[0] * rect.x + resolved[2] * rect.y + resolved[4],
			resolved[1] * rect.x + resolved[3] * rect.y + resolved[5]],
		[resolved[0] * (rect.x + rect.width) + resolved[2] * rect.y + resolved[4],
			resolved[1] * (rect.x + rect.width) + resolved[3] * rect.y + resolved[5]],
		[resolved[0] * (rect.x + rect.width) + resolved[2] * (rect.y + rect.height) + resolved[4],
			resolved[1] * (rect.x + rect.width) + resolved[3] * (rect.y + rect.height) + resolved[5]],
		[resolved[0] * rect.x + resolved[2] * (rect.y + rect.height) + resolved[4],
			resolved[1] * rect.x + resolved[3] * (rect.y + rect.height) + resolved[5]],
	]
	mut left := points[0][0]
	mut top := points[0][1]
	mut right := left
	mut bottom := top
	for point in points[1..] {
		left = math.min(left, point[0])
		top = math.min(top, point[1])
		right = math.max(right, point[0])
		bottom = math.max(bottom, point[1])
	}
	return LayoutRect{left, top, right - left, bottom - top}
}

fn compatibility_intersect_rects(first LayoutRect, second LayoutRect) LayoutRect {
	left := math.max(first.x, second.x)
	top := math.max(first.y, second.y)
	right := math.min(first.x + first.width, second.x + second.width)
	bottom := math.min(first.y + first.height, second.y + second.height)
	if right <= left || bottom <= top {
		return LayoutRect{}
	}
	return LayoutRect{left, top, right - left, bottom - top}
}

fn compatibility_box_radii(radii painting.CornerRadii) BoxRadii {
	return BoxRadii{
		top_left: CornerRadius{f64(radii.top_left.horizontal), f64(radii.top_left.vertical)}
		top_right: CornerRadius{f64(radii.top_right.horizontal), f64(radii.top_right.vertical)}
		bottom_right: CornerRadius{f64(radii.bottom_right.horizontal), f64(radii.bottom_right.vertical)}
		bottom_left: CornerRadius{f64(radii.bottom_left.horizontal), f64(radii.bottom_left.vertical)}
	}
}

pub const compatibility_clip_path_segment_stride = 12

fn compatibility_clip_path_kind(kind painting.ClipPathSegmentKind) f32 {
	return match kind {
		.move_to { 0 }
		.line_to { 1 }
		.quadratic_bezier_curve_to { 2 }
		.cubic_bezier_curve_to { 3 }
		.elliptical_arc_to { 4 }
		.close_path { 5 }
	}
}

pub fn compatibility_pack_clip_path_segments(clip painting.ClipPathVisualData) []f32 {
	mut segments := clip.segments.clone()
	if segments.len == 0 {
		contours := if clip.polygons.len > 0 {
			clip.polygons
		} else if clip.polygon.len > 0 {
			[clip.polygon]
		} else {
			[][]painting.Point{}
		}
		for contour in contours {
			if contour.len == 0 {
				continue
			}
			segments << painting.ClipPathSegment{
				kind: painting.ClipPathSegmentKind.move_to
				point: contour[0]
			}
			for point in contour[1..] {
				segments << painting.ClipPathSegment{
					kind: painting.ClipPathSegmentKind.line_to
					point: point
				}
			}
			segments << painting.ClipPathSegment{
				kind: painting.ClipPathSegmentKind.close_path
			}
		}
	}
	mut packed := []f32{cap: segments.len * compatibility_clip_path_segment_stride}
	for segment in segments {
		packed << compatibility_clip_path_kind(segment.kind)
		packed << f32(segment.point.x)
		packed << f32(segment.point.y)
		packed << f32(segment.control_point_0.x)
		packed << f32(segment.control_point_0.y)
		packed << f32(segment.control_point_1.x)
		packed << f32(segment.control_point_1.y)
		packed << f32(segment.radii.width)
		packed << f32(segment.radii.height)
		packed << f32(segment.rotation)
		packed << if segment.large_arc { f32(1) } else { f32(0) }
		packed << if segment.sweep { f32(1) } else { f32(0) }
	}
	return packed
}

// Flatten the translated AccumulatedVisualContext tree for the immediate-mode
// native shell. Context nodes remain retained and shared; only the compact
// affine and effective clip are copied onto a replayed command.
fn flatten_compatibility_visual_context(tree painting.AccumulatedVisualContextTree, index int, snapshot painting.ScrollStateSnapshot) CompatibilityFlattenedVisualContext {
	mut flattened := CompatibilityFlattenedVisualContext{}
	chain := tree.ancestor_chain(index)
	for reverse_index := chain.len - 1; reverse_index >= 0; reverse_index-- {
		node := tree.nodes[chain[reverse_index]]
		match node.data {
			painting.TransformVisualData {
				matrix := [node.data.matrix.a, node.data.matrix.b, node.data.matrix.c,
					node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!
				around_origin := affine_around_origin(matrix, node.data.origin.x, node.data.origin.y)
				flattened.transform = multiply_affine(flattened.transform, around_origin)
			}
			painting.PerspectiveVisualData {
				matrix := [node.data.matrix.a, node.data.matrix.b, node.data.matrix.c,
					node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!
				flattened.transform = multiply_affine(flattened.transform, matrix)
			}
			painting.ScrollVisualData {
				offset := snapshot.device_offset_for_index(node.data.scroll_frame_index)
				flattened.transform = multiply_affine(flattened.transform, translated_affine(offset.x, offset.y))
			}
			painting.ClipVisualData {
				local_clip := LayoutRect{
					x: node.data.rect.x
					y: node.data.rect.y
					width: node.data.rect.width
					height: node.data.rect.height
				}
				flattened.clips << PaintClip{
					rect: local_clip
					corner_radii: compatibility_box_radii(node.data.corner_radii)
					transform: flattened.transform
				}
				clip := compatibility_affine_map_rect(flattened.transform, local_clip)
				if flattened.has_clip {
					flattened.clip = compatibility_intersect_rects(flattened.clip, clip)
				} else {
					flattened.has_clip = true
					flattened.clip = clip
				}
			}
			painting.ClipPathVisualData {
				local_clip := LayoutRect{
					x: node.data.bounding_rect.x
					y: node.data.bounding_rect.y
					width: node.data.bounding_rect.width
					height: node.data.bounding_rect.height
				}
				flattened.clips << PaintClip{
					rect: local_clip
					is_path: true
					path_data: compatibility_pack_clip_path_segments(node.data)
					path_even_odd: node.data.fill_rule == .even_odd
					transform: flattened.transform
				}
				clip := compatibility_affine_map_rect(flattened.transform, local_clip)
				if flattened.has_clip {
					flattened.clip = compatibility_intersect_rects(flattened.clip, clip)
				} else {
					flattened.has_clip = true
					flattened.clip = clip
				}
			}
			painting.SVGClipVisualData {
				local_clip := LayoutRect{
					x: node.data.bounding_rect.x
					y: node.data.bounding_rect.y
					width: node.data.bounding_rect.width
					height: node.data.bounding_rect.height
				}
				mut components := []PaintPath{cap: node.data.components.len}
				for component in node.data.components {
					component_transform := multiply_affine(flattened.transform, [
						component.transform.a,
						component.transform.b,
						component.transform.c,
						component.transform.d,
						component.transform.e,
						component.transform.f,
					]!)
					components << PaintPath{
						path_data: compatibility_pack_clip_path_segments(component.path)
						path_even_odd: component.path.fill_rule == .even_odd
						transform: component_transform
					}
				}
				mut cache_key := node.data.cache_key
				for value in flattened.transform {
					cache_key = svg_clip_hash_mix(cache_key, math.f64_bits(value))
				}
				resolved_clip := PaintClip{
					rect: local_clip
					is_svg_mask: true
					path_components: components
					cache_key: cache_key
					scope_id: node.data.scope_id
					transform: flattened.transform
				}
				flattened.clips << resolved_clip
				flattened.layers << PaintVisualLayer{
					kind: .svg_mask
					scope_id: node.data.scope_id
					mask_clip: resolved_clip
				}
				clip := compatibility_affine_map_rect(flattened.transform, local_clip)
				if flattened.has_clip {
					flattened.clip = compatibility_intersect_rects(flattened.clip, clip)
				} else {
					flattened.has_clip = true
					flattened.clip = clip
				}
			}
			painting.SVGMaskVisualData {
				local_clip := LayoutRect{
					x: node.data.bounding_rect.x
					y: node.data.bounding_rect.y
					width: node.data.bounding_rect.width
					height: node.data.bounding_rect.height
				}
				mut operations := []PaintMaskOperation{cap: node.data.operations.len}
				for operation in node.data.operations {
					operation_transform := multiply_affine(flattened.transform, [
						operation.transform.a,
						operation.transform.b,
						operation.transform.c,
						operation.transform.d,
						operation.transform.e,
						operation.transform.f,
					]!)
					operations << PaintMaskOperation{
						kind: match operation.kind {
							.begin_opacity { PaintMaskOperationKind.begin_opacity }
							.end_opacity { PaintMaskOperationKind.end_opacity }
							.image { PaintMaskOperationKind.image }
							.path { PaintMaskOperationKind.path }
						}
						opacity: operation.opacity
						image_url: operation.image_url
						image_rect: LayoutRect{
							x: operation.image_rect.x
							y: operation.image_rect.y
							width: operation.image_rect.width
							height: operation.image_rect.height
						}
						image_position_x: operation.image_position_x
						image_position_y: operation.image_position_y
						image_rendering: operation.image_rendering
						path_data: compatibility_pack_clip_path_segments(operation.path)
						path_even_odd: operation.path.fill_rule == .even_odd
						transform: operation_transform
						fill_color: painting_color_string(operation.fill_color)
						stroke_color: painting_color_string(operation.stroke_color)
						fill_linear_gradient: operation.fill_linear_gradient
						stroke_linear_gradient: operation.stroke_linear_gradient
						fill_radial_gradient: operation.fill_radial_gradient
						stroke_radial_gradient: operation.stroke_radial_gradient
						fill_pattern: operation.fill_pattern
						stroke_pattern: operation.stroke_pattern
						has_fill: operation.has_fill
						has_stroke: operation.has_stroke
						fill_opacity: operation.fill_opacity
						stroke_opacity: operation.stroke_opacity
						stroke_width: operation.stroke_width
						stroke_linecap: int(operation.stroke_linecap)
						stroke_linejoin: int(operation.stroke_linejoin)
						stroke_miterlimit: operation.stroke_miter_limit
						stroke_first: operation.stroke_first
					}
				}
				mut cache_key := node.data.cache_key
				for value in flattened.transform {
					cache_key = svg_clip_hash_mix(cache_key, math.f64_bits(value))
				}
				resolved_clip := PaintClip{
					rect: local_clip
					is_svg_content_mask: true
					mask_operations: operations
					cache_key: cache_key
					scope_id: node.data.scope_id
					mask_luminance: node.data.mask_type == .luminance
					transform: flattened.transform
				}
				flattened.clips << resolved_clip
				flattened.layers << PaintVisualLayer{
					kind: .svg_mask
					scope_id: node.data.scope_id
					mask_clip: resolved_clip
				}
				clip := compatibility_affine_map_rect(flattened.transform, local_clip)
				if flattened.has_clip {
					flattened.clip = compatibility_intersect_rects(flattened.clip, clip)
				} else {
					flattened.has_clip = true
					flattened.clip = clip
				}
			}
			painting.EffectsVisualData {
				if filter := node.data.filter {
					flattened.layers << PaintVisualLayer{
						kind: .css_filter
						scope_id: u64(chain[reverse_index])
						filter: filter
					}
				}
			}
		}
	}
	if flattened.clips.len > 0 {
		flattened.clip_list = &PaintClipList{
			items: flattened.clips
		}
	}
	if flattened.layers.len > 0 {
		flattened.layer_list = &PaintVisualLayerList{
			items: flattened.layers
		}
	}
	return flattened
}

fn paint_clip_is_svg_layer_mask(clip PaintClip) bool {
	return clip.is_svg_mask || clip.is_svg_content_mask
}

fn compatibility_begin_visual_layer_kind(layer PaintVisualLayer) string {
	return match layer.kind {
		.css_filter { 'begin_css_filter_layer' }
		.svg_mask { 'begin_svg_mask_layer' }
	}
}

fn compatibility_end_visual_layer_kind(layer PaintVisualLayer) string {
	return match layer.kind {
		.css_filter { 'end_css_filter_layer' }
		.svg_mask { 'end_svg_mask_layer' }
	}
}

// DisplayListRecorder group effects and masks bracket the complete target
// paint. Convert retained visual-context membership into one balanced command
// stream, preserving the ancestor order when filters and SVG masks are nested.
fn lower_visual_layers(commands []PaintCommand) []PaintCommand {
	mut result := []PaintCommand{cap: commands.len}
	mut active := []PaintVisualLayer{}
	for source_command in commands {
		mut desired := []PaintVisualLayer{}
		if source_command.visual_layer_list != unsafe { nil } {
			desired = source_command.visual_layer_list.items.clone()
		}
		mut common := 0
		for common < active.len && common < desired.len
			&& active[common].kind == desired[common].kind
			&& active[common].scope_id == desired[common].scope_id {
			common++
		}
		for index := active.len - 1; index >= common; index-- {
			result << PaintCommand{
				kind: compatibility_end_visual_layer_kind(active[index])
				mask_clip: active[index].mask_clip
				visual_layer: active[index]
			}
		}
		active = active[..common].clone()
		for index := common; index < desired.len; index++ {
			result << PaintCommand{
				kind: compatibility_begin_visual_layer_kind(desired[index])
				mask_clip: desired[index].mask_clip
				visual_layer: desired[index]
				// Filter bounds are in document coordinates. Preserve the first
				// enclosed command's accumulated transform so the native graph can
				// map them through scrolling and CSS transforms exactly once.
				transform: source_command.transform
				fixed_to_viewport: source_command.fixed_to_viewport
			}
			active << desired[index]
		}

		mut command := source_command
		if command.clip_list != unsafe { nil }
			&& desired.any(it.kind == .svg_mask) {
			mut ordinary_clips := []PaintClip{}
			for clip in command.clip_list.items {
				if !paint_clip_is_svg_layer_mask(clip) {
					ordinary_clips << clip
				}
			}
			if ordinary_clips.len > 0 {
				command.clip_list = &PaintClipList{ items: ordinary_clips }
			} else {
				command.clip_list = unsafe { nil }
			}
		}
		command.visual_layer_list = unsafe { nil }
		result << command
	}
	for index := active.len - 1; index >= 0; index-- {
		result << PaintCommand{
			kind: compatibility_end_visual_layer_kind(active[index])
			mask_clip: active[index].mask_clip
			visual_layer: active[index]
		}
	}
	return result
}

fn replay_cached_paint_commands_with_visual_context(steps []CompatibilityPaintStep, phase_commands [][]PaintCommand, command_count int, tree painting.AccumulatedVisualContextTree, snapshot painting.ScrollStateSnapshot,
	viewport_scroll_offset painting.Point) []PaintCommand {
	mut commands := []PaintCommand{cap: command_count}
	// A box contributes several paint phases, and many descendants inherit the
	// same accumulated context. Resolve each retained context once per replay,
	// matching DisplayListPlayer's state switching instead of walking its full
	// ancestor chain for every phase bucket.
	mut flattened_contexts := map[int]CompatibilityFlattenedVisualContext{}
	for step in steps {
		if step.entry_index < 0 {
			continue
		}
		context_index := if step.phase == .foreground && step.box.paintable_with_lines {
			step.box.accumulated_visual_context_for_descendants_idx
		} else {
			step.box.accumulated_visual_context_index
		}
		context := if cached_context := flattened_contexts[context_index] {
			cached_context
		} else {
			flattened := flatten_compatibility_visual_context(tree, context_index, snapshot)
			flattened_contexts[context_index] = flattened
			flattened
		}
		bucket := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		for cached_command in phase_commands[bucket] {
			mut command := cached_command
			command.transform = context.transform
			command.fixed_to_viewport = step.box.fixed_to_viewport
			if recording_clip := command.recording_clip {
				mapped_recording_clip := compatibility_affine_map_rect(context.transform, recording_clip)
				mut clips := []PaintClip{}
				if context.clip_list != unsafe { nil } {
					clips << context.clip_list.items
				}
				clips << PaintClip{
					rect: recording_clip
					transform: context.transform
				}
				command.has_clip = true
				command.clip_list = &PaintClipList{ items: clips }
				combined_clip := if context.has_clip {
					compatibility_intersect_rects(context.clip, mapped_recording_clip)
				} else {
					mapped_recording_clip
				}
				command.clip_x = combined_clip.x
				command.clip_y = combined_clip.y
				command.clip_width = combined_clip.width
				command.clip_height = combined_clip.height
			} else {
				command.has_clip = context.has_clip
				command.clip_list = context.clip_list
				if context.has_clip {
					command.clip_x = context.clip.x
					command.clip_y = context.clip.y
					command.clip_width = context.clip.width
					command.clip_height = context.clip.height
				}
			}
			command.visual_layer_list = context.layer_list
			apply_live_scrollbar_offset(mut command, step.box)
			apply_live_background_offsets(mut command, step.box, viewport_scroll_offset)
			commands << command
		}
	}
	return commands
}

fn viewport_record_display_list(target voidptr) &dom.DisplayList {
	mut result := viewport_layout_result(target)
	if result.display_list != unsafe { nil } && !result.needs_repaint {
		return result.display_list
	}
	viewport_build_stacking_context_tree(target)
	if !result.paint_phase_cache_valid {
		result.paint_phase_commands, result.paint_phase_command_count = result.paint_tree.build_paint_phase_command_cache(result.paint_order)
		result.paint_phase_entry_valid = []bool{len: result.paint_order.len, init: true}
		result.paint_phase_cache_valid = true
	} else {
		result.paint_phase_command_count += result.paint_tree.refresh_paint_phase_command_cache(result.paint_order, mut result.paint_phase_commands, mut result.paint_phase_entry_valid)
	}
	snapshot := result.scroll_state.snapshot(1.0)
	viewport_scroll_offset := snapshot.device_offset_for_index(result.paint_tree.own_scroll_frame_index).scale(-1)
	result.display_list_commands = lower_visual_layers(replay_cached_paint_commands_with_visual_context(result.paint_steps, result.paint_phase_commands, result.paint_phase_command_count, result.visual_context_tree, snapshot, viewport_scroll_offset))
	result.display_list = &dom.DisplayList{
		concrete_handle: target
		command_count_: result.display_list_commands.len
	}
	result.needs_repaint = false
	return result.display_list
}

fn viewport_build_stacking_context_tree(target voidptr) {
	mut result := viewport_layout_result(target)
	if result.stacking_context_tree_is_valid {
		return
	}
	// The compatibility paint tree preserves the stacking-context flags and
	// computes Ladybird's negative/block/float/inline/foreground/zero/positive
	// phase ordering. Retain a concrete context handle for DOM callers.
	result.stacking_context = &dom.StackingContext{
		concrete_handle: target
		dump_callback: viewport_stacking_context_dump
	}
	result.paint_order, result.paint_steps = result.paint_tree.compatibility_paint_plan()
	result.hit_test_order = []&BlockBox{cap: result.paint_order.len}
	for entry in result.paint_order {
		result.hit_test_order << entry.box
	}
	result.stacking_context_tree_is_valid = true
}

fn direct_child_stacking_contexts(box &BlockBox) []&BlockBox {
	mut contexts := []&BlockBox{}
	for child_index := 0; child_index < box.children.len; child_index++ {
		child := unsafe { &box.children[child_index] }
		if child.stacking_context {
			contexts << child
		} else {
			contexts << direct_child_stacking_contexts(child)
		}
	}
	contexts.sort_with_compare(fn (first &&BlockBox, second &&BlockBox) int {
		if first.z_index != second.z_index {
			return first.z_index - second.z_index
		}
		return 0
	})
	return contexts
}

fn dump_stacking_context(box &BlockBox, indent int, mut builder strings.Builder) {
	for _ in 0 .. indent {
		builder.write_string(' ')
	}
	rect := box.border_box()
	mut description := if box.tag_name.len > 0 { box.tag_name } else { 'anonymous' }
	if box.node_id != 0 {
		if node := dom.Node.from_unique_id(dom.UniqueNodeID(box.node_id)) {
			description = node.debug_description()
		}
	}
	children := direct_child_stacking_contexts(box)
	z_index := if box.z_index_auto { 'auto' } else { box.z_index.str() }
	builder.write_string('SC for ${description} [${rect.x},${rect.y} ${rect.width}x${rect.height}] [children: ${children.len}] (z-index: ${z_index})')
	if box.paint_transform != [6]f64{} {
		builder.write_string(', has_transform')
	}
	builder.write_string('\n')
	for child in children {
		dump_stacking_context(child, indent + 1, mut builder)
	}
}

fn viewport_stacking_context_dump(target voidptr) string {
	result := viewport_layout_result(target)
	mut builder := strings.new_builder(256)
	dump_stacking_context(&result.paint_tree, 0, mut builder)
	return builder.str()
}

fn viewport_stacking_context(target voidptr) &dom.StackingContext {
	viewport_build_stacking_context_tree(target)
	return viewport_layout_result(target).stacking_context
}

fn viewport_invalidate_stacking_context(target voidptr) {
	mut result := viewport_layout_result(target)
	result.stacking_context_tree_is_valid = false
	result.stacking_context = unsafe { nil }
	result.paint_order.clear()
	result.paint_steps.clear()
	result.hit_test_order.clear()
	// The cache is indexed by the retained paint order. A rebuilt stacking tree
	// may assign different indices even when individual box commands are stable.
	result.paint_phase_commands.clear()
	result.paint_phase_command_count = 0
	result.paint_phase_cache_valid = false
	result.paint_phase_entry_valid.clear()
}

fn viewport_hit_test(target voidptr, x f64, y f64, type_ dom.HitTestType) ?dom.HitTestResult {
	_ = type_
	mut result := viewport_layout_result(target)
	viewport_refresh_scroll_state(target)
	viewport_build_stacking_context_tree(target)
	snapshot := result.scroll_state.snapshot(1.0)
	mut node_id := i64(0)
	for index := result.hit_test_order.len - 1; index >= 0; index-- {
		box := result.hit_test_order[index]
		if box.node_id != 0 && box.visible && box.pointer_events_enabled
			&& compatibility_box_contains_hit_test_point(box, x, y, result.visual_context_tree, snapshot) {
			node_id = box.node_id
			break
		}
	}
	if node_id == 0 {
		return none
	}
	element := element_for_paint_node_id(node_id) or { return none }
	return dom.HitTestResult{
		element: element
	}
}

fn viewport_hit_test_all(target voidptr, x f64, y f64) []&dom.Element {
	mut result := viewport_layout_result(target)
	viewport_refresh_scroll_state(target)
	viewport_build_stacking_context_tree(target)
	snapshot := result.scroll_state.snapshot(1.0)
	mut elements := []&dom.Element{}
	for index := result.hit_test_order.len - 1; index >= 0; index-- {
		box := result.hit_test_order[index]
		if box.node_id == 0 || !box.visible || !box.pointer_events_enabled
			|| !compatibility_box_contains_hit_test_point(box, x, y, result.visual_context_tree, snapshot) {
			continue
		}
		if element := element_for_paint_node_id(box.node_id) {
			elements << element
		}
	}
	return elements
}

fn compatibility_box_contains_hit_test_point(box &BlockBox, x f64, y f64, tree painting.AccumulatedVisualContextTree, snapshot painting.ScrollStateSnapshot) bool {
	local_point := tree.transform_point_for_hit_test(box.accumulated_visual_context_index, painting.Point{x, y}, snapshot) or { return false }
	return box.border_box().contains(local_point.x, local_point.y)
}

// Recover the concrete renderer commands retained by a DOM DisplayList. Like
// upstream's RefPtr<DisplayList>, the returned array shares immutable command
// storage with the display list instead of cloning every command at the native
// boundary.
pub fn display_list_commands(display_list &dom.DisplayList) []PaintCommand {
	if display_list.concrete_handle == unsafe { nil } {
		return []PaintCommand{}
	}
	result := viewport_layout_result(display_list.concrete_handle)
	return result.display_list_commands
}
