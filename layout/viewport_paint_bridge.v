module layout

import css
import dom
import math
import os
import page
import painting
import platform
import strings

// The concrete painting state owned by a committed DocumentLayoutResult is
// exposed to DOM through ViewportPaintable callbacks. This mirrors the
// upstream DOM -> Painting ownership boundary without making DOM import the
// downstream layout or painting modules.
fn install_document_painting_bridge(document &dom.Document, result &DocumentLayoutResult) {
	target := voidptr(result)
	mut paintable := &dom.ViewportPaintable{
		target: target
		document: document
		invalidate_scroll_state_callback: viewport_invalidate_scroll_state
		refresh_scroll_state_callback: viewport_refresh_scroll_state
		assign_accumulated_visual_contexts_callback: viewport_assign_accumulated_visual_contexts
		selection_callback: viewport_selection
		recompute_selection_states_callback: viewport_recompute_selection_states
		set_needs_repaint_callback: viewport_set_needs_repaint
		document_set_needs_repaint_callback: viewport_document_set_needs_repaint
		invalidate_all_paint_caches_callback: viewport_invalidate_all_paint_caches
		invalidate_hit_test_display_list_callback: viewport_invalidate_hit_test_display_list
		record_display_list_callback: viewport_record_display_list
		build_stacking_context_tree_callback: viewport_build_stacking_context_tree
		stacking_context_callback: viewport_stacking_context
		invalidate_stacking_context_callback: viewport_invalidate_stacking_context
		hit_test_callback: viewport_hit_test
		hit_test_all_callback: viewport_hit_test_all
	}
	paintable.set_paintable_boxes_with_auto_content_visibility(collect_paintable_boxes_with_auto_content_visibility(result.root))
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_viewport_paintable(paintable)
	mutable_document.set_viewport_scroll_snap_hook(dom.DocumentViewportScrollSnapHook{
		target: target
		adjust_destination: layout_viewport_adjust_scroll_destination
	})
	if viewport := document.layout_node() {
		if root := viewport.root_layout_node() {
			install_layout_paintable_repaint_callbacks(root, result)
		}
	}
	resnap_document_scroll_containers(result)
}

// Paint-only style changes do not run Layout::LayoutState::commit upstream:
// retained Paintable objects read the layout node's newly applied style when
// paint properties are rebuilt. BlockBox is this port's renderer transport
// snapshot, so refresh that snapshot from the retained typed tree without
// needlessly rebuilding layout geometry.
fn refresh_document_paint_tree(document &dom.Document, mut result DocumentLayoutResult,
	viewport_width f64, viewport_height f64) {
	had_valid_hit_test_display_list := result.hit_test_display_list_is_valid
	result.paint_tree = renderer_box_from_document_layout_result(result, viewport_width, viewport_height)
	result.display_list_commands.clear()
	result.display_list = unsafe { nil }
	result.needs_repaint = true
	result.scroll_state.invalidate()
	viewport_invalidate_stacking_context(voidptr(&result))
	install_document_painting_bridge(document, &result)
	viewport_assign_accumulated_visual_contexts(voidptr(&result))
	// The compatibility hit-test plan holds paint-tree pointers. A paint-only
	// style change keeps it logically valid, so remap it eagerly to the refreshed
	// renderer snapshot instead of rebuilding it inside the next input event.
	if had_valid_hit_test_display_list {
		viewport_build_stacking_context_tree(voidptr(&result))
	}
}

// Document::update_layout() builds this cache after committing paintables.
// Keep the concrete PaintableBox wrappers at the DOM/Painting cycle boundary;
// the HTML event loop can then perform proximity checks without walking the
// whole retained layout tree on every rendering opportunity.
fn collect_paintable_boxes_with_auto_content_visibility(root &Node) []&dom.PaintableBox {
	mut paintable_boxes := []&dom.PaintableBox{}
	collect_paintable_boxes_with_auto_content_visibility_in_subtree(root, mut paintable_boxes)
	return paintable_boxes
}

fn collect_paintable_boxes_with_auto_content_visibility_in_subtree(node &Node, mut paintable_boxes []&dom.PaintableBox) {
	if styled := node.as_node_with_style() {
		if styled.computed_values().content_visibility() == .auto_ {
			if dom_node := node.dom_node() {
				if element := dom_node.as_element() {
					if paintable_box := element.paintable_box() {
						paintable_boxes << paintable_box
					}
				}
			}
		}
	}
	for child in node.children() {
		collect_paintable_boxes_with_auto_content_visibility_in_subtree(child, mut paintable_boxes)
	}
}

fn install_layout_paintable_repaint_callbacks(node &dom.LayoutNode, result &DocumentLayoutResult) {
	for paintable in node.paintables() {
		mut mutable_paintable := unsafe { &dom.Paintable(paintable) }
		mutable_paintable.repaint_callback_target = voidptr(result)
		mutable_paintable.set_needs_repaint_callback = layout_paintable_set_needs_repaint
		mutable_paintable.scroll_ancestor_to_offset_into_view_callback = layout_paintable_scroll_ancestor_to_offset_into_view
		mutable_paintable.box_type_agnostic_position_callback = layout_paintable_box_type_agnostic_position
		mutable_paintable.adjust_scroll_destination_callback = layout_paintable_adjust_scroll_destination
	}
	for child in node.children_ {
		install_layout_paintable_repaint_callbacks(child, result)
	}
}

fn viewport_layout_result(target voidptr) &DocumentLayoutResult {
	return unsafe { &DocumentLayoutResult(target) }
}

fn viewport_invalidate_scroll_state(target voidptr) {
	mut result := viewport_layout_result(target)
	result.scroll_state.invalidate()
}

fn viewport_refresh_scroll_state(target voidptr) {
	mut result := viewport_layout_result(target)
	if result.scroll_state.begin_refresh(false) {
		result.scroll_state_snapshot = viewport_rederive_scroll_state(mut result)
		return
	}
	// LIBWEB_VERIFY_SCROLL_STATE: a skipped refresh must have been skippable.
	// Re-derive through the same path and compare against the retained snapshot.
	if os.getenv('LIBWEB_VERIFY_SCROLL_STATE') == '' {
		return
	}
	assert result.scroll_state.begin_refresh(true)
	rederived_snapshot := viewport_rederive_scroll_state(mut result)
	assert rederived_snapshot.device_offsets == result.scroll_state_snapshot.device_offsets
}

