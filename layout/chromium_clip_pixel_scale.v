module layout

import painting

// ClipVisualData stores integer device geometry. Convert back only when
// replaying it among CSS-coordinate transforms, retaining half-CSS-pixel edges.
fn compatibility_clip_visual_data(box &BlockBox, rect LayoutRect, radii BoxRadii) painting.ClipVisualData {
	scale := chromium_paint_pixel_scale(box.layout_handle)
	mut precise_rect := ?painting.Rect(none)
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if is_svg_viewport_node(node) && node.document().font_rendering_policy() == .chromium {
			if parent := node.parent() {
				if parent.is_svg_box() || parent.is_svg_svg_box() {
					precise_rect = painting.Rect{rect.x, rect.y, rect.width, rect.height}
				}
			}
		}
	}
	return painting.ClipVisualData{
		layout_rect_override: precise_rect
		rect:                 compatibility_rounded_int_rect(LayoutRect{rect.x * scale, rect.y * scale, rect.width * scale, rect.height * scale})
		corner_radii:         compatibility_corner_radii(BoxRadii{
			top_left:     CornerRadius{radii.top_left.x * scale, radii.top_left.y * scale}
			top_right:    CornerRadius{radii.top_right.x * scale, radii.top_right.y * scale}
			bottom_right: CornerRadius{radii.bottom_right.x * scale, radii.bottom_right.y * scale}
			bottom_left:  CornerRadius{radii.bottom_left.x * scale, radii.bottom_left.y * scale}
		})
		device_pixel_scale:   scale
	}
}

fn compatibility_clip_layout_rect(clip painting.ClipVisualData) LayoutRect {
	rect := clip.layout_rect()
	return LayoutRect{rect.x, rect.y, rect.width, rect.height}
}

fn compatibility_clip_layout_radii(clip painting.ClipVisualData) BoxRadii {
	scale := clip.pixel_scale()
	radii := clip.corner_radii
	return BoxRadii{
		top_left:     CornerRadius{radii.top_left.horizontal / scale, radii.top_left.vertical / scale}
		top_right:    CornerRadius{radii.top_right.horizontal / scale, radii.top_right.vertical / scale}
		bottom_right: CornerRadius{radii.bottom_right.horizontal / scale, radii.bottom_right.vertical / scale}
		bottom_left:  CornerRadius{radii.bottom_left.horizontal / scale, radii.bottom_left.vertical / scale}
	}
}
