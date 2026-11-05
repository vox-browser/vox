module layout

// A calculated ink envelope limits temporary allocation. It must not turn
// into an authored clip when choosing a shared picture or folding SVG alpha.
pub fn (command &PaintCommand) effect_ancestor_clip() ?LayoutRect {
	if layer := command.visual_layer_data {
		if layer.content_bounds_applied { return layer.clip_rect }
	}
	if command.has_clip {
		return LayoutRect{command.clip_x, command.clip_y, command.clip_width, command.clip_height}
	}
	return none
}
