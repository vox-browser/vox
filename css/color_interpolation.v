// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module css

import math

// A direct translation of CSS/ColorInterpolation. Keeping floating-point
// components until final color resolution avoids reducing wide-gamut and
// polar interpolation to 8-bit sRGB at every intermediate step.
pub struct InterpolationColorComponents {
pub mut:
	values [4]f64
}

fn interpolation_color_components(c1 f64, c2 f64, c3 f64, alpha f64) InterpolationColorComponents {
	return InterpolationColorComponents{
		values: [c1, c2, c3, alpha]!
	}
}

fn (components InterpolationColorComponents) component(index int) f64 {
	return components.values[index]
}

fn (mut components InterpolationColorComponents) set_component(index int, value f64) {
	components.values[index] = value
}

fn (components InterpolationColorComponents) alpha() f64 {
	return components.values[3]
}

fn (mut components InterpolationColorComponents) set_alpha(value f64) {
	components.values[3] = value
}

pub struct MissingColorComponents {
pub mut:
	components [3]bool
	alpha      bool
}

enum ColorComponentCategory {
	red
	green
	blue
	lightness
	colorfulness
	hue
	opponent_a
	opponent_b
	not_analogous
}

struct ColorComponentCategories {
	components [3]ColorComponentCategory = [ColorComponentCategory.not_analogous,
		.not_analogous, .not_analogous]!
}

struct ColorInterpolationPolicy {
	use_legacy_output         bool
	color_interpolation_method ColorInterpolationMethod
}

struct ColorInterpolationSpaceState {
mut:
	from_components         InterpolationColorComponents
	to_components           InterpolationColorComponents
	from_missing            MissingColorComponents
	to_missing              MissingColorComponents
	hue_index               int
	hue_interpolation_method HueInterpolationMethod = .shorter
	polar_color_space       PolarColorSpace = .hsl
	rectangular_color_space RectangularColorSpace = .srgb
	is_polar                bool
	polar_target_categories ColorComponentCategories
}

pub struct InterpolatedColor {
pub mut:
	components InterpolationColorComponents

pub:
	missing    MissingColorComponents
mut:
	policy ColorInterpolationPolicy
	state  ColorInterpolationSpaceState
}

struct PreparedInterpolationColor {
mut:
	missing_components MissingColorComponents
	source_categories  ColorComponentCategories
	native_components  ?InterpolationColorComponents
	srgb_components    ?InterpolationColorComponents
}

fn interpolate_color_component(from f64, to f64, delta f64) f64 {
	return from + (to - from) * delta
}

fn fixup_interpolation_hue(first_hue f64, second_hue f64, method HueInterpolationMethod) (f64, f64) {
	mut hue1 := first_hue
	mut hue2 := second_hue
	difference := hue2 - hue1
	match method {
		.shorter {
			if difference > 180 {
				hue1 += 360
			} else if difference < -180 {
				hue2 += 360
			}
		}
		.longer {
			if difference > 0 && difference < 180 {
				hue1 += 360
			} else if difference > -180 && difference <= 0 {
				hue2 += 360
			}
		}
		.increasing {
			if hue2 < hue1 {
				hue2 += 360
			}
		}
		.decreasing {
			if hue1 < hue2 {
				hue1 += 360
			}
		}
	}
	return hue1, hue2
}

fn map_color_components(components InterpolationColorComponents, mapper fn (f64) f64) InterpolationColorComponents {
	return interpolation_color_components(mapper(components.component(0)), mapper(components.component(1)), mapper(components.component(2)), components.alpha())
}

fn ci_srgb_to_linear(components InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(components, fn (component f64) f64 {
		sign := if component < 0 { -1.0 } else { 1.0 }
		absolute := math.abs(component)
		if absolute <= 0.04045 {
			return component / 12.92
		}
		return sign * math.pow((absolute + 0.055) / 1.055, 2.4)
	})
}

fn ci_linear_to_srgb(components InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(components, fn (component f64) f64 {
		sign := if component < 0 { -1.0 } else { 1.0 }
		absolute := math.abs(component)
		if absolute > 0.0031308 {
			return sign * (1.055 * math.pow(absolute, 1.0 / 2.4) - 0.055)
		}
		return 12.92 * component
	})
}

fn ci_linear_srgb_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	return interpolation_color_components(0.4123907992659595 * r + 0.35758433938387796 * g + 0.1804807884018343 * b, 0.2126390058715103 * r + 0.7151686787677559 * g + 0.07219231536073371 * b, 0.01933081871559185 * r + 0.11919477979462599 * g + 0.9505321522496606 * b, c.alpha())
}

fn ci_xyz65_to_linear_srgb(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(3.240970 * x - 1.537383 * y - 0.498611 * z, -0.969244 * x + 1.875968 * y + 0.041555 * z, 0.055630 * x - 0.203977 * y + 1.056972 * z, c.alpha())
}

fn ci_xyz65_to_xyz50(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(1.0479298208 * x + 0.0229468746 * y - 0.0501922295 * z, 0.0296278156 * x + 0.9904344482 * y - 0.0170738250 * z, -0.0092430581 * x + 0.0150551448 * y + 0.7518742814 * z, c.alpha())
}

fn ci_xyz50_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(0.9554734528 * x - 0.0230985368 * y + 0.0632593086 * z, -0.0283697094 * x + 1.0099954580 * y + 0.0210415381 * z, 0.0123140016 * x - 0.0205076964 * y + 1.3303659366 * z, c.alpha())
}

