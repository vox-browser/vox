// vtest build: macos
module ggshape

import stbi

fn test_tall_rounded_shadow_keeps_the_tile_local_filter_input_grid() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/tall-rounded-shadow-mask.png').to_bytes()
	expected := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { expected.free() }
	// Brave's first affected 256px raster tile starts at document y=254.
	// The source continues far below it; its input ends at tile height+3sigma.
	shape := C.VoxGraphiteShape{
		matrix:          [f32(1), 0, 0, 0, 1, -254, 0, 0, 1]!
		rect:            [f32(32), 474, 960, 3069, 13, 13, 13, 13, 0, 0, 0, 0]!
		underlay_rect:   [f32(33), 451, 958, 3067, 12, 12, 12, 12, 0, 0, 0, 0]!
		fill:            10
		thickness:       60
		anti_alias:      1
		force_msaa:      1
		has_float_color: 1
		float_color:     [f32(0), 0, 0, 1]!
	}
	mut pixels := []u8{len: 1024 * 256 * 4, init: 255}
	assert draw(pixels.data, 1024, 256, 4096, 1, &shape) == 1
	// This band is outside the foreground and its rounded clip. The complete
	// colored-control/foreground composition has its own browser fixture.
	mut differing := 0
	for y in 0 .. 196 {
		for x in 0 .. 1024 {
			for c in 0 .. 4 {
				channel := if c == 0 {
					2
				} else if c == 2 {
					0
				} else {
					c
				}
				if pixels[(y * 1024 + x) * 4 + channel] != unsafe { expected.data[((y + 254) * 1024 + x) * 4 + c] } {
					differing++
				}
			}
		}
	}
	assert differing == 0, 'shadow band differs in ${differing} channels'
}
