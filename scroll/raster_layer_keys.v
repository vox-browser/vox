module main

import math
import os

// Same-binary control: retained-raster keys ignore the command's raster layer.
const retain_layer_blind_raster_keys = os.getenv('VOX_RETAIN_LAYER_BLIND_RASTER_KEYS') != ''

// A command rasterizes under its Chromium raster layer: the layer's origin
// and phase, its legacy or composited mode, its raster parent and image decode
// scope (chromium/msaa_tiles.v select_chromium_raster_layer). The same command
// moved to another layer rasterizes its edges and glyphs differently, but its
// key did not change. On the archived github.com/vlang/v page the sponsor
// heart's pulse animation gave it a layer of its own and moved the branch
// button that follows it into another; after the animation the retained
// pixels kept the button as rasterized under that layer. Mix each command's
// layer signature into its key, so moving between differing layers damages
// it.
fn (app &BrowserApp) mix_raster_layer_keys(mut keys []ScrollRasterCommandKey) {
	if retain_layer_blind_raster_keys { return }
	plan := &app.chromium_raster_plan
	if plan.command_layers.len != keys.len || plan.layers.len == 0 { return }
	mut signatures := map[int]u64{}
	for index in 0 .. keys.len {
		if keys[index].skip_diff { continue }
		layer := plan.command_layers[index]
		signature := signatures[layer] or {
			computed := app.chromium_raster_layer_signature(layer)
			signatures[layer] = computed
			computed
		}
		keys[index].hash = srk_mix(keys[index].hash, signature)
	}
}

fn (app &BrowserApp) chromium_raster_layer_signature(index int) u64 {
	plan := &app.chromium_raster_plan
	if index < 0 || index >= plan.layers.len { return u64(0x5c0b) }
	raster_index := if index < app.chromium_msaa_storage.raster_parents.len {
		app.chromium_msaa_storage.raster_parents[index]
	} else {
		index
	}
	original := &plan.layers[index]
	layer := if raster_index >= 0 && raster_index < plan.layers.len {
		&plan.layers[raster_index]
	} else {
		original
	}
	root := raster_index == 0 || layer.legacy_raster
	mut h := srk_bool(u64(0x9e3779b97f4a7c15), root)
	h = srk_bool(h, index == 0 || original.legacy_raster)
	h = srk_bool(h, raster_index != index)
	if root { return h }
	h = srk_bool(h, layer.composited_contents)
	h = srk_bool(h, layer.scroll_contents)
	h = srk_bool(h, layer.picture_local_rounded_clip)
	h = srk_bool(h, layer.over_opaque_scroll_background)
	origin := layer.compositor_origin or { [layer.bounds.x, layer.bounds.y]! }
	h = srk_f64(h, origin[0])
	h = srk_f64(h, origin[1])
	h = srk_f64(h, math.floor(layer.bounds.x * plan.device_scale))
	h = srk_f64(h, math.floor(layer.bounds.y * plan.device_scale))
	h = srk_f64(h, layer.bounds.width)
	h = srk_f64(h, layer.bounds.height)
	if size := layer.compositor_size {
		h = srk_f64(srk_f64(h, size[0]), size[1])
	}
	h = srk_bool(h, original.has_fixed_opacity_paint_origin)
	h = srk_f64(h, original.fixed_opacity_paint_origin_x)
	h = srk_f64(h, original.fixed_opacity_paint_origin_y)
	return h
}
