// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Rust/src/painting/force_dark.rs. Force-dark is a paint-time
// color filter: roles decide whether a color is eligible and Oklab inversion
// changes lightness without rotating hue.
module painting

import dom
import math

pub struct ForceDarkSettings {
pub:
	foreground_brightness_threshold i32 = 150
	background_brightness_threshold i32 = 205
}

pub fn ForceDarkSettings.default() ForceDarkSettings {
	return ForceDarkSettings{}
}

pub enum ForceDarkRole {
	none_
	foreground
	list_symbol
	background
	svg
	border
	selection
}

fn (role ForceDarkRole) classifies_as_background() bool {
	return role in [.background, .selection]
}

pub fn force_dark_brightness(color Color) i32 {
	weighted := i32(color.r) * 299 + i32(color.g) * 587 + i32(color.b) * 114
	return weighted / 1000
}

pub fn force_dark_should_invert(color Color, role ForceDarkRole, settings ForceDarkSettings) bool {
	if role == .none_ {
		return false
	}
	if role.classifies_as_background() {
		threshold := settings.background_brightness_threshold
		if threshold >= 255 {
			return false
		}
		if threshold <= 0 {
			return true
		}
		return force_dark_brightness(color) > threshold
	}
	threshold := settings.foreground_brightness_threshold
	if threshold >= 255 {
		return true
	}
	if threshold <= 0 {
		return false
	}
	return force_dark_brightness(color) < threshold
}

const force_dark_gray_brightness_threshold = 32.0 / 255.0
const force_dark_gray_adjusted_brightness = 18.0 / 255.0
const force_dark_lightness_lift = 1.20
const force_dark_minimum_visible_contrast_ratio = 3.0
const force_dark_minimum_readable_contrast_ratio = 4.5
const force_dark_inverted_color_cache_capacity = 1024

pub const force_dark_surface = Color{18, 18, 18, 255}

fn force_dark_srgb_channel_to_linear(channel f64) f64 {
	if channel <= 0.04045 {
		return channel / 12.92
	}
	return math.pow((channel + 0.055) / 1.055, 2.4)
}

fn force_dark_linear_channel_to_srgb(channel f64) f64 {
	if channel <= 0.0031308 {
		return channel * 12.92
	}
	return 1.055 * math.pow(channel, 1.0 / 2.4) - 0.055
}

pub fn force_dark_srgb_to_oklab(red f64, green f64, blue f64) (f64, f64, f64) {
	r := force_dark_srgb_channel_to_linear(red)
	g := force_dark_srgb_channel_to_linear(green)
	b := force_dark_srgb_channel_to_linear(blue)
	l := math.cbrt(0.41222146 * r + 0.53633255 * g + 0.051445995 * b)
	m := math.cbrt(0.2119035 * r + 0.6806995 * g + 0.10739696 * b)
	s := math.cbrt(0.08830246 * r + 0.28171885 * g + 0.6299787 * b)
	return 0.21045426 * l + 0.7936178 * m - 0.004072047 * s,
		1.9779985 * l - 2.4285922 * m + 0.4505937 * s,
		0.025904037 * l + 0.78277177 * m - 0.80867577 * s
}

fn force_dark_clamp_unit(value f64) f64 {
	return math.max(0.0, math.min(1.0, value))
}

pub fn force_dark_oklab_to_srgb(lightness f64, a f64, b f64) (f64, f64, f64) {
	l := lightness + 0.39633778 * a + 0.21580376 * b
	m := lightness - 0.105561346 * a - 0.06385417 * b
	s := lightness - 0.08948418 * a - 1.2914855 * b
	l_cubed := l * l * l
	m_cubed := m * m * m
	s_cubed := s * s * s
	r := 4.0767417 * l_cubed - 3.3077116 * m_cubed + 0.23096994 * s_cubed
	g := -1.268438 * l_cubed + 2.6097574 * m_cubed - 0.34131938 * s_cubed
	bl := -0.0041960863 * l_cubed - 0.7034186 * m_cubed + 1.7076147 * s_cubed
	return force_dark_clamp_unit(force_dark_linear_channel_to_srgb(r)),
		force_dark_clamp_unit(force_dark_linear_channel_to_srgb(g)),
		force_dark_clamp_unit(force_dark_linear_channel_to_srgb(bl))
}