fn viewport_rederive_scroll_state(mut result DocumentLayoutResult) painting.ScrollStateSnapshot {
	// Sticky frames are refreshed before ordinary frames, in creation/tree
	// order. A nested sticky can therefore consume its parent's current offset.
	result.scroll_state.for_each_sticky_frame(fn [mut result] (index int, mut frame painting.ScrollFrame) {
		nearest_scrolling_ancestor := result.scroll_state.nearest_scrolling_ancestor(index)
		if nearest_scrolling_ancestor == 0 || !frame.has_sticky_constraints() {
			return
		}
		constraints := frame.sticky_constraints()

		mut parent_sticky_offset := painting.Point{}
		parent_index := frame.parent_index()
		if parent_index > 0 && result.scroll_state.frame_at(parent_index).is_sticky() {
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
		live_scroll := compatibility_live_scroll_offset(result, result.scroll_state.frame_at(nearest_scrolling_ancestor))
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
		frame.set_own_offset(painting.Point{sticky_offset_x, sticky_offset_y})
	})

	// ViewportPaintable::refresh_scroll_state() then snapshots the negated live
	// PaintableBox offsets. Display-list phase commands do not change when a
	// scroller moves; replay combines them with this state instead.
	result.scroll_state.for_each_scroll_frame(fn [result] (_ int, mut frame painting.ScrollFrame) {
		live := compatibility_live_scroll_offset(result, &frame)
		frame.set_own_offset(painting.Point{-live.x, -live.y})
	})
	return result.scroll_state.snapshot(1.0)
}

fn compatibility_live_scroll_offset(result &DocumentLayoutResult, frame &painting.ScrollFrame) painting.Point {
	paintable_box := frame.paintable_box()
	if paintable_box == 'viewport' {
		viewport := result.document.viewport_rect()
		return painting.Point{viewport.x, viewport.y}
	}
	node_id := paintable_box.i64()
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

// Direct translation of PaintableBox::nearest_scroll_frame_index(). The zero
// index is ScrollFrameIndex{} in the V scroll-state representation.
fn paintable_box_nearest_scroll_frame_index(box &BlockBox, boxes_by_layout map[u64]&BlockBox) int {
	if box.layout_handle == unsafe { nil } {
		return 0
	}
	node := unsafe { &Node(box.layout_handle) }
	if node.is_fixed_position() {
		return 0
	}
	mut containing_block := node.containing_block()
	for containing_block != none {
		ancestor := containing_block or { break }
		if ancestor_box := boxes_by_layout[u64(voidptr(ancestor))] {
			if ancestor_box.own_scroll_frame_index > 0 {
				return ancestor_box.own_scroll_frame_index
			}
		}
		// Sticky boxes still need the outside scrollport to resolve their
		// constraints, even when a fixed-position ancestor intervenes.
		if ancestor.is_fixed_position() && !node.is_sticky_position() {
			return 0
		}
		containing_block = ancestor.containing_block()
	}
	return 0
}

fn paintable_box_could_be_scrolled_by_wheel_event(box &BlockBox) bool {
	if box.layout_handle == unsafe { nil } {
		return false
	}
	overflow_rect := box.scrollable_overflow or { return false }
	node := unsafe { &Node(box.layout_handle) }
	styled := node.as_node_with_style() or { return false }
	computed := styled.computed_values()
	is_viewport := box.is_viewport_scroller || node.is_viewport()
	padding_width := if is_viewport {
		box.viewport_width
	} else {
		box.width + box.padding.left + box.padding.right
	}
	padding_height := if is_viewport {
		box.viewport_height
	} else {
		box.height + box.padding.top + box.padding.bottom
	}
	return (compatibility_overflow_allows_scrolling(computed.overflow_x(), is_viewport)
		&& overflow_rect.width > padding_width)
		|| (compatibility_overflow_allows_scrolling(computed.overflow_y(), is_viewport)
			&& overflow_rect.height > padding_height)
}

// Direct translation of PaintableBox::nearest_scrollable_ancestor(). This is
// deliberately not the nearest scroll frame: overflow:hidden creates a frame
// for programmatic scrolling, but could_be_scrolled_by_wheel_event() rejects it.
fn paintable_box_nearest_scrollable_ancestor(box &BlockBox, boxes_by_layout map[u64]&BlockBox) ?&BlockBox {
	if box.layout_handle == unsafe { nil } {
		return none
	}
	node := unsafe { &Node(box.layout_handle) }
	mut containing_block := node.containing_block()
	for containing_block != none {
		ancestor := containing_block or { break }
		if ancestor_box := boxes_by_layout[u64(voidptr(ancestor))] {
			if paintable_box_could_be_scrolled_by_wheel_event(ancestor_box) {
				return ancestor_box
			}
		}
		if ancestor.is_fixed_position() {
			return none
		}
		containing_block = ancestor.containing_block()
	}
	return none
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
	mut inset_percentage_basis := painting.Size{}
	if nearest_scrollable := paintable_box_nearest_scrollable_ancestor(box, boxes_by_layout) {
		nearest_scrollport := compatibility_scrollport_rect(nearest_scrollable)
		inset_percentage_basis = painting.Size{nearest_scrollport.width, nearest_scrollport.height}
	}
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
	mut sticky_frame := state.frame_at(sticky_frame_index)
	sticky_frame.set_sticky_constraints(painting.StickyConstraints{
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
		insets: compatibility_sticky_insets(box, inset_percentage_basis)
	})
}

fn assign_compatibility_scroll_frames(mut box BlockBox, boxes_by_layout map[u64]&BlockBox, mut boxes_by_scroll_frame map[int]&BlockBox, mut state painting.ScrollState) {
	box.own_scroll_frame_index = 0
	box.sticky_scroll_frame_index = 0
	parent_index := paintable_box_nearest_scroll_frame_index(box, boxes_by_layout)
	if box.sticky_position {
		sticky_frame_index := state.create_sticky_frame_for(box.node_id.str(), parent_index)
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
		box.own_scroll_frame_index = state.create_scroll_frame_for(paintable_id, scroll_parent_index)
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

fn compatibility_perspective_visual_data(box &BlockBox,
	computed &css.ComputedValues) ?painting.PerspectiveVisualData {
	distance := computed.perspective() or { return none }
	if distance.to_double() == 0 {
		return none
	}
	border_box := box.border_box()
	origin := computed.perspective_origin().resolved(computed.length_resolution_context(), css.CSSPixelRect.new(border_box.x, border_box.y, border_box.width, border_box.height))
	perspective := css.FloatMatrix4x4.from_values(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -1.0 / distance.to_double(), 1)
	matrix := css.translation_matrix_4x4(origin.x().to_double(), origin.y().to_double(), 0).multiply(perspective).multiply(css.translation_matrix_4x4(-origin.x().to_double(), -origin.y().to_double(), 0))
	return painting.PerspectiveVisualData{
		matrix_4x4: matrix
		uses_matrix_4x4: true
	}
}

fn assign_compatibility_visual_contexts(mut box BlockBox, visual_parent ?&BlockBox, boxes_by_layout map[u64]&BlockBox, mut tree painting.AccumulatedVisualContextTree) {
	box.fixed_background_visual_context = none
	mut inherited_state := 0
	mut inherited_plane_root := 0
	mut fixed_to_viewport := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if node.is_fixed_position() {
			if containing_block := node.containing_block() {
				containing_node := unsafe { &Node(containing_block) }
				if !containing_node.is_viewport() {
					if containing_box := boxes_by_layout[u64(voidptr(containing_block))] {
						inherited_state = containing_box.accumulated_visual_context_for_descendants_idx
						inherited_plane_root = containing_box.plane_root_for_descendants_idx
						fixed_to_viewport = containing_box.fixed_to_viewport
					}
				} else {
					fixed_to_viewport = true
				}
			} else {
				fixed_to_viewport = true
			}
		} else if node.is_absolutely_positioned() {
			if containing_block := node.containing_block() {
				if containing_box := boxes_by_layout[u64(voidptr(containing_block))] {
					inherited_state = containing_box.accumulated_visual_context_for_descendants_idx
					inherited_plane_root = containing_box.plane_root_for_descendants_idx
					fixed_to_viewport = containing_box.fixed_to_viewport
				}
			}
		} else if parent := visual_parent {
			inherited_state = parent.accumulated_visual_context_for_descendants_idx
			inherited_plane_root = parent.plane_root_for_descendants_idx
			fixed_to_viewport = parent.fixed_to_viewport
		}
	} else if parent := visual_parent {
		inherited_state = parent.accumulated_visual_context_for_descendants_idx
		inherited_plane_root = parent.plane_root_for_descendants_idx
		fixed_to_viewport = parent.fixed_to_viewport
	}
	box.fixed_to_viewport = fixed_to_viewport

	mut own_state := inherited_state
	mut enters_3d_sorting_plane := false
	mut needs_synthetic_3d_plane := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		enters_3d_sorting_plane = node.participates_in_a_3d_rendering_context()
			|| node.establishes_or_extends_a_3d_rendering_context()
		needs_synthetic_3d_plane = node.establishes_or_extends_a_3d_rendering_context()
			&& !box.uses_own_paint_transform_4x4
			&& affine_is_compact_identity(box.own_paint_transform)
	}
	if box.sticky_scroll_frame_index > 0 {
		own_state = tree.append(painting.ScrollVisualData{
			scroll_frame_index: box.sticky_scroll_frame_index
			is_sticky: true
		}, own_state)
	}
	gfx_filter := box.filter.to_gfx_filter(1.0)
	if box.opacity < 1.0 || box.mix_blend_mode != .normal || gfx_filter != none {
		own_state = tree.append(painting.EffectsVisualData{
			opacity: box.opacity
			blend_mode: box.mix_blend_mode
			filter: gfx_filter
		}, own_state)
	}
	if box.uses_own_paint_transform_4x4 || !affine_is_compact_identity(box.own_paint_transform) {
		own_state = tree.append(painting.TransformVisualData{
			matrix: compatibility_painting_affine(box.own_paint_transform)
			matrix_4x4: box.own_paint_transform_4x4
			uses_matrix_4x4: box.uses_own_paint_transform_4x4
			resets_backface_culling: enters_3d_sorting_plane
		}, own_state)
	} else if needs_synthetic_3d_plane {
		// Preserve-3d establishes a sorting plane even when the element has no
		// transform. Keep that plane explicit so it can escape an ancestor's
		// hidden back face, matching VisualContext::build_box_contexts().
		own_state = tree.append(painting.TransformVisualData{
			resets_backface_culling: true
		}, own_state)
	}
	mut plane_root_for_descendants := own_state
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		computed := node.computed_values()
		if computed.backface_visibility() == .hidden && node.is_transformable() {
			own_state = tree.append(painting.BackfaceVisibilityVisualData{
				plane_root_index: inherited_plane_root
			}, own_state)
		}
		plane_root_for_descendants = if node.establishes_or_extends_a_3d_rendering_context() {
			inherited_plane_root
		} else {
			own_state
		}
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

	if box.background_images.any(it.attachment == 'fixed') {
		// CSS Transforms makes fixed backgrounds on transformed non-root boxes
		// behave as scroll backgrounds. Inspect the typed layout ancestors so SVG
		// transforms do not accidentally change the CSS rule.
		mut is_root_element := box.is_viewport_scroller
		mut has_transform_ancestor := false
		if box.layout_handle != unsafe { nil } {
			layout_node := unsafe { &Node(box.layout_handle) }
			is_root_element = layout_node.is_root_element()
			if !is_root_element {
				mut current := ?&Node(layout_node)
				for current != none {
					node := current or { break }
					if node.is_viewport() {
						break
					}
					if node.has_css_transform() {
						has_transform_ancestor = true
						break
					}
					current = node.parent()
				}
			}
		} else if !is_root_element {
			mut context_index := own_state
			for context_index > 0 {
				context_node := tree.node_at(context_index)
				if context_node.data is painting.TransformVisualData {
					has_transform_ancestor = true
					break
				}
				context_index = context_node.parent_index
			}
		}

		if !has_transform_ancestor {
			// Negate every scroll frame in the accumulated ancestor chain. The
			// resulting context is evaluated against the live scroll snapshot.
			mut fixed_context := own_state
			mut context_index := own_state
			for context_index > 0 {
				context_node := tree.node_at(context_index)
				if context_node.data is painting.ScrollVisualData {
					fixed_context = tree.append(painting.ScrollCompensationVisualData{
						scroll_frame_index: context_node.data.scroll_frame_index
					}, fixed_context)
				}
				context_index = context_node.parent_index
			}
			box.fixed_background_visual_context = fixed_context
		}
	}

	mut descendants_state := own_state
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if perspective := compatibility_perspective_visual_data(box, node.computed_values()) {
			descendants_state = tree.append(perspective, descendants_state)
		}
	}
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
	box.plane_root_for_descendants_idx = plane_root_for_descendants

	for child_index := 0; child_index < box.children.len; child_index++ {
		mut child := unsafe { &box.children[child_index] }
		assign_compatibility_visual_contexts(mut child, unsafe { box }, boxes_by_layout, mut tree)
	}
}

fn paintable_box_point_to_device_pixels(point painting.Point, device_pixels_per_css_pixel f64) painting.Point {
	scale := f32(device_pixels_per_css_pixel)
	return painting.Point{
		x: f64(f32(point.x) * scale)
		y: f64(f32(point.y) * scale)
	}
}

fn paintable_box_point_to_css_pixels(point painting.Point, device_pixels_per_css_pixel f64) painting.Point {
	scale := f32(device_pixels_per_css_pixel)
	return painting.Point{
		x: css.CSSPixels.nearest_value_for(f64(f32(point.x) / scale)).to_double()
		y: css.CSSPixels.nearest_value_for(f64(f32(point.y) / scale)).to_double()
	}
}

// Direct translation of PaintableBox::transform_point_to_local(). The active
// bridge currently records its accumulated visual tree at one device pixel per
// CSS pixel, but retaining the scale conversion here preserves the source API
// and prevents callers from growing their own affine/scroll/clip shortcuts.
fn paintable_box_transform_point_to_local(box &BlockBox, screen_position painting.Point,
	device_pixels_per_css_pixel f64, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) ?painting.Point {
	if box.accumulated_visual_context_index == 0 {
		return screen_position
	}
	device_position := paintable_box_point_to_device_pixels(screen_position, device_pixels_per_css_pixel)
	result := tree.transform_point_for_hit_test(box.accumulated_visual_context_index, device_position, snapshot) or { return none }
	return paintable_box_point_to_css_pixels(result, device_pixels_per_css_pixel)
}

// Direct translation of
// PaintableBox::transform_point_to_local_for_descendants(). Overflow clips and
// the box's own scroll frame are deliberately included only in this variant.
fn paintable_box_transform_point_to_local_for_descendants(box &BlockBox,
	screen_position painting.Point, device_pixels_per_css_pixel f64,
	tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) ?painting.Point {
	if box.accumulated_visual_context_for_descendants_idx == 0 {
		return screen_position
	}
	device_position := paintable_box_point_to_device_pixels(screen_position, device_pixels_per_css_pixel)
	result := tree.transform_point_for_hit_test(box.accumulated_visual_context_for_descendants_idx, device_position, snapshot) or {
		return none
	}
	return paintable_box_point_to_css_pixels(result, device_pixels_per_css_pixel)
}

// Direct translation of PaintableBox::transform_rect_to_viewport().
fn paintable_box_transform_rect_to_viewport(box &BlockBox, rect LayoutRect,
	device_pixels_per_css_pixel f64, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) LayoutRect {
	if box.accumulated_visual_context_index == 0 {
		return rect
	}
	scale := f32(device_pixels_per_css_pixel)
	device_rect := painting.Rect{
		x: f64(f32(rect.x) * scale)
		y: f64(f32(rect.y) * scale)
		width: f64(f32(rect.width) * scale)
		height: f64(f32(rect.height) * scale)
	}
	result := tree.transform_rect_to_viewport(box.accumulated_visual_context_index, device_rect, snapshot)
	inverse_scale := f32(1) / scale
	return LayoutRect{
		x: css.CSSPixels.nearest_value_for(f64(f32(result.x) * inverse_scale)).to_double()
		y: css.CSSPixels.nearest_value_for(f64(f32(result.y) * inverse_scale)).to_double()
		width: css.CSSPixels.nearest_value_for(f64(f32(result.width) * inverse_scale)).to_double()
		height: css.CSSPixels.nearest_value_for(f64(f32(result.height) * inverse_scale)).to_double()
	}
}

// Direct translation of PaintableBox::inverse_transform_point(). Scroll and
// clip nodes are ignored by AccumulatedVisualContextTree, as they are upstream.
fn paintable_box_inverse_transform_point(box &BlockBox, screen_position painting.Point,
	device_pixels_per_css_pixel f64, tree painting.AccumulatedVisualContextTree) painting.Point {
	if box.accumulated_visual_context_index == 0 {
		return screen_position
	}
	device_position := paintable_box_point_to_device_pixels(screen_position, device_pixels_per_css_pixel)
	result := tree.inverse_transform_point(box.accumulated_visual_context_index, device_position)
	return paintable_box_point_to_css_pixels(result, device_pixels_per_css_pixel)
}

// Direct translation of PaintableBox::transform_to_local_coordinates().
fn paintable_box_transform_to_local_coordinates(box &BlockBox,
	screen_position painting.Point, device_pixels_per_css_pixel f64,
	tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) painting.Point {
	return paintable_box_transform_point_to_local(box, screen_position, device_pixels_per_css_pixel, tree, snapshot) or { screen_position }
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
	if should_invalidate_display_list != .no {
		viewport_invalidate_layout_paint_cache(mut result, layout_handle)
	}
	// Scroll snapshots are lowered into this port's paint-command list, so `No`
	// still discards that list while retaining the independent hit-test plan.
	mut document := unsafe { &dom.Document(result.document) }
	document.needs_repaint = true
	document.invalidate_display_list()
	if should_invalidate_display_list == .paint_commands_and_hit_test_list {
		viewport_invalidate_hit_test_display_list(target)
	}
}

fn compatibility_cursor_rect_for_layout_handle(box &BlockBox, layout_handle voidptr,
	offset int) ?painting.Rect {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle != layout_handle {
				continue
			}
			start := fragment.paintable_fragment.start_offset
			end := start + fragment.paintable_fragment.length_in_code_units
			if offset >= start && offset <= end {
				return fragment.paintable_fragment.range_rect(.start_and_end, offset, offset)
			}
		}
	}
	for child in box.children {
		if rect := compatibility_cursor_rect_for_layout_handle(child, layout_handle, offset) {
			return rect
		}
	}
	return none
}