fn ci_xyz65_to_oklab(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	l := math.cbrt(0.8190224379967030 * x + 0.3619062600528904 * y - 0.1288737815209879 * z)
	m := math.cbrt(0.0329836539323885 * x + 0.9292868615863434 * y + 0.0361446663506424 * z)
	s := math.cbrt(0.0481771893596242 * x + 0.2642395317527308 * y + 0.6335478284694309 * z)
	return interpolation_color_components(0.2104542683093140 * l + 0.7936177747023054 * m - 0.0040720430116193 * s, 1.9779985324311684 * l - 2.4285922420485799 * m + 0.4505937096174110 * s, 0.0259040424655478 * l + 0.7827717124575296 * m - 0.8086757549230774 * s, c.alpha())
}

fn ci_oklab_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	lightness := c.component(0)
	a := c.component(1)
	b := c.component(2)
	mut l := lightness + 0.3963377774 * a + 0.2158037573 * b
	mut m := lightness - 0.1055613458 * a - 0.0638541728 * b
	mut s := lightness - 0.0894841775 * a - 1.2914855480 * b
	l *= l * l
	m *= m * m
	s *= s * s
	return interpolation_color_components(1.2268798758459243 * l - 0.5578149944602171 * m + 0.2813910456659647 * s, -0.0405757452148008 * l + 1.1122868032803170 * m - 0.0717110580655164 * s, -0.0763729366746601 * l - 0.4214933324022432 * m + 1.5869240198367816 * s, c.alpha())
}

fn ci_xyz50_to_lab(c InterpolationColorComponents) InterpolationColorComponents {
	kappa := 24389.0 / 27.0
	epsilon := 216.0 / 24389.0
	x_n := 0.3457 / 0.3585
	z_n := (1.0 - 0.3457 - 0.3585) / 0.3585
	f := fn [epsilon, kappa] (value f64) f64 {
		if value > epsilon {
			return math.cbrt(value)
		}
		return (kappa * value + 16.0) / 116.0
	}
	fx := f(c.component(0) / x_n)
	fy := f(c.component(1))
	fz := f(c.component(2) / z_n)
	return interpolation_color_components(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz), c.alpha())
}

fn ci_lab_to_xyz50(c InterpolationColorComponents) InterpolationColorComponents {
	kappa := 24389.0 / 27.0
	epsilon := 216.0 / 24389.0
	l := c.component(0)
	a := c.component(1)
	b := c.component(2)
	f1 := (l + 16) / 116
	f0 := a / 500 + f1
	f2 := f1 - b / 200
	compute := fn [epsilon, kappa] (f f64) f64 {
		cubed := f * f * f
		if cubed > epsilon {
			return cubed
		}
		return (116 * f - 16) / kappa
	}
	x_n := 0.3457 / 0.3585
	z_n := (1.0 - 0.3457 - 0.3585) / 0.3585
	x := x_n * compute(f0)
	y := if l > kappa * epsilon { math.pow((l + 16) / 116, 3) } else { l / kappa }
	z := z_n * compute(f2)
	return interpolation_color_components(x, y, z, c.alpha())
}

fn ci_rectangular_to_polar(c InterpolationColorComponents) InterpolationColorComponents {
	a := c.component(1)
	b := c.component(2)
	mut hue := math.atan2(b, a) * 180 / math.pi
	if hue < 0 {
		hue += 360
	}
	return interpolation_color_components(c.component(0), math.sqrt(a * a + b * b), hue, c.alpha())
}

fn ci_polar_to_rectangular(c InterpolationColorComponents) InterpolationColorComponents {
	radians := c.component(2) * math.pi / 180
	return interpolation_color_components(c.component(0), c.component(1) * math.cos(radians), c.component(1) * math.sin(radians), c.alpha())
}

fn ci_srgb_to_hsl(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	maximum := math.max(r, math.max(g, b))
	minimum := math.min(r, math.min(g, b))
	chroma := maximum - minimum
	lightness := (minimum + maximum) / 2
	mut hue := 0.0
	mut saturation := 0.0
	if chroma != 0 {
		if lightness != 0 && lightness != 1 {
			saturation = (maximum - lightness) / math.min(lightness, 1 - lightness)
		}
		if maximum == r {
			hue = (g - b) / chroma + if g < b { 6.0 } else { 0.0 }
		} else if maximum == g {
			hue = (b - r) / chroma + 2
		} else {
			hue = (r - g) / chroma + 4
		}
		hue *= 60
		if saturation < 0 {
			hue += 180
			saturation = math.abs(saturation)
		}
		if hue >= 360 {
			hue -= 360
		}
	}
	return interpolation_color_components(hue, saturation, lightness, c.alpha())
}

fn ci_hsl_to_srgb(c InterpolationColorComponents) InterpolationColorComponents {
	h := c.component(0)
	s := c.component(1)
	l := c.component(2)
	to_rgb := fn [h, s, l] (offset f64) f64 {
		k := math.fmod(offset + h / 30, 12)
		a := s * math.min(l, 1 - l)
		return l - a * math.max(-1.0, math.min(math.min(k - 3.0, 9.0 - k), 1.0))
	}
	return interpolation_color_components(to_rgb(0), to_rgb(8), to_rgb(4), c.alpha())
}

fn ci_srgb_to_hwb(c InterpolationColorComponents) InterpolationColorComponents {
	hsl := ci_srgb_to_hsl(c)
	maximum := math.max(c.component(0), math.max(c.component(1), c.component(2)))
	minimum := math.min(c.component(0), math.min(c.component(1), c.component(2)))
	return interpolation_color_components(hsl.component(0), minimum, 1 - maximum, c.alpha())
}