pub fn force_dark_adjust_gray(color Color) Color {
	r := f64(color.r) / 255.0
	g := f64(color.g) / 255.0
	b := f64(color.b) / 255.0
	epsilon := 1.0 / 255.0
	is_gray := math.abs(r - g) <= epsilon && math.abs(r - b) <= epsilon
	if is_gray && r < force_dark_gray_brightness_threshold
		&& r > force_dark_gray_adjusted_brightness {
		level := u8(math.round(force_dark_gray_adjusted_brightness * 255.0))
		return Color{level, level, level, color.a}
	}
	return color
}

fn force_dark_with_lightness(color Color, lightness f64) Color {
	_, a, b := force_dark_srgb_to_oklab(f64(color.r) / 255.0, f64(color.g) / 255.0,
		f64(color.b) / 255.0)
	r, g, blue := force_dark_oklab_to_srgb(lightness, a, b)
	return Color{
		r: u8(math.round(r * 255.0))
		g: u8(math.round(g * 255.0))
		b: u8(math.round(blue * 255.0))
		a: color.a
	}
}

pub fn force_dark_invert_lightness(color Color) Color {
	lightness, _, _ := force_dark_srgb_to_oklab(f64(color.r) / 255.0,
		f64(color.g) / 255.0, f64(color.b) / 255.0)
	return force_dark_adjust_gray(force_dark_with_lightness(color,
		math.min(force_dark_lightness_lift - lightness, 1.0)))
}

fn force_dark_blend(backdrop Color, source Color) Color {
	if backdrop.a == 0 || source.a == 255 {
		return source
	}
	if source.a == 0 {
		return backdrop
	}
	d := 255 * (int(backdrop.a) + int(source.a)) - int(backdrop.a) * int(source.a)
	return Color{
		r: u8((int(backdrop.r) * int(backdrop.a) * (255 - int(source.a)) + int(source.r) * 255 * int(source.a)) / d)
		g: u8((int(backdrop.g) * int(backdrop.a) * (255 - int(source.a)) + int(source.g) * 255 * int(source.a)) / d)
		b: u8((int(backdrop.b) * int(backdrop.a) * (255 - int(source.a)) + int(source.b) * 255 * int(source.a)) / d)
		a: u8(d / 255)
	}
}

