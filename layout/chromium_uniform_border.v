module layout

import painting

// Shrinking an opaque solid border's background by half its width keeps its
// antialiased outer edge from bleeding through the border's coverage.
fn chromium_background_under_opaque_border(rect LayoutRect, radii BoxRadii,
	border BoxEdges, colors BoxColors, styles BoxBorderStyles) (LayoutRect, BoxRadii) {
	// Missing sides do not expose a translucent border. Blink can still move
	// the background halfway beneath each visible opaque solid side.
	widths := [border.top, border.right, border.bottom, border.left]
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]
	side_styles := [styles.top, styles.right, styles.bottom, styles.left]
	for side, width in widths {
		if width > 0 && (side_colors[side].a != 255 || side_styles[side] != .solid) {
			return rect, radii
		}
	}
	top := border.top / 2
	right := border.right / 2
	bottom := border.bottom / 2
	left := border.left / 2
	return LayoutRect{rect.x + left, rect.y + top, non_negative(rect.width - left - right), non_negative(rect.height - top - bottom)}, BoxRadii{
		top_left:     shrink_corner_radius(radii.top_left, left, top)
		top_right:    shrink_corner_radius(radii.top_right, right, top)
		bottom_right: shrink_corner_radius(radii.bottom_right, right, bottom)
		bottom_left:  shrink_corner_radius(radii.bottom_left, left, bottom)
	}
}

// A uniform solid rounded border is an analytic stroked rrect in Chromium,
// rather than four independently rasterized border paths.
fn append_chromium_uniform_border(mut commands []PaintCommand, border BoxEdges,
	colors BoxColors, styles BoxBorderStyles, radii BoxRadii, rect painting.IntRect,
	opacity f64) bool {
	w := border.top
	if w <= 0 || border.right != w || border.bottom != w || border.left != w
		|| colors.top != colors.right || colors.top != colors.bottom || colors.top != colors.left
		|| styles.top != .solid || styles.right != .solid || styles.bottom != .solid
		|| styles.left != .solid || rect.width <= w || rect.height <= w {
		return false
	}
	for r in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
		if r.x != r.y || (r.x > 0 && r.x < w / 2) { return false }
	}
	commands << PaintCommand{
		kind:         'paint_uniform_border'
		x:            rect.x + w / 2
		y:            rect.y + w / 2
		width:        rect.width - w
		height:       rect.height - w
		corner_radii: BoxRadii{
			top_left:     shrink_corner_radius(radii.top_left, w / 2, w / 2)
			top_right:    shrink_corner_radius(radii.top_right, w / 2, w / 2)
			bottom_right: shrink_corner_radius(radii.bottom_right, w / 2, w / 2)
			bottom_left:  shrink_corner_radius(radii.bottom_left, w / 2, w / 2)
		}
		stroke_width: w
		color:        colors.top.serialize()
		opacity:      opacity
	}
	return true
}
