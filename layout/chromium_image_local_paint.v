module layout

import css
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
}

fn chromium_image_local_transform(data &PaintLocalImageData, full [6]f64,
	own [6]f64) [6]f64 {
	geometry := PaintLocalBorderData{
		origin_x:data.origin_x
		origin_y:data.origin_y
	}
	return chromium_local_border_transform(&geometry,full,own)
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