fn ci_hwb_to_srgb(c InterpolationColorComponents) InterpolationColorComponents {
	white := c.component(1)
	black := c.component(2)
	if white + black >= 1 {
		gray := white / (white + black)
		return interpolation_color_components(gray, gray, gray, c.alpha())
	}
	rgb := ci_hsl_to_srgb(interpolation_color_components(c.component(0), 1, 0.5, c.alpha()))
	scale := 1 - white - black
	return interpolation_color_components(rgb.component(0) * scale + white, rgb.component(1) * scale + white, rgb.component(2) * scale + white, c.alpha())
}

fn ci_xyz65_to_linear_display_p3(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(2.4934969119 * x - 0.9313836179 * y - 0.4027107845 * z, -0.8294889696 * x + 1.7626640603 * y + 0.0236246858 * z, 0.0358458302 * x - 0.0761723893 * y + 0.9568845240 * z, c.alpha())
}

fn ci_linear_display_p3_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	return interpolation_color_components(0.48657095 * r + 0.26566769 * g + 0.19821729 * b, 0.22897456 * r + 0.69173852 * g + 0.07928691 * b, 0.04511338 * g + 1.04394437 * b, c.alpha())
}

fn ci_a98_to_linear(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		return if value < 0 { -math.pow(-value, 563.0 / 256.0) } else { math.pow(value, 563.0 / 256.0) }
	})
}

fn ci_linear_to_a98(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		return if value < 0 { -math.pow(-value, 256.0 / 563.0) } else { math.pow(value, 256.0 / 563.0) }
	})
}

fn ci_linear_a98_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	return interpolation_color_components((573536.0 / 994567.0) * r + (263643.0 / 1420810.0) * g + (187206.0 / 994567.0) * b, (591459.0 / 1989134.0) * r + (6239551.0 / 9945670.0) * g + (374412.0 / 4972835.0) * b, (53769.0 / 1989134.0) * r + (351524.0 / 4972835.0) * g + (4929758.0 / 4972835.0) * b, c.alpha())
}

fn ci_xyz65_to_linear_a98(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components((1829569.0 / 896150.0) * x - (506331.0 / 896150.0) * y - (308931.0 / 896150.0) * z, -(851781.0 / 878810.0) * x + (1648619.0 / 878810.0) * y + (36519.0 / 878810.0) * z, (16779.0 / 1248040.0) * x - (147721.0 / 1248040.0) * y + (1266979.0 / 1248040.0) * z, c.alpha())
}

fn ci_prophoto_to_linear(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		absolute := math.abs(value)
		if absolute <= 16.0 / 512.0 {
			return value / 16
		}
		return if value < 0 { -math.pow(absolute, 1.8) } else { math.pow(absolute, 1.8) }
	})
}

fn ci_linear_to_prophoto(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		absolute := math.abs(value)
		if absolute <= 1.0 / 512.0 {
			return value * 16
		}
		return if value < 0 { -math.pow(absolute, 1.0 / 1.8) } else { math.pow(absolute, 1.0 / 1.8) }
	})
}

fn ci_linear_prophoto_to_xyz50(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	return interpolation_color_components(0.79776664 * r + 0.13518130 * g + 0.03134773 * b, 0.28807483 * r + 0.71183523 * g + 0.00008994 * b, 0.82510460 * b, c.alpha())
}

fn ci_xyz50_to_linear_prophoto(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(1.3457989731 * x - 0.2555802200 * y - 0.0511188540 * z, -0.5446224939 * x + 1.5082327413 * y + 0.0205274474 * z, 1.2119675456 * z, c.alpha())
}

fn ci_rec2020_to_linear(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		alpha := 1.09929682680944
		beta := 0.018053968510807
		absolute := math.abs(value)
		if absolute < beta * 4.5 {
			return value / 4.5
		}
		result := math.pow((absolute + alpha - 1) / alpha, 1.0 / 0.45)
		return if value < 0 { -result } else { result }
	})
}

fn ci_linear_to_rec2020(c InterpolationColorComponents) InterpolationColorComponents {
	return map_color_components(c, fn (value f64) f64 {
		alpha := 1.09929682680944
		beta := 0.018053968510807
		absolute := math.abs(value)
		if absolute < beta {
			return value * 4.5
		}
		result := alpha * math.pow(absolute, 0.45) - (alpha - 1)
		return if value < 0 { -result } else { result }
	})
}

fn ci_linear_rec2020_to_xyz65(c InterpolationColorComponents) InterpolationColorComponents {
	r := c.component(0)
	g := c.component(1)
	b := c.component(2)
	return interpolation_color_components(0.63695805 * r + 0.14461690 * g + 0.16888098 * b, 0.26270021 * r + 0.67799807 * g + 0.05930172 * b, 0.02807269 * g + 1.06098506 * b, c.alpha())
}

fn ci_xyz65_to_linear_rec2020(c InterpolationColorComponents) InterpolationColorComponents {
	x := c.component(0)
	y := c.component(1)
	z := c.component(2)
	return interpolation_color_components(1.7166511880 * x - 0.3556707838 * y - 0.2533662814 * z, -0.6666843518 * x + 1.6164812366 * y + 0.0157685458 * z, 0.0176398574 * x - 0.0427706133 * y + 0.9421031212 * z, c.alpha())
}

