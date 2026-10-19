module main

import math

fn C.native_set_chromium_msaa_grid(&i32, int, int, int, int)

struct ChromiumRasterGrid {
	tile_width  int
	tile_height int
	columns     int
	cells       []int
	// cells for the native renderer, which reads C ints: V's int is 64-bit
	// under current V.
	native_cells []i32
}

// cc/layers/tile_size_calculator.cc. The raster scale and the device viewport
// are separate inputs: content larger than that viewport uses half-width tiles.
fn chromium_raster_tile_size(viewport_width int, viewport_height int,
	content_width int, content_height int, scale f64) (int, int) {
	mut base_width := int(math.ceil(math.ceil(f64(viewport_width) / scale) * scale))
	base_height := int(math.ceil(math.ceil(f64(viewport_height) / scale) * scale))
	mut tile_width := 0
	mut tile_height := 0
	for pass in 0 .. 2 {
		divisor := if content_width <= base_width / 4 {
			1
		} else if content_width <= base_width / 2 {
			2
		} else {
			4
		}
		tile_width = (base_width + 2 + 31) / 32 * 32
		tile_height = math.max(((base_height + divisor - 1) / divisor + 2 + 31) / 32 * 32, 256)
		if pass == 0 && content_width > tile_width {
			base_width = (base_width + 1) / 2
			continue
		}
		break
	}
	if content_width < tile_width {
		tile_width = math.min((content_width + 63) / 64 * 64, tile_width)
	}
	if content_height < tile_height {
		tile_height = math.min((content_height + 63) / 64 * 64, tile_height)
	}
	return math.max(4, (tile_width + 3) / 4 * 4), math.max(4, (tile_height + 3) / 4 * 4)
}

fn chromium_raster_grid(triggers []ChromiumMSAATrigger, viewport_width int,
	viewport_height int, content_width f64, content_height f64, origin_x f64,
	origin_y f64, scale f64) ChromiumRasterGrid {
	width := math.max(1, int(math.ceil(content_width * scale)))
	height := math.max(1, int(math.ceil(content_height * scale)))
	tile_width, tile_height := chromium_raster_tile_size(viewport_width, viewport_height,
		width, height, scale)
	step_x := tile_width - 2
	step_y := tile_height - 2
	columns := math.max(1, (width - 2 + step_x - 1) / step_x)
	rows := math.max(1, (height - 2 + step_y - 1) / step_y)
	mut cells := map[int]bool{}
	for trigger in triggers {
		left := (trigger.left - origin_x) * scale
		right := (trigger.right - origin_x) * scale
		top := (trigger.top - origin_y) * scale
		bottom := (trigger.bottom - origin_y) * scale
		if !(right > left && bottom > top) || math.is_inf(left, 0) || math.is_inf(right, 0)
			|| math.is_inf(top, 0) || math.is_inf(bottom, 0) {
			continue
		}
		first_x := math.max(0, int(math.ceil((left - tile_width) / step_x)))
		last_x := math.min(columns - 1, int(math.floor(math.max(right - 1, 0) / step_x)))
		first_y := math.max(0, int(math.ceil((top - tile_height) / step_y)))
		last_y := math.min(rows - 1, int(math.floor(math.max(bottom - 1, 0) / step_y)))
		for y := first_y; y <= last_y; y++ {
			for x := first_x; x <= last_x; x++ { cells[y * columns + x] = true }
		}
	}
	mut active := cells.keys()
	active.sort()
	return ChromiumRasterGrid{
		tile_width:   tile_width
		tile_height:  tile_height
		columns:      columns
		cells:        active
		native_cells: active.map(i32(it))
	}
}
