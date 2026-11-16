// vtest build: macos
module ggshape

fn test_containing_rectangle_clip_keeps_the_fill_antialias_fringe() {
	shape := C.VoxGraphiteShape{
		matrix: [f32(.5), 0, 0, 0, .5, 0, 0, 0, 1]!
		rect: [f32(10), 10, 20.9375, 3, 0, 0, 0, 0, 0, 0, 0, 0]!
		fill: 1
		anti_alias: 1
		force_msaa: 1
		blue: 255
		alpha: 255
	}
	mut unclipped := [u8(255), 255, 255, 255].repeat(64 * 64)
	mut clipped := unclipped.clone()
	assert draw(unclipped.data, 64, 64, 256, 1, &shape) == 1
	with_clip := C.VoxGraphiteShape{...shape, has_intersect_clip: 1,
		intersect_clip: [f32(10), 0, 70, 50]!}
	assert draw(clipped.data, 64, 64, 256, 1, &with_clip) == 1
	assert clipped == unclipped
}