fn srgb_to_rectangular_color_space(srgb InterpolationColorComponents, space RectangularColorSpace) InterpolationColorComponents {
	if space == .srgb {
		return srgb
	}
	linear := ci_srgb_to_linear(srgb)
	if space == .srgb_linear {
		return linear
	}
	xyz65 := ci_linear_srgb_to_xyz65(linear)
	return match space {
		.display_p3 { ci_linear_to_srgb(ci_xyz65_to_linear_display_p3(xyz65)) }
		.display_p3_linear { ci_xyz65_to_linear_display_p3(xyz65) }
		.a98_rgb { ci_linear_to_a98(ci_xyz65_to_linear_a98(xyz65)) }
		.prophoto_rgb { ci_linear_to_prophoto(ci_xyz50_to_linear_prophoto(ci_xyz65_to_xyz50(xyz65))) }
		.rec2020 { ci_linear_to_rec2020(ci_xyz65_to_linear_rec2020(xyz65)) }
		.lab { ci_xyz50_to_lab(ci_xyz65_to_xyz50(xyz65)) }
		.oklab { ci_xyz65_to_oklab(xyz65) }
		.xyz, .xyz_d65 { xyz65 }
		.xyz_d50 { ci_xyz65_to_xyz50(xyz65) }
		.srgb, .srgb_linear { srgb }
	}
}

fn srgb_to_polar_color_space(srgb InterpolationColorComponents, space PolarColorSpace) InterpolationColorComponents {
	return match space {
		.hsl { ci_srgb_to_hsl(srgb) }
		.hwb { ci_srgb_to_hwb(srgb) }
		.lch { ci_rectangular_to_polar(ci_xyz50_to_lab(ci_xyz65_to_xyz50(ci_linear_srgb_to_xyz65(ci_srgb_to_linear(srgb))))) }
		.oklch { ci_rectangular_to_polar(ci_xyz65_to_oklab(ci_linear_srgb_to_xyz65(ci_srgb_to_linear(srgb)))) }
	}
}

fn extract_missing_components(style_value StyleValue) MissingColorComponents {
	match style_value {
		HSLColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.h_[0]), style_value_is_none_keyword(style_value.s_[0]), style_value_is_none_keyword(style_value.l_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		HWBColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.h_[0]), style_value_is_none_keyword(style_value.w_[0]), style_value_is_none_keyword(style_value.b_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		LabColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.l_[0]), style_value_is_none_keyword(style_value.a_[0]), style_value_is_none_keyword(style_value.b_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		OKLabColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.l_[0]), style_value_is_none_keyword(style_value.a_[0]), style_value_is_none_keyword(style_value.b_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		LCHColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.l_[0]), style_value_is_none_keyword(style_value.c_[0]), style_value_is_none_keyword(style_value.h_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		OKLCHColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.l_[0]), style_value_is_none_keyword(style_value.c_[0]), style_value_is_none_keyword(style_value.h_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		RGBColorStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.r_[0]), style_value_is_none_keyword(style_value.g_[0]), style_value_is_none_keyword(style_value.b_[0])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		ColorFunctionStyleValue {
			return MissingColorComponents{
				components: [style_value_is_none_keyword(style_value.channels_[0]), style_value_is_none_keyword(style_value.channels_[1]), style_value_is_none_keyword(style_value.channels_[2])]!
				alpha: style_value_is_none_keyword(style_value.alpha_[0])
			}
		}
		else {}
	}
	return MissingColorComponents{}
}

fn categories_for_rectangular_space(space RectangularColorSpace) ColorComponentCategories {
	return match space {
		.srgb, .srgb_linear, .display_p3, .display_p3_linear, .a98_rgb, .prophoto_rgb, .rec2020, .xyz, .xyz_d50, .xyz_d65 { ColorComponentCategories{components: [ColorComponentCategory.red, .green, .blue]!} }
		.lab, .oklab { ColorComponentCategories{components: [ColorComponentCategory.lightness, .opponent_a, .opponent_b]!} }
	}
}

fn categories_for_polar_space(space PolarColorSpace) ColorComponentCategories {
	return match space {
		.hsl { ColorComponentCategories{components: [ColorComponentCategory.hue, .colorfulness, .lightness]!} }
		.hwb { ColorComponentCategories{components: [ColorComponentCategory.hue, .not_analogous, .not_analogous]!} }
		.lch, .oklch { ColorComponentCategories{components: [ColorComponentCategory.lightness, .colorfulness, .hue]!} }
	}
}

fn categories_for_color_type(color_type ConcreteColorType) ColorComponentCategories {
	return match color_type {
		.hsl { ColorComponentCategories{components: [ColorComponentCategory.hue, .colorfulness, .lightness]!} }
		.hwb { ColorComponentCategories{components: [ColorComponentCategory.hue, .not_analogous, .not_analogous]!} }
		.lab, .oklab { ColorComponentCategories{components: [ColorComponentCategory.lightness, .opponent_a, .opponent_b]!} }
		.lch, .oklch { ColorComponentCategories{components: [ColorComponentCategory.lightness, .colorfulness, .hue]!} }
		.rgb, .a98_rgb, .display_p3, .display_p3_linear, .srgb, .srgb_linear, .pro_photo_rgb, .rec2020, .xyzd50, .xyzd65 { ColorComponentCategories{components: [ColorComponentCategory.red, .green, .blue]!} }
		else { ColorComponentCategories{} }
	}
}