fn compatibility_cursor_rect_in_box(box &BlockBox, offset int) ?painting.Rect {
	for line in box.lines {
		for fragment in line.fragments {
			start := fragment.paintable_fragment.start_offset
			end := start + fragment.paintable_fragment.length_in_code_units
			if offset >= start && offset <= end {
				return fragment.paintable_fragment.range_rect(.start_and_end, offset, offset)
			}
		}
	}
	for child in box.children {
		if rect := compatibility_cursor_rect_in_box(child, offset) {
			return rect
		}
	}
	return none
}

fn compatibility_absolute_padding_box_rect(box &BlockBox) LayoutRect {
	if box.is_viewport_scroller {
		return LayoutRect{ width: box.viewport_width, height: box.viewport_height }
	}
	return LayoutRect{
		x: box.x - box.padding.left
		y: box.y - box.padding.top
		width: box.width + box.padding.left + box.padding.right
		height: box.height + box.padding.top + box.padding.bottom
	}
}

fn compatibility_scroll_box_to_rect(mut result DocumentLayoutResult, box &BlockBox,
	rect painting.Rect) {
	scrollport := compatibility_absolute_padding_box_rect(box)
	mut current_x := 0.0
	mut current_y := 0.0
	mut paintable_box := ?&dom.PaintableBox(none)
	if box.is_viewport_scroller {
		viewport := result.document.viewport_rect()
		current_x = viewport.x
		current_y = viewport.y
	} else if box.layout_handle != unsafe { nil } {
		layout_node := unsafe { &Node(box.layout_handle) }
		if dom_node := layout_node.dom_node() {
			paintable_box = dom_node.paintable_box()
			if value := paintable_box {
				current := value.scroll_offset()
				current_x = current.x()
				current_y = current.y()
			}
		}
	}
	mut target_x := current_x
	mut target_y := current_y
	content_left := rect.x - scrollport.x
	content_top := rect.y - scrollport.y
	content_right := content_left + rect.width
	content_bottom := content_top + rect.height
	if content_right > current_x + scrollport.width {
		target_x = content_right - scrollport.width
	} else if content_left < current_x {
		target_x = content_left
	}
	if content_bottom > current_y + scrollport.height {
		target_y = content_bottom - scrollport.height
	} else if content_top < current_y {
		target_y = content_top
	}
	requested := dom.CSSPixelPoint_{ x_: target_x, y_: target_y }
	if box.is_viewport_scroller {
		if navigable := result.document.navigable() {
			navigable.perform_scroll_of_viewport_scrolling_box(requested)
		}
	} else if mut value := paintable_box {
		value.set_scroll_offset(requested)
	}
}

// Paintable::scroll_ancestor_to_offset_into_view(). The retained text fragment
// supplies the cursor rectangle; the typed containing-block chain selects the
// first box with scrollable overflow, including overflow:hidden containers.
fn layout_paintable_scroll_ancestor_to_offset_into_view(target voidptr, layout_handle voidptr,
	offset int) {
	if layout_handle == unsafe { nil } {
		return
	}
	mut result := viewport_layout_result(target)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut result.paint_tree, mut boxes_by_layout)
	source_node := unsafe { &Node(layout_handle) }
	mut form_text_control := false
	if dom_node := source_node.dom_node() {
		if element := dom_node.as_element() {
			form_text_control = element.is_html_element()
				&& element.local_name() in ['input', 'textarea']
		}
	}
	cursor_rect := if form_text_control {
		source_box := boxes_by_layout[u64(layout_handle)] or { return }
		compatibility_cursor_rect_in_box(source_box, offset) or { return }
	} else {
		compatibility_cursor_rect_for_layout_handle(result.paint_tree, layout_handle, offset) or {
			return
		}
	}
	mut containing_block := if form_text_control {
		source_node.as_box()
	} else {
		source_node.containing_block()
	}
	for containing_block != none {
		ancestor := containing_block or { break }
		mut ancestor_box := ?&BlockBox(none)
		if ancestor.is_viewport() {
			ancestor_box = &result.paint_tree
		} else if box := boxes_by_layout[u64(voidptr(ancestor))] {
			ancestor_box = box
		}
		if box := ancestor_box {
			if box.has_scrollable_overflow || ancestor.is_viewport() {
				compatibility_scroll_box_to_rect(mut result, box, cursor_rect)
				return
			}
		}
		containing_block = ancestor.containing_block()
	}
}

// Paintable::box_type_agnostic_position(). Boxes report their content origin;
// inline paintables fall back to the first fragment in their line container.
fn layout_paintable_box_type_agnostic_position(target voidptr,
	layout_handle voidptr) dom.CSSPixelPoint_ {
	if layout_handle == unsafe { nil } {
		return dom.CSSPixelPoint_{}
	}
	mut result := viewport_layout_result(target)
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut result.paint_tree, mut boxes_by_layout)
	if box := boxes_by_layout[u64(layout_handle)] {
		return dom.CSSPixelPoint_{ x_: box.x, y_: box.y }
	}
	source_node := unsafe { &Node(layout_handle) }
	containing_block := source_node.containing_block() or { return dom.CSSPixelPoint_{} }
	box := boxes_by_layout[u64(voidptr(containing_block))] or { return dom.CSSPixelPoint_{} }
	for line in box.lines {
		if line.fragments.len > 0 {
			rect := line.fragments[0].paintable_fragment.absolute_rect()
			return dom.CSSPixelPoint_{ x_: rect.x, y_: rect.y }
		}
	}
	// An empty inline has no fragment of its own. Its containing block's
	// content origin is the only committed position until adjacent fragments
	// supply a more specific inline coordinate.
	return dom.CSSPixelPoint_{ x_: box.x, y_: box.y }
}

