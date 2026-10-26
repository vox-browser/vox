module layout

// BackgroundImageGeometry trims image destinations behind opaque, continuous
// border edges. This is separate from the half-border rounded bleed clip.
fn chromium_background_image_destination(rect LayoutRect, border BoxEdges,
	colors BoxColors, styles BoxBorderStyles) LayoutRect {
	widths := [border.top, border.right, border.bottom, border.left]
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]
	side_styles := [styles.top, styles.right, styles.bottom, styles.left]
	mut insets := [4]f64{}
	for side, width in widths {
		if width <= 0 || side_colors[side].a != 255 { continue }
		mut style := side_styles[side]
		if (style == .double && width < 3) || (style in [.ridge, .groove] && width <= 1) {
			style = .solid
		}
		if style in [.solid, .inset, .outset, .ridge, .groove] {
			insets[side] = width
		}
	}
	return pixel_snapped_layout_rect(LayoutRect{
		x:      rect.x + insets[3]
		y:      rect.y + insets[0]
		width:  non_negative(rect.width - insets[1] - insets[3])
		height: non_negative(rect.height - insets[0] - insets[2])
	})
}

// Blink puts the bottom image and its color inside the same rounded clip.
// Keep both ordinary commands for portable players; native replay can defer
// the color until it knows that one repeated-image draw will consume it.
fn chromium_pair_background_image_color(mut commands []PaintCommand) {
	if commands.len < 2 { return }
	image_command := commands.last()
	if image_command.kind != 'draw_background_image' { return }
	image := image_command.image()
	background := commands[commands.len - 2]
	if background.kind != 'fill_rect' || background.radius <= 0
		|| background.opacity != image_command.opacity
		|| background.clip_outs.len != 0 || image_command.clip_outs.len != 0
		|| image.background_blend_mode != .normal || image.image_attachment == 'fixed'
		|| [background.x, background.y, background.width, background.height] !=
			[image.image_clip_x, image.image_clip_y, image.image_clip_width, image.image_clip_height] {
		return
	}
	for radius in [image.image_clip_radii.top_left, image.image_clip_radii.top_right,
		image.image_clip_radii.bottom_right, image.image_clip_radii.bottom_left] {
		if radius.x != background.radius || radius.y != background.radius { return }
	}
	commands[commands.len - 2].underlays_next = true
}

// Adjacent image and border operations may retain MSAA samples only when
// their transform, clip and compositing scope are identical. Keep the ordinary
// border command so a player that cannot combine them still paints it.
pub fn background_image_border_can_share_pass(image_command PaintCommand, border PaintCommand) bool {
	if image_command.kind != 'draw_background_image' || border.kind != 'paint_uniform_border'
		|| border.disable_antialias || border.stroke_width <= 0
		|| image_command.transform != border.transform
		|| image_command.group_opacity != border.group_opacity
		|| image_command.visual_context_index != border.visual_context_index
		|| image_command.has_clip || border.has_clip
		|| image_command.recording_clip != none || border.recording_clip != none
		|| image_command.clip_outs.len != 0 || border.clip_outs.len != 0
		|| border.local_border_data != unsafe { nil } {
		return false
	}
	image := image_command.image()
	return image.background_blend_mode == .normal && image.image_attachment != 'fixed'
		&& image.background_svg_document == none && image.background_static_svg_resource == none
}