fn carry_forward_missing_components(source MissingColorComponents, source_categories ColorComponentCategories, target_categories ColorComponentCategories) MissingColorComponents {
	mut result := MissingColorComponents{}
	if source_categories.components == target_categories.components {
		result.components = source.components
		result.alpha = source.alpha
		return result
	}
	for target_index in 0 .. 3 {
		if target_categories.components[target_index] == .not_analogous {
			continue
		}
		for source_index in 0 .. 3 {
			if source.components[source_index] && source_categories.components[source_index] == target_categories.components[target_index] {
				result.components[target_index] = true
				break
			}
		}
	}
	mut all_non_analogous_missing := true
	mut has_non_analogous := false
	for source_index in 0 .. 3 {
		mut individually_analogous := false
		for target_index in 0 .. 3 {
			if source_categories.components[source_index] != .not_analogous && source_categories.components[source_index] == target_categories.components[target_index] {
				individually_analogous = true
				break
			}
		}
		if !individually_analogous {
			has_non_analogous = true
			if !source.components[source_index] {
				all_non_analogous_missing = false
			}
		}
	}
	if has_non_analogous && all_non_analogous_missing {
		for target_index in 0 .. 3 {
			mut individually_analogous := false
			for source_index in 0 .. 3 {
				if target_categories.components[target_index] != .not_analogous && target_categories.components[target_index] == source_categories.components[source_index] {
					individually_analogous = true
					break
				}
			}
			if !individually_analogous {
				result.components[target_index] = true
			}
		}
	}
	result.alpha = source.alpha
	return result
}

fn number_or_none(value f64, missing bool) StyleValue {
	if missing {
		return StyleValue(KeywordStyleValue.create(.none_))
	}
	return StyleValue(NumberStyleValue.create(value))
}

fn style_value_from_rectangular_color_space(components InterpolationColorComponents, space RectangularColorSpace, missing MissingColorComponents) StyleValue {
	c1 := number_or_none(components.component(0), missing.components[0])
	c2 := number_or_none(components.component(1), missing.components[1])
	c3 := number_or_none(components.component(2), missing.components[2])
	alpha := number_or_none(components.alpha(), missing.alpha)
	return match space {
		.lab { StyleValue(LabColorStyleValue.create(c1, c2, c3, alpha)) }
		.oklab { StyleValue(OKLabColorStyleValue.create(c1, c2, c3, alpha)) }
		.srgb { StyleValue(ColorFunctionStyleValue.create('srgb', c1, c2, c3, alpha)) }
		.srgb_linear { StyleValue(ColorFunctionStyleValue.create('srgb-linear', c1, c2, c3, alpha)) }
		.display_p3 { StyleValue(ColorFunctionStyleValue.create('display-p3', c1, c2, c3, alpha)) }
		.display_p3_linear { StyleValue(ColorFunctionStyleValue.create('display-p3-linear', c1, c2, c3, alpha)) }
		.a98_rgb { StyleValue(ColorFunctionStyleValue.create('a98-rgb', c1, c2, c3, alpha)) }
		.prophoto_rgb { StyleValue(ColorFunctionStyleValue.create('prophoto-rgb', c1, c2, c3, alpha)) }
		.rec2020 { StyleValue(ColorFunctionStyleValue.create('rec2020', c1, c2, c3, alpha)) }
		.xyz, .xyz_d65 { StyleValue(ColorFunctionStyleValue.create('xyz-d65', c1, c2, c3, alpha)) }
		.xyz_d50 { StyleValue(ColorFunctionStyleValue.create('xyz-d50', c1, c2, c3, alpha)) }
	}
}

fn style_value_from_polar_color_space(components InterpolationColorComponents, space PolarColorSpace, missing MissingColorComponents) StyleValue {
	alpha := number_or_none(components.alpha(), missing.alpha)
	return match space {
		.hsl {
			srgb := ci_hsl_to_srgb(components)
			StyleValue(ColorFunctionStyleValue.create('srgb', number_or_none(srgb.component(0), false), number_or_none(srgb.component(1), false), number_or_none(srgb.component(2), false), alpha))
		}
		.hwb {
			srgb := ci_hwb_to_srgb(components)
			StyleValue(ColorFunctionStyleValue.create('srgb', number_or_none(srgb.component(0), false), number_or_none(srgb.component(1), false), number_or_none(srgb.component(2), false), alpha))
		}
		.lch { StyleValue(LCHColorStyleValue.create(number_or_none(components.component(0), missing.components[0]), number_or_none(components.component(1), missing.components[1]), number_or_none(components.component(2), missing.components[2]), alpha)) }
		.oklch { StyleValue(OKLCHColorStyleValue.create(number_or_none(components.component(0), missing.components[0]), number_or_none(components.component(1), missing.components[1]), number_or_none(components.component(2), missing.components[2]), alpha)) }
	}
}

