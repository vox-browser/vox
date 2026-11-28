// Copyright (c) 2023, MacDue <macdue@dueutil.tech>
// Copyright (c) 2025, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CanvasPattern.{h,cpp} and the CanvasImageSource bitmap helpers
// used by CanvasDrawImage.
module html

import dom
import geometry
import math

pub struct ImageBitmapCanvasSource {
pub:
	value &ImageBitmap = unsafe { nil }
	// Canvas hosts snapshot their pixels into ImageBitmap storage. Carry the
	// source canvas's security state alongside that snapshot.
	origin_clean bool = true
}

pub struct DecodedImageCanvasSource {
pub:
	value       DecodedImageData
	frame_index uint
}

pub type CanvasImageSource = DecodedImageCanvasSource | ImageBitmapCanvasSource

pub enum CanvasImageSourceUsability {
	bad
	good
}

pub fn check_usability_of_image(image CanvasImageSource) CanvasImageSourceUsability {
	return match image {
		ImageBitmapCanvasSource {
			source := image as ImageBitmapCanvasSource
			if source.value == unsafe { nil } || source.value.is_detached()
				|| source.value.bitmap() == none {
				CanvasImageSourceUsability.bad
			} else {
				CanvasImageSourceUsability.good
			}
		}
		DecodedImageCanvasSource {
			source := image as DecodedImageCanvasSource
			if source.value.frame(source.frame_index) == none {
				CanvasImageSourceUsability.bad
			} else {
				CanvasImageSourceUsability.good
			}
		}
	}
}

pub fn canvas_image_source_frame(image CanvasImageSource) ?&dom.DecodedImageFrame_ {
	return match image {
		ImageBitmapCanvasSource {
			bitmap := (image as ImageBitmapCanvasSource).value.bitmap() or { return none }
			dom.DecodedImageFrame_.create(bitmap)
		}
		DecodedImageCanvasSource {
			source := image as DecodedImageCanvasSource
			source.value.frame(source.frame_index)
		}
	}
}

pub fn canvas_image_source_bitmap(image CanvasImageSource) ?&dom.Bitmap_ {
	frame := canvas_image_source_frame(image) or { return none }
	return frame.bitmap()
}

pub struct CanvasImageSourceDimensions {
pub:
	width  int
	height int
}

pub fn canvas_image_source_dimensions(image CanvasImageSource) CanvasImageSourceDimensions {
	frame := canvas_image_source_frame(image) or { return CanvasImageSourceDimensions{} }
	return CanvasImageSourceDimensions{
		width:  frame.width()
		height: frame.height()
	}
}

pub enum CanvasPatternRepetition {
	repeat
	repeat_x
	repeat_y
	no_repeat
}

@[heap]
pub struct CanvasPattern {
mut:
	frame_      &dom.DecodedImageFrame_
	repetition_ CanvasPatternRepetition
	transform_  CanvasAffineTransform
}

pub struct CanvasPatternCreateResult {
pub:
	pattern ?&CanvasPattern
}

pub fn CanvasPattern.create(image CanvasImageSource, repetition_input string) !CanvasPatternCreateResult {
	if check_usability_of_image(image) == .bad {
		return CanvasPatternCreateResult{}
	}
	repetition := match repetition_input {
		'', 'repeat' { CanvasPatternRepetition.repeat }
		'repeat-x' { CanvasPatternRepetition.repeat_x }
		'repeat-y' { CanvasPatternRepetition.repeat_y }
		'no-repeat' { CanvasPatternRepetition.no_repeat }
		else { return error('SyntaxError: repetition value is not valid') }
	}
	frame := canvas_image_source_frame(image) or { return CanvasPatternCreateResult{} }
	return CanvasPatternCreateResult{
		pattern: &CanvasPattern{
			frame_:      frame
			repetition_: repetition
			transform_:  CanvasAffineTransform{}
		}
	}
}

pub fn (pattern &CanvasPattern) bitmap() &dom.Bitmap_ {
	return pattern.frame_.bitmap()
}

pub fn (pattern &CanvasPattern) frame() &dom.DecodedImageFrame_ {
	return pattern.frame_
}

pub fn (pattern &CanvasPattern) repetition() CanvasPatternRepetition {
	return pattern.repetition_
}

pub fn (pattern &CanvasPattern) transform() CanvasAffineTransform {
	return pattern.transform_
}

pub fn (pattern &CanvasPattern) to_gfx_paint_style() CanvasGfxPaintStyle {
	return CanvasGfxPaintStyle{
		kind:    .pattern
		pattern: pattern
	}
}

pub fn (mut pattern CanvasPattern) set_transform(mut transform geometry.DOMMatrix2DInit) ! {
	matrix := geometry.DOMMatrixReadOnly.create_from_dom_matrix_2d_init(mut transform)!
	values := [matrix.a(), matrix.b(), matrix.c(), matrix.d(),
		matrix.e(), matrix.f()]
	for value in values {
		if math.is_nan(value) || math.is_inf(value, 0) {
			return
		}
	}
	pattern.transform_ = CanvasAffineTransform{
		a: matrix.a()
		b: matrix.b()
		c: matrix.c()
		d: matrix.d()
		e: matrix.e()
		f: matrix.f()
	}
}
