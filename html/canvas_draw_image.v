// Copyright (c) 2022, Sam Atkins <atkinssj@serenityos.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Canvas/CanvasDrawImage.{h,cpp}. Concrete canvas contexts
// provide the painter-side draw_image_internal operation as a callback.
module html

pub struct CanvasDrawImageRequest {
pub:
	image              CanvasImageSource
	source_x           f64
	source_y           f64
	source_width       f64
	source_height      f64
	destination_x      f64
	destination_y      f64
	destination_width  f64
	destination_height f64
}

pub type CanvasDrawImageInternal = fn (CanvasDrawImageRequest) !

@[heap]
pub struct CanvasDrawImage {
mut:
	draw_image_internal_ CanvasDrawImageInternal @[required]
}

pub fn CanvasDrawImage.create(draw_image_internal CanvasDrawImageInternal) &CanvasDrawImage {
	return &CanvasDrawImage{
		draw_image_internal_: draw_image_internal
	}
}

pub fn (draw &CanvasDrawImage) draw_image(image CanvasImageSource, destination_x f64, destination_y f64) ! {
	dimensions := canvas_image_source_dimensions(image)
	draw.draw_image_internal_(CanvasDrawImageRequest{
		image:              image
		source_width:       dimensions.width
		source_height:      dimensions.height
		destination_x:      destination_x
		destination_y:      destination_y
		destination_width:  dimensions.width
		destination_height: dimensions.height
	})!
}

pub fn (draw &CanvasDrawImage) draw_image_scaled(image CanvasImageSource, destination_x f64, destination_y f64, destination_width f64, destination_height f64) ! {
	dimensions := canvas_image_source_dimensions(image)
	draw.draw_image_internal_(CanvasDrawImageRequest{
		image:              image
		source_width:       dimensions.width
		source_height:      dimensions.height
		destination_x:      destination_x
		destination_y:      destination_y
		destination_width:  destination_width
		destination_height: destination_height
	})!
}

pub fn (draw &CanvasDrawImage) draw_image_rect(image CanvasImageSource, source_x f64, source_y f64, source_width f64, source_height f64, destination_x f64, destination_y f64, destination_width f64, destination_height f64) ! {
	draw.draw_image_internal_(CanvasDrawImageRequest{
		image:              image
		source_x:           source_x
		source_y:           source_y
		source_width:       source_width
		source_height:      source_height
		destination_x:      destination_x
		destination_y:      destination_y
		destination_width:  destination_width
		destination_height: destination_height
	})!
}
