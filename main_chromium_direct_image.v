module main

import layout

fn C.native_set_chromium_direct_image_layer(i32)

// A sole replaced-image command can retain Chromium's direct-image raster
// scale. Explicit effect/transform pictures and mixed content keep their
// existing picture path; native replay checks decoded source geometry too.
fn chromium_direct_image_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	if layer.legacy_raster || !layer.composited_contents || layer.command_indices.len != 1 {
		return false
	}
	command_index := layer.command_indices[0]
	if command_index < 0 || command_index >= commands.len || plan.command_layers[command_index] != index {
		return false
	}
	command := &commands[command_index]
	paintable := command.image_paintable or { return false }
	// A clip painted inside the image picture prevents Chromium's direct-image
	// optimization. Ancestor clips remain compositor clips and are supported.
	if paintable.border_radii.has_any_radius() {
		return false
	}
	if plan.has_picture_clip_metadata && layer.picture_local_rounded_clip { return false }
	if !plan.has_picture_clip_metadata && command.clip_list != unsafe { nil } {
		for clip_index, clip in command.clip_list.items {
			if clip.corner_radii == layout.BoxRadii{} { continue }
			// A new rounded clip can remain inside the ancestor's picture even
			// when our leaf contains only an image command. Use the two-stage
			// sampler only when the preceding composited content shares this
			// clip: it must then survive outside both content pictures. More
			// general clip upcasting needs separate compositor metadata.
			if index < 2 || !plan.layers[index - 1].composited_contents
				|| plan.layers[index - 1].legacy_raster {
				return false
			}
			mut shared := false
			for previous_index in plan.layers[index - 1].command_indices {
				if previous_index < 0 || previous_index >= commands.len { return false }
				previous := &commands[previous_index]
				if previous.clip_list == unsafe { nil }
					|| previous.clip_list.items.len <= clip_index {
					continue
				}
				mut matching := true
				for prefix in 0 .. clip_index + 1 {
					if previous.clip_list.items[prefix] != command.clip_list.items[prefix] {
						matching = false
						break
					}
				}
				if matching {
					shared = true
					break
				}
			}
			if !shared { return false }
		}
	}
	return command.kind == 'draw_replaced_image' && command.opacity == 1 && command.group_opacity == 1
		&& command.blur == 0 && !command.outer_shadow && command.scrollbar_axis == ''
		&& command.video_frame_source == none && chromium_shared_recording_clips_supported(command)
}
