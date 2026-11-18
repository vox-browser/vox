module main

import layout

fn normal_opacity_paint_layer(command &layout.PaintCommand) ?&layout.PaintVisualLayer {
	layer := command.visual_layer_data or { return none }
	if command.kind != 'begin_css_effect_layer' || layer.kind != .css_effect || layer.scope_id == 0
		|| layer.blend_mode != .normal || layer.filter != none || !(layer.opacity > 0 && layer.opacity < 1) {
		return none
	}
	return layer
}