fn style_value_to_color_components(style_value StyleValue, context CalculationResolutionContext) ?InterpolationColorComponents {
	return match style_value {
		ColorStyleValue { interpolation_color_components(f64(style_value.color_.r) / 255, f64(style_value.color_.g) / 255, f64(style_value.color_.b) / 255, f64(style_value.color_.a) / 255) }
		HSLColorStyleValue { interpolation_color_components(resolve_hue(style_value.h_[0], context)?, resolve_with_reference_value(style_value.s_[0], 100, context)? / 100, resolve_with_reference_value(style_value.l_[0], 100, context)? / 100, resolve_alpha(style_value.alpha_[0], context)?) }
		HWBColorStyleValue { interpolation_color_components(resolve_hue(style_value.h_[0], context)?, resolve_with_reference_value(style_value.w_[0], 100, context)? / 100, resolve_with_reference_value(style_value.b_[0], 100, context)? / 100, resolve_alpha(style_value.alpha_[0], context)?) }
		LabColorStyleValue { interpolation_color_components(resolve_with_reference_value(style_value.l_[0], 100, context)?, resolve_with_reference_value(style_value.a_[0], 125, context)?, resolve_with_reference_value(style_value.b_[0], 125, context)?, resolve_alpha(style_value.alpha_[0], context)?) }
		OKLabColorStyleValue { interpolation_color_components(resolve_with_reference_value(style_value.l_[0], 1, context)?, resolve_with_reference_value(style_value.a_[0], 0.4, context)?, resolve_with_reference_value(style_value.b_[0], 0.4, context)?, resolve_alpha(style_value.alpha_[0], context)?) }
		LCHColorStyleValue { interpolation_color_components(resolve_with_reference_value(style_value.l_[0], 100, context)?, resolve_with_reference_value(style_value.c_[0], 150, context)?, resolve_hue(style_value.h_[0], context)?, resolve_alpha(style_value.alpha_[0], context)?) }
		OKLCHColorStyleValue { interpolation_color_components(resolve_with_reference_value(style_value.l_[0], 1, context)?, resolve_with_reference_value(style_value.c_[0], 0.4, context)?, resolve_hue(style_value.h_[0], context)?, resolve_alpha(style_value.alpha_[0], context)?) }
		RGBColorStyleValue { interpolation_color_components(image_color_clamp(resolve_with_reference_value(style_value.r_[0], 255, context)?, 0, 255) / 255, image_color_clamp(resolve_with_reference_value(style_value.g_[0], 255, context)?, 0, 255) / 255, image_color_clamp(resolve_with_reference_value(style_value.b_[0], 255, context)?, 0, 255) / 255, resolve_alpha(style_value.alpha_[0], context)?) }
		ColorFunctionStyleValue { interpolation_color_components(resolve_with_reference_value(style_value.channels_[0], 1, context)?, resolve_with_reference_value(style_value.channels_[1], 1, context)?, resolve_with_reference_value(style_value.channels_[2], 1, context)?, resolve_alpha(style_value.alpha_[0], context)?) }
		else { none }
	}
}

fn concrete_color_type(style_value StyleValue) ?ConcreteColorType {
	return match style_value {
		ColorStyleValue { ConcreteColorType.rgb }
		HSLColorStyleValue { ConcreteColorType.hsl }
		HWBColorStyleValue { ConcreteColorType.hwb }
		LabColorStyleValue { ConcreteColorType.lab }
		OKLabColorStyleValue { ConcreteColorType.oklab }
		LCHColorStyleValue { ConcreteColorType.lch }
		OKLCHColorStyleValue { ConcreteColorType.oklch }
		RGBColorStyleValue { ConcreteColorType.rgb }
		ColorFunctionStyleValue { style_value.color_type_ }
		else { none }
	}
}

fn native_components_to_srgb(native InterpolationColorComponents, source_type ConcreteColorType) InterpolationColorComponents {
	return match source_type {
		.rgb, .srgb { native }
		.srgb_linear { ci_linear_to_srgb(native) }
		.hsl { ci_hsl_to_srgb(native) }
		.hwb { ci_hwb_to_srgb(native) }
		.lab { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_xyz50_to_xyz65(ci_lab_to_xyz50(native)))) }
		.oklab { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_oklab_to_xyz65(native))) }
		.lch { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_xyz50_to_xyz65(ci_lab_to_xyz50(ci_polar_to_rectangular(native))))) }
		.oklch { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_oklab_to_xyz65(ci_polar_to_rectangular(native)))) }
		.display_p3 { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_linear_display_p3_to_xyz65(ci_srgb_to_linear(native)))) }
		.display_p3_linear { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_linear_display_p3_to_xyz65(native))) }
		.a98_rgb { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_linear_a98_to_xyz65(ci_a98_to_linear(native)))) }
		.pro_photo_rgb { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_xyz50_to_xyz65(ci_linear_prophoto_to_xyz50(ci_prophoto_to_linear(native))))) }
		.rec2020 { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_linear_rec2020_to_xyz65(ci_rec2020_to_linear(native)))) }
		.xyzd50 { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(ci_xyz50_to_xyz65(native))) }
		.xyzd65 { ci_linear_to_srgb(ci_xyz65_to_linear_srgb(native)) }
		else { native }
	}
}

fn color_type_matches_rectangular_space(source ConcreteColorType, space RectangularColorSpace) bool {
	return match space {
		.srgb { source in [.srgb, .rgb] }
		.srgb_linear { source == .srgb_linear }
		.display_p3 { source == .display_p3 }
		.display_p3_linear { source == .display_p3_linear }
		.a98_rgb { source == .a98_rgb }
		.prophoto_rgb { source == .pro_photo_rgb }
		.rec2020 { source == .rec2020 }
		.lab { source == .lab }
		.oklab { source == .oklab }
		.xyz, .xyz_d65 { source == .xyzd65 }
		.xyz_d50 { source == .xyzd50 }
	}
}

fn color_type_matches_polar_space(source ConcreteColorType, space PolarColorSpace) bool {
	return match space {
		.hsl { source == .hsl }
		.hwb { source == .hwb }
		.lch { source == .lch }
		.oklch { source == .oklch }
	}
}

fn color_syntax_for_interpolation(style_value StyleValue) ColorSyntax {
	return match style_value {
		KeywordStyleValue, ColorStyleValue, RGBColorStyleValue, HSLColorStyleValue, HWBColorStyleValue { .legacy }
		else { .modern }
	}
}

