/*
 * Copyright (c) 2018-2026, Ladybird contributors
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// Translated from:
// - Libraries/LibWeb/CSS/CSSImageValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/AbstractImageStyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/ImageStyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/*Color*StyleValue.cpp/.h
// - Libraries/LibWeb/CSS/StyleValues/*GradientStyleValue.cpp/.h
module css

import dom
import math
import platform

pub enum ConcreteColorType {
	rgb
	a98_rgb
	display_p3
	display_p3_linear
	hsl
	hwb
	lab
	lch
	oklab
	oklch
	srgb
	srgb_linear
	pro_photo_rgb
	rec2020
	xyzd50
	xyzd65
	light_dark
	color_mix
}

pub fn ColorStyleValue.create_from_color(color Color, color_syntax ColorSyntax, name ?string) RGBColorStyleValue {
	return RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(color.red())), StyleValue(NumberStyleValue.create(color.green())), StyleValue(NumberStyleValue.create(color.blue())), StyleValue(NumberStyleValue.create(f64(color.alpha()) / 255.0)), color_syntax, name)
}

fn image_color_clamp(value f64, min f64, max f64) f64 {
	if math.is_nan(value) {
		return min
	}
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

fn image_color_round_to_u8(value f64) u8 {
	return u8(int(math.round(image_color_clamp(value, 0.0, 255.0))))
}

fn image_color_modulo(value f64, divisor f64) f64 {
	mut result := math.fmod(value, divisor)
	if result < 0 {
		result += divisor
	}
	return result
}

fn style_value_is_none_keyword(style_value StyleValue) bool {
	if style_value is CustomIdentStyleValue {
		return to_ascii_lowercase(style_value.custom_ident()) == 'none'
	}
	if style_value is KeywordStyleValue {
		return style_value.serialize(.normal) == 'none'
	}
	return false
}

fn resolve_hue(style_value StyleValue, resolution_context CalculationResolutionContext) ?f64 {
	// <number> | <angle> | none
	normalized := fn (number_ f64) f64 {
		mut number := number_
		// +inf should be clamped to 360
		if math.is_inf(number, 1) {
			number = 360.0
		}

		// -inf and NaN should be clamped to 0
		if math.is_inf(number, -1) || math.is_nan(number) {
			number = 0.0
		}

		return image_color_modulo(number, 360.0)
	}

	if style_value.is_number() {
		return normalized(style_value.as_number().number())
	}

	if style_value is AngleStyleValue {
		return normalized(style_value.angle().to_degrees())
	}

	if style_value.is_calculated() {
		calculated := style_value.as_calculated()
		if calculated.resolves_to_number() {
			maybe_number := calculated.resolve_number(resolution_context) or { return none }
			return normalized(maybe_number)
		}

		if calculated.resolves_to_angle() {
			maybe_angle := calculated.resolve_angle(resolution_context) or { return none }
			return normalized(maybe_angle.to_degrees())
		}
	}

	return 0
}

fn resolve_with_reference_value(style_value StyleValue, one_hundred_percent_value f64, resolution_context CalculationResolutionContext) ?f64 {
	// <percentage> | <number> | none
	// Plain arithmetic rather than a capturing closure: every closure is
	// registered in V's global closure table, and this runs for each color
	// on every animation frame.
	if style_value.is_percentage() {
		return style_value.as_percentage().percentage().as_fraction() * one_hundred_percent_value
	}

	if style_value.is_number() {
		return style_value.as_number().number()
	}

	if style_value.is_calculated() {
		calculated := style_value.as_calculated()
		if calculated.resolves_to_number() {
			maybe_number := calculated.resolve_number(resolution_context) or { return none }
			return maybe_number
		}

		if calculated.resolves_to_percentage() {
			percentage := calculated.resolve_percentage(resolution_context) or { return none }
			return percentage.as_fraction() * one_hundred_percent_value
		}
	}

	return 0
}

fn resolve_alpha(style_value StyleValue, resolution_context CalculationResolutionContext) ?f64 {
	// <number> | <percentage> | none
	normalized := fn (number_ f64) f64 {
		mut number := number_
		if math.is_nan(number) {
			number = 0
		}
		return image_color_clamp(number, 0.0, 1.0)
	}

	if style_value.is_number() {
		return normalized(style_value.as_number().number())
	}

	if style_value.is_percentage() {
		return normalized(style_value.as_percentage().percentage().as_fraction())
	}

	if style_value.is_calculated() {
		calculated := style_value.as_calculated()
		if calculated.resolves_to_number() {
			maybe_number := calculated.resolve_number(resolution_context) or { return none }
			return normalized(maybe_number)
		}

		if calculated.resolves_to_percentage() {
			percentage := calculated.resolve_percentage(resolution_context) or { return none }
			return normalized(percentage.as_fraction())
		}
	}

	if style_value_is_none_keyword(style_value) {
		return 0
	}

	return 1
}

fn serialize_color_component(component StyleValue, mode SerializationMode, one_hundred_percent_value f64, clamp_min ?f64, clamp_max ?f64) string {
	if style_value_is_none_keyword(component) {
		return 'none'
	}
	if component.is_calculated() && mode == .normal {
		return component.serialize(mode)
	}

	mut resolved_value := resolve_with_reference_value(component, one_hundred_percent_value, CalculationResolutionContext{}) or {
		return component.serialize(mode)
	}

	if min := clamp_min {
		if resolved_value < min {
			resolved_value = min
		}
	}
	if max := clamp_max {
		if resolved_value > max {
			resolved_value = max
		}
	}

	return serialize_a_number(resolved_value)
}

fn serialize_alpha_component(component StyleValue, mode SerializationMode) string {
	if style_value_is_none_keyword(component) {
		return 'none'
	}
	if component.is_calculated() && mode == .normal {
		return component.serialize(mode)
	}

	resolved_value := resolve_alpha(component, CalculationResolutionContext{}) or {
		return component.serialize(mode)
	}
	return serialize_a_number(resolved_value)
}

fn serialize_hue_component(component StyleValue, mode SerializationMode) string {
	if style_value_is_none_keyword(component) {
		return 'none'
	}
	if component.is_calculated() && mode == .normal {
		return component.serialize(mode)
	}

	resolved_value := resolve_hue(component, CalculationResolutionContext{}) or {
		return component.serialize(mode)
	}
	return serialize_hue_angle(resolved_value)
}

// ColorStyleValue::serialize_hue_component() formats the resolved hue with
// AK's `{:.4}`, which rounds to four decimals and then drops the trailing zeros
// and a bare decimal point - so a whole-degree hue prints as `30`, not
// `30.0000`.
fn serialize_hue_angle(value f64) string {
	mut serialized := '${value:.4f}'
	for serialized.contains('.') && serialized.ends_with('0') {
		serialized = serialized[..serialized.len - 1]
	}
	if serialized.ends_with('.') {
		serialized = serialized[..serialized.len - 1]
	}
	if serialized == '-0' {
		return '0'
	}
	return serialized
}

fn alpha_needs_serialization(alpha StyleValue) bool {
	return (!alpha.is_number() || alpha.as_number().number() < 1)
		&& (!alpha.is_percentage() || alpha.as_percentage().percentage().as_fraction() < 1)
}

fn color_style_value_from_style_value(style_value StyleValue, color_resolution_context ColorResolutionContext) ?Color {
	return style_value.to_color(color_resolution_context)
}

// --- RGBColorStyleValue ---

pub struct RGBColorStyleValue {
pub mut:
	r_            StyleValue
	g_            StyleValue
	b_            StyleValue
	alpha_        StyleValue
	color_syntax_ ColorSyntax
	name_         ?string
}

pub fn RGBColorStyleValue.create(r StyleValue, g StyleValue, b StyleValue, alpha ?StyleValue, color_syntax ColorSyntax, name ?string) RGBColorStyleValue {
	return RGBColorStyleValue{
		r_: r
		g_: g
		b_: b
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
		color_syntax_: color_syntax
		name_: name
	}
}

pub fn (style_value RGBColorStyleValue) color_type() ConcreteColorType {
	return .rgb
}

pub fn (style_value RGBColorStyleValue) color_syntax() ColorSyntax {
	return style_value.color_syntax_
}

pub fn (style_value RGBColorStyleValue) r() StyleValue {
	return style_value.r_
}

pub fn (style_value RGBColorStyleValue) g() StyleValue {
	return style_value.g_
}

pub fn (style_value RGBColorStyleValue) b() StyleValue {
	return style_value.b_
}

pub fn (style_value RGBColorStyleValue) alpha() StyleValue {
	return style_value.alpha_
}

pub fn (style_value RGBColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	resolve_rgb_to_u8 := fn (component StyleValue) ?u8 {
		// <number> | <percentage> | none
		normalized := fn (number_ f64) u8 {
			mut number := number_
			if math.is_nan(number) {
				number = 0
			}
			return image_color_round_to_u8(image_color_clamp(number, 0.0, 255.0))
		}

		if component.is_number() {
			return normalized(component.as_number().number())
		}

		if component.is_percentage() {
			return normalized(component.as_percentage().raw_value() * 255.0 / 100.0)
		}

		if component.is_calculated() {
			calculated := component.as_calculated()
			if calculated.resolves_to_number() {
				maybe_number := calculated.resolve_number(CalculationResolutionContext{}) or {
					return none
				}
				return normalized(maybe_number)
			}

			if calculated.resolves_to_percentage() {
				maybe_percentage := calculated.resolve_percentage(CalculationResolutionContext{}) or {
					return none
				}
				return normalized(maybe_percentage.value() * 255.0 / 100.0)
			}
		}

		return 0
	}

	resolve_alpha_to_u8 := fn (component StyleValue) ?u8 {
		alpha_0_1 := resolve_alpha(component, CalculationResolutionContext{}) or { return none }
		return image_color_round_to_u8(image_color_clamp(alpha_0_1 * 255.0, 0.0, 255.0))
	}

	_ = color_resolution_context
	r_val := resolve_rgb_to_u8(style_value.r_) or { return none }
	g_val := resolve_rgb_to_u8(style_value.g_) or { return none }
	b_val := resolve_rgb_to_u8(style_value.b_) or { return none }
	alpha_val := resolve_alpha_to_u8(style_value.alpha_) or { return none }

	return Color.rgba(r_val, g_val, b_val, alpha_val)
}

pub fn (style_value RGBColorStyleValue) absolutized(context ComputationContext) RGBColorStyleValue {
	return RGBColorStyleValue.create(style_value.r_.absolutized(context), style_value.g_.absolutized(context), style_value.b_.absolutized(context), style_value.alpha_.absolutized(context), style_value.color_syntax(), none)
}

// https://www.w3.org/TR/css-color-4/#serializing-sRGB-values
pub fn (style_value RGBColorStyleValue) serialize(mode SerializationMode) string {
	if mode != .resolved_value {
		if name := style_value.name_ {
			return to_ascii_lowercase(name)
		}
	}

	if color := style_value.to_color(ColorResolutionContext{}) {
		return color.serialize_a_srgb_value()
	}

	mut result := 'rgb('
	result += serialize_color_component(style_value.r_, mode, 255, 0, 255)
	result += ' '
	result += serialize_color_component(style_value.g_, mode, 255, 0, 255)
	result += ' '
	result += serialize_color_component(style_value.b_, mode, 255, 0, 255)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

// --- HSLColorStyleValue ---

pub struct HSLColorStyleValue {
pub mut:
	h_            StyleValue
	s_            StyleValue
	l_            StyleValue
	alpha_        StyleValue
	color_syntax_ ColorSyntax
}

pub fn HSLColorStyleValue.create(h StyleValue, s StyleValue, l StyleValue, alpha ?StyleValue, color_syntax ColorSyntax) HSLColorStyleValue {
	return HSLColorStyleValue{
		h_: h
		s_: s
		l_: l
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
		color_syntax_: color_syntax
	}
}

pub fn (style_value HSLColorStyleValue) color_type() ConcreteColorType {
	return .hsl
}

pub fn (style_value HSLColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	h_val := resolve_hue(style_value.h_, CalculationResolutionContext{}) or { return none }
	s_val := resolve_with_reference_value(style_value.s_, 100.0, CalculationResolutionContext{}) or {
		return none
	}
	l_val := resolve_with_reference_value(style_value.l_, 100.0, CalculationResolutionContext{}) or {
		return none
	}
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	return Color.from_hsla(h_val, s_val / 100.0, l_val / 100.0, alpha_val)
}

pub fn (style_value HSLColorStyleValue) absolutized(context ComputationContext) RGBColorStyleValue {
	absolutized_h := style_value.h_.absolutized(context)
	absolutized_s := style_value.s_.absolutized(context)
	absolutized_l := style_value.l_.absolutized(context)
	absolutized_alpha := style_value.alpha_.absolutized(context)

	// hsl() computes to rgb()
	// https://drafts.csswg.org/css-color-4/#resolving-sRGB-values
	resolved_h := resolve_hue(absolutized_h, CalculationResolutionContext{}) or { 0.0 }
	resolved_s := resolve_with_reference_value(absolutized_s, 100.0, CalculationResolutionContext{}) or {
		0.0
	}
	resolved_l := resolve_with_reference_value(absolutized_l, 100.0, CalculationResolutionContext{}) or {
		0.0
	}
	resolved_alpha := resolve_alpha(absolutized_alpha, CalculationResolutionContext{}) or { 1.0 }

	color := Color.from_hsla(resolved_h, resolved_s / 100.0, resolved_l / 100.0, resolved_alpha)
	if element := context.abstract_element {
		if element.document().font_rendering_policy() == .chromium {
			components := ci_hsl_to_srgb(interpolation_color_components(resolved_h,
				image_color_clamp(resolved_s / 100, 0, 1), image_color_clamp(resolved_l / 100, 0, 1), resolved_alpha))
			return RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(components.values[0] * 255)),
				StyleValue(NumberStyleValue.create(components.values[1] * 255)),
				StyleValue(NumberStyleValue.create(components.values[2] * 255)),
				StyleValue(NumberStyleValue.create(resolved_alpha)), .legacy, none)
		}
	}
	return RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(color.red())), StyleValue(NumberStyleValue.create(color.green())), StyleValue(NumberStyleValue.create(color.blue())), StyleValue(NumberStyleValue.create(f64(color.alpha()) / 255.0)), .legacy, none)
}

// https://www.w3.org/TR/css-color-4/#serializing-sRGB-values
pub fn (style_value HSLColorStyleValue) serialize(mode SerializationMode) string {
	if color := style_value.to_color(ColorResolutionContext{}) {
		return color.serialize_a_srgb_value()
	}

	mut result := 'hsl('
	result += serialize_hue_component(style_value.h_, mode)
	result += ' '
	result += serialize_color_component(style_value.s_, mode, 100, 0, none)
	result += ' '
	result += serialize_color_component(style_value.l_, mode, 100, 0, none)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

// --- HWBColorStyleValue ---

pub struct HWBColorStyleValue {
pub mut:
	h_            StyleValue
	w_            StyleValue
	b_            StyleValue
	alpha_        StyleValue
	color_syntax_ ColorSyntax
}

pub fn HWBColorStyleValue.create(h StyleValue, w StyleValue, b StyleValue, alpha ?StyleValue, color_syntax ColorSyntax) HWBColorStyleValue {
	return HWBColorStyleValue{
		h_: h
		w_: w
		b_: b
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
		color_syntax_: color_syntax
	}
}

pub fn (style_value HWBColorStyleValue) color_type() ConcreteColorType {
	return .hwb
}

pub fn (style_value HWBColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	h_val := resolve_hue(style_value.h_, CalculationResolutionContext{}) or { return none }
	raw_w_value := resolve_with_reference_value(style_value.w_, 100.0, CalculationResolutionContext{}) or {
		return none
	}
	raw_b_value := resolve_with_reference_value(style_value.b_, 100.0, CalculationResolutionContext{}) or {
		return none
	}
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	w_val := image_color_clamp(raw_w_value, 0, 100) / 100.0
	b_val := image_color_clamp(raw_b_value, 0, 100) / 100.0

	if w_val + b_val >= 1.0 {
		gray := image_color_round_to_u8(w_val / (w_val + b_val) * 255.0)
		return Color.rgba(gray, gray, gray, image_color_round_to_u8(alpha_val * 255.0))
	}

	value := 1 - b_val
	saturation := 1 - (w_val / value)
	return Color.from_hsv(h_val, saturation, value).with_opacity(alpha_val)
}

pub fn (style_value HWBColorStyleValue) absolutized(context ComputationContext) RGBColorStyleValue {
	absolutized_h := style_value.h_.absolutized(context)
	absolutized_w := style_value.w_.absolutized(context)
	absolutized_b := style_value.b_.absolutized(context)
	absolutized_alpha := style_value.alpha_.absolutized(context)

	resolved_h := resolve_hue(absolutized_h, CalculationResolutionContext{}) or { 0.0 }
	resolved_w := resolve_with_reference_value(absolutized_w, 100.0, CalculationResolutionContext{}) or {
		0.0
	}
	resolved_b := resolve_with_reference_value(absolutized_b, 100.0, CalculationResolutionContext{}) or {
		0.0
	}
	resolved_alpha := resolve_alpha(absolutized_alpha, CalculationResolutionContext{}) or { 1.0 }

	// https://drafts.csswg.org/css-color-4/#hwb-to-rgb
	whiteness := image_color_clamp(resolved_w / 100.0, 0.0, 1.0)
	blackness := image_color_clamp(resolved_b / 100.0, 0.0, 1.0)

	mut color := Color.rgb(0, 0, 0)
	// If the sum of whiteness + blackness is >= 1, the result is an achromatic (gray) color.
	if whiteness + blackness >= 1.0 {
		gray := image_color_round_to_u8(whiteness / (whiteness + blackness) * 255.0)
		color = Color.rgba(gray, gray, gray, image_color_round_to_u8(resolved_alpha * 255.0))
	} else {
		// Convert hue to RGB (using HSL with S=1, L=0.5)
		mut hue := math.fmod(resolved_h, 360.0)
		if hue < 0.0 {
			hue += 360.0
		}

		hue_to_rgb := fn (h f64, offset f64) f64 {
			k := math.fmod(offset + h / 30.0, 12.0)
			return 0.5 - 0.5 * math.max(-1.0, math.min(math.min(k - 3.0, 9.0 - k), 1.0))
		}

		// Apply whiteness and blackness: rgb = rgb * (1 - whiteness - blackness) + whiteness
		scale := 1.0 - whiteness - blackness
		r := hue_to_rgb(hue, 0.0) * scale + whiteness
		g := hue_to_rgb(hue, 8.0) * scale + whiteness
		b := hue_to_rgb(hue, 4.0) * scale + whiteness
		color = Color.rgba(image_color_round_to_u8(r * 255.0), image_color_round_to_u8(g * 255.0), image_color_round_to_u8(b * 255.0), image_color_round_to_u8(resolved_alpha * 255.0))
	}

	return RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(color.red())), StyleValue(NumberStyleValue.create(color.green())), StyleValue(NumberStyleValue.create(color.blue())), StyleValue(NumberStyleValue.create(f64(color.alpha()) / 255.0)), .legacy, none)
}

// https://www.w3.org/TR/css-color-4/#serializing-sRGB-values
pub fn (style_value HWBColorStyleValue) serialize(mode SerializationMode) string {
	if color := style_value.to_color(ColorResolutionContext{}) {
		return color.serialize_a_srgb_value()
	}

	mut result := 'hwb('
	result += serialize_hue_component(style_value.h_, mode)
	result += ' '
	result += serialize_color_component(style_value.w_, mode, 100, 0, none)
	result += ' '
	result += serialize_color_component(style_value.b_, mode, 100, 0, none)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

// --- LabLikeColorStyleValue ---

pub struct LabColorStyleValue {
pub mut:
	l_     StyleValue
	a_     StyleValue
	b_     StyleValue
	alpha_ StyleValue
}

pub struct OKLabColorStyleValue {
pub mut:
	l_     StyleValue
	a_     StyleValue
	b_     StyleValue
	alpha_ StyleValue
}

pub fn LabColorStyleValue.create(l StyleValue, a StyleValue, b StyleValue, alpha ?StyleValue) LabColorStyleValue {
	return LabColorStyleValue{
		l_: l
		a_: a
		b_: b
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

pub fn OKLabColorStyleValue.create(l StyleValue, a StyleValue, b StyleValue, alpha ?StyleValue) OKLabColorStyleValue {
	return OKLabColorStyleValue{
		l_: l
		a_: a
		b_: b
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

pub fn (style_value OKLabColorStyleValue) absolutized(context ComputationContext) OKLabColorStyleValue {
	return OKLabColorStyleValue.create(style_value.l_.absolutized(context), style_value.a_.absolutized(context), style_value.b_.absolutized(context), style_value.alpha_.absolutized(context))
}

pub fn (style_value LabColorStyleValue) absolutized(context ComputationContext) LabColorStyleValue {
	return LabColorStyleValue.create(style_value.l_.absolutized(context), style_value.a_.absolutized(context), style_value.b_.absolutized(context), style_value.alpha_.absolutized(context))
}

pub fn (style_value OKLabColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	l_val := resolve_with_reference_value(style_value.l_, 1.0, CalculationResolutionContext{}) or {
		return none
	}
	a_val := resolve_with_reference_value(style_value.a_, 0.4, CalculationResolutionContext{}) or {
		return none
	}
	b_val := resolve_with_reference_value(style_value.b_, 0.4, CalculationResolutionContext{}) or {
		return none
	}
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	return Color.from_oklab(image_color_clamp(l_val, 0, 1), a_val, b_val, alpha_val)
}

// https://www.w3.org/TR/css-color-4/#serializing-oklab-oklch
pub fn (style_value OKLabColorStyleValue) serialize(mode SerializationMode) string {
	mut result := 'oklab('
	result += serialize_color_component(style_value.l_, mode, 1.0, 0, 1)
	result += ' '
	result += serialize_color_component(style_value.a_, mode, 0.4, none, none)
	result += ' '
	result += serialize_color_component(style_value.b_, mode, 0.4, none, none)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

pub fn (style_value LabColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	l_val := resolve_with_reference_value(style_value.l_, 100, CalculationResolutionContext{}) or {
		return none
	}
	a_val := resolve_with_reference_value(style_value.a_, 125, CalculationResolutionContext{}) or {
		return none
	}
	b_val := resolve_with_reference_value(style_value.b_, 125, CalculationResolutionContext{}) or {
		return none
	}
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	return Color.from_lab(image_color_clamp(l_val, 0, 100), a_val, b_val, alpha_val)
}

// https://www.w3.org/TR/css-color-4/#serializing-lab-lch
pub fn (style_value LabColorStyleValue) serialize(mode SerializationMode) string {
	mut result := 'lab('
	result += serialize_color_component(style_value.l_, mode, 100, 0, 100)
	result += ' '
	result += serialize_color_component(style_value.a_, mode, 125, none, none)
	result += ' '
	result += serialize_color_component(style_value.b_, mode, 125, none, none)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

// --- LCHLikeColorStyleValue ---

pub struct LCHColorStyleValue {
pub mut:
	l_     StyleValue
	c_     StyleValue
	h_     StyleValue
	alpha_ StyleValue
}

pub struct OKLCHColorStyleValue {
pub mut:
	l_     StyleValue
	c_     StyleValue
	h_     StyleValue
	alpha_ StyleValue
}

pub fn LCHColorStyleValue.create(l StyleValue, c StyleValue, h StyleValue, alpha ?StyleValue) LCHColorStyleValue {
	return LCHColorStyleValue{
		l_: l
		c_: c
		h_: h
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

pub fn OKLCHColorStyleValue.create(l StyleValue, c StyleValue, h StyleValue, alpha ?StyleValue) OKLCHColorStyleValue {
	return OKLCHColorStyleValue{
		l_: l
		c_: c
		h_: h
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

pub fn (style_value LCHColorStyleValue) absolutized(context ComputationContext) LCHColorStyleValue {
	return LCHColorStyleValue.create(style_value.l_.absolutized(context), style_value.c_.absolutized(context), style_value.h_.absolutized(context), style_value.alpha_.absolutized(context))
}

pub fn (style_value OKLCHColorStyleValue) absolutized(context ComputationContext) OKLCHColorStyleValue {
	return OKLCHColorStyleValue.create(style_value.l_.absolutized(context), style_value.c_.absolutized(context), style_value.h_.absolutized(context), style_value.alpha_.absolutized(context))
}

pub fn (style_value LCHColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	raw_l_val := resolve_with_reference_value(style_value.l_, 100, CalculationResolutionContext{}) or {
		return none
	}
	c_val := resolve_with_reference_value(style_value.c_, 150, CalculationResolutionContext{}) or {
		return none
	}
	raw_h_val := resolve_hue(style_value.h_, CalculationResolutionContext{}) or { return none }
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	l_val := image_color_clamp(raw_l_val, 0, 100)
	h_val := raw_h_val * math.pi / 180.0

	return Color.from_lab(l_val, c_val * math.cos(h_val), c_val * math.sin(h_val), alpha_val)
}

// https://www.w3.org/TR/css-color-4/#serializing-lab-lch
pub fn (style_value LCHColorStyleValue) serialize(mode SerializationMode) string {
	mut result := 'lch('
	result += serialize_color_component(style_value.l_, mode, 100, 0, 100)
	result += ' '
	result += serialize_color_component(style_value.c_, mode, 150, 0, none)
	result += ' '
	result += serialize_hue_component(style_value.h_, mode)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

pub fn (style_value OKLCHColorStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	_ = color_resolution_context
	raw_l_val := resolve_with_reference_value(style_value.l_, 1.0, CalculationResolutionContext{}) or {
		return none
	}
	raw_c_val := resolve_with_reference_value(style_value.c_, 0.4, CalculationResolutionContext{}) or {
		return none
	}
	raw_h_val := resolve_hue(style_value.h_, CalculationResolutionContext{}) or { return none }
	alpha_val := resolve_alpha(style_value.alpha_, CalculationResolutionContext{}) or {
		return none
	}

	l_val := image_color_clamp(raw_l_val, 0, 1)
	c_val := math.max(raw_c_val, 0)
	h_val := raw_h_val * math.pi / 180.0

	return Color.from_oklab(l_val, c_val * math.cos(h_val), c_val * math.sin(h_val), alpha_val)
}

// https://www.w3.org/TR/css-color-4/#serializing-oklab-oklch
pub fn (style_value OKLCHColorStyleValue) serialize(mode SerializationMode) string {
	mut result := 'oklch('
	result += serialize_color_component(style_value.l_, mode, 1.0, 0, 1)
	result += ' '
	result += serialize_color_component(style_value.c_, mode, 0.4, 0, none)
	result += ' '
	result += serialize_hue_component(style_value.h_, mode)
	if alpha_needs_serialization(style_value.alpha_) {
		result += ' / '
		result += serialize_alpha_component(style_value.alpha_, mode)
	}
	result += ')'
	return result
}

// --- ColorFunctionStyleValue ---

pub struct ColorFunctionStyleValueResolved {
pub mut:
	channels [3]f64
	alpha    f64
}

pub struct ColorFunctionStyleValue {
pub mut:
	color_type_ ConcreteColorType
	channels_   []StyleValue
	alpha_      StyleValue
}

fn color_type_from_color_space(color_space string) ConcreteColorType {
	return match color_space {
		'a98-rgb' { .a98_rgb }
		'display-p3' { .display_p3 }
		'display-p3-linear' { .display_p3_linear }
		'srgb' { .srgb }
		'srgb-linear' { .srgb_linear }
		'prophoto-rgb' { .pro_photo_rgb }
		'rec2020' { .rec2020 }
		'xyz-d50' { .xyzd50 }
		'xyz', 'xyz-d65' { .xyzd65 }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

fn color_space_from_color_type(color_type ConcreteColorType) string {
	return match color_type {
		.a98_rgb { 'a98-rgb' }
		.display_p3 { 'display-p3' }
		.display_p3_linear { 'display-p3-linear' }
		.srgb { 'srgb' }
		.srgb_linear { 'srgb-linear' }
		.pro_photo_rgb { 'prophoto-rgb' }
		.rec2020 { 'rec2020' }
		.xyzd50 { 'xyz-d50' }
		.xyzd65 { 'xyz-d65' }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

pub fn ColorFunctionStyleValue.create(color_space string, c1 StyleValue, c2 StyleValue, c3 StyleValue, alpha ?StyleValue) ColorFunctionStyleValue {
	return ColorFunctionStyleValue{
		color_type_: color_type_from_color_space(color_space)
		channels_: [c1, c2, c3]
		alpha_: alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

pub fn (style_value ColorFunctionStyleValue) color_type() ConcreteColorType {
	return style_value.color_type_
}

pub fn (style_value ColorFunctionStyleValue) resolve_properties(resolution_context CalculationResolutionContext) ?ColorFunctionStyleValueResolved {
	c1 := resolve_with_reference_value(style_value.channels_[0], 1, resolution_context) or {
		return none
	}
	c2 := resolve_with_reference_value(style_value.channels_[1], 1, resolution_context) or {
		return none
	}
	c3 := resolve_with_reference_value(style_value.channels_[2], 1, resolution_context) or {
		return none
	}
	alpha := resolve_alpha(style_value.alpha_, resolution_context) or { return none }

	return ColorFunctionStyleValueResolved{
		channels: [c1, c2, c3]!
		alpha: alpha
	}
}

fn color_function_convert_percentage(value StyleValue, mode SerializationMode) StyleValue {
	if value.is_percentage() {
		return StyleValue(NumberStyleValue.create(value.as_percentage().raw_value() / 100.0))
	}
	if mode == .resolved_value && value.is_calculated() {
		// Boundary: Serialization has no full calculation tree context here, matching the upstream
		// FIXME path that resolves with an empty CalculationResolutionContext.
		calculated := value.as_calculated()
		if calculated.resolves_to_percentage() {
			if resolved_percentage := calculated.resolve_percentage(CalculationResolutionContext{}) {
				mut resolved_number := resolved_percentage.value() / 100.0
				if math.is_inf(resolved_number, 0) || math.is_nan(resolved_number) {
					resolved_number = 0
				}
				return StyleValue(NumberStyleValue.create(resolved_number))
			}
		} else if calculated.resolves_to_number() {
			if resolved_number := calculated.resolve_number(CalculationResolutionContext{}) {
				return StyleValue(NumberStyleValue.create(resolved_number))
			}
		}
	}

	return value
}

pub fn (style_value ColorFunctionStyleValue) absolutized(context ComputationContext) StyleValue {
	channel0 := style_value.channels_[0].absolutized(context)
	channel1 := style_value.channels_[1].absolutized(context)
	channel2 := style_value.channels_[2].absolutized(context)
	alpha := style_value.alpha_.absolutized(context)

	return StyleValue(ColorFunctionStyleValue.create(color_space_from_color_type(style_value.color_type_), channel0, channel1, channel2, alpha))
}

// https://www.w3.org/TR/css-color-4/#serializing-color-function-values
pub fn (style_value ColorFunctionStyleValue) serialize(mode SerializationMode) string {
	mut alpha := color_function_convert_percentage(style_value.alpha_, mode)
	is_alpha_required := if alpha.is_number() {
		alpha.as_number().number() < 1
	} else {
		true
	}

	if alpha.is_number() && alpha.as_number().number() < 0 {
		alpha = StyleValue(NumberStyleValue.create(0))
	}

	mut result := 'color(${color_space_from_color_type(style_value.color_type_)} '
	result += color_function_convert_percentage(style_value.channels_[0], mode).serialize(mode)
	result += ' '
	result += color_function_convert_percentage(style_value.channels_[1], mode).serialize(mode)
	result += ' '
	result += color_function_convert_percentage(style_value.channels_[2], mode).serialize(mode)
	if is_alpha_required {
		result += ' / '
		result += alpha.serialize(mode)
	}
	result += ')'
	return result
}

pub fn (style_value ColorFunctionStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	properties := style_value.resolve_properties(color_resolution_context.calculation_resolution_context) or {
		return none
	}
	c1 := properties.channels[0]
	c2 := properties.channels[1]
	c3 := properties.channels[2]
	alpha_val := properties.alpha

	return match style_value.color_type() {
		.a98_rgb {
			Color.from_a98rgb(c1, c2, c3, alpha_val)
		}
		.display_p3 {
			Color.from_display_p3(c1, c2, c3, alpha_val)
		}
		.display_p3_linear {
			Color.from_linear_display_p3(c1, c2, c3, alpha_val)
		}
		.srgb {
			Color.rgba(image_color_round_to_u8(255 * c1), image_color_round_to_u8(255 * c2), image_color_round_to_u8(255 * c3), image_color_round_to_u8(255 * alpha_val))
		}
		.srgb_linear {
			Color.from_linear_srgb(c1, c2, c3, alpha_val)
		}
		.pro_photo_rgb {
			Color.from_pro_photo_rgb(c1, c2, c3, alpha_val)
		}
		.rec2020 {
			Color.from_rec2020(c1, c2, c3, alpha_val)
		}
		.xyzd50 {
			Color.from_xyz50(c1, c2, c3, alpha_val)
		}
		.xyzd65 {
			Color.from_xyz65(c1, c2, c3, alpha_val)
		}
		else {
			none
		}
	}
}

// --- ColorInterpolationMethodStyleValue ---

pub enum RectangularColorSpace {
	srgb
	srgb_linear
	display_p3
	display_p3_linear
	a98_rgb
	prophoto_rgb
	rec2020
	lab
	oklab
	xyz
	xyz_d50
	xyz_d65
}

pub enum PolarColorSpace {
	hsl
	hwb
	lch
	oklch
}

pub enum HueInterpolationMethod {
	shorter
	longer
	increasing
	decreasing
}

pub struct PolarColorInterpolationMethod {
pub mut:
	color_space              PolarColorSpace
	hue_interpolation_method HueInterpolationMethod = .shorter
}

pub type ColorInterpolationMethod = PolarColorInterpolationMethod | RectangularColorSpace

pub struct ColorInterpolationMethodStyleValue {
pub mut:
	color_interpolation_method_ ColorInterpolationMethod
}

pub fn (space RectangularColorSpace) to_string() string {
	return match space {
		.srgb { 'srgb' }
		.srgb_linear { 'srgb-linear' }
		.display_p3 { 'display-p3' }
		.display_p3_linear { 'display-p3-linear' }
		.a98_rgb { 'a98-rgb' }
		.prophoto_rgb { 'prophoto-rgb' }
		.rec2020 { 'rec2020' }
		.lab { 'lab' }
		.oklab { 'oklab' }
		.xyz { 'xyz' }
		.xyz_d50 { 'xyz-d50' }
		.xyz_d65 { 'xyz-d65' }
	}
}

pub fn (space PolarColorSpace) to_string() string {
	return match space {
		.hsl { 'hsl' }
		.hwb { 'hwb' }
		.lch { 'lch' }
		.oklch { 'oklch' }
	}
}

pub fn (method HueInterpolationMethod) to_string() string {
	return match method {
		.shorter { 'shorter' }
		.longer { 'longer' }
		.increasing { 'increasing' }
		.decreasing { 'decreasing' }
	}
}

pub fn ColorInterpolationMethodStyleValue.default_color_interpolation_method(color_syntax ColorSyntax) ColorInterpolationMethod {
	if color_syntax == .legacy {
		return ColorInterpolationMethod(RectangularColorSpace.srgb)
	}
	return ColorInterpolationMethod(RectangularColorSpace.oklab)
}

pub fn ColorInterpolationMethodStyleValue.create(color_space ColorInterpolationMethod) ColorInterpolationMethodStyleValue {
	return ColorInterpolationMethodStyleValue{
		color_interpolation_method_: color_space
	}
}

pub fn (style_value ColorInterpolationMethodStyleValue) color_interpolation_method() ColorInterpolationMethod {
	return style_value.color_interpolation_method_
}

pub fn (style_value ColorInterpolationMethodStyleValue) absolutized(context ComputationContext) ColorInterpolationMethodStyleValue {
	_ = context
	return style_value
}

pub fn (style_value ColorInterpolationMethodStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	mut result := 'in '
	match style_value.color_interpolation_method_ {
		RectangularColorSpace {
			result += style_value.color_interpolation_method_.to_string()
		}
		PolarColorInterpolationMethod {
			result += style_value.color_interpolation_method_.color_space.to_string()
			if style_value.color_interpolation_method_.hue_interpolation_method != .shorter {
				result += ' ${style_value.color_interpolation_method_.hue_interpolation_method} hue'
			}
		}
	}

	return result
}

// --- ColorMixStyleValue ---

pub struct ColorMixComponent {
pub mut:
	color      StyleValue
	percentage ?StyleValue
}

pub struct ColorMixPercentageNormalizationResult {
pub mut:
	p1               StyleValue
	p2               StyleValue
	alpha_multiplier f64
}

struct ColorMixNormalizedPercentagePair {
	p1               Percentage
	p2               Percentage
	alpha_multiplier f64 = 1.0
}

pub struct ColorMixStyleValue {
pub mut:
	color_interpolation_method ?ColorInterpolationMethodStyleValue
	first_component            ColorMixComponent
	second_component           ColorMixComponent
}

pub fn ColorMixStyleValue.create(color_interpolation_method ?ColorInterpolationMethodStyleValue, first_component ColorMixComponent, second_component ColorMixComponent) ColorMixStyleValue {
	return ColorMixStyleValue{
		color_interpolation_method: color_interpolation_method
		first_component: first_component
		second_component: second_component
	}
}

// https://drafts.csswg.org/css-color-5/#serial-color-mix
pub fn (style_value ColorMixStyleValue) serialize(mode SerializationMode) string {
	mut result := 'color-mix('

	if color_interpolation_method := style_value.color_interpolation_method {
		if color_interpolation_method.color_interpolation_method() != ColorInterpolationMethod(RectangularColorSpace.oklab) {
			result += color_interpolation_method.serialize(mode)
			result += ', '
		}
	}

	result += style_value.first_component.color.serialize(mode)
	result += serialize_first_color_mix_percentage(style_value.first_component.percentage, style_value.second_component.percentage, mode)
	result += ', '
	result += style_value.second_component.color.serialize(mode)
	result += serialize_second_color_mix_percentage(style_value.first_component.percentage, style_value.second_component.percentage, mode)
	result += ')'
	return result
}

fn serialize_first_color_mix_percentage(p1 ?StyleValue, p2 ?StyleValue, mode SerializationMode) string {
	// if BOTH the first percentage p1 and second percentage p2 are specified:
	if first := p1 {
		if second := p2 {
			// If both p1 equals 50% and p2 equals 50%, nothing is serialized.
			if first.is_percentage() && second.is_percentage()
				&& first.as_percentage().percentage().value() == 50
				&& second.as_percentage().percentage().value() == 50 {
				return ''
			}

			// else, p1 is serialized as is.
			return ' ${first.serialize(mode)}'
		}

		// else if ONLY the first percentage p1 is specified:
		// If p1 is equal to 50%, nothing is serialized.
		if first.is_percentage() && first.as_percentage().percentage().value() == 50 {
			return ''
		}

		// else, p1 is serialized as is.
		return ' ${first.serialize(mode)}'
	}

	if second := p2 {
		// else if ONLY the second percentage p2 is specified:
		// if p2 equals 50%, nothing is serialized.
		if second.is_percentage() && second.as_percentage().percentage().value() == 50 {
			return ''
		}

		// if p2 is not calc(), the value of 100% - p2 is serialized.
		if !second.is_calculated() {
			return ' ${serialize_a_number(100 - second.as_percentage().percentage().value())}%'
		}
	}

	// else, nothing is serialized.
	return ''
}

fn serialize_second_color_mix_percentage(p1 ?StyleValue, p2 ?StyleValue, mode SerializationMode) string {
	if first := p1 {
		if second := p2 {
			// If both p1 and p2 are specified, and neither p1 nor p2 is calc(), and p1 + p2 equals 100%, nothing is serialized.
			if first.is_percentage() && second.is_percentage()
				&& first.as_percentage().percentage().value() + second.as_percentage().percentage().value() == 100 {
				return ''
			}

			// else, p2 is serialized as is.
			return ' ${second.serialize(mode)}'
		}

		// else if ONLY the first percentage p1 is specified: nothing is serialized.
		_ = first
		return ''
	}

	if second := p2 {
		// if p2 equals 50%, nothing is serialized.
		if second.is_percentage() && second.as_percentage().percentage().value() == 50 {
			return ''
		}

		// if p2 is not calc(), nothing is serialized.
		if !second.is_calculated() {
			return ''
		}

		// else, p2 is serialized as is.
		return ' ${second.serialize(mode)}'
	}

	return ''
}

// https://drafts.csswg.org/css-color-5/#color-mix-percent-norm
fn normalize_color_mix_percentage_pair(first_percentage ?Percentage, second_percentage ?Percentage) ColorMixNormalizedPercentagePair {
	// 1. Let p1 be the first percentage and p2 the second one.
	mut p1 := first_percentage
	mut p2 := second_percentage
	mut alpha_multiplier := 1.0

	// 2. If both percentages are omitted, they each default to 50% (an equal mix of the two colors).
	if p1 == none && p2 == none {
		p1 = Percentage.new(50)
		p2 = Percentage.new(50)
	} else if p2 == none {
		// 3. Otherwise, if p2 is omitted, it becomes 100% - p1
		first := p1 or { Percentage.new(0) }
		p2 = Percentage.new(100 - first.value())
	} else if p1 == none {
		// 4. Otherwise, if p1 is omitted, it becomes 100% - p2
		second := p2 or { Percentage.new(0) }
		p1 = Percentage.new(100 - second.value())
	} else {
		// 5. Otherwise, if both are provided and add up to greater than 100%, they are scaled accordingly so that they add up to 100%.
		first := p1 or { Percentage.new(0) }
		second := p2 or { Percentage.new(0) }
		if first.value() + second.value() > 100 {
			sum := first.value() + second.value()
			p1 = Percentage.new((first.value() / sum) * 100)
			p2 = Percentage.new((second.value() / sum) * 100)
		} else if first.value() + second.value() < 100 {
			// 6. Otherwise, if both are provided and add up to less than 100%, the sum is saved as an alpha multiplier.
			//    If the sum is greater than zero, they are then scaled accordingly so that they add up to 100%.
			sum := first.value() + second.value()
			alpha_multiplier = sum / 100
			if sum > 0 {
				p1 = Percentage.new((first.value() / sum) * 100)
				p2 = Percentage.new((second.value() / sum) * 100)
			}
		}
	}

	return ColorMixNormalizedPercentagePair{
		p1: p1 or { Percentage.new(0) }
		p2: p2 or { Percentage.new(0) }
		alpha_multiplier: alpha_multiplier
	}
}

pub fn (style_value ColorMixStyleValue) normalize_percentages(context ComputationContext) ColorMixPercentageNormalizationResult {
	resolve_percentage := fn [context] (percentage_style_value ?StyleValue) ?Percentage {
		percentage := percentage_style_value or { return none }
		return Percentage.from_style_value_logic(percentage.absolutized(context))
	}
	normalized := normalize_color_mix_percentage_pair(resolve_percentage(style_value.first_component.percentage), resolve_percentage(style_value.second_component.percentage))
	return ColorMixPercentageNormalizationResult{
		p1: StyleValue(PercentageStyleValue.create(normalized.p1))
		p2: StyleValue(PercentageStyleValue.create(normalized.p2))
		alpha_multiplier: normalized.alpha_multiplier
	}
}

// https://drafts.csswg.org/css-color-5/#color-mix-result
pub fn (style_value ColorMixStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	first_percentage := if percentage := style_value.first_component.percentage {
		?Percentage(Percentage.from_style_value_logic(percentage))
	} else {
		?Percentage(none)
	}
	second_percentage := if percentage := style_value.second_component.percentage {
		?Percentage(Percentage.from_style_value_logic(percentage))
	} else {
		?Percentage(none)
	}
	normalized := normalize_color_mix_percentage_pair(first_percentage, second_percentage)
	color_interpolation_method := if method := style_value.color_interpolation_method {
		?ColorInterpolationMethod(method.color_interpolation_method())
	} else {
		?ColorInterpolationMethod(RectangularColorSpace.oklab)
	}
	mut interpolated := perform_color_interpolation(style_value.first_component.color,
		style_value.second_component.color, normalized.p2.as_fraction(),
		color_interpolation_method, color_resolution_context) or { return none }
	if normalized.alpha_multiplier < 1 {
		interpolated.components.set_alpha(interpolated.components.alpha() *
			normalized.alpha_multiplier)
	}
	result := style_value_for_interpolated_color(interpolated)
	return result.to_color(color_resolution_context)
}

pub fn (style_value ColorMixStyleValue) absolutized(context ComputationContext) StyleValue {
	// FIXME: Follow the spec algorithm. https://drafts.csswg.org/css-color-5/#calculate-a-color-mix
	normalized_percentages := style_value.normalize_percentages(context)
	mut context_document := ?&dom.Document(none)
	if abstract_element := context.abstract_element {
		context_document = ?&dom.Document(abstract_element.document())
	}
	color_resolution_context := ColorResolutionContext{
		color_scheme: context.color_scheme
		document: context_document
		calculation_resolution_context: CalculationResolutionContext.from_computation_context(context, none)
	}
	absolutized_color_interpolation_method := if method := style_value.color_interpolation_method {
		?ColorInterpolationMethodStyleValue(method)
	} else {
		?ColorInterpolationMethodStyleValue(none)
	}
	delta := Percentage.from_style_value_logic(normalized_percentages.p2).as_fraction()
	color_interpolation_method := if method := absolutized_color_interpolation_method {
		?ColorInterpolationMethod(method.color_interpolation_method())
	} else {
		?ColorInterpolationMethod(RectangularColorSpace.oklab)
	}
	if initial_interpolation := perform_color_interpolation(style_value.first_component.color,
		style_value.second_component.color, delta, color_interpolation_method,
		color_resolution_context) {
		mut interpolated := initial_interpolation
		if normalized_percentages.alpha_multiplier < 1 {
			interpolated.components.set_alpha(interpolated.components.alpha() *
				normalized_percentages.alpha_multiplier)
		}
		return style_value_for_interpolated_color(interpolated)
	}

	absolutized_first_color := style_value.first_component.color.absolutized(context)
	absolutized_second_color := style_value.second_component.color.absolutized(context)
	return StyleValue(ColorMixStyleValue.create(absolutized_color_interpolation_method, ColorMixComponent{
		color: absolutized_first_color
		percentage: normalized_percentages.p1
	}, ColorMixComponent{
		color: absolutized_second_color
		percentage: normalized_percentages.p2
	}))
}

// --- LightDarkStyleValue ---

pub struct LightDarkStyleValue {
pub mut:
	light StyleValue
	dark  StyleValue
}

pub fn LightDarkStyleValue.create(light StyleValue, dark StyleValue) LightDarkStyleValue {
	return LightDarkStyleValue{
		light: light
		dark: dark
	}
}

pub fn (style_value LightDarkStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	if scheme := color_resolution_context.color_scheme {
		if scheme == .dark {
			return style_value.dark.to_color(color_resolution_context)
		}
	}

	return style_value.light.to_color(color_resolution_context)
}

pub fn (style_value LightDarkStyleValue) absolutized(context ComputationContext) StyleValue {
	if scheme := context.color_scheme {
		if scheme == .dark {
			return style_value.dark.absolutized(context)
		}
		return style_value.light.absolutized(context)
	}

	return StyleValue(style_value)
}

pub fn (style_value LightDarkStyleValue) serialize(mode SerializationMode) string {
	// FIXME: We don't have enough information to determine the computed value here.
	return 'light-dark(${style_value.light.serialize(mode)}, ${style_value.dark.serialize(mode)})'
}

// --- ColorSchemeStyleValue ---

pub struct ColorSchemeStyleValue {
pub mut:
	schemes_ []string
	only_    bool
}

pub fn ColorSchemeStyleValue.create(schemes []string, only bool) ColorSchemeStyleValue {
	return ColorSchemeStyleValue{
		schemes_: schemes
		only_: only
	}
}

pub fn ColorSchemeStyleValue.normal() ColorSchemeStyleValue {
	return ColorSchemeStyleValue.create([]string{}, false)
}

pub fn (style_value ColorSchemeStyleValue) schemes() []string {
	return style_value.schemes_
}

pub fn (style_value ColorSchemeStyleValue) only() bool {
	return style_value.only_
}

pub fn (style_value ColorSchemeStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if style_value.schemes_.len == 0 {
		return 'normal'
	}

	mut result := ''
	for i, scheme in style_value.schemes_ {
		if i != 0 {
			result += ' '
		}
		result += serialize_an_identifier(scheme)
	}

	if style_value.only_ {
		result += ' only'
	}
	return result
}

// --- AbstractImageStyleValue and image resources ---

pub enum GradientRepeating {
	yes
	no
}

pub struct ColorStop {
pub mut:
	color           StyleValue
	position        ?StyleValue
	second_position ?StyleValue
}

pub struct ColorStopListElement {
pub mut:
	transition_hint ?StyleValue
	color_stop      ColorStop
}

pub fn (element ColorStopListElement) absolutized(context ComputationContext) ColorStopListElement {
	transition_hint := if hint := element.transition_hint {
		?StyleValue(hint.absolutized(context))
	} else {
		?StyleValue(none)
	}
	position := if value := element.color_stop.position {
		?StyleValue(value.absolutized(context))
	} else {
		?StyleValue(none)
	}
	second_position := if value := element.color_stop.second_position {
		?StyleValue(value.absolutized(context))
	} else {
		?StyleValue(none)
	}

	return ColorStopListElement{
		transition_hint: transition_hint
		color_stop: ColorStop{
			color: element.color_stop.color.absolutized(context)
			position: position
			second_position: second_position
		}
	}
}

pub fn serialize_color_stop_list(color_stop_list []ColorStopListElement, mode SerializationMode) string {
	mut parts := []string{}
	for element in color_stop_list {
		mut serialized := ''
		if transition_hint := element.transition_hint {
			serialized += transition_hint.serialize(mode)
			serialized += ', '
		}

		serialized += element.color_stop.color.serialize(mode)
		if position := element.color_stop.position {
			serialized += ' '
			serialized += position.serialize(mode)
		}
		if second_position := element.color_stop.second_position {
			serialized += ' '
			serialized += second_position.serialize(mode)
		}
		parts << serialized
	}
	return parts.join(', ')
}

pub type ImageStyleValueClientCallback = fn (voidptr)

pub struct ImageStyleValueClient {
pub:
	target     voidptr
	did_update ImageStyleValueClientCallback
}

@[heap]
struct ImageStyleValueClientState {
mut:
	clients             []ImageStyleValueClient
	callback_registered bool
}

fn (state &ImageStyleValueClientState) notify_clients() {
	for client in state.clients.clone() {
		client.did_update(client.target)
	}
}

pub struct ImageStyleValue {
pub mut:
	resource_request_    ?&dom.SharedResourceRequest
	style_sheet_         ?&CSSStyleSheet
	url_                 URL
	document_            ?&dom.Document
	current_frame_index_ uint
	loops_completed_     uint
	image_data_          ?dom.SharedDecodedImageData
	did_request_resource bool
mut:
	client_state_ &ImageStyleValueClientState = &ImageStyleValueClientState{}
}

pub type ImageSetImageStyleValue = ConicGradientStyleValue
	| ImageStyleValue
	| LinearGradientStyleValue
	| RadialGradientStyleValue

pub type ImageSetResolutionStyleValue = CalculatedStyleValue | ResolutionStyleValue

pub struct ImageSetOption {
pub mut:
	image      ImageSetImageStyleValue
	resolution ImageSetResolutionStyleValue
	type_      ?string
}

pub struct ImageSetStyleValue {
pub mut:
	options_        []ImageSetOption
	style_sheet_    ?&CSSStyleSheet
	selected_index_ int = -1
}

pub fn ImageSetStyleValue.create(options []ImageSetOption) ImageSetStyleValue {
	return ImageSetStyleValue{
		options_: options.clone()
	}
}

fn (image ImageSetImageStyleValue) serialize(mode SerializationMode) string {
	return match image {
		ConicGradientStyleValue { image.serialize(mode) }
		ImageStyleValue { image.serialize(mode) }
		LinearGradientStyleValue { image.serialize(mode) }
		RadialGradientStyleValue { image.serialize(mode) }
	}
}

fn (image ImageSetImageStyleValue) absolutized(context ComputationContext) ImageSetImageStyleValue {
	return match image {
		ConicGradientStyleValue { ImageSetImageStyleValue(image.absolutized(context)) }
		ImageStyleValue { ImageSetImageStyleValue(image.absolutized(context)) }
		LinearGradientStyleValue { ImageSetImageStyleValue(image.absolutized(context)) }
		RadialGradientStyleValue { ImageSetImageStyleValue(image.absolutized(context)) }
	}
}

fn (resolution ImageSetResolutionStyleValue) serialize(mode SerializationMode) string {
	return match resolution {
		CalculatedStyleValue { resolution.serialize(mode) }
		ResolutionStyleValue { resolution.serialize(mode) }
	}
}

fn (resolution ImageSetResolutionStyleValue) dots_per_pixel() ?f64 {
	return match resolution {
		CalculatedStyleValue {
			resolution.resolve_resolution(CalculationResolutionContext{})?.to_dots_per_pixel()
		}
		ResolutionStyleValue { resolution.resolution().to_dots_per_pixel() }
	}
}

pub fn (style_value ImageSetStyleValue) serialize(mode SerializationMode) string {
	mut options := []string{cap: style_value.options_.len}
	for option in style_value.options_ {
		mut serialized := '${option.image.serialize(mode)} ${option.resolution.serialize(mode)}'
		if type_ := option.type_ {
			serialized += ' type("${type_.replace('\\', '\\\\').replace('"', '\\"')}")'
		}
		options << serialized
	}
	return 'image-set(${options.join(', ')})'
}

pub fn (style_value ImageSetStyleValue) equals(other ImageSetStyleValue) bool {
	return style_value.serialize(.normal) == other.serialize(.normal)
}

pub fn (style_value ImageSetStyleValue) absolutized(context ComputationContext) ImageSetStyleValue {
	mut options := []ImageSetOption{cap: style_value.options_.len}
	for option in style_value.options_ {
		mut resolution := option.resolution
		if option.resolution is CalculatedStyleValue {
			absolutized := option.resolution.absolutized(context)
			resolution = image_set_resolution_from_absolutized_value(absolutized) or {
				option.resolution
			}
		}
		options << ImageSetOption{
			image: option.image.absolutized(context)
			resolution: resolution
			type_: option.type_
		}
	}
	return ImageSetStyleValue.create(options)
}

fn image_set_resolution_from_absolutized_value(value StyleValue) ?ImageSetResolutionStyleValue {
	return match value {
		CalculatedStyleValue { ImageSetResolutionStyleValue(value) }
		ResolutionStyleValue { ImageSetResolutionStyleValue(value) }
		else { none }
	}
}

pub fn (style_value ImageSetStyleValue) select_image_index(device_pixels_per_css_pixel f64) ?int {
	mut best_below_index := -1
	mut best_below_resolution := -1.0
	mut best_above_index := -1
	mut best_above_resolution := f64(1.7976931348623157e+308)
	for index, option in style_value.options_ {
		if type_ := option.type_ {
			if !platform.is_supported_image_type(type_) {
				continue
			}
		}
		resolution := option.resolution.dots_per_pixel() or { continue }
		if resolution >= device_pixels_per_css_pixel {
			if resolution < best_above_resolution {
				best_above_index = index
				best_above_resolution = resolution
			}
		} else if resolution > best_below_resolution {
			best_below_index = index
			best_below_resolution = resolution
		}
	}
	if best_above_index >= 0 {
		return best_above_index
	}
	if best_below_index >= 0 {
		return best_below_index
	}
	return none
}

pub fn (mut style_value ImageSetStyleValue) load_any_resources(mut document dom.Document, device_pixels_per_css_pixel f64) {
	style_value.selected_index_ = style_value.select_image_index(device_pixels_per_css_pixel) or { return }
	mut option := style_value.options_[style_value.selected_index_]
	match option.image {
		ImageStyleValue {
			option.image.set_style_sheet(style_value.style_sheet_)
			option.image.load_any_resources(mut document)
		}
		else {}
	}
	style_value.options_[style_value.selected_index_] = option
}

pub fn (mut style_value ImageSetStyleValue) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	style_value.style_sheet_ = style_sheet
	for index := 0; index < style_value.options_.len; index++ {
		mut option := style_value.options_[index]
		if type_ := option.type_ {
			if !platform.is_supported_image_type(type_) {
				continue
			}
		}
		match option.image {
			ImageStyleValue { option.image.set_style_sheet(style_sheet) }
			else {}
		}
		style_value.options_[index] = option
	}
}

pub fn (style_value ImageSetStyleValue) selected_image() ?ImageSetImageStyleValue {
	if style_value.selected_index_ < 0 || style_value.selected_index_ >= style_value.options_.len {
		return none
	}
	return style_value.options_[style_value.selected_index_].image
}

pub fn (style_value ImageSetStyleValue) image_for_device_pixel_ratio(device_pixels_per_css_pixel f64) ?ImageSetImageStyleValue {
	index := style_value.select_image_index(device_pixels_per_css_pixel)?
	return style_value.options_[index].image
}

pub fn (style_value ImageSetStyleValue) image_url_for_device_pixel_ratio(device_pixels_per_css_pixel f64) ?ImageStyleValue {
	image := style_value.image_for_device_pixel_ratio(device_pixels_per_css_pixel)?
	return match image {
		ImageStyleValue { image }
		else { none }
	}
}

pub fn (style_value ImageSetStyleValue) is_paintable() bool {
	image := style_value.selected_image() or { return false }
	return match image {
		ImageStyleValue { image.is_paintable() }
		ConicGradientStyleValue, LinearGradientStyleValue, RadialGradientStyleValue { true }
	}
}

// ImageSetStyleValue::natural_size(): the selected candidate's natural size is
// scaled by the candidate's resolution.
fn (style_value ImageSetStyleValue) selected_resolution() f64 {
	if style_value.selected_index_ < 0 || style_value.selected_index_ >= style_value.options_.len {
		return 1.0
	}
	resolution := style_value.options_[style_value.selected_index_].resolution.dots_per_pixel() or {
		return 1.0
	}
	return if resolution > 0 { resolution } else { 1.0 }
}

pub fn (style_value ImageSetStyleValue) natural_width() ?CSSPixels {
	image := style_value.selected_image() or { return none }
	width := match image {
		ImageStyleValue { image.natural_width() or { return none } }
		else { return none }
	}
	return CSSPixels.nearest_value_for(width.to_double() / style_value.selected_resolution())
}

pub fn (style_value ImageSetStyleValue) natural_height() ?CSSPixels {
	image := style_value.selected_image() or { return none }
	height := match image {
		ImageStyleValue { image.natural_height() or { return none } }
		else { return none }
	}
	return CSSPixels.nearest_value_for(height.to_double() / style_value.selected_resolution())
}

pub fn (style_value ImageSetStyleValue) natural_aspect_ratio() ?CSSPixelFraction {
	image := style_value.selected_image() or { return none }
	return match image {
		ImageStyleValue { image.natural_aspect_ratio() }
		else { none }
	}
}

pub fn ImageStyleValue.create(url URL) ImageStyleValue {
	return ImageStyleValue{
		url_: url
	}
}

pub fn ImageStyleValue.create_from_url_string(url string) ImageStyleValue {
	return ImageStyleValue.create(URL.from_url(url))
}

pub fn (mut style_value ImageStyleValue) load_any_resources(mut document dom.Document) {
	if style_value.resource_request_ != none {
		return
	}
	style_value.document_ = &document

	rule_or_declaration := RuleOrDeclaration{
		environment_settings_object: CSSFetchEnvironmentSettings.from_document(&document)
		value: RuleOrDeclarationValue(RuleOrDeclarationRule{
			parent_style_sheet: style_value.style_sheet_
		})
	}

	style_value.resource_request_ = fetch_an_external_image_for_a_stylesheet(StyleResourceURL(style_value.url_), rule_or_declaration, mut document)
	style_value.did_request_resource = style_value.resource_request_ != none
	if mut resource_request := style_value.resource_request_ {
		mut client_state := style_value.client_state_
		if !client_state.callback_registered {
			client_state.callback_registered = true
			resource_request.add_callbacks(fn [client_state] () {
				client_state.notify_clients()
			}, none)
		}
	}
	// Boundary: Animated-image timers depend on platform timer APIs that are
	// outside this V StyleValue translation.
}

pub fn (mut style_value ImageStyleValue) animate() {
	image_data := style_value.image_data() or { return }
	if image_data.frame_count() <= 0 {
		return
	}

	style_value.current_frame_index_ = (style_value.current_frame_index_ + 1) % image_data.frame_count()
	if style_value.current_frame_index_ == image_data.frame_count() - 1 {
		style_value.loops_completed_++
		if style_value.loops_completed_ > 0
			&& style_value.loops_completed_ == image_data.loop_count() {
			return
		}
	}
}

pub fn (style_value ImageStyleValue) is_paintable() bool {
	return style_value.image_data() != none
}

pub fn (style_value ImageStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.url_.to_string()
}

pub fn (style_value ImageStyleValue) equals(other ImageStyleValue) bool {
	return style_value.url_.equals(other.url_)
}

pub fn (style_value ImageStyleValue) natural_width() ?CSSPixels {
	if image_data := style_value.image_data() {
		if width := image_data.intrinsic_width() {
			return CSSPixels.nearest_value_for(width)
		}
	}
	return none
}

pub fn (style_value ImageStyleValue) natural_height() ?CSSPixels {
	if image_data := style_value.image_data() {
		if height := image_data.intrinsic_height() {
			return CSSPixels.nearest_value_for(height)
		}
	}
	return none
}

pub fn (style_value ImageStyleValue) natural_aspect_ratio() ?CSSPixelFraction {
	if image_data := style_value.image_data() {
		if width := image_data.intrinsic_width() {
			if height := image_data.intrinsic_height() {
				if height != 0 {
					return CSSPixelFraction.new(CSSPixels.nearest_value_for(width), CSSPixels.nearest_value_for(height))
				}
			}
		}
		if ratio := image_data.intrinsic_aspect_ratio() {
			return CSSPixelFraction.new(CSSPixels.nearest_value_for(ratio), CSSPixels.new(1))
		}
	}
	return none
}

pub fn (style_value ImageStyleValue) image_data() ?dom.SharedDecodedImageData {
	if resource_request := style_value.resource_request_ {
		if shared_data := resource_request.image_data() {
			return shared_data.data
		}
	}
	return style_value.image_data_
}

pub fn (mut style_value ImageStyleValue) set_image_data(image_data dom.SharedDecodedImageData) {
	style_value.image_data_ = image_data
}

pub fn (style_value ImageStyleValue) current_frame() ?&dom.DecodedImageFrame_ {
	image_data := style_value.image_data() or { return none }
	return image_data.frame(style_value.current_frame_index_)
}

pub fn (style_value ImageStyleValue) color_if_single_pixel_bitmap() ?Color {
	frame := style_value.current_frame() or { return none }
	bitmap := frame.bitmap()
	if bitmap.width == 1 && bitmap.height == 1 && bitmap.data.len >= 4 {
		return Color.rgba(bitmap.data[0], bitmap.data[1], bitmap.data[2], bitmap.data[3])
	}
	return none
}

pub fn (mut style_value ImageStyleValue) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	style_value.style_sheet_ = style_sheet
	// FIXME: CSSStyleSheet stores DOM-side placeholders for pending image values. Register this image once the
	// StyleValue hierarchy is represented by GC references in the V port.
}

pub fn (style_value ImageStyleValue) absolutized(context ComputationContext) ImageStyleValue {
	_ = context
	if style_value.url_.url().len == 0 {
		return style_value
	}

	// FIXME: The spec has been updated to handle this better. The computation of the base URL here is roughly based on:
	//        https://drafts.csswg.org/css-values-4/#style-resource-base-url
	//        https://github.com/w3c/csswg-drafts/pull/12261
	mut base_url := ?string(none)
	if style_sheet := style_value.style_sheet_ {
		if sheet_base_url := style_sheet.base_url {
			base_url = sheet_base_url
		} else if location := style_sheet.base.location {
			base_url = location
		} else if document := style_sheet.owning_document() {
			base_url = document.base_url().to_string()
		}
	} else if document := style_value.document_ {
		base_url = document.base_url().to_string()
	}

	if base := base_url {
		if resolved_url := resolve_css_url_with_base(style_value.url_.url(), base) {
			return ImageStyleValue.create(URL.from_url(resolved_url))
		}
	}

	return style_value
}

pub fn (style_value ImageStyleValue) register_client(client ImageStyleValueClient) {
	mut state := style_value.client_state_
	for existing in state.clients {
		if existing.target == client.target {
			return
		}
	}
	state.clients << client
}

pub fn (style_value ImageStyleValue) unregister_client(client voidptr) {
	mut state := style_value.client_state_
	mut kept := []ImageStyleValueClient{}
	for existing in state.clients {
		if existing.target != client {
			kept << existing
		}
	}
	state.clients = kept
}

pub fn (style_value ImageStyleValue) notify_clients() {
	style_value.client_state_.notify_clients()
}

pub type CSSImageSourceStyleValue = ConicGradientStyleValue
	| ImageSetStyleValue
	| ImageStyleValue
	| LinearGradientStyleValue
	| RadialGradientStyleValue
	| StyleValue

pub fn (style_value CSSImageSourceStyleValue) serialize(mode SerializationMode) string {
	return match style_value {
		ConicGradientStyleValue { style_value.serialize(mode) }
		ImageSetStyleValue { style_value.serialize(mode) }
		ImageStyleValue { style_value.serialize(mode) }
		LinearGradientStyleValue { style_value.serialize(mode) }
		RadialGradientStyleValue { style_value.serialize(mode) }
		StyleValue { style_value.serialize(mode) }
	}
}

pub fn (style_value CSSImageSourceStyleValue) absolutized(context ComputationContext) CSSImageSourceStyleValue {
	return match style_value {
		ConicGradientStyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
		ImageSetStyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
		ImageStyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
		LinearGradientStyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
		RadialGradientStyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
		StyleValue { CSSImageSourceStyleValue(style_value.absolutized(context)) }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssimagevalue
pub struct CSSImageValue {
pub mut:
	source_value_ CSSImageSourceStyleValue
}

pub fn CSSImageValue.create(source_value CSSImageSourceStyleValue) CSSImageValue {
	return CSSImageValue{
		source_value_: source_value
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#stylevalue-serialization
pub fn (style_value CSSImageValue) to_string() string {
	// AD-HOC: The spec doesn't say how to serialize this, as it's intentionally a black box.
	//         We just rely on CSSStyleValue serializing its held StyleValue.
	return style_value.source_value_.serialize(.normal)
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (style_value CSSImageValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !CSSImageSourceStyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	// NB: https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue-match-a-grammar doesn't list CSSImageValue, but
	//     we should match <image>.
	matches_grammar := if property.is_custom_property() {
		// FIXME: If this is a registered custom property, check if that allows <image>.
		true
	} else {
		if property_id := property.id() {
			property_accepts_type(property_id, .image)
		} else {
			false
		}
	}
	if perform_type_check == .yes && !matches_grammar {
		return error("Property '${property.name()}' does not accept <image>")
	}

	//     FIXME: If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//            is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//            fresh CSSMathSum whose values internal slot contains only that part of value.

	//     Return the value.
	return style_value.source_value_
}

// --- LinearGradientStyleValue ---

// Note: The sides must be before the corners in this enum (as this order is used in parsing).
pub enum LinearGradientSideOrCorner {
	top
	bottom
	left
	right
	top_left
	top_right
	bottom_left
	bottom_right
}

pub type LinearGradientDirection = LinearGradientSideOrCorner | StyleValue

pub enum LinearGradientType {
	standard
	webkit
}

pub struct LinearGradientStyleValue {
pub mut:
	direction_                  LinearGradientDirection
	color_stop_list_            []ColorStopListElement
	gradient_type_              LinearGradientType
	repeating_                  GradientRepeating
	color_interpolation_method_ ?ColorInterpolationMethodStyleValue
	color_syntax_               ColorSyntax
}

fn gradient_color_syntax(color StyleValue) ColorSyntax {
	return match color {
		RGBColorStyleValue { color.color_syntax_ }
		HSLColorStyleValue { color.color_syntax_ }
		HWBColorStyleValue { color.color_syntax_ }
		KeywordStyleValue, ColorStyleValue { .legacy }
		else { .modern }
	}
}

fn gradient_color_stop_list_syntax(color_stop_list []ColorStopListElement) ColorSyntax {
	for stop in color_stop_list {
		if gradient_color_syntax(stop.color_stop.color) == .modern {
			return .modern
		}
	}
	return .legacy
}

pub fn LinearGradientStyleValue.create(direction LinearGradientDirection, color_stop_list []ColorStopListElement, type_ LinearGradientType, repeating GradientRepeating, color_interpolation_method ?ColorInterpolationMethodStyleValue) LinearGradientStyleValue {
	return LinearGradientStyleValue{
		direction_: direction
		color_stop_list_: color_stop_list
		gradient_type_: type_
		repeating_: repeating
		color_interpolation_method_: color_interpolation_method
		color_syntax_: gradient_color_stop_list_syntax(color_stop_list)
	}
}

fn side_or_corner_to_string(value LinearGradientSideOrCorner) string {
	return match value {
		.top { 'top' }
		.bottom { 'bottom' }
		.left { 'left' }
		.right { 'right' }
		.top_left { 'left top' }
		.top_right { 'right top' }
		.bottom_left { 'left bottom' }
		.bottom_right { 'right bottom' }
	}
}

pub fn (style_value LinearGradientStyleValue) is_repeating() bool {
	return style_value.repeating_ == .yes
}

pub fn (style_value LinearGradientStyleValue) is_paintable() bool {
	return true
}

pub fn (style_value LinearGradientStyleValue) interpolation_method() ColorInterpolationMethod {
	if color_interpolation_method := style_value.color_interpolation_method_ {
		return color_interpolation_method.color_interpolation_method()
	}

	return ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
}

pub fn (style_value LinearGradientStyleValue) serialize(mode SerializationMode) string {
	default_direction := if style_value.gradient_type_ == .webkit {
		LinearGradientDirection(LinearGradientSideOrCorner.top)
	} else {
		LinearGradientDirection(LinearGradientSideOrCorner.bottom)
	}
	has_direction := style_value.direction_ != default_direction
	has_color_space := if color_interpolation_method := style_value.color_interpolation_method_ {
		color_interpolation_method.color_interpolation_method() != ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
	} else {
		false
	}

	mut result := ''
	if style_value.gradient_type_ == .webkit {
		result += '-webkit-'
	}
	if style_value.is_repeating() {
		result += 'repeating-'
	}
	result += 'linear-gradient('
	if has_direction {
		match style_value.direction_ {
			LinearGradientSideOrCorner {
				if style_value.gradient_type_ == .standard {
					result += 'to '
				}
				result += side_or_corner_to_string(style_value.direction_)
			}
			StyleValue {
				result += style_value.direction_.serialize(mode)
			}
		}

		if has_color_space {
			result += ' '
		}
	}

	if has_color_space {
		result += (style_value.color_interpolation_method_ or {
			ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(RectangularColorSpace.srgb))
		}).serialize(mode)
	}

	if has_direction || has_color_space {
		result += ', '
	}

	result += serialize_color_stop_list(style_value.color_stop_list_, mode)
	result += ')'
	return result
}

pub fn (style_value LinearGradientStyleValue) absolutized(context ComputationContext) LinearGradientStyleValue {
	mut absolutized_color_stops := []ColorStopListElement{}
	for color_stop in style_value.color_stop_list_ {
		absolutized_color_stops << color_stop.absolutized(context)
	}
	absolutized_color_interpolation_method := if method := style_value.color_interpolation_method_ {
		?ColorInterpolationMethodStyleValue(method.absolutized(context))
	} else {
		?ColorInterpolationMethodStyleValue(none)
	}

	return LinearGradientStyleValue.create(style_value.direction_, absolutized_color_stops, style_value.gradient_type_, style_value.repeating_, absolutized_color_interpolation_method)
}

pub fn (style_value LinearGradientStyleValue) angle_degrees(gradient_size CSSPixelSize) f64 {
	corner_angle_degrees := fn [gradient_size] () f64 {
		return math.atan2(gradient_size.height().to_double(), gradient_size.width().to_double()) * 180.0 / math.pi
	}
	return match style_value.direction_ {
		LinearGradientSideOrCorner {
			mut angle := match style_value.direction_ {
				.top { 0.0 }
				.bottom { 180.0 }
				.left { 270.0 }
				.right { 90.0 }
				.top_right { corner_angle_degrees() }
				.bottom_left { corner_angle_degrees() + 180.0 }
				.top_left { -corner_angle_degrees() }
				.bottom_right { -(corner_angle_degrees() + 180.0) }
			}

			// Note: For unknowable reasons the angles are opposite on the -webkit- version
			if style_value.gradient_type_ == .webkit {
				angle += 180.0
			}
			angle
		}
		StyleValue {
			angle_from_style_value(style_value.direction_).to_degrees()
		}
	}
}

fn angle_from_style_value(style_value StyleValue) Angle {
	if style_value is AngleStyleValue {
		return style_value.angle()
	}
	if style_value.is_calculated() {
		return style_value.as_calculated().resolve_angle(CalculationResolutionContext{}) or {
			Angle.make_degrees(0)
		}
	}
	return Angle.make_degrees(0)
}

// --- RadialGradientStyleValue ---

pub enum RadialGradientEndingShape {
	circle
	ellipse
}

pub struct RadialGradientStyleValue {
pub mut:
	ending_shape_               RadialGradientEndingShape
	size_                       StyleValue
	position_                   PositionStyleValue
	color_stop_list_            []ColorStopListElement
	repeating_                  GradientRepeating
	color_interpolation_method_ ?ColorInterpolationMethodStyleValue
	color_syntax_               ColorSyntax
	webkit_                     bool
	webkit_shape_specified_     bool
	webkit_extent_keyword_      string
}

pub fn RadialGradientStyleValue.create(ending_shape RadialGradientEndingShape, size StyleValue, position PositionStyleValue, color_stop_list []ColorStopListElement, repeating GradientRepeating, color_interpolation_method ?ColorInterpolationMethodStyleValue) RadialGradientStyleValue {
	return RadialGradientStyleValue{
		ending_shape_: ending_shape
		size_: size
		position_: position
		color_stop_list_: color_stop_list
		repeating_: repeating
		color_interpolation_method_: color_interpolation_method
		color_syntax_: gradient_color_stop_list_syntax(color_stop_list)
	}
}

pub fn (style_value RadialGradientStyleValue) is_repeating() bool {
	return style_value.repeating_ == .yes
}

pub fn (style_value RadialGradientStyleValue) is_paintable() bool {
	return true
}

pub fn (style_value RadialGradientStyleValue) interpolation_method() ColorInterpolationMethod {
	if color_interpolation_method := style_value.color_interpolation_method_ {
		return color_interpolation_method.color_interpolation_method()
	}

	return ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
}

pub fn (style_value RadialGradientStyleValue) serialize(mode SerializationMode) string {
	if style_value.webkit_ {
		mut result := if style_value.is_repeating() { '-webkit-repeating-radial-gradient(' } else { '-webkit-radial-gradient(' }
		result += if style_value.position_.is_center(mode) { 'center' } else { style_value.position_.serialize(mode) }
		if style_value.webkit_shape_specified_ || style_value.webkit_extent_keyword_ != '' {
			result += ', ' + if style_value.ending_shape_ == .circle { 'circle' } else { 'ellipse' }
			result += ' ' + if style_value.webkit_extent_keyword_ != '' { style_value.webkit_extent_keyword_ } else { 'cover' }
		} else if size := style_value.size_.as_radial_size() {
			if size.components().len == 2 {
				result += ', ' + style_value.size_.serialize(mode)
			}
		}
		return result + ', ' + serialize_color_stop_list(style_value.color_stop_list_, mode) + ')'
	}
	mut result := ''
	if style_value.is_repeating() {
		result += 'repeating-'
	}
	result += 'radial-gradient('

	// Upstream checks the serialized radial-size to determine whether it should
	// be included. EndingShape affects resolution, but is not emitted separately.
	serialized_size := style_value.size_.serialize(mode)
	has_size := serialized_size != 'farthest-corner'
	has_position := !style_value.position_.is_center(mode)
	has_color_space := if color_interpolation_method := style_value.color_interpolation_method_ {
		color_interpolation_method.color_interpolation_method() != ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
	} else {
		false
	}

	if has_size {
		result += serialized_size
	}

	if has_position {
		if has_size {
			result += ' '
		}

		result += 'at '
		result += style_value.position_.serialize(mode)
	}

	if has_color_space {
		if has_size || has_position {
			result += ' '
		}

		result += (style_value.color_interpolation_method_ or {
			ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(RectangularColorSpace.srgb))
		}).serialize(mode)
	}

	if has_size || has_position || has_color_space {
		result += ', '
	}

	result += serialize_color_stop_list(style_value.color_stop_list_, mode)
	result += ')'
	return result
}

pub fn (style_value RadialGradientStyleValue) absolutized(context ComputationContext) RadialGradientStyleValue {
	mut absolutized_color_stops := []ColorStopListElement{}
	for color_stop in style_value.color_stop_list_ {
		absolutized_color_stops << color_stop.absolutized(context)
	}
	absolutized_color_interpolation_method := if method := style_value.color_interpolation_method_ {
		?ColorInterpolationMethodStyleValue(method.absolutized(context))
	} else {
		?ColorInterpolationMethodStyleValue(none)
	}

	mut result := RadialGradientStyleValue.create(style_value.ending_shape_, style_value.size_.absolutized(context), (style_value.position_.absolutized(context) as PositionStyleValue), absolutized_color_stops, style_value.repeating_, absolutized_color_interpolation_method)
	result.webkit_ = style_value.webkit_
	result.webkit_shape_specified_ = style_value.webkit_shape_specified_
	result.webkit_extent_keyword_ = style_value.webkit_extent_keyword_
	return result
}

// --- ConicGradientStyleValue ---

pub struct ConicGradientStyleValue {
pub mut:
	from_angle_                 ?StyleValue
	position_                   PositionStyleValue
	color_stop_list_            []ColorStopListElement
	repeating_                  GradientRepeating
	color_interpolation_method_ ?ColorInterpolationMethodStyleValue
	color_syntax_               ColorSyntax
}

pub fn ConicGradientStyleValue.create(from_angle ?StyleValue, position PositionStyleValue, color_stop_list []ColorStopListElement, repeating GradientRepeating, color_interpolation_method ?ColorInterpolationMethodStyleValue) ConicGradientStyleValue {
	return ConicGradientStyleValue{
		from_angle_: from_angle
		position_: position
		color_stop_list_: color_stop_list
		repeating_: repeating
		color_interpolation_method_: color_interpolation_method
		color_syntax_: gradient_color_stop_list_syntax(color_stop_list)
	}
}

pub fn (style_value ConicGradientStyleValue) is_repeating() bool {
	return style_value.repeating_ == .yes
}

pub fn (style_value ConicGradientStyleValue) is_paintable() bool {
	return true
}

pub fn (style_value ConicGradientStyleValue) interpolation_method() ColorInterpolationMethod {
	if color_interpolation_method := style_value.color_interpolation_method_ {
		return color_interpolation_method.color_interpolation_method()
	}

	return ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
}

pub fn (style_value ConicGradientStyleValue) serialize(mode SerializationMode) string {
	mut result := ''
	if style_value.is_repeating() {
		result += 'repeating-'
	}
	result += 'conic-gradient('

	has_from_angle := style_value.from_angle_ != none
	has_at_position := !style_value.position_.is_center(mode)
	has_color_space := if color_interpolation_method := style_value.color_interpolation_method_ {
		color_interpolation_method.color_interpolation_method() != ColorInterpolationMethodStyleValue.default_color_interpolation_method(style_value.color_syntax_)
	} else {
		false
	}

	if from_angle := style_value.from_angle_ {
		result += 'from '
		result += from_angle.serialize(mode)
	}
	if has_at_position {
		if has_from_angle {
			result += ' '
		}
		result += 'at '
		result += style_value.position_.serialize(mode)
	}
	if has_color_space {
		if has_from_angle || has_at_position {
			result += ' '
		}
		result += (style_value.color_interpolation_method_ or {
			ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(RectangularColorSpace.srgb))
		}).serialize(mode)
	}
	if has_from_angle || has_at_position || has_color_space {
		result += ', '
	}
	result += serialize_color_stop_list(style_value.color_stop_list_, mode)
	result += ')'
	return result
}

pub fn (style_value ConicGradientStyleValue) absolutized(context ComputationContext) ConicGradientStyleValue {
	mut absolutized_color_stops := []ColorStopListElement{}
	for color_stop in style_value.color_stop_list_ {
		absolutized_color_stops << color_stop.absolutized(context)
	}
	absolutized_from_angle := if from_angle := style_value.from_angle_ {
		?StyleValue(from_angle.absolutized(context))
	} else {
		?StyleValue(none)
	}
	absolutized_color_interpolation_method := if method := style_value.color_interpolation_method_ {
		?ColorInterpolationMethodStyleValue(method.absolutized(context))
	} else {
		?ColorInterpolationMethodStyleValue(none)
	}

	return ConicGradientStyleValue.create(absolutized_from_angle, (style_value.position_.absolutized(context) as PositionStyleValue), absolutized_color_stops, style_value.repeating_, absolutized_color_interpolation_method)
}

pub fn (style_value ConicGradientStyleValue) angle_degrees() f64 {
	if from_angle := style_value.from_angle_ {
		return angle_from_style_value(from_angle).to_degrees()
	}
	return 0
}
