module layout

import css
import math
import painting

// A static rotated/skewed replaced box paints in its transform fragment.
// Snapping its document-space edges instead changes both the bitmap size and
// the paint offset. Keep layout geometry and ancestor clips in their own space.
pub struct PaintLocalImageData {
pub:
	origin_x f64
	origin_y f64
	transform_context_index int
	initial_transform painting.Affine
	fragment_adjustment painting.Point
}

fn chromium_image_local_transform(data &PaintLocalImageData, full [6]f64,
	own [6]f64) [6]f64 {
	determinant := own[0] * own[3] - own[1] * own[2]
	if determinant == 0 { return full }
	dx := math.floor(data.origin_x + data.fragment_adjustment.x + .5) - data.origin_x
	dy := math.floor(data.origin_y + data.fragment_adjustment.y + .5) - data.origin_y
	x := data.origin_x + (own[3] * dx - own[2] * dy) / determinant
	y := data.origin_y + (own[0] * dy - own[1] * dx) / determinant
	return multiply_affine(full, translated_affine(x, y))
}

// Will-change transform/scale/rotate boundaries reset Blink's subpixel
// accumulation even when their current transform is the identity. Resolve
// those offsets from the outside in, before rounding the image's own offset.
fn chromium_image_transform_fragment_adjustment(node &Node,
	state &LayoutState) ?painting.Point {
	if node.document().font_rendering_policy() != .chromium
		|| computed_transform_is_none(node.computed_values()) { return none }
	mut origins := []painting.Point{}
	mut parent := node.parent()
	mut seen := map[u64]bool{}
	for parent != none {
		ancestor := parent or { break }
		key := u64(voidptr(ancestor))
		if key in seen { return none }
		seen[key] = true
		if ancestor.has_style() {
			computed := ancestor.computed_values()
			if !computed_transform_is_none(computed) {
				styled := ancestor.as_node_with_style() or { return none }
				used := state.try_get(styled) or { return none }
				position := paint_cumulative_offset(ancestor,state,used)
				reference := paintable_box_transform_reference_box(ancestor,computed,used,position,state)
				matrix := resolved_computed_transform_4x4_matrix(computed,reference.x,reference.y,
					reference.width,reference.height)
				// Complex ancestor transforms retain their established policy until
				// their separate local paint spaces can be represented as well.
				if matrix.m11 != 1 || matrix.m12 != 0 || matrix.m13 != 0
					|| matrix.m21 != 0 || matrix.m22 != 1 || matrix.m23 != 0
					|| matrix.m31 != 0 || matrix.m32 != 0 || matrix.m33 != 1 || matrix.m34 != 0
					|| matrix.m41 != 0 || matrix.m42 != 0 || matrix.m43 != 0 || matrix.m44 != 1 {
					return none
				}
			}
			hints := computed.will_change()
			if (hints.has_property(.transform) || hints.has_property(.scale)
				|| hints.has_property(.rotate)) && chromium_will_change_transform_needs_surface(ancestor) {
				styled := ancestor.as_node_with_style() or { return none }
				used := state.try_get(styled) or { return none }
				position := paint_cumulative_offset(ancestor,state,used)
				origins << painting.Point{
					x:position.x().to_double()-used.padding_left.to_double()-used.border_left.to_double()
					y:position.y().to_double()-used.padding_top.to_double()-used.border_top.to_double()
				}
			}
		}
		parent = ancestor.parent()
	}
	mut adjustment := painting.Point{}
	for index := origins.len - 1; index >= 0; index-- {
		origin := origins[index]
		adjustment = painting.Point{math.floor(origin.x+adjustment.x+.5)-origin.x,
			math.floor(origin.y+adjustment.y+.5)-origin.y}
	}
	return adjustment
}

fn chromium_image_replay_transform(data &PaintLocalImageData, full [6]f64,
	tree &painting.AccumulatedVisualContextTree) [6]f64 {
	initial := data.initial_transform
	mut own := [initial.a,initial.b,initial.c,initial.d,initial.e,initial.f]!
	if data.transform_context_index > 0 && data.transform_context_index < tree.nodes.len {
		node := tree.node_at(data.transform_context_index)
		if node.data is painting.TransformVisualData {
			own = css.project_plane_to_affine_transform(node.data.matrix_including_origin_4x4()) or { own }
		}
	}
	return chromium_image_local_transform(data,full,own)
}

fn chromium_local_image_geometry(mut command PaintCommand, box &BlockBox,
	border_rect LayoutRect) {
	if command.kind != 'draw_replaced_image' || !box.snaps_background_rect
		|| command.local_image_data != unsafe { nil } || box.media().is_svg_image {
		return
	}
	paintable := command.image_paintable or { return }
	if paintable.paint_offset_adjustment != painting.Point{} { return }
	fragment_adjustment := paintable.transform_fragment_adjustment or { return }
	own := box.own_paint_transform
	// Pure translations and axis-aligned scales retain their existing
	// subpixel propagation. Depth transforms need their separate raster policy.
	if own[1] == 0 && own[2] == 0 { return }
	if box.uses_own_paint_transform_4x4 {
		m := box.own_paint_transform_4x4
		if m.m13 != 0 || m.m23 != 0 || m.m31 != 0 || m.m32 != 0
			|| m.m33 != 1 || m.m34 != 0 || m.m41 != 0 || m.m42 != 0
			|| m.m43 != 0 || m.m44 != 1 { return }
	}
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if chromium_compositor_animation_properties(node).transform { return }
	}
	data := &PaintLocalImageData{
		origin_x:border_rect.x
		origin_y:border_rect.y
		transform_context_index:box.own_transform_visual_context_idx
		initial_transform:painting.Affine{a:own[0],b:own[1],c:own[2],d:own[3],e:own[4],f:own[5]}
		fragment_adjustment:fragment_adjustment
	}
	command.local_image_data = data
	command.x -= border_rect.x
	command.y -= border_rect.y
	command.image_paintable = &painting.ImagePaintable{
		...*paintable
		image_rect:painting.Rect{paintable.image_rect.x-border_rect.x,
			paintable.image_rect.y-border_rect.y,paintable.image_rect.width,paintable.image_rect.height}
	}
	command.transform = chromium_image_local_transform(data,box.paint_transform,own)
}
