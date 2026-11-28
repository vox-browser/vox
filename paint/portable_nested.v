module main

import layout
import math
import painting

struct PortableNestedPlacement {
	transform [6]f64
	origin    painting.IntPoint
	opacity   f64
	clip      painting.Rect
}

fn portable_nested_clip(command &layout.PaintCommand, viewport painting.Rect) painting.Rect {
	if !command.has_clip { return viewport }
	return viewport.intersection(painting.Rect{command.clip_x, command.clip_y, command.clip_width,
		command.clip_height})
}

fn (mut app BrowserApp) draw_portable_nested_commands(commands []layout.PaintCommand,
	placement PortableNestedPlacement, page_x f32, page_y f32, window_height int) {
	if placement.clip.is_empty() { return }
	left := int(math.floor(placement.clip.x + f64(page_x)))
	top := int(math.floor(placement.clip.y + f64(page_y)))
	right := int(math.ceil(placement.clip.right() + f64(page_x)))
	bottom := int(math.ceil(placement.clip.bottom() + f64(page_y)))
	mut index := 0
	for index < commands.len {
		command := &commands[index]
		if placement.opacity == 1 && (command.kind == 'begin_svg_mask_layer'
			|| command.kind == 'begin_css_effect_layer') {
			if end := app.draw_portable_nested_svg_group(commands, index, placement, page_x, page_y) {
				index = end
				continue
			}
		}
		mut mapped := layout.paint_command_for_nested_viewport(*command, placement.transform,
			placement.origin, placement.opacity)
		if mapped.has_clip || mapped.kind in ['paint_nested_display_list', 'draw_background_image'] {
			// A child can replace its scissor or pass it on to another viewport.
			clip := portable_nested_clip(&mapped, placement.clip)
			mapped.has_clip = true
			mapped.clip_x = clip.x
			mapped.clip_y = clip.y
			mapped.clip_width = clip.width
			mapped.clip_height = clip.height
		} else {
			app.ctx.scissor_rect(left, top, right - left, bottom - top)
		}
		app.draw_command(mapped, page_x, page_y, window_height)
		index++
	}
	app.flush_rounded_rect_underlay(page_x, page_y, window_height)
	app.ctx.scissor_rect(0, 0, app.ctx.width, app.ctx.height)
}

fn (mut app BrowserApp) draw_portable_nested_svg_group(commands []layout.PaintCommand, start int,
	placement PortableNestedPlacement, page_x f32, page_y f32) ?int {
	if !app.portable_svg_group_allowed() { return none }
	command := &commands[start]
	is_mask := command.kind == 'begin_svg_mask_layer'
	end := if is_mask {
		mask := command.mask_clip()
		group := portable_svg_mask_group(commands, start, &mask) or { return none }
		group.end
	} else {
		if disable_portable_svg_opacity { return none }
		layer := normal_opacity_paint_layer(command) or { return none }
		portable_svg_opacity_end(commands, start, layer) or { return none }
	}
	clip := placement.clip
	viewport := app.portable_device_viewport(page_y).intersection(portable_svg_device_clip(
		layout.LayoutRect{clip.x, clip.y, clip.width, clip.height}, page_x, page_y, f64(app.ctx.scale)))
	if viewport.is_empty() { return end + 1 }
	// Project only a complete, eligible group. Ordinary images keep the
	// per-command replay and avoid allocating a transformed command array.
	mapped := commands[start..end + 1].map(layout.paint_command_for_nested_viewport(it,
		placement.transform, placement.origin, placement.opacity))
	next := if is_mask {
		app.draw_portable_svg_mask_group(mapped, 0, page_x, page_y, viewport)
	} else {
		app.draw_portable_svg_opacity_group(mapped, 0, page_x, page_y, viewport)
	}
	if next == 0 { return none }
	return start + next
}
