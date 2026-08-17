module html

import dom

fn test_canvas_rendering_context_2d_settings_defaults() {
	settings := CanvasRenderingContext2DSettings.from_js_value(none)!
	assert settings.alpha
	assert !settings.desynchronized
	assert settings.color_space == .srgb
	assert settings.color_type == .unorm8
	assert !settings.will_read_frequently
}

fn test_canvas_rendering_context_2d_settings_dictionary_conversion() {
	settings := CanvasRenderingContext2DSettings.from_js_value({
		'alpha':              dom.js_bool(false)
		'desynchronized':     dom.js_string('yes')
		'colorSpace':         dom.js_string('display-p3')
		'colorType':          dom.js_string('float16')
		'willReadFrequently': dom.js_bool(true)
	})!
	assert !settings.alpha
	assert settings.desynchronized
	assert settings.color_space == .display_p3
	assert settings.color_type == .float16
	assert settings.will_read_frequently
}

fn test_canvas_rendering_context_2d_settings_rejects_invalid_enums() {
	if _ := CanvasRenderingContext2DSettings.from_js_value({
		'colorSpace': dom.js_string('rec2020')
	})
	{
		assert false
	}
}
