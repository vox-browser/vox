module painting

import dom
import math

const force_dark_test_white = Color{255, 255, 255, 255}
const force_dark_test_black = Color{0, 0, 0, 255}

fn force_dark_test_settings(foreground i32, background i32) ForceDarkSettings {
	return ForceDarkSettings{
		foreground_brightness_threshold: foreground
		background_brightness_threshold: background
	}
}

fn test_force_dark_classifies_roles_and_threshold_edges() {
	settings := force_dark_test_settings(128, 128)
	assert force_dark_brightness(force_dark_test_white) == 255
	assert force_dark_brightness(force_dark_test_black) == 0
	assert force_dark_should_invert(force_dark_test_black, .foreground, settings)
	assert !force_dark_should_invert(force_dark_test_white, .foreground, settings)
	assert force_dark_should_invert(force_dark_test_white, .background, settings)
	assert !force_dark_should_invert(force_dark_test_black, .background, settings)
	assert force_dark_should_invert(force_dark_test_white, .selection, settings)
	assert force_dark_should_invert(force_dark_test_black, .border, settings)
	assert !force_dark_should_invert(force_dark_test_black, .none_, settings)
	assert force_dark_should_invert(force_dark_test_white, .foreground,
		force_dark_test_settings(255, 205))
	assert !force_dark_should_invert(force_dark_test_black, .foreground,
		force_dark_test_settings(0, 205))
	assert !force_dark_should_invert(force_dark_test_white, .background,
		force_dark_test_settings(150, 255))
	assert force_dark_should_invert(force_dark_test_black, .background,
		force_dark_test_settings(150, 0))
}

fn test_force_dark_oklab_inversion_preserves_expected_color_properties() {
	for color in [force_dark_test_white, force_dark_test_black, Color{200, 30, 90, 255}, Color{18, 52, 86, 255}] {
		r, g, b := f64(color.r) / 255.0, f64(color.g) / 255.0, f64(color.b) / 255.0
		lightness, a, bb := force_dark_srgb_to_oklab(r, g, b)
		roundtrip_r, roundtrip_g, roundtrip_b := force_dark_oklab_to_srgb(lightness, a, bb)
		assert math.abs(r - roundtrip_r) < 0.01
		assert math.abs(g - roundtrip_g) < 0.01
		assert math.abs(b - roundtrip_b) < 0.01
	}
	assert force_dark_invert_lightness(force_dark_test_white) == force_dark_surface
	mid_gray := force_dark_invert_lightness(Color{128, 128, 128, 255})
	assert force_dark_int_abs(int(mid_gray.r) - 128) <= 1
	near_white_brightness := force_dark_brightness(force_dark_invert_lightness(Color{238, 238, 238, 255}))
	white_brightness := force_dark_brightness(force_dark_invert_lightness(force_dark_test_white))
	assert near_white_brightness - white_brightness >= 12
	assert force_dark_brightness(force_dark_invert_lightness(force_dark_test_black)) > 200
	translucent := force_dark_invert_lightness(Color{200, 30, 90, 128})
	assert translucent.a == 128
	assert translucent.r > translucent.g && translucent.r > translucent.b
}

fn test_force_dark_resolves_background_foreground_and_transparency() {
	settings := ForceDarkSettings.default()
	dark_background := Color{32, 32, 32, 255}
	light_text := Color{238, 238, 238, 255}
	assert force_dark_resolve(dark_background, .background, settings) == dark_background
	assert force_dark_resolve(light_text, .foreground, settings) == light_text
	assert force_dark_resolve(force_dark_test_white, .background, settings) == force_dark_surface
	assert force_dark_brightness(force_dark_resolve(force_dark_test_black, .foreground,
		settings)) > 200
	transparent_color := Color{255, 255, 255, 0}
	assert force_dark_resolve(transparent_color, .background, settings) == transparent_color
	assert force_dark_resolve(force_dark_test_white, .none_, settings) == force_dark_test_white
}