fn source_categories_for_interpolation(style_value StyleValue) ColorComponentCategories {
	if color_type := concrete_color_type(style_value) {
		return categories_for_color_type(color_type)
	}
	return ColorComponentCategories{components: [ColorComponentCategory.red, .green, .blue]!}
}

fn initialize_interpolation_color(style_value StyleValue, context ColorResolutionContext) PreparedInterpolationColor {
	return PreparedInterpolationColor{
		missing_components: extract_missing_components(style_value)
		source_categories: source_categories_for_interpolation(style_value)
		native_components: style_value_to_color_components(style_value, context.calculation_resolution_context)
	}
}

fn resolve_interpolation_color_to_srgb(style_value StyleValue, mut prepared PreparedInterpolationColor, context ColorResolutionContext) ?InterpolationColorComponents {
	if srgb := prepared.srgb_components {
		return srgb
	}
	if native := prepared.native_components {
		color_type := concrete_color_type(style_value) or { return none }
		prepared.srgb_components = native_components_to_srgb(native, color_type)
		return prepared.srgb_components
	}
	resolved := style_value.to_color(context) or { return none }
	prepared.srgb_components = interpolation_color_components(f64(resolved.r) / 255, f64(resolved.g) / 255, f64(resolved.b) / 255, f64(resolved.a) / 255)
	return prepared.srgb_components
}

fn prepare_interpolation_color(style_value StyleValue, mut prepared PreparedInterpolationColor, context ColorResolutionContext) bool {
	alpha := if native := prepared.native_components {
		native.alpha()
	} else {
		resolved := resolve_interpolation_color_to_srgb(style_value, mut prepared, context) or { return false }
		resolved.alpha()
	}
	if prepared.native_components == none && !prepared.missing_components.alpha && alpha == 0 {
		prepared.missing_components.components = [true, true, true]!
	}
	return true
}

fn convert_color_to_rectangular(style_value StyleValue, mut prepared PreparedInterpolationColor, space RectangularColorSpace, context ColorResolutionContext) InterpolationColorComponents {
	if native := prepared.native_components {
		if color_type := concrete_color_type(style_value) {
			if color_type_matches_rectangular_space(color_type, space) {
				return native
			}
		}
	}
	srgb := resolve_interpolation_color_to_srgb(style_value, mut prepared, context) or { return InterpolationColorComponents{} }
	return srgb_to_rectangular_color_space(srgb, space)
}

fn convert_color_to_polar(style_value StyleValue, mut prepared PreparedInterpolationColor, space PolarColorSpace, context ColorResolutionContext) InterpolationColorComponents {
	if native := prepared.native_components {
		if color_type := concrete_color_type(style_value) {
			if color_type_matches_polar_space(color_type, space) {
				return native
			}
		}
	}
	srgb := resolve_interpolation_color_to_srgb(style_value, mut prepared, context) or { return InterpolationColorComponents{} }
	return srgb_to_polar_color_space(srgb, space)
}

fn mark_powerless_hue_after_conversion(components InterpolationColorComponents, mut missing MissingColorComponents, style_value StyleValue, space PolarColorSpace, categories ColorComponentCategories) {
	if color_type := concrete_color_type(style_value) {
		if color_type_matches_polar_space(color_type, space) {
			return
		}
	}
	mut zero_colorfulness := false
	for index in 0 .. 3 {
		if categories.components[index] == .colorfulness && math.abs(components.component(index)) < 0.02 {
			zero_colorfulness = true
		}
	}
	if space == .hwb && components.component(1) + components.component(2) >= 0.98 {
		zero_colorfulness = true
	}
	if zero_colorfulness {
		for index in 0 .. 3 {
			if categories.components[index] == .hue {
				missing.components[index] = true
			}
		}
	}
}

fn substitute_missing_components(mut from InterpolationColorComponents, mut to InterpolationColorComponents, from_missing MissingColorComponents, to_missing MissingColorComponents) {
	for index in 0 .. 3 {
		if from_missing.components[index] && !to_missing.components[index] {
			from.set_component(index, to.component(index))
		} else if to_missing.components[index] && !from_missing.components[index] {
			to.set_component(index, from.component(index))
		}
	}
	if from_missing.alpha && !to_missing.alpha {
		from.set_alpha(to.alpha())
	} else if to_missing.alpha && !from_missing.alpha {
		to.set_alpha(from.alpha())
	} else if from_missing.alpha && to_missing.alpha {
		from.set_alpha(1)
		to.set_alpha(1)
	}
}

fn resolve_color_interpolation_policy(from StyleValue, to StyleValue, method ?ColorInterpolationMethod) ColorInterpolationPolicy {
	modern := color_syntax_for_interpolation(from) == .modern || color_syntax_for_interpolation(to) == .modern
	return ColorInterpolationPolicy{
		use_legacy_output: method == none && !modern
		color_interpolation_method: method or {
			ColorInterpolationMethodStyleValue.default_color_interpolation_method(if modern { ColorSyntax.modern } else { ColorSyntax.legacy })
		}
	}
}

