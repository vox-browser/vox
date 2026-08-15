// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of a few self-contained Color operations from LibGfx/Color.h — the HSL->RGB constructor
// (from_hsl/from_hsla), the relative luminosity, and the RGB inversion. Color-space conversions
// (OKLab/Lab/Display-P3/...) and premultiplied-alpha handling are out of scope.
module color

import math

fn fmin(a f64, b f64) f64 {
	return if a < b { a } else { b }
}

fn fmax(a f64, b f64) f64 {
	return if a > b { a } else { b }
}

fn clamp_unit(value f64) f64 {
	if value < 0.0 {
		return 0.0
	}
	if value > 1.0 {
		return 1.0
	}
	return value
}

// Round to nearest (half away from zero) and clamp to the 0..255 u8 range.
fn round_clamp_u8(value f64) u8 {
	rounded := math.round(value)
	if rounded < 0.0 {
		return 0
	}
	if rounded > 255.0 {
		return 255
	}
	return u8(rounded)
}

// One channel of the CSS Color 3 HSL-to-RGB conversion.
fn hsl_to_rgb_channel(h f64, s f64, l f64, offset f64) f64 {
	k := math.fmod(offset + h / 30.0, 12.0)
	a := s * fmin(l, 1.0 - l)
	return l - a * fmax(-1.0, fmin(fmin(k - 3.0, 9.0 - k), 1.0))
}

// https://www.w3.org/TR/css-color-3/#hsl-color — an opaque color from hue (degrees), saturation, and
// lightness.
pub fn Color.from_hsl(h_degrees f64, s f64, l f64) Color {
	return Color.from_hsla(h_degrees, s, l, 1.0)
}

pub fn Color.from_hsla(h_degrees f64, saturation f64, lightness f64, alpha f64) Color {
	// Wrap hue into [0, 360) and clamp the others into [0, 1].
	mut h := math.fmod(h_degrees, 360.0)
	if h < 0.0 {
		h += 360.0
	}
	s := clamp_unit(saturation)
	l := clamp_unit(lightness)
	a := clamp_unit(alpha)
	r := hsl_to_rgb_channel(h, s, l, 0.0)
	g := hsl_to_rgb_channel(h, s, l, 8.0)
	b := hsl_to_rgb_channel(h, s, l, 4.0)
	return Color{
		red:   round_clamp_u8(r * 255.0)
		green: round_clamp_u8(g * 255.0)
		blue:  round_clamp_u8(b * 255.0)
		alpha: round_clamp_u8(a * 255.0)
	}
}

// The relative luminosity (Rec. 709 coefficients), rounded to a u8.
pub fn (c Color) luminosity() u8 {
	value := f64(c.red) * 0.2126 + f64(c.green) * 0.7152 + f64(c.blue) * 0.0722
	return round_clamp_u8(value)
}

// The color with its RGB channels inverted; the alpha is preserved.
pub fn (c Color) inverted() Color {
	return Color{
		red:   ~c.red
		green: ~c.green
		blue:  ~c.blue
		alpha: c.alpha
	}
}