fn test_force_dark_contrast_and_backdrop_adjustment() {
	dark_backdrop := Color{20, 20, 20, 255}
	text := Color{40, 40, 40, 255}
	assert force_dark_contrast_ratio(text, dark_backdrop) < 4.5
	adjusted := force_dark_adjust_for_contrast(text, dark_backdrop, 4.5)
	assert force_dark_contrast_ratio(adjusted, dark_backdrop) >= 4.5
	quiet_border := Color{200, 200, 200, 100}
	assert force_dark_adjust_border_against_backdrop(quiet_border, force_dark_surface) == quiet_border
	pale_border := Color{221, 221, 221, 255}
	resolved_border := force_dark_resolve(pale_border, .border, ForceDarkSettings.default())
	assert resolved_border != pale_border
	assert force_dark_contrast_ratio(resolved_border, force_dark_surface) < 4.5
	selection := force_dark_resolve_against_backdrop(Color{102, 102, 102, 255}, .selection,
		Color{128, 128, 128, 255}, ForceDarkSettings.default())
	assert force_dark_contrast_ratio(selection, Color{128, 128, 128, 255}) >= 3.0
}

fn test_force_dark_gradients_and_resolver_cache_match_pure_resolution() {
	settings := force_dark_test_settings(255, 0)
	colors := [force_dark_test_white, Color{128, 128, 128, 255}, force_dark_test_black]
	resolved := force_dark_resolve_each(colors, .background, settings)
	assert resolved.len == colors.len
	assert force_dark_brightness(resolved[0]) < force_dark_brightness(resolved[2])
	mut resolver := ForceDarkResolver.create(settings)
	for role in [ForceDarkRole.none_, .foreground, .background, .border, .selection] {
		for color in colors {
			expected := force_dark_resolve(color, role, settings)
			assert resolver.resolve(color, role) == expected
			assert resolver.resolve(color, role) == expected
		}
	}
}

fn force_dark_solid_samples(count int, color Color) []Color {
	return []Color{len: count, init: color}
}

fn test_force_dark_image_size_and_feature_classification() {
	assert force_dark_image_size_allows_classification(64, 64, IntSize{64, 64})
	assert force_dark_image_size_allows_classification(300, 300, IntSize{8, 200})
	assert !force_dark_image_size_allows_classification(800, 600, IntSize{1024, 768})
	assert force_dark_role_for_image(.background, 128, 128, 2, IntSize{256, 256}) == .background
	assert force_dark_role_for_image(.background, 800, 600, 1, IntSize{1024, 768}) == .none_

	gray_icon := force_dark_features_from_samples(force_dark_solid_samples(200,
		Color{100, 100, 100, 255}), 0)
	assert !gray_icon.is_colorful
	assert force_dark_should_filter_image(gray_icon)
	vivid_logo := force_dark_features_from_samples(force_dark_solid_samples(200,
		Color{208, 16, 16, 255}), 0)
	assert vivid_logo.saturated_pixel_ratio > 0.3
	assert !force_dark_should_filter_image(vivid_logo)
	transparent_light := force_dark_features_from_samples(force_dark_solid_samples(200,
		Color{240, 240, 240, 255}), 0.5)
	assert !force_dark_should_filter_image(transparent_light)
	assert !force_dark_should_filter_image(force_dark_features_from_samples([]Color{}, 0))
}

fn test_force_dark_decoded_bitmap_classification_and_filtering() {
	mut data := []u8{len: 8 * 8 * 4}
	for pixel := 0; pixel < 8 * 8; pixel++ {
		offset := pixel * 4
		data[offset] = 255
		data[offset + 1] = 255
		data[offset + 2] = 255
		data[offset + 3] = 255
	}
	bitmap := &dom.Bitmap_{
		width: 8
		height: 8
		pitch: 32
		data: data
		native_rows_are_top_down: true
	}
	assert force_dark_should_filter_bitmap(bitmap)
	filtered := force_dark_filter_bitmap(bitmap)
	assert filtered != bitmap
	assert filtered.data[0..4] == [u8(18), 18, 18, 255]
	assert bitmap.data[0..4] == [u8(255), 255, 255, 255]
	assert filtered.native_rows_are_top_down

	mut transparent_data := data.clone()
	for pixel := 0; pixel < 40; pixel++ {
		transparent_data[pixel * 4 + 3] = 0
	}
	transparent_bitmap := &dom.Bitmap_{ width: 8, height: 8, pitch: 32, data: transparent_data }
	assert !force_dark_should_filter_bitmap(transparent_bitmap)
}