fn convert_to_interpolation_space(from StyleValue, mut from_color PreparedInterpolationColor, to StyleValue, mut to_color PreparedInterpolationColor, method ColorInterpolationMethod, context ColorResolutionContext) ColorInterpolationSpaceState {
	mut state := ColorInterpolationSpaceState{}
	match method {
		RectangularColorSpace {
			state.rectangular_color_space = method
			state.from_components = convert_color_to_rectangular(from, mut from_color, method, context)
			state.to_components = convert_color_to_rectangular(to, mut to_color, method, context)
			target := categories_for_rectangular_space(method)
			state.from_missing = carry_forward_missing_components(from_color.missing_components, from_color.source_categories, target)
			state.to_missing = carry_forward_missing_components(to_color.missing_components, to_color.source_categories, target)
		}
		PolarColorInterpolationMethod {
			state.is_polar = true
			state.polar_color_space = method.color_space
			state.hue_interpolation_method = method.hue_interpolation_method
			state.hue_index = if method.color_space in [.hsl, .hwb] { 0 } else { 2 }
			state.from_components = convert_color_to_polar(from, mut from_color, method.color_space, context)
			state.to_components = convert_color_to_polar(to, mut to_color, method.color_space, context)
			target := categories_for_polar_space(method.color_space)
			state.from_missing = carry_forward_missing_components(from_color.missing_components, from_color.source_categories, target)
			state.to_missing = carry_forward_missing_components(to_color.missing_components, to_color.source_categories, target)
			state.polar_target_categories = target
		}
	}
	if state.is_polar {
		mark_powerless_hue_after_conversion(state.from_components, mut state.from_missing, from, state.polar_color_space, state.polar_target_categories)
		mark_powerless_hue_after_conversion(state.to_components, mut state.to_missing, to, state.polar_color_space, state.polar_target_categories)
	}
	return state
}

fn premultiply_color_components(components InterpolationColorComponents, is_polar bool, hue_index int) InterpolationColorComponents {
	mut result := InterpolationColorComponents{}
	result.set_alpha(components.alpha())
	for index in 0 .. 3 {
		result.set_component(index, if is_polar && index == hue_index { components.component(index) } else { components.component(index) * components.alpha() })
	}
	return result
}

fn result_missing_components(state ColorInterpolationSpaceState) MissingColorComponents {
	return MissingColorComponents{
		components: [state.from_missing.components[0] && state.to_missing.components[0], state.from_missing.components[1] && state.to_missing.components[1], state.from_missing.components[2] && state.to_missing.components[2]]!
		alpha: state.from_missing.alpha && state.to_missing.alpha
	}
}

pub fn perform_color_interpolation(from StyleValue, to StyleValue, delta f64, method ?ColorInterpolationMethod, context ColorResolutionContext) ?InterpolatedColor {
	mut from_color := initialize_interpolation_color(from, context)
	mut to_color := initialize_interpolation_color(to, context)
	if !prepare_interpolation_color(from, mut from_color, context) || !prepare_interpolation_color(to, mut to_color, context) {
		return none
	}
	policy := resolve_color_interpolation_policy(from, to, method)
	mut state := convert_to_interpolation_space(from, mut from_color, to, mut to_color, policy.color_interpolation_method, context)
	both_alpha_missing := state.from_missing.alpha && state.to_missing.alpha
	substitute_missing_components(mut state.from_components, mut state.to_components, state.from_missing, state.to_missing)
	if state.is_polar {
		from_hue, to_hue := fixup_interpolation_hue(state.from_components.component(state.hue_index), state.to_components.component(state.hue_index), state.hue_interpolation_method)
		state.from_components.set_component(state.hue_index, from_hue)
		state.to_components.set_component(state.hue_index, to_hue)
	}
	interpolated_alpha := image_color_clamp(interpolate_color_component(state.from_components.alpha(), state.to_components.alpha(), delta), 0, 1)
	if interpolated_alpha == 0 && !both_alpha_missing {
		return InterpolatedColor{
			components: interpolation_color_components(0, 0, 0, 0)
			policy: policy
			state: state
		}
	}
	from_premultiplied := premultiply_color_components(state.from_components, state.is_polar, state.hue_index)
	to_premultiplied := premultiply_color_components(state.to_components, state.is_polar, state.hue_index)
	mut result := InterpolationColorComponents{}
	result.set_alpha(interpolated_alpha)
	for index in 0 .. 3 {
		interpolated := interpolate_color_component(from_premultiplied.component(index), to_premultiplied.component(index), delta)
		result.set_component(index, if state.is_polar && index == state.hue_index { interpolated } else { interpolated / interpolated_alpha })
	}
	return InterpolatedColor{
		components: result
		missing: result_missing_components(state)
		policy: policy
		state: state
	}
}

pub fn style_value_for_interpolated_color(interpolated InterpolatedColor) StyleValue {
	if interpolated.policy.use_legacy_output {
		components := interpolated.components
		color := Color.rgba(image_color_round_to_u8(components.component(0) * 255), image_color_round_to_u8(components.component(1) * 255), image_color_round_to_u8(components.component(2) * 255), image_color_round_to_u8(components.alpha() * 255))
		return StyleValue(ColorStyleValue.create_from_color(color, .legacy, none))
	}
	if interpolated.state.is_polar {
		return style_value_from_polar_color_space(interpolated.components, interpolated.state.polar_color_space, interpolated.missing)
	}
	return style_value_from_rectangular_color_space(interpolated.components, interpolated.state.rectangular_color_space, interpolated.missing)
}

pub fn interpolate_style_values_color(from StyleValue, to StyleValue, delta f64, method ?ColorInterpolationMethod, context ColorResolutionContext) ?StyleValue {
	interpolated := perform_color_interpolation(from, to, delta, method, context) or { return none }
	return style_value_for_interpolated_color(interpolated)
}
