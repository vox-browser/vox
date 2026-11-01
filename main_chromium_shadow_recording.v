module main

import layout
import math
import os

const disable_complete_shadow_pictures = os.getenv('VOX_DISABLE_COMPLETE_SHADOW_PICTURES') != ''

// The native outer-shadow painter already records this geometry inside an
// isolated compositor surface. Retain malformed/legacy input on its old path.
fn chromium_complete_outer_shadow_supported(command &layout.PaintCommand) bool {
	if command.kind != 'paint_outer_box_shadow' || command.box_shadow_data == unsafe { nil }
		|| command.outer_shadow || command.width <= 0 || command.height <= 0
		|| command.blur < 0 || command.clip_outs.len != 0
		|| !chromium_shared_recording_clips_supported(command) { return false }
	data := command.box_shadow_data
	box := data.content_rect
	if box.width <= 0 || box.height <= 0 { return false }
	for value in [command.x, command.y, command.width, command.height, command.blur,
		box.x, box.y, box.width, box.height] {
		if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 65536 { return false }
	}
	for value in command.transform {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	for corner in [data.content_radii.top_left, data.content_radii.top_right,
		data.content_radii.bottom_right, data.content_radii.bottom_left] {
		if math.is_nan(corner.x) || math.is_nan(corner.y) || math.is_inf(corner.x, 0)
			|| math.is_inf(corner.y, 0) || corner.x < 0 || corner.y < 0 { return false }
	}
	return true
}
