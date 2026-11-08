module main

import adblock
import layout
import os

const disable_github_raster_input_reuse = os.getenv('VOX_DISABLE_GITHUB_RASTER_INPUT_REUSE') != ''
const github_raster_input_diagnostics = os.getenv('VOX_GITHUB_RASTER_INPUT_DIAGNOSTICS') != ''

// A new display-list generation need not change the rendered inputs. Retain
// the ordinary cache's owner, viewport, transform and independent-media guards;
// identify supported static recordings by their paint values and resource bytes.
fn (app &BrowserApp) site_stationary_raster_inputs() ?[2]u64 {
	if disable_github_raster_input_reuse || app.document == unsafe { nil }
		|| !site_batches_image_completion_layout(app.document.url.serialize()) { return none }
	key := app.github_static_raster_inputs()?
	if github_raster_input_diagnostics {
		eprintln('Vox site raster inputs: key=${key[0]},${key[1]} generation=${app.paint_generation}')
	}
	return key
}

fn (app &BrowserApp) github_static_raster_inputs() ?[2]u64 {
	mut content := srk_int(u64(0xcbf29ce484222325), app.paint_commands.len)
	mut resources := srk_bool(u64(0x9e3779b97f4a7c15), adblock.is_enabled())
	for index in 0 .. app.paint_commands.len {
		command := &app.paint_commands[index]
		if command.kind !in ['fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect',
			'fill_ellipse', 'stroke_ellipse', 'fill_polygon', 'draw_line', 'draw_text',
			'draw_svg_path', 'fill_gradient', 'draw_border', 'draw_image', 'draw_replaced_image', 'draw_background_image',
			'paint_uniform_border', 'paint_rounded_border_top', 'paint_rounded_border_right',
			'paint_rounded_border_bottom', 'paint_rounded_border_left', 'paint_partial_rounded_border',
			'paint_inner_box_shadow', 'paint_outer_box_shadow', 'draw_text_shadow', 'fill_inset_shadow',
			'begin_css_effect_layer', 'end_css_effect_layer', 'begin_css_filter_layer',
			'end_css_filter_layer', 'apply_backdrop_filter'] {
			if github_raster_input_diagnostics { eprintln('Vox site raster inputs: unsupported=${command.kind}') }
			return none
		}
		if !stationary_document_raster_command_eligible(command, 0)
			|| command.nested_viewport_commands.len > 0 || command.mask_clip_data != none {
			return none
		}
		if image := command.image_paintable {
			if image.is_svg_image { return none }
		}
		if command.image_data != unsafe { nil } {
			image := command.image_data
			if image.background_svg_document != none || image.background_static_svg_resource != none {
				return none
			}
		}
		if layer := command.visual_layer_data {
			if layer.kind == .svg_mask { return none }
			if filter := layer.filter { if filter.nodes.len > 0 { return none } }
		}
		if command.clip_list != unsafe { nil } {
			for clip in command.clip_list.items {
				if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask { return none }
			}
		}
		content = srk_mix(content, scroll_raster_command_hash(command, 0))
		if command.svg_data != unsafe { nil } {
			path := command.svg_data
			if path.svg_gradient_data != none || path.fill_pattern != none || path.stroke_pattern != none {
				return none
			}
			for value in path.path_data { content = srk_f64(content, value) }
			for polygon in path.path_polygons {
				content = srk_int(content, polygon.len)
				for value in polygon { content = srk_f64(content, value) }
			}
		}
		if filter := command.backdrop_filter_data {
			if filter.nodes.len > 0 { return none }
			for operation in filter.operations {
				content = srk_str(content, operation.kind)
				content = srk_f64(content, operation.first)
				content = srk_f64(content, operation.second)
				content = srk_f64(content, operation.third)
				content = srk_int(content, int(operation.color_operation))
				for channel in [operation.color.r, operation.color.g, operation.color.b, operation.color.a]! {
					content = srk_int(content, int(channel))
				}
			}
		}
		if bitmap := command.replaced_image_bitmap {
			resources = srk_int(resources, bitmap.width)
			resources = srk_int(resources, bitmap.height)
			resources = srk_int(resources, bitmap.pitch)
			resources = srk_int(resources, int(bitmap.format))
			resources = srk_int(resources, int(bitmap.alpha_type))
			resources = srk_bool(resources, bitmap.native_rows_are_top_down)
			resources = srk_str(resources, unsafe { tos(bitmap.data.data, bitmap.data.len) })
		}
		address := command.image_url()
		if address != '' {
			// Unknown transports and unresolved images keep the revision-based
			// key. A completed response or a newly decoded native image changes
			// this key even when its URL and dimensions stay the same.
			if !address.starts_with('https://') && !address.starts_with('http://') { return none }
			response := app.resource_cache[address] or { return none }
			resources = srk_str(resources, address)
			resources = srk_str(resources, response.body)
			resources = srk_str(resources, response.error)
			resources = srk_int(resources, app.background_image_scope_ids[address] or { -1 })
		}
	}
	return [resources, content]!
}
