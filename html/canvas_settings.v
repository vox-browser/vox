// Copyright (c) 2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Canvas/CanvasSettings.{h,cpp}.
module html

import dom
import math

pub enum PredefinedColorSpace {
	srgb
	display_p3
}

pub enum CanvasColorType {
	unorm8
	float16
}

pub struct CanvasRenderingContext2DSettings {
pub:
	alpha                bool = true
	desynchronized       bool
	color_space          PredefinedColorSpace = .srgb
	color_type           CanvasColorType      = .unorm8
	will_read_frequently bool
}

fn canvas_settings_to_boolean(value dom.JSValue) bool {
	return match value.kind {
		.undefined, .null_ { false }
		.boolean { value.boolean_data }
		.number { value.number_data != 0 && !math.is_nan(value.number_data) }
		.string { value.string_data.len != 0 }
		.object { true }
		.runtime_value { value.native_boolean_value() or { panic(err) } }
	}
}

// The map is the V representation of the Web IDL dictionary object. `none`
// represents a nullish JS value and therefore yields all dictionary defaults.
pub fn CanvasRenderingContext2DSettings.from_js_value(value ?map[string]dom.JSValue) !CanvasRenderingContext2DSettings {
	dictionary := value or { return CanvasRenderingContext2DSettings{} }.clone()
	mut settings := CanvasRenderingContext2DSettings{}

	if alpha := dictionary['alpha'] {
		if !alpha.is_undefined() {
			settings = CanvasRenderingContext2DSettings{
				...settings
				alpha: canvas_settings_to_boolean(alpha)
			}
		}
	}
	if desynchronized := dictionary['desynchronized'] {
		if !desynchronized.is_undefined() {
			settings = CanvasRenderingContext2DSettings{
				...settings
				desynchronized: canvas_settings_to_boolean(desynchronized)
			}
		}
	}
	if color_space := dictionary['colorSpace'] {
		if !color_space.is_undefined() {
			parsed_color_space := match color_space.to_string_value() {
				'srgb' { PredefinedColorSpace.srgb }
				'display-p3' { PredefinedColorSpace.display_p3 }
				else { return error('invalid CanvasRenderingContext2DSettings colorSpace') }
			}
			settings = CanvasRenderingContext2DSettings{
				...settings
				color_space: parsed_color_space
			}
		}
	}
	if color_type := dictionary['colorType'] {
		if !color_type.is_undefined() {
			parsed_color_type := match color_type.to_string_value() {
				'unorm8' { CanvasColorType.unorm8 }
				'float16' { CanvasColorType.float16 }
				else { return error('invalid CanvasRenderingContext2DSettings colorType') }
			}
			settings = CanvasRenderingContext2DSettings{
				...settings
				color_type: parsed_color_type
			}
		}
	}
	if will_read_frequently := dictionary['willReadFrequently'] {
		if !will_read_frequently.is_undefined() {
			settings = CanvasRenderingContext2DSettings{
				...settings
				will_read_frequently: canvas_settings_to_boolean(will_read_frequently)
			}
		}
	}
	return settings
}

// https://html.spec.whatwg.org/multipage/canvas.html#canvassettings
pub interface CanvasSettings {
	get_context_attributes() CanvasRenderingContext2DSettings
}
