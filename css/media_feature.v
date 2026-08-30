// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the generated MediaFeatureID type and the value carrier in
// Libraries/LibWeb/CSS/MediaQuery.h. Keeping the value kind explicit mirrors
// the upstream Variant while remaining convenient to inspect from V tests.
module css

pub enum MediaFeatureID {
	any_hover
	any_pointer
	aspect_ratio
	color
	color_gamut
	color_index
	device_aspect_ratio
	device_height
	device_width
	display_mode
	dynamic_range
	environment_blending
	forced_colors
	grid
	height
	horizontal_viewport_segments
	hover
	inverted_colors
	monochrome
	nav_controls
	orientation
	overflow_block
	overflow_inline
	pointer
	prefers_color_scheme
	prefers_contrast
	prefers_reduced_data
	prefers_reduced_motion
	prefers_reduced_transparency
	resolution
	scan
	scripting
	update
	vertical_viewport_segments
	video_color_gamut
	video_dynamic_range
	width
}

pub enum MediaFeatureValueKind {
	ident
	integer
	length
	ratio
	resolution
}

pub struct MediaFeatureValue {
pub:
	kind       MediaFeatureValueKind
	ident      string
	integer    i64
	length     Length
	ratio      Ratio
	resolution Resolution
}

pub fn MediaFeatureValue.from_ident(value string) MediaFeatureValue {
	return MediaFeatureValue{
		kind:  .ident
		ident: value
	}
}

pub fn MediaFeatureValue.from_integer(value i64) MediaFeatureValue {
	return MediaFeatureValue{
		kind:    .integer
		integer: value
	}
}

pub fn MediaFeatureValue.from_length(value Length) MediaFeatureValue {
	return MediaFeatureValue{
		kind:   .length
		length: value
	}
}

pub fn MediaFeatureValue.from_ratio(value Ratio) MediaFeatureValue {
	return MediaFeatureValue{
		kind:  .ratio
		ratio: value
	}
}

pub fn MediaFeatureValue.from_resolution(value Resolution) MediaFeatureValue {
	return MediaFeatureValue{
		kind:       .resolution
		resolution: value
	}
}
