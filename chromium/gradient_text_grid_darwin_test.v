// vtest build: macos
module main

import math
import stbi

fn test_gradient_text_grid_preserves_other_layers_and_rejects_invalid_bounds() {
	assert gradient_text_raster_grid(none) == none
	for bounds in [[f32(0),0,-1,20,1]!, [f32(0),0,0,20,1]!,
		[f32(0),0,4095,20,1]!, [f32(0),0,4094,4094,1]!,
		[f32(math.nan()),0,20,20,1]!, [f32(0),f32(math.inf(1)),20,20,1]!, [f32(48),56,1320,180,2]!] {
		assert gradient_text_raster_grid(bounds) == none
	}
	grid := gradient_text_raster_grid([f32(24),28,660,90,1]!) or { panic('valid bounds') }
	assert grid.width == 662 && grid.height == 92 && grid.columns == 1 && grid.rows == 1
	assert grid.origin_x == 24 && grid.origin_y == 28 && grid.cells.len == 0
}

fn test_gradient_text_layer_origin_matches_unchanged_brave_pixels() {
	mask_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/gradient-text-linear-mask.png').to_bytes()
	mask := stbi.load_from_memory(mask_bytes.data, mask_bytes.len, desired_channels: 4)!
	defer { mask.free() }
	ref := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/background-clip-text-retained-gradient.png').to_bytes()
	expected := stbi.load_from_memory(ref.data, ref.len, desired_channels: 4)!
	defer { expected.free() }
	segments := [f32(0),24,28,0,0,0,0,0,0,0,0,0,
		1,684,28,0,0,0,0,0,0,0,0,0, 1,684,118,0,0,0,0,0,0,0,0,0,
		1,24,118,0,0,0,0,0,0,0,0,0, 5,0,0,0,0,0,0,0,0,0,0,0]
	stops := [f32(121)/255,168/f32(255),243/f32(255),f32(1),0,
		201/f32(255),221/f32(255),f32(1),1,1]
	path := C.VoxGraphitePath{
		matrix: [f32(1),0,-22,0,1,-26,0,0,1]!
		segments: segments.data
		segment_count: 5
		gradient: 1
		gradient_points: [f32(24),28,684,28,0,0]!
		gradient_matrix: [f32(1),0,0,0,1,0,0,0,1]!
		stops: stops.data
		stop_count: 2
		opacity: 1
		gradient_premul: 1
		alpha: 255
	}
	fallback := DocumentGeometryGrid{width: 1026,height: 258,columns: 1,rows: 3}
	for padding in [2, 4] {
	for text_layer in [false, true] {
		grid := if text_layer { gradient_text_raster_grid([f32(24),28,660,90,1]!) or { panic('valid bounds') } } else { fallback }
		width, height := 660+padding*2, 90+padding*2
		mut padded_path := path
		padded_path.matrix[2] = f32(padding-24)
		padded_path.matrix[5] = f32(padding-28)
		mut pixels := []u8{len: width*height*4}
		assert draw_document_gradient_tiles(pixels.data,i32(width),i32(height),i32(width*4),0,
			24-padding,28-padding,&padded_path,grid,text_layer) == 1
		mut different := 0
		for y in 0 .. 90 {
			for x in 0 .. 660 {
				a := unsafe { int(mask.data[(y*660+x)*4+3]) }
				mut changed := false
				for c in 0 .. 3 {
					bg := [9,11,15][c]
					color := int(pixels[((y+padding)*width+x+padding)*4+2-c])
					value := (color*a+127)/255+(bg*(255-a)+127)/255
					if value != unsafe { expected.data[((y+28)*expected.width+x+24)*4+c] } { changed=true }
				}
				if changed { different++ }
			}
		}
		if text_layer { assert different == 0 } else { assert different == 597 }
	}
	}
}

fn test_gradient_text_padding_outside_the_mask_does_not_mutate_pixels() {
	grid := gradient_text_raster_grid([f32(24),28,660,90,1]!) or { panic('valid bounds') }
	mut pixels := []u8{len: 16*16*4, init: 37}
	before := pixels.clone()
	path := C.VoxGraphitePath{}
	assert draw_document_gradient_tiles(pixels.data,16,16,64,0,1000,1000,&path,grid,true) == 1
	assert pixels == before
}