fn viewport_invalidate_layout_paint_cache(mut result DocumentLayoutResult, layout_handle voidptr) {
	if layout_handle == unsafe { nil } {
		return
	}
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

fn viewport_sync_cursor_paint_cache(mut result DocumentLayoutResult) {
	mut layout_handle := unsafe { nil }
	mut offset := 0
	mut visible := false
	if position := result.document.cursor_position() {
		if node := position.node() {
			if paintable := node.unsafe_paintable() {
				layout_handle = paintable.layout_handle
				offset = position.offset()
				if navigable := result.document.navigable() {
					visible = navigable.is_focused() && result.document.get_cursor_blink_state()
				}
			}
		}
	}

	if !result.cursor_cache_initialized {
		result.cursor_cache_layout_handle = layout_handle
		result.cursor_cache_offset = offset
		result.cursor_cache_visible = visible
		result.cursor_cache_initialized = true
		return
	}
	if result.cursor_cache_layout_handle == layout_handle
		&& result.cursor_cache_offset == offset && result.cursor_cache_visible == visible {
		return
	}

	viewport_invalidate_layout_paint_cache(mut result, result.cursor_cache_layout_handle)
	if layout_handle != result.cursor_cache_layout_handle {
		viewport_invalidate_layout_paint_cache(mut result, layout_handle)
	}
	result.cursor_cache_layout_handle = layout_handle
	result.cursor_cache_offset = offset
	result.cursor_cache_visible = visible
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

// StackingContext::paint_node() deliberately skips its retained phase cache
// for a box with a fixed background context. Context indices and the initial
// containing-block positioning area can change independently of that box's
// own repaint bit when an ancestor transform changes.
fn viewport_invalidate_fixed_background_paint_caches(mut result DocumentLayoutResult) {
	if !result.paint_phase_cache_valid || result.paint_phase_entry_valid.len != result.paint_order.len {
		return
	}
	for index, entry in result.paint_order {
		if !entry.box.background_images.any(it.attachment == 'fixed')
			|| !result.paint_phase_entry_valid[index] {
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
	transform       [6]f64 = [f64(1), 0, 0, 1, 0, 0]!
	matrix_4x4      css.FloatMatrix4x4
	matrices_4x4    map[int]css.FloatMatrix4x4
	backface_culled bool
	has_clip        bool
	clip            LayoutRect
	clips           []PaintClip
	clip_list       &PaintClipList = unsafe { nil }
	layers          []PaintVisualLayer
	layer_list      &PaintVisualLayerList = unsafe { nil }
	group_opacity   f64 = 1.0
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

// DisplayListPlayer::execute_impl() recursively walks from the common ancestor
// towards its target. Preserve that source ordering for the immediate-mode
// native bridge without allocating an ancestor array for each distinct context.
fn apply_compatibility_visual_context_chain(tree &painting.AccumulatedVisualContextTree,
	index int, snapshot painting.ScrollStateSnapshot,
	mut flattened CompatibilityFlattenedVisualContext) {
	if index <= 0 || index >= tree.nodes.len {
		return
	}
	node := tree.node_at(index)
	apply_compatibility_visual_context_chain(tree, node.parent_index, snapshot, mut flattened)
	match node.data {
		painting.TransformVisualData {
			matrix := [node.data.matrix.a, node.data.matrix.b, node.data.matrix.c,
				node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!
			around_origin := affine_around_origin(matrix, node.data.origin.x, node.data.origin.y)
			flattened.transform = multiply_affine(flattened.transform, around_origin)
			flattened.matrix_4x4 = flattened.matrix_4x4.multiply(node.data.matrix_including_origin_4x4())
			if node.data.resets_backface_culling {
				flattened.backface_culled = false
			}
		}
		painting.PerspectiveVisualData {
			matrix := [node.data.matrix.a, node.data.matrix.b, node.data.matrix.c,
				node.data.matrix.d, node.data.matrix.e, node.data.matrix.f]!
			flattened.transform = multiply_affine(flattened.transform, matrix)
			resolved := if node.data.uses_matrix_4x4 {
				node.data.matrix_4x4
			} else {
				css.FloatMatrix4x4.from_values(node.data.matrix.a, node.data.matrix.c, 0, node.data.matrix.e, node.data.matrix.b, node.data.matrix.d, 0, node.data.matrix.f, 0, 0, 1, 0, 0, 0, 0, 1)
			}
			flattened.matrix_4x4 = flattened.matrix_4x4.multiply(resolved)
		}
		painting.BackfaceVisibilityVisualData {
			plane_root := flattened.matrices_4x4[node.data.plane_root_index] or {
				css.FloatMatrix4x4.identity()
			}
			if !flattened.backface_culled
				&& painting.should_cull_back_face(flattened.matrix_4x4, plane_root) {
				flattened.backface_culled = true
			}
		}
		painting.ScrollVisualData {
			offset := snapshot.device_offset_for_index(node.data.scroll_frame_index)
			flattened.transform = multiply_affine(flattened.transform, translated_affine(offset.x, offset.y))
			flattened.matrix_4x4 = flattened.matrix_4x4.multiply(css.translation_matrix_4x4(offset.x, offset.y, 0))
		}
		painting.ScrollCompensationVisualData {
			offset := snapshot.device_offset_for_index(node.data.scroll_frame_index)
			flattened.transform = multiply_affine(flattened.transform, translated_affine(-offset.x, -offset.y))
			flattened.matrix_4x4 = flattened.matrix_4x4.multiply(css.translation_matrix_4x4(-offset.x, -offset.y, 0))
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
				mut operation_kind := PaintMaskOperationKind.path
				match operation.kind {
					.begin_filter, .end_filter { continue }
					.begin_opacity { operation_kind = .begin_opacity }
					.end_opacity { operation_kind = .end_opacity }
					.image { operation_kind = .image }
					.path { operation_kind = .path }
				}
				operations << PaintMaskOperation{
					kind: operation_kind
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
					image_paintable: operation.image_paintable
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
			if node.data.opacity < 1.0 || node.data.blend_mode != .normal {
				flattened.layers << PaintVisualLayer{
					kind: .css_effect
					scope_id: u64(index)
					opacity: node.data.opacity
					blend_mode: node.data.blend_mode
				}
				flattened.group_opacity *= node.data.opacity
			}
			if filter := node.data.filter {
				flattened.layers << PaintVisualLayer{
					kind: .css_filter
					scope_id: u64(index)
					filter: filter
				}
			}
		}
	}
	flattened.matrices_4x4[index] = flattened.matrix_4x4
}

// Flatten the translated AccumulatedVisualContext tree for the immediate-mode
// native shell. Context nodes remain retained and shared; only the compact
// affine and effective clip are copied onto a replayed command.
fn flatten_compatibility_visual_context(tree painting.AccumulatedVisualContextTree, index int, snapshot painting.ScrollStateSnapshot) CompatibilityFlattenedVisualContext {
	mut flattened := CompatibilityFlattenedVisualContext{}
	flattened.matrices_4x4[0] = css.FloatMatrix4x4.identity()
	apply_compatibility_visual_context_chain(&tree, index, snapshot, mut flattened)
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
		.css_effect { 'begin_css_effect_layer' }
		.css_filter { 'begin_css_filter_layer' }
		.svg_mask { 'begin_svg_mask_layer' }
	}
}

fn compatibility_end_visual_layer_kind(layer PaintVisualLayer) string {
	return match layer.kind {
		.css_effect { 'end_css_effect_layer' }
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

fn replay_cached_paint_commands_with_visual_context(steps []CompatibilityPaintStep, phase_commands [][]PaintCommand, command_count int, tree painting.AccumulatedVisualContextTree, snapshot painting.ScrollStateSnapshot) []PaintCommand {
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
		default_context_index := if step.phase == .foreground && step.box.paintable_with_lines {
			step.box.accumulated_visual_context_for_descendants_idx
		} else {
			step.box.accumulated_visual_context_index
		}
		bucket := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		for cached_command in phase_commands[bucket] {
			mut command := cached_command
			context_index := command.visual_context_index or { default_context_index }
			context := if cached_context := flattened_contexts[context_index] {
				cached_context
			} else {
				flattened := flatten_compatibility_visual_context(tree, context_index, snapshot)
				flattened_contexts[context_index] = flattened
				flattened
			}
			if context.backface_culled {
				continue
			}
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
			command.group_opacity = context.group_opacity
			apply_live_scrollbar_offset(mut command, step.box)
			apply_live_background_offsets(mut command, step.box)
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
	viewport_sync_cursor_paint_cache(mut result)
	viewport_invalidate_fixed_background_paint_caches(mut result)
	if !result.paint_phase_cache_valid {
		result.paint_phase_commands, result.paint_phase_command_count = result.paint_tree.build_paint_phase_command_cache(result.paint_order)
		result.paint_phase_entry_valid = []bool{len: result.paint_order.len, init: true}
		result.paint_phase_cache_valid = true
	} else {
		result.paint_phase_command_count += result.paint_tree.refresh_paint_phase_command_cache(result.paint_order, mut result.paint_phase_commands, mut result.paint_phase_entry_valid)
	}
	snapshot := result.scroll_state_snapshot
	result.display_list_commands = lower_visual_layers(replay_cached_paint_commands_with_visual_context(result.paint_steps, result.paint_phase_commands, result.paint_phase_command_count, result.visual_context_tree, snapshot))
	result.display_list_commands << result.paint_tree.paint_inspector_overlay(result.document, result.visual_context_tree, snapshot)
	result.display_list = &dom.DisplayList{
		concrete_handle: target
		command_count_: result.display_list_commands.len
		dump_callback: viewport_display_list_dump
	}
	result.needs_repaint = false
	return result.display_list
}

struct CompatibilityInspectorBoxRects {
mut:
	found         bool
	content       LayoutRect
	padding       LayoutRect
	border        LayoutRect
	margin        LayoutRect
	context_index int
	fixed         bool
}

fn compatibility_inspector_rects_for_box(box &BlockBox) CompatibilityInspectorBoxRects {
	content := LayoutRect{box.x, box.y, box.width, box.height}
	padding := LayoutRect{
		x: box.x - box.padding.left
		y: box.y - box.padding.top
		width: box.width + box.padding.left + box.padding.right
		height: box.height + box.padding.top + box.padding.bottom
	}
	border := LayoutRect{
		x: padding.x - box.border.left
		y: padding.y - box.border.top
		width: padding.width + box.border.left + box.border.right
		height: padding.height + box.border.top + box.border.bottom
	}
	margin := LayoutRect{
		x: border.x - box.margin.left
		y: border.y - box.margin.top
		width: border.width + box.margin.left + box.margin.right
		height: border.height + box.margin.top + box.margin.bottom
	}
	return CompatibilityInspectorBoxRects{
		found: true
		content: content
		padding: padding
		border: border
		margin: margin
		context_index: box.accumulated_visual_context_index
		fixed: box.fixed_to_viewport
	}
}

fn compatibility_collect_inspector_box_rects(box &BlockBox, layout_handle voidptr,
	mut result CompatibilityInspectorBoxRects) {
	if box.layout_handle == layout_handle {
		current := compatibility_inspector_rects_for_box(box)
		if result.found {
			result.content = rect_union(result.content, current.content)
			result.padding = rect_union(result.padding, current.padding)
			result.border = rect_union(result.border, current.border)
			result.margin = rect_union(result.margin, current.margin)
		} else {
			result = current
		}
	}
	for index in 0 .. box.children.len {
		compatibility_collect_inspector_box_rects(&box.children[index], layout_handle, mut result)
	}
}

fn compatibility_apply_inspector_context(mut commands []PaintCommand,
	context CompatibilityFlattenedVisualContext, fixed bool) {
	for mut command in commands {
		command.transform = context.transform
		command.fixed_to_viewport = fixed
		// Paintable::paint_inspector_overlay() keeps scroll, transform, and
		// perspective nodes but deliberately excludes clips and effects.
		command.has_clip = false
		command.clip_list = unsafe { nil }
		command.visual_layer_list = unsafe { nil }
	}
}

fn compatibility_inspector_rect_commands(rect LayoutRect, fill string,
	outline string) []PaintCommand {
	return [
		PaintCommand{
			kind: 'fill_rect'
			x: rect.x
			y: rect.y
			width: rect.width
			height: rect.height
			color: fill
		},
		PaintCommand{
			kind: 'stroke_rounded_rect'
			x: rect.x
			y: rect.y
			width: rect.width
			height: rect.height
			color: outline
			stroke_width: 1
		},
	]
}

// PaintableBox::paint_inspector_overlay_internal(). The palette-backed tooltip
// roles cross the compatibility boundary as their conventional UI colors.
fn compatibility_paint_box_inspector_overlay(layout_node &Node,
	rects CompatibilityInspectorBoxRects) []PaintCommand {
	mut commands := []PaintCommand{}
	commands << compatibility_inspector_rect_commands(rects.margin, '#ffff0064', '#ffff00')
	commands << compatibility_inspector_rect_commands(rects.padding, '#00ffff64', '#00ffff')
	commands << compatibility_inspector_rect_commands(rects.border, '#00800064', '#008000')
	commands << compatibility_inspector_rect_commands(rects.content, '#ff00ff64', '#ff00ff')
	// The compatibility renderer has a built-in SerenitySans fallback even when
	// an embedder has not installed FontPlugin (as in focused Layout tests).
	// That is the deterministic equivalent of Gfx::FontDatabase's 12px default
	// font used by the upstream inspector tooltip.
	font := platform.Font{
		family: 'sans-serif'
		point_size: 12
	}
	label := '${layout_node.debug_description()} ${rects.border.width}x${rects.border.height} @ ${rects.border.x},${rects.border.y}'
	run := platform.shape_text(0, 0, label, &font, .ltr)
	metrics := font.pixel_metrics()
	label_rect := LayoutRect{
		x: rects.border.x
		y: rects.border.y + rects.border.height
		width: css.CSSPixels.nearest_value_for(f64(run.width())).to_double() + 4
		height: f64(metrics.size) + 4
	}
	commands << PaintCommand{
		kind: 'fill_rect'
		x: label_rect.x
		y: label_rect.y
		width: label_rect.width
		height: label_rect.height
		color: '#ffffe1'
	}
	commands << PaintCommand{
		kind: 'stroke_rounded_rect'
		x: label_rect.x
		y: label_rect.y
		width: label_rect.width
		height: label_rect.height
		color: '#808080'
		stroke_width: 1
	}
	commands << PaintCommand{
		kind: 'draw_text'
		x: label_rect.x + 2
		y: label_rect.y
		width: f64(run.width())
		height: label_rect.height
		color: '#000000'
		text: label
		font_size: 12
		glyph_run: run
		glyph_translation_x: label_rect.x + 2
		glyph_translation_y: label_rect.y + 2 + f64(metrics.ascent)
		glyph_orientation: .horizontal
	}
	return commands
}

// PaintableWithLines::paint_text_fragment_debug_highlight().
fn paint_text_fragment_debug_highlight(fragment painting.PaintableFragment) []PaintCommand {
	rect := fragment.absolute_rect()
	baseline_y := rect.y + fragment.baseline
	return [
		PaintCommand{
			kind: 'stroke_rounded_rect'
			x: rect.x
			y: rect.y
			width: rect.width
			height: rect.height
			color: '#008000'
			stroke_width: 1
		},
		PaintCommand{
			kind: 'draw_line'
			color: '#ff0000'
			stroke_width: 1
			points: [rect.x, baseline_y, rect.x + rect.width - 1, baseline_y]
		},
	]
}

fn compatibility_collect_text_inspector_overlay(box &BlockBox, layout_handle voidptr,
	tree painting.AccumulatedVisualContextTree, snapshot painting.ScrollStateSnapshot,
	mut commands []PaintCommand) {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle != layout_handle {
				continue
			}
			mut fragment_commands := paint_text_fragment_debug_highlight(fragment.paintable_fragment)
			context := flatten_compatibility_visual_context(tree, box.accumulated_visual_context_index, snapshot)
			compatibility_apply_inspector_context(mut fragment_commands, context, box.fixed_to_viewport)
			commands << fragment_commands
		}
	}
	for child in box.children {
		compatibility_collect_text_inspector_overlay(child, layout_handle, tree, snapshot, mut commands)
	}
}

// Paintable::paint_inspector_overlay().
fn (root &BlockBox) paint_inspector_overlay(document &dom.Document,
	tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) []PaintCommand {
	layout_node := document.highlighted_layout_node() or { return []PaintCommand{} }
	layout_handle := layout_node.real_layout_handle()
	if layout_handle == unsafe { nil } {
		return []PaintCommand{}
	}
	mut rects := CompatibilityInspectorBoxRects{}
	compatibility_collect_inspector_box_rects(root, layout_handle, mut rects)
	if rects.found {
		source_node := unsafe { &Node(layout_handle) }
		mut commands := compatibility_paint_box_inspector_overlay(source_node, rects)
		context := flatten_compatibility_visual_context(tree, rects.context_index, snapshot)
		compatibility_apply_inspector_context(mut commands, context, rects.fixed)
		return commands
	}
	mut commands := []PaintCommand{}
	compatibility_collect_text_inspector_overlay(root, layout_handle, tree, snapshot, mut commands)
	return commands
}

fn display_list_command_nesting_change(kind string) int {
	return match kind {
		'begin_background_blend_group', 'begin_background_text_clip', 'begin_css_effect_layer', 'begin_css_filter_layer', 'begin_svg_mask_layer' {
			1
		}
		'end_background_blend_group', 'end_background_text_clip', 'end_css_effect_layer', 'end_css_filter_layer', 'end_svg_mask_layer' {
			-1
		}
		else { 0 }
	}
}

fn append_display_list_command_dump(command PaintCommand, mut builder strings.Builder) {
	builder.write_string(command.kind)
	if command.x != 0 || command.y != 0 || command.width != 0 || command.height != 0 {
		builder.write_string(' rect=[${command.x},${command.y} ${command.width}x${command.height}]')
	}
	if command.color != '' {
		builder.write_string(' color=${command.color}')
	}
	if command.text != '' {
		builder.write_string(' text=${command.text}')
	}
	if command.image_url != '' {
		builder.write_string(' image=${command.image_url}')
	}
}

fn viewport_display_list_dump(target voidptr) string {
	result := viewport_layout_result(target)
	mut builder := strings.new_builder(256 + result.display_list_commands.len * 48)
	builder.write_string('AccumulatedVisualContext Tree:\n')
	for index := 1; index < result.visual_context_tree.nodes.len; index++ {
		node := result.visual_context_tree.nodes[index]
		for _ in 0 .. node.depth {
			builder.write_string('  ')
		}
		builder.writeln('[${index}] ${result.visual_context_tree.dump(index)}')
	}

	builder.write_string('\nDisplayList:\n')
	mut indent := 0
	for command in result.display_list_commands {
		nesting_change := display_list_command_nesting_change(command.kind)
		if nesting_change < 0 && indent > 0 {
			indent--
		}
		for _ in 0 .. indent {
			builder.write_string('  ')
		}
		append_display_list_command_dump(command, mut builder)
		builder.write_u8(`\n`)
		if nesting_change > 0 {
			indent++
		}
	}
	return builder.str()
}

fn viewport_build_stacking_context_tree(target voidptr) {
	mut result := viewport_layout_result(target)
	if result.stacking_context_tree_is_valid {
		viewport_build_hit_test_display_list(target)
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
	result.stacking_context_tree_is_valid = true
	viewport_build_hit_test_display_list(target)
}

fn viewport_build_hit_test_display_list(target voidptr) {
	mut result := viewport_layout_result(target)
	if result.hit_test_display_list_is_valid {
		return
	}
	if !result.stacking_context_tree_is_valid {
		viewport_build_stacking_context_tree(target)
		return
	}
	result.hit_test_steps = result.paint_tree.compatibility_hit_test_steps()
	result.hit_test_order = []&BlockBox{cap: result.paint_order.len}
	result.chrome_widget_boxes.clear()
	for entry in result.paint_order {
		result.hit_test_order << entry.box
	}
	for step in result.hit_test_steps {
		if step.box.overlay != none && step.box.node_id != 0 {
			result.chrome_widget_boxes[u64(step.box.node_id)] = voidptr(step.box)
		}
	}
	result.hit_test_display_list_is_valid = true
}

fn viewport_invalidate_hit_test_display_list(target voidptr) {
	mut result := viewport_layout_result(target)
	result.hit_test_steps.clear()
	result.hit_test_order.clear()
	result.chrome_widget_boxes.clear()
	result.hit_test_display_list_is_valid = false
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
	z_index := if box.z_index_auto { 'auto' } else { box.z_index.str() }
	builder.write_string('SC for ${description} [${rect.x},${rect.y} ${rect.width}x${rect.height}] (z-index: ${z_index})')
	if box.paint_transform != [6]f64{} {
		builder.write_string(', has_transform')
	}
	builder.write_string('\n')
	children := direct_child_stacking_contexts(box)
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
	viewport_invalidate_hit_test_display_list(target)
	// The cache is indexed by the retained paint order. A rebuilt stacking tree
	// may assign different indices even when individual box commands are stable.
	result.paint_phase_commands.clear()
	result.paint_phase_command_count = 0
	result.paint_phase_cache_valid = false
	result.paint_phase_entry_valid.clear()
}

fn viewport_hit_test(target voidptr, x f64, y f64, type_ dom.HitTestType) ?dom.HitTestResult {
	mut result := viewport_layout_result(target)
	viewport_build_hit_test_display_list(target)
	snapshot := result.scroll_state_snapshot
	metrics := painting.new_chrome_metrics(1.0) or { return none }
	mut hit_test_state := CompatibilityHitTestState{}
	// StackingContext paints chrome in the overlay phase, fragments in the
	// foreground phase, and the box itself behind its descendants. Reversing
	// that retained source-shaped plan preserves the recursive hit-test order
	// without rebuilding or resorting the tree for every pointer event.
	for index := result.hit_test_steps.len - 1; index >= 0; index-- {
		step := result.hit_test_steps[index]
		box := step.box
		match step.phase {
			.overlay {
				// Child stacking-context roots are entered through
				// StackingContext::hit_test(), which does not run the ordinary
				// PaintableBox chrome/empty-host preamble. The viewport itself is
				// initially entered through PaintableBox::hit_test() and does.
				if box.stacking_context && voidptr(box) != voidptr(&result.paint_tree) {
					continue
				}
				// PaintableWithLines tests an empty editable host before chrome.
				if empty_editable_result := compatibility_empty_editable_hit_test(box, x, y, type_, result.visual_context_tree, snapshot) {
					if hit_test_state.consider_hit_test_result(empty_editable_result, type_) {
						return hit_test_state.result
					}
				}
				if chrome_result := compatibility_hit_test_chrome(box, x, y, result.visual_context_tree, snapshot, metrics) {
					if hit_test_state.consider_hit_test_result(chrome_result, type_) {
						return hit_test_state.result
					}
				}
			}
			.foreground {
				if compatibility_hit_test_fragments(result.document, box, x, y, type_, result.visual_context_tree, snapshot, mut hit_test_state) {
					return hit_test_state.result
				}
			}
			.border {
				candidate_node_id := box.node_id_for_hit_test()
				if candidate_node_id == 0 || !box.visible || !box.pointer_events_enabled
					|| !compatibility_box_contains_hit_test_point(box, x, y, box.stacking_context, result.visual_context_tree, snapshot) {
					continue
				}
				if element := element_for_paint_node_id(candidate_node_id) {
					candidate := dom.HitTestResult{
						element: element
						node: element.as_node()
					}
					if hit_test_state.consider_hit_test_result(candidate, type_) {
						return hit_test_state.result
					}
				}
			}
			else {}
		}
	}
	return hit_test_state.result
}

enum CompatibilityChromeWidgetKind {
	resize_handle
	horizontal_scrollbar
	vertical_scrollbar
}

struct CompatibilityChromeWidgetTarget {
	kind     CompatibilityChromeWidgetKind
	identity u64
}

fn compatibility_chrome_widget_target(id string) ?CompatibilityChromeWidgetTarget {
	parts := id.split(':')
	if parts.len != 2 {
		return none
	}
	kind := match parts[0] {
		'resize-handle' { CompatibilityChromeWidgetKind.resize_handle }
		'scrollbar-horizontal' { CompatibilityChromeWidgetKind.horizontal_scrollbar }
		'scrollbar-vertical' { CompatibilityChromeWidgetKind.vertical_scrollbar }
		else {
			return none
		}
	}
	identity := parts[1].u64()
	if identity == 0 {
		return none
	}
	return CompatibilityChromeWidgetTarget{kind, identity}
}

fn compatibility_request_box_repaint(box &BlockBox) {
	if box.node_id == 0 {
		return
	}
	if node := dom.Node.from_unique_id(dom.UniqueNodeID(box.node_id)) {
		if mut paintable := node.paintable_box() {
			paintable.set_needs_repaint(.paint_commands)
		}
	}
}

fn compatibility_apply_scrollbar_hover(mut box BlockBox,
	kind CompatibilityChromeWidgetKind, hovered bool) {
	match kind {
		.horizontal_scrollbar {
			if hovered {
				box.horizontal_scrollbar.mouse_enter()
			} else {
				box.horizontal_scrollbar.mouse_leave()
			}
			if box.horizontal_scrollbar.take_repaint_request() {
				compatibility_request_box_repaint(box)
			}
		}
		.vertical_scrollbar {
			if hovered {
				box.vertical_scrollbar.mouse_enter()
			} else {
				box.vertical_scrollbar.mouse_leave()
			}
			if box.vertical_scrollbar.take_repaint_request() {
				compatibility_request_box_repaint(box)
			}
		}
		.resize_handle {
			// ResizeHandle's source hover methods are no-ops.
		}
	}
}

// These methods expose the retained ChromeWidget objects across the compact
// layout boundary. EventHandler calls leave/enter in this order whenever the
// hit-tested widget changes, exactly like the C++ owner.
pub fn (mut result DocumentLayoutResult) chrome_widget_mouse_enter(id string) {
	target := compatibility_chrome_widget_target(id) or { return }
	viewport_build_stacking_context_tree(voidptr(result))
	box_pointer := result.chrome_widget_boxes[target.identity] or { return }
	mut box := unsafe { &BlockBox(box_pointer) }
	compatibility_apply_scrollbar_hover(mut box, target.kind, true)
}

pub fn (mut result DocumentLayoutResult) chrome_widget_mouse_leave(id string) {
	target := compatibility_chrome_widget_target(id) or { return }
	viewport_build_stacking_context_tree(voidptr(result))
	box_pointer := result.chrome_widget_boxes[target.identity] or { return }
	mut box := unsafe { &BlockBox(box_pointer) }
	compatibility_apply_scrollbar_hover(mut box, target.kind, false)
}

// EventHandler::update_cursor() gives a ChromeWidget's cursor precedence over
// the owning paintable's CSS cursor. Scrollbars inherit that cursor, while a
// ResizeHandle derives its physical cursor from resize, writing-mode and the
// mirrored chrome edge.
pub fn (mut result DocumentLayoutResult) chrome_widget_cursor(id string) ?painting.ResizeCursor {
	target := compatibility_chrome_widget_target(id) or { return none }
	if target.kind != .resize_handle {
		return none
	}
	viewport_build_stacking_context_tree(voidptr(result))
	box_pointer := result.chrome_widget_boxes[target.identity] or { return none }
	box := unsafe { &BlockBox(box_pointer) }
	if box.layout_handle == unsafe { nil } {
		return none
	}
	node := unsafe { &Node(box.layout_handle) }
	styled := node.as_node_with_style() or { return none }
	overlay := box.overlay or { return none }
	return painting.ResizeHandle.create().cursor(paintable_box_physical_resize_axes(node, styled.computed_values()), overlay.chrome_mirrored)
}

struct CompatibilityResizeHandleState {
mut:
	handle painting.ResizeHandle = painting.ResizeHandle.create()
	action ?page.ElementResizeAction
}

fn compatibility_resize_mode(value css.Resize) page.ResizeMode {
	return match value {
		.none_ { .none }
		.both { .both }
		.horizontal { .horizontal }
		.vertical { .vertical }
		.inline_ { .inline }
		.block { .block }
	}
}

fn compatibility_resize_writing_mode(value css.WritingMode) page.WritingMode {
	return match value {
		.horizontal_tb { .horizontal_tb }
		.vertical_rl { .vertical_rl }
		.vertical_lr { .vertical_lr }
		.sideways_rl { .sideways_rl }
		.sideways_lr { .sideways_lr }
	}
}

// ElementResizeAction::handle_pointer_move() resolves min/max percentages
// against the containing block's padding box, not the resized box itself.
fn compatibility_resize_reference_size(mut result DocumentLayoutResult,
	box &BlockBox) ?painting.Size {
	if box.layout_handle == unsafe { nil } {
		return none
	}
	node := unsafe { &Node(box.layout_handle) }
	containing_block := node.containing_block() or { return none }
	mut boxes_by_layout := map[u64]&BlockBox{}
	collect_compatibility_boxes(mut result.paint_tree, mut boxes_by_layout)
	containing_box := boxes_by_layout[u64(voidptr(containing_block))] or { return none }
	padding_rect := containing_box.compatibility_absolute_padding_rect()
	return painting.Size{padding_rect.width, padding_rect.height}
}

fn compatibility_resize_constraints(mut result DocumentLayoutResult,
	box &BlockBox, layout_node &dom.LayoutNode, computed &css.ComputedValues) page.ResizeConstraints {
	mut min_width := ?f64(none)
	mut max_width := ?f64(none)
	mut min_height := ?f64(none)
	mut max_height := ?f64(none)
	if reference := compatibility_resize_reference_size(mut result, box) {
		if !computed.min_width().is_auto() {
			min_width = computed.min_width().to_px_for_layout_node(layout_node, css.CSSPixels.nearest_value_for(reference.width)).to_double()
		}
		if !computed.max_width().is_none() {
			max_width = computed.max_width().to_px_for_layout_node(layout_node, css.CSSPixels.nearest_value_for(reference.width)).to_double()
		}
		if !computed.min_height().is_auto() {
			min_height = computed.min_height().to_px_for_layout_node(layout_node, css.CSSPixels.nearest_value_for(reference.height)).to_double()
		}
		if !computed.max_height().is_none() {
			max_height = computed.max_height().to_px_for_layout_node(layout_node, css.CSSPixels.nearest_value_for(reference.height)).to_double()
		}
	}
	return page.ResizeConstraints{
		mode: compatibility_resize_mode(computed.resize())
		writing_mode: compatibility_resize_writing_mode(computed.writing_mode())
		rtl: computed.direction() == .rtl
		min_width: min_width
		max_width: max_width
		min_height: min_height
		max_height: max_height
		content_box: computed.box_sizing() == .content_box
		horizontal_noncontent: box.padding.left + box.padding.right + box.border.left + box.border.right
		vertical_noncontent: box.padding.top + box.padding.bottom + box.border.top + box.border.bottom
	}
}

// ResizeHandle::handle_pointer_event() owns the capture state while
// ElementResizeAction applies each accepted position to element.style.
fn compatibility_dispatch_resize_handle_pointer_event(mut result DocumentLayoutResult,
	box &BlockBox, event_type string, button int,
	visual_viewport_position painting.Point) painting.MouseAction {
	if box.node_id == 0 || box.layout_handle == unsafe { nil } {
		return .none
	}
	node := unsafe { &Node(box.layout_handle) }
	dom_node := node.dom_node() or { return .none }
	element := dom_node.as_element() or { return .none }
	dom_layout_node := dom_node.layout_node() or { return .none }
	mut state := result.resize_handle_states[box.node_id] or {
		CompatibilityResizeHandleState{}
	}
	was_resizing := state.handle.is_resizing
	event_is_accepted := if event_type == 'pointermove' {
		was_resizing
	} else {
		button == 0
	}
	action_result := state.handle.handle_pointer_event(event_type, button, visual_viewport_position)
	if !was_resizing && state.handle.is_resizing {
		border_box := box.border_box()
		state.action = page.ElementResizeAction{
			pointer_down_origin: page.PixelPoint{
				x: visual_viewport_position.x
				y: visual_viewport_position.y
			}
			initial_border_size: page.PixelSize{
				width: border_box.width
				height: border_box.height
			}
		}
	} else if was_resizing && event_is_accepted {
		if action := state.action {
			constraints := compatibility_resize_constraints(mut result, box, dom_layout_node, node.computed_values())
			if size := action.handle_pointer_move(page.PixelPoint{
				x: visual_viewport_position.x
				y: visual_viewport_position.y
			}, constraints) {
				style := css.inline_style(element)
				style.set_property('width', '${size.width:.2f}px')
				style.set_property('height', '${size.height:.2f}px')
			}
		}
	}
	if !state.handle.is_resizing {
		state.action = none
		result.resize_handle_states.delete(box.node_id)
	} else {
		result.resize_handle_states[box.node_id] = state
	}
	return action_result
}

fn compatibility_dispatch_scrollbar_pointer_event(mut result DocumentLayoutResult,
	mut box BlockBox,
	kind CompatibilityChromeWidgetKind, event_type string, button int,
	visual_viewport_position painting.Point, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot, metrics painting.ChromeMetrics) painting.MouseAction {
	if kind == .resize_handle {
		return compatibility_dispatch_resize_handle_pointer_event(mut result, &box, event_type, button, visual_viewport_position)
	}
	overlay := box.overlay or { return .none }
	direction := if kind == .horizontal_scrollbar {
		painting.ScrollDirection.horizontal
	} else {
		painting.ScrollDirection.vertical
	}
	local_position := paintable_box_transform_to_local_coordinates(box, visual_viewport_position, 1.0, tree, snapshot)
	geometry := box.compatibility_scrollbar_geometry_input(overlay, direction, metrics, if direction == .horizontal {
		box.horizontal_scrollbar.is_enlarged()
	} else {
		box.vertical_scrollbar.is_enlarged()
	})
	interaction := painting.ScrollbarInteractionInput{
		geometry: geometry
	}
	mut action := painting.MouseAction.none
	mut requested_offset := ?painting.Point(none)
	mut repaint_requested := false
	if direction == .horizontal {
		action = box.horizontal_scrollbar.handle_pointer_event(event_type, button, local_position, interaction)
		requested_offset = box.horizontal_scrollbar.take_requested_scroll_offset()
		repaint_requested = box.horizontal_scrollbar.take_repaint_request()
	} else {
		action = box.vertical_scrollbar.handle_pointer_event(event_type, button, local_position, interaction)
		requested_offset = box.vertical_scrollbar.take_requested_scroll_offset()
		repaint_requested = box.vertical_scrollbar.take_repaint_request()
	}
	if offset := requested_offset {
		if box.node_id != 0 {
			if node := dom.Node.from_unique_id(dom.UniqueNodeID(box.node_id)) {
				if mut paintable := node.paintable_box() {
					paintable.set_scroll_offset(dom.CSSPixelPoint_{
						x_: offset.x
						y_: offset.y
					})
				}
			}
		}
	}
	if repaint_requested {
		compatibility_request_box_repaint(box)
	}
	return action
}

pub fn (mut result DocumentLayoutResult) handle_scrollbar_pointer_event(id string,
	event_type string, button int, x f64, y f64) painting.MouseAction {
	target := compatibility_chrome_widget_target(id) or { return .none }
	mut document := unsafe { &dom.Document(result.document) }
	document.update_paint_and_hit_testing_properties_if_needed()
	viewport_build_stacking_context_tree(voidptr(result))
	box_pointer := result.chrome_widget_boxes[target.identity] or { return .none }
	mut box := unsafe { &BlockBox(box_pointer) }
	snapshot := result.scroll_state_snapshot
	metrics := painting.new_chrome_metrics(1.0) or { return .none }
	return compatibility_dispatch_scrollbar_pointer_event(mut result, mut box, target.kind, event_type, button, painting.Point{x, y}, result.visual_context_tree, snapshot, metrics)
}

struct CompatibilityHitTestState {
mut:
	result ?dom.HitTestResult
}

fn compatibility_hit_test_distance(distance ?f64) f64 {
	// CSSPixels::max_integer_value is the fallback in PaintableBox.cpp. The
	// fixed-point maximum itself still contains its 63/64 fractional tail.
	return distance or { math.floor(css.CSSPixels.max().to_double()) }
}

// PaintableBox::hit_test() retains the candidate with either a smaller
// vertical or horizontal distance. This deliberately mirrors its non-
// lexicographic comparison rather than replacing it with an invented metric.
fn compatibility_hit_test_result_is_better(candidate dom.HitTestResult, current ?dom.HitTestResult) bool {
	result := current or { return true }
	return compatibility_hit_test_distance(candidate.vertical_distance) < compatibility_hit_test_distance(result.vertical_distance)
		|| compatibility_hit_test_distance(candidate.horizontal_distance) < compatibility_hit_test_distance(result.horizontal_distance)
}

fn compatibility_hit_test_result_has_zero_distances(result dom.HitTestResult) bool {
	vertical_distance := result.vertical_distance or { return false }
	horizontal_distance := result.horizontal_distance or { return false }
	return vertical_distance == 0 && horizontal_distance == 0
}

fn (mut state CompatibilityHitTestState) consider_hit_test_result(candidate dom.HitTestResult,
	type_ dom.HitTestType) bool {
	mut result := state.result or { candidate }
	if compatibility_hit_test_result_is_better(candidate, state.result) {
		result = candidate
	}
	state.result = result
	return type_ == .exact || compatibility_hit_test_result_has_zero_distances(result)
}

fn compatibility_element_for_hit_node(node &dom.Node) &dom.Element {
	if element := node.as_element() {
		return element
	}
	if element := node.parent_element() {
		return element
	}
	return unsafe { &dom.Element(nil) }
}

fn compatibility_hit_test_result_for_node(node &dom.Node, index_in_node int,
	vertical_distance ?f64, horizontal_distance ?f64,
	caret_rect ?dom.CSSPixelRect_) dom.HitTestResult {
	return dom.HitTestResult{
		element: compatibility_element_for_hit_node(node)
		node: node
		index_in_node: index_in_node
		caret_rect: caret_rect
		vertical_distance: vertical_distance
		horizontal_distance: horizontal_distance
	}
}

fn compatibility_caret_rect_for_fragment(box &BlockBox,
	fragment painting.PaintableFragment, index_in_node int,
	tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) dom.CSSPixelRect_ {
	mut rect := fragment.range_rect(.start_and_end, index_in_node, index_in_node)
	context_index := box.accumulated_visual_context_for_descendants_idx
	if context_index != 0 {
		rect = tree.transform_rect_to_viewport(context_index, rect, snapshot)
	}
	return dom.CSSPixelRect_{
		x_: rect.x
		y_: rect.y
		width_: rect.width
		height_: rect.height
	}
}

fn compatibility_hit_test_result_for_chrome(box &BlockBox, chrome_widget_id string) dom.HitTestResult {
	mut dom_node := unsafe { &dom.Node(nil) }
	if box.layout_handle != unsafe { nil } {
		layout_node := unsafe { &Node(box.layout_handle) }
		if node := layout_node.dom_node() {
			dom_node = node
		}
	}
	if dom_node == unsafe { nil } {
		node_id := box.node_id_for_hit_test()
		if node_id != 0 {
			if node := dom.Node.from_unique_id(dom.UniqueNodeID(node_id)) {
				dom_node = node
			}
		}
	}
	return dom.HitTestResult{
		element: if dom_node == unsafe { nil } {
			unsafe { &dom.Element(nil) }
		} else {
			compatibility_element_for_hit_node(dom_node)
		}
		node: dom_node
		chrome_widget_id: chrome_widget_id
	}
}

fn compatibility_uses_paintable_with_lines_hit_test(box &BlockBox) bool {
	if !box.paintable_with_lines {
		return false
	}
	if box.layout_handle == unsafe { nil } {
		return true
	}
	layout_node := unsafe { &Node(box.layout_handle) }
	return layout_node.children_are_inline()
}

// Direct translation of PaintableBox::hit_test_chrome(). Resize chrome wins
// over horizontal and then vertical scrollbars in their overlapping corners.
fn compatibility_hit_test_chrome(box &BlockBox, x f64, y f64,
	tree painting.AccumulatedVisualContextTree, snapshot painting.ScrollStateSnapshot,
	metrics painting.ChromeMetrics) ?dom.HitTestResult {
	uses_lines_hit_test := compatibility_uses_paintable_with_lines_hit_test(box)
	if !box.visible || (!uses_lines_hit_test && !box.pointer_events_enabled) {
		return none
	}
	overlay := box.overlay or { return none }
	has_resizer := overlay.has_resizer
	can_scroll_horizontally := overlay.scrollbar_width != .none_
		&& overlay.can_scroll_horizontally
	can_scroll_vertically := overlay.scrollbar_width != .none_ && overlay.can_scroll_vertically
	if !has_resizer && !can_scroll_horizontally && !can_scroll_vertically {
		return none
	}
	position := if uses_lines_hit_test {
		painting.Point{x, y}
	} else {
		paintable_box_transform_to_local_coordinates(box, painting.Point{x, y}, 1.0, tree, snapshot)
	}
	if box.node_id == 0 {
		return none
	}
	identity := u64(box.node_id)
	if has_resizer && box.compatibility_resizer_contains(position, overlay, metrics) {
		return compatibility_hit_test_result_for_chrome(box, 'resize-handle:${identity}')
	}
	if overlay.scrollbar_width == .none_ {
		return none
	}
	for direction in [painting.ScrollDirection.horizontal, .vertical] {
		can_scroll := if direction == .horizontal {
			can_scroll_horizontally
		} else {
			can_scroll_vertically
		}
		if !can_scroll {
			continue
		}
		scrollbar := if direction == .horizontal {
			&box.horizontal_scrollbar
		} else {
			&box.vertical_scrollbar
		}
		input := box.compatibility_scrollbar_geometry_input(overlay, direction, metrics, scrollbar.is_enlarged())
		if scrollbar.contains(position, input) {
			name := if direction == .horizontal { 'horizontal' } else { 'vertical' }
			return compatibility_hit_test_result_for_chrome(box, 'scrollbar-${name}:${identity}')
		}
	}
	return none
}

// PaintableWithLines::hit_test()'s empty-editable fast path. It precedes the
// ordinary child/fragment walk and gives an empty editing host an exact cursor
// position at DOM offset zero.
fn compatibility_empty_editable_hit_test(box &BlockBox, x f64, y f64,
	type_ dom.HitTestType, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) ?dom.HitTestResult {
	if !box.paintable_with_lines || box.lines.any(it.fragments.len > 0) || box.children.len > 0
		|| type_ != .text_cursor || !box.visible || !box.pointer_events_enabled
		|| box.layout_handle == unsafe { nil } {
		return none
	}
	layout_node := unsafe { &Node(box.layout_handle) }
	dom_node := layout_node.dom_node() or { return none }
	if !dom_node.is_editable_or_editing_host() {
		return none
	}
	local_position := paintable_box_transform_point_to_local(box, painting.Point{x, y}, 1.0, tree, snapshot) or { return none }
	if !box.border_box_contains_hit_test_point(local_position) {
		return none
	}
	return compatibility_hit_test_result_for_node(dom_node, 0, f64(0), f64(0), none)
}

fn compatibility_text_cursor_common_ancestor_parent(document &dom.Document) ?&dom.Node {
	selection := document.get_selection() or { return none }
	range := selection.range() or { return none }
	common_ancestor := range.common_ancestor_container()
	return common_ancestor.parent() or { common_ancestor }
}

// Direct translation of PaintableWithLines::hit_test_fragments(). Fragment
// geometry is already absolute in the containing block's descendant visual
// space, including its scroll offset.
fn compatibility_hit_test_fragments(document &dom.Document, box &BlockBox, x f64,
	y f64, type_ dom.HitTestType, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot, mut hit_test_state CompatibilityHitTestState) bool {
	if !compatibility_uses_paintable_with_lines_hit_test(box) || !box.visible
		|| !box.pointer_events_enabled {
		return false
	}
	local_position := if box.stacking_context {
		paintable_box_transform_point_to_local(box, painting.Point{x, y}, 1.0, tree, snapshot) or { return false }
	} else {
		paintable_box_transform_point_to_local_for_descendants(box, painting.Point{x, y}, 1.0, tree, snapshot) or { return false }
	}
	common_ancestor_parent := if type_ == .text_cursor {
		compatibility_text_cursor_common_ancestor_parent(document)
	} else {
		?&dom.Node(none)
	}
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == unsafe { nil } {
				continue
			}
			layout_node := unsafe { &Node(fragment.layout_handle) }
			computed := layout_node.computed_values()
			if layout_node.establishes_stacking_context() || computed.visibility() != .visible
				|| !paintable_visible_for_hit_testing(layout_node, computed) {
				continue
			}
			dom_node := layout_node.dom_node() or { continue }
			fragment_rect := fragment.paintable_fragment.absolute_rect()
			if fragment_rect.contains(local_position) {
				index_in_node := if layout_node.is_text_node() {
					fragment.paintable_fragment.index_in_node_for_point(local_position)
				} else {
					0
				}
				caret_rect := compatibility_caret_rect_for_fragment(box,
					fragment.paintable_fragment, index_in_node, tree, snapshot)
				candidate := compatibility_hit_test_result_for_node(dom_node, index_in_node,
					f64(0), f64(0), caret_rect)
				if hit_test_state.consider_hit_test_result(candidate, type_) {
					return true
				}
				continue
			}
			if type_ != .text_cursor || layout_node.user_select_used_value() == .none_ {
				continue
			}
			ancestor := common_ancestor_parent or { continue }
			if !ancestor.is_ancestor_of(dom_node) {
				continue
			}

			mut candidate := ?dom.HitTestResult(none)
			if fragment_rect.bottom() - 1 <= local_position.y {
				index_in_node := fragment.paintable_fragment.start_offset + fragment.paintable_fragment.length_in_code_units
				caret_rect := compatibility_caret_rect_for_fragment(box,
					fragment.paintable_fragment, index_in_node, tree, snapshot)
				hit := compatibility_hit_test_result_for_node(dom_node, index_in_node,
					local_position.y - fragment_rect.bottom(), none, caret_rect)
				candidate = hit
			} else if local_position.y < fragment_rect.top() {
				index_in_node := fragment.paintable_fragment.start_offset
				caret_rect := compatibility_caret_rect_for_fragment(box,
					fragment.paintable_fragment, index_in_node, tree, snapshot)
				hit := compatibility_hit_test_result_for_node(dom_node, index_in_node,
					fragment_rect.top() - local_position.y, none, caret_rect)
				candidate = hit
			} else if fragment_rect.top() <= local_position.y {
				if local_position.x < fragment_rect.left() {
					index_in_node := fragment.paintable_fragment.start_offset
					caret_rect := compatibility_caret_rect_for_fragment(box,
						fragment.paintable_fragment, index_in_node, tree, snapshot)
					hit := compatibility_hit_test_result_for_node(dom_node, index_in_node,
						f64(0), fragment_rect.left() - local_position.x, caret_rect)
					candidate = hit
				} else if local_position.x > fragment_rect.right() {
					index_in_node := fragment.paintable_fragment.start_offset + fragment.paintable_fragment.length_in_code_units
					caret_rect := compatibility_caret_rect_for_fragment(box,
						fragment.paintable_fragment, index_in_node, tree, snapshot)
					hit := compatibility_hit_test_result_for_node(dom_node, index_in_node,
						f64(0), local_position.x - fragment_rect.right(), caret_rect)
					candidate = hit
				}
			}
			if value := candidate {
				if hit_test_state.consider_hit_test_result(value, type_) {
					return true
				}
			}
		}
	}
	return false
}

fn viewport_hit_test_all(target voidptr, x f64, y f64) []&dom.Element {
	mut result := viewport_layout_result(target)
	viewport_build_hit_test_display_list(target)
	snapshot := result.scroll_state_snapshot
	metrics := painting.new_chrome_metrics(1.0) or { return []&dom.Element{} }
	mut elements := []&dom.Element{}
	for index := result.hit_test_steps.len - 1; index >= 0; index-- {
		step := result.hit_test_steps[index]
		box := step.box
		match step.phase {
			.overlay {
				if box.stacking_context && voidptr(box) != voidptr(&result.paint_tree) {
					continue
				}
				if chrome_result := compatibility_hit_test_chrome(box, x, y, result.visual_context_tree, snapshot, metrics) {
					if chrome_result.element != unsafe { nil } {
						elements << chrome_result.element
					}
				}
			}
			.border {
				node_id := box.node_id_for_hit_test()
				if node_id == 0 || !box.visible || !box.pointer_events_enabled
					|| !compatibility_box_contains_hit_test_point(box, x, y, box.stacking_context, result.visual_context_tree, snapshot) {
					continue
				}
				if element := element_for_paint_node_id(node_id) {
					elements << element
				}
			}
			else {}
		}
	}
	return elements
}

fn compatibility_box_contains_hit_test_point(box &BlockBox, x f64, y f64,
	stacking_context_root bool, tree painting.AccumulatedVisualContextTree,
	snapshot painting.ScrollStateSnapshot) bool {
	local_point := paintable_box_transform_point_to_local(box, painting.Point{x, y}, 1.0, tree, snapshot) or { return false }
	if !box.svg_path_bounding_box_contains_hit_test_point(local_point) {
		return false
	}
	if stacking_context_root {
		// StackingContext::hit_test() intentionally performs only the final
		// absolute-border-box containment check here.
		border_box := box.border_box()
		return border_box.contains(local_point.x, local_point.y)
	}
	// PaintableBox::hit_test() applies the normalized border radii after mapping
	// the viewport point into the box's local coordinate space.
	return box.border_box_contains_hit_test_point(local_point)
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