fn force_dark_relative_luminance(color Color) f64 {
	r := force_dark_srgb_channel_to_linear(f64(color.r) / 255.0)
	g := force_dark_srgb_channel_to_linear(f64(color.g) / 255.0)
	b := force_dark_srgb_channel_to_linear(f64(color.b) / 255.0)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

pub fn force_dark_contrast_ratio(first Color, second Color) f64 {
	first_luminance := force_dark_relative_luminance(first)
	second_luminance := force_dark_relative_luminance(second)
	darkest := math.min(first_luminance, second_luminance)
	brightest := math.max(first_luminance, second_luminance)
	return (brightest + 0.05) / (darkest + 0.05)
}

fn force_dark_clears_contrast(color Color, backdrop Color, target_ratio f64) bool {
	return force_dark_contrast_ratio(force_dark_blend(backdrop, color), backdrop) >= target_ratio
}

pub fn force_dark_adjust_for_contrast(color Color, backdrop Color, target_ratio f64) Color {
	if force_dark_clears_contrast(color, backdrop, target_ratio) {
		return color
	}
	start_lightness, _, _ := force_dark_srgb_to_oklab(f64(color.r) / 255.0,
		f64(color.g) / 255.0, f64(color.b) / 255.0)
	white := force_dark_with_lightness(color, 1.0)
	black := force_dark_with_lightness(color, 0.0)
	pole := if force_dark_clears_contrast(white, backdrop, target_ratio) {
		1.0
	} else if force_dark_clears_contrast(black, backdrop, target_ratio) {
		0.0
	} else if force_dark_contrast_ratio(force_dark_blend(backdrop, white), backdrop) >= force_dark_contrast_ratio(force_dark_blend(backdrop, black), backdrop) {
		1.0
	} else {
		0.0
	}
	mut near := start_lightness
	mut far := pole
	mut best := force_dark_with_lightness(color, pole)
	for _ in 0 .. 16 {
		mid := (near + far) / 2.0
		candidate := force_dark_with_lightness(color, mid)
		if force_dark_clears_contrast(candidate, backdrop, target_ratio) {
			best = candidate
			far = mid
		} else {
			near = mid
		}
	}
	return best
}

fn force_dark_darken(color Color) Color {
	brightest_channel := if color.r >= color.g && color.r >= color.b {
		color.r
	} else if color.g >= color.b {
		color.g
	} else {
		color.b
	}
	brightest := f64(brightest_channel) / 255.0
	multiplier := if brightest == 0.0 {
		0.0
	} else {
		math.max(0.0, (brightest - 0.33) / brightest)
	}
	return Color{
		r: u8(math.round(f64(color.r) * multiplier))
		g: u8(math.round(f64(color.g) * multiplier))
		b: u8(math.round(f64(color.b) * multiplier))
		a: color.a
	}
}

pub fn force_dark_adjust_border_against_backdrop(color Color, backdrop Color) Color {
	mut current := color
	for {
		if current.r == 0 && current.g == 0 && current.b == 0 {
			return current
		}
		painted := force_dark_blend(backdrop, current)
		if force_dark_contrast_ratio(painted, backdrop) < force_dark_minimum_readable_contrast_ratio {
			return current
		}
		current = force_dark_darken(current)
	}
	return current
}

fn force_dark_resolved_backdrop(backdrop ?Color, settings ForceDarkSettings) Color {
	provided := backdrop or { return force_dark_surface }
	if provided.a != 255 {
		return force_dark_surface
	}
	if force_dark_should_invert(provided, .background, settings) {
		return force_dark_invert_lightness(provided)
	}
	return provided
}

pub fn force_dark_resolve_against_backdrop(color Color, role ForceDarkRole, backdrop ?Color,
	settings ForceDarkSettings) Color {
	if role == .none_ || color.a == 0 {
		return color
	}
	resolved := if force_dark_should_invert(color, role, settings) {
		force_dark_invert_lightness(color)
	} else {
		color
	}
	return match role {
		.border {
			force_dark_adjust_border_against_backdrop(resolved,
				force_dark_resolved_backdrop(backdrop, settings))
		}
		.selection {
			force_dark_adjust_for_contrast(resolved,
				force_dark_resolved_backdrop(backdrop, settings),
				force_dark_minimum_visible_contrast_ratio)
		}
		else { resolved }
	}
}

pub fn force_dark_resolve(color Color, role ForceDarkRole, settings ForceDarkSettings) Color {
	return force_dark_resolve_against_backdrop(color, role, none, settings)
}

pub fn force_dark_resolve_each(colors []Color, role ForceDarkRole,
	settings ForceDarkSettings) []Color {
	mut resolved := []Color{cap: colors.len}
	for color in colors {
		resolved << force_dark_resolve(color, role, settings)
	}
	return resolved
}

fn force_dark_color_key(color Color) u32 {
	return u32(color.r) << 24 | u32(color.g) << 16 | u32(color.b) << 8 | u32(color.a)
}

pub struct ForceDarkResolver {
	settings ForceDarkSettings
mut:
	inverted map[u32]Color
}

pub fn ForceDarkResolver.create(settings ForceDarkSettings) &ForceDarkResolver {
	return &ForceDarkResolver{
		settings: settings
		inverted: map[u32]Color{}
	}
}

pub fn (resolver &ForceDarkResolver) settings() ForceDarkSettings {
	return resolver.settings
}

fn (mut resolver ForceDarkResolver) invert_memoized(color Color) Color {
	key := force_dark_color_key(color)
	if inverted := resolver.inverted[key] {
		return inverted
	}
	if resolver.inverted.len >= force_dark_inverted_color_cache_capacity {
		resolver.inverted.clear()
	}
	inverted := force_dark_invert_lightness(color)
	resolver.inverted[key] = inverted
	return inverted
}

fn (mut resolver ForceDarkResolver) resolve_backdrop(backdrop ?Color) Color {
	provided := backdrop or { return force_dark_surface }
	if provided.a != 255 {
		return force_dark_surface
	}
	if force_dark_should_invert(provided, .background, resolver.settings) {
		return resolver.invert_memoized(provided)
	}
	return provided
}

pub fn (mut resolver ForceDarkResolver) resolve_against_backdrop(color Color, role ForceDarkRole,
	backdrop ?Color) Color {
	if role == .none_ || color.a == 0 {
		return color
	}
	resolved := if force_dark_should_invert(color, role, resolver.settings) {
		resolver.invert_memoized(color)
	} else {
		color
	}
	return match role {
		.border {
			force_dark_adjust_border_against_backdrop(resolved,
				resolver.resolve_backdrop(backdrop))
		}
		.selection {
			force_dark_adjust_for_contrast(resolved, resolver.resolve_backdrop(backdrop),
				force_dark_minimum_visible_contrast_ratio)
		}
		else { resolved }
	}
}

pub fn (mut resolver ForceDarkResolver) resolve(color Color, role ForceDarkRole) Color {
	return resolver.resolve_against_backdrop(color, role, none)
}

pub fn (mut resolver ForceDarkResolver) resolve_each(colors []Color,
	role ForceDarkRole) []Color {
	mut resolved := []Color{cap: colors.len}
	for color in colors {
		resolved << resolver.resolve(color, role)
	}
	return resolved
}

const force_dark_max_icon_length_css = 64.0
const force_dark_max_separator_source_length = 8
const force_dark_high_lightness = 96
const force_dark_gray_channel_spread = 8
const force_dark_high_saturation = 80
const force_dark_chromatic = 20
const force_dark_transparency_ratio = 0.4
const force_dark_high_luminance_ratio = 0.5
const force_dark_high_saturation_ratio = 0.3
const force_dark_low_saturation_ratio = 0.1
const force_dark_chromatic_pixel_ratio = 0.5
const force_dark_max_sampled_pixels = 1000

pub const force_dark_low_color_count = [f64(0.8125), 0.015137]
pub const force_dark_high_color_count = [f64(1.0), 0.025635]

const force_dark_max_buckets = [f64(16.0), 4096.0]

pub fn force_dark_image_size_allows_classification(destination_width_css f64,
	destination_height_css f64, source_size IntSize) bool {
	if destination_width_css <= force_dark_max_icon_length_css
		&& destination_height_css <= force_dark_max_icon_length_css {
		return true
	}
	return source_size.width <= force_dark_max_separator_source_length
		|| source_size.height <= force_dark_max_separator_source_length
}

pub fn force_dark_role_for_image(role ForceDarkRole, destination_width f64,
	destination_height f64, device_pixels_per_css_pixel f64, source_size IntSize) ForceDarkRole {
	if device_pixels_per_css_pixel > 0
		&& force_dark_image_size_allows_classification(destination_width / device_pixels_per_css_pixel,
			destination_height / device_pixels_per_css_pixel, source_size) {
		return role
	}
	return .none_
}

pub struct ForceDarkImageFeatures {
pub:
	color_buckets_ratio   f64
	transparency_ratio    f64
	high_luminance_ratio  f64
	saturated_pixel_ratio f64
	chromatic_pixel_ratio f64
	is_colorful           bool
}

fn force_dark_int_abs(value int) int {
	return if value < 0 { -value } else { value }
}

fn force_dark_is_gray(color Color) bool {
	r := int(color.r)
	g := int(color.g)
	b := int(color.b)
	return force_dark_int_abs(r - g) + force_dark_int_abs(g - b) <= force_dark_gray_channel_spread
}

fn force_dark_chroma(color Color) int {
	highest := if color.r >= color.g && color.r >= color.b {
		color.r
	} else if color.g >= color.b {
		color.g
	} else {
		color.b
	}
	lowest := if color.r <= color.g && color.r <= color.b {
		color.r
	} else if color.g <= color.b {
		color.g
	} else {
		color.b
	}
	return int(highest) - int(lowest)
}

fn force_dark_color_buckets_ratio(samples []Color, colorful bool) f64 {
	mut seen := map[u16]bool{}
	for sample in samples {
		bucket := if colorful {
			u16((u16(sample.r) >> 4) << 8 | (u16(sample.g) >> 4) << 4 | (u16(sample.b) >> 4))
		} else {
			(u16(sample.r) * 5 + u16(sample.g) * 3 + u16(sample.b) * 2) / 10 / 16
		}
		seen[bucket] = true
	}
	return f64(seen.len) / force_dark_max_buckets[if colorful { 1 } else { 0 }]
}

pub fn force_dark_features_from_samples(samples []Color,
	transparency_ratio f64) ForceDarkImageFeatures {
	if samples.len == 0 {
		return ForceDarkImageFeatures{
			color_buckets_ratio: 1.0
			transparency_ratio: transparency_ratio
		}
	}
	mut color_pixels := 0
	mut light_pixels := 0
	mut saturated_pixels := 0
	mut chromatic_pixels := 0
	for sample in samples {
		if !force_dark_is_gray(sample) {
			color_pixels++
		}
		if force_dark_brightness(sample) >= force_dark_high_lightness {
			light_pixels++
		}
		chroma := force_dark_chroma(sample)
		if chroma >= force_dark_high_saturation {
			saturated_pixels++
		}
		if chroma >= force_dark_chromatic {
			chromatic_pixels++
		}
	}
	colorful := color_pixels > samples.len / 100
	return ForceDarkImageFeatures{
		color_buckets_ratio: force_dark_color_buckets_ratio(samples, colorful)
		transparency_ratio: transparency_ratio
		high_luminance_ratio: f64(light_pixels) / f64(samples.len)
		saturated_pixel_ratio: f64(saturated_pixels) / f64(samples.len)
		chromatic_pixel_ratio: f64(chromatic_pixels) / f64(samples.len)
		is_colorful: colorful
	}
}

pub fn force_dark_should_filter_image(features ForceDarkImageFeatures) bool {
	if features.transparency_ratio > force_dark_transparency_ratio
		&& features.high_luminance_ratio > force_dark_high_luminance_ratio {
		return false
	}
	colorful_index := if features.is_colorful { 1 } else { 0 }
	limited_palette := features.is_colorful
		&& features.color_buckets_ratio < force_dark_high_color_count[colorful_index]
	if limited_palette {
		if features.saturated_pixel_ratio > force_dark_high_saturation_ratio {
			return false
		}
		if features.high_luminance_ratio > force_dark_high_luminance_ratio
			&& features.saturated_pixel_ratio > force_dark_low_saturation_ratio {
			return false
		}
		if features.chromatic_pixel_ratio > force_dark_chromatic_pixel_ratio {
			return false
		}
	}
	return features.color_buckets_ratio < force_dark_low_color_count[colorful_index]
}

// DisplayListResourceStorage samples at most roughly one thousand decoded
// pixels. Transparent pixels describe the image's shape rather than its
// palette, so they contribute only to the transparency ratio.
pub fn force_dark_bitmap_features(bitmap &dom.Bitmap_) ?ForceDarkImageFeatures {
	if bitmap.width <= 0 || bitmap.height <= 0 || bitmap.pitch < bitmap.width * 4
		|| bitmap.data.len < bitmap.pitch * bitmap.height {
		return none
	}
	total := f64(bitmap.width) * f64(bitmap.height)
	step := int(math.max(1.0, math.ceil(math.sqrt(total / force_dark_max_sampled_pixels))))
	mut opaque_samples := []Color{}
	mut transparent_count := 0
	mut sampled_count := 0
	for y := 0; y < bitmap.height; y += step {
		for x := 0; x < bitmap.width; x += step {
			offset := y * bitmap.pitch + x * 4
			sampled_count++
			if bitmap.data[offset + 3] < 128 {
				transparent_count++
				continue
			}
			opaque_samples << Color{bitmap.data[offset], bitmap.data[offset + 1],
				bitmap.data[offset + 2], bitmap.data[offset + 3]}
		}
	}
	if sampled_count == 0 {
		return none
	}
	return force_dark_features_from_samples(opaque_samples,
		f64(transparent_count) / f64(sampled_count))
}

pub fn force_dark_should_filter_bitmap(bitmap &dom.Bitmap_) bool {
	features := force_dark_bitmap_features(bitmap) or { return false }
	return force_dark_should_filter_image(features)
}

// The native image filter receives unpremultiplied decoded RGBA. Retain the
// source bitmap and its row orientation while producing the equivalent
// Oklab-filtered frame for V replay.
pub fn force_dark_filter_bitmap(bitmap &dom.Bitmap_) &dom.Bitmap_ {
	mut filtered := bitmap.clone()
	if filtered.width <= 0 || filtered.height <= 0 || filtered.pitch < filtered.width * 4
		|| filtered.data.len < filtered.pitch * filtered.height {
		return filtered
	}
	for y in 0 .. filtered.height {
		for x in 0 .. filtered.width {
			offset := y * filtered.pitch + x * 4
			alpha := filtered.data[offset + 3]
			if alpha == 0 {
				continue
			}
			resolved := force_dark_invert_lightness(Color{filtered.data[offset],
				filtered.data[offset + 1], filtered.data[offset + 2], alpha})
			filtered.data[offset] = resolved.r
			filtered.data[offset + 1] = resolved.g
			filtered.data[offset + 2] = resolved.b
		}
	}
	return filtered
}
