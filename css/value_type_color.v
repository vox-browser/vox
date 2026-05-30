module css

import math

// Small translated subset of Gfx::Color used by CSS style values.
pub struct Color {
pub mut:
	r u8
	g u8
	b u8
	a u8 = 255
}

pub struct Oklab {
pub mut:
	l f64
	a f64
	b f64
}

pub fn Color.rgb(r u8, g u8, b u8) Color {
	return Color{
		r: r
		g: g
		b: b
		a: 255
	}
}

pub fn Color.rgba(r u8, g u8, b u8, a u8) Color {
	return Color{
		r: r
		g: g
		b: b
		a: a
	}
}

fn color_clamp_f64(value f64, min f64, max f64) f64 {
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

fn color_round_to_u8(value f64) u8 {
	return u8(int(math.round(color_clamp_f64(value, 0.0, 255.0))))
}

fn color_nth_digit(value u32, digit u8) u8 {
	mut remaining := value
	mut digit_index := digit
	for digit_index > 1 {
		remaining /= 10
		digit_index--
	}
	return `0` + u8(remaining % 10)
}

fn color_format_to_8bit_compatible(value u8) string {
	// This function formats to the shortest string that roundtrips at 8 bits.
	// As an example:
	//      127 / 255 = 0.498 +/- 0.001
	//      128 / 255 = 0.502 +/- 0.001
	// But round(.5 * 255) == 128, so this function returns (note that it's only the fractional part):
	//      127 -> "498"
	//      128 -> "5"
	three_digits := (u32(value) * 1000 + 127) / 255
	rounded_to_two_digits := (three_digits + 5) / 10 * 10

	if ((rounded_to_two_digits * 255 / 100 + 5) / 10) != u32(value) {
		return [color_nth_digit(three_digits, 3), color_nth_digit(three_digits, 2),
			color_nth_digit(three_digits, 1)].bytestr()
	}

	rounded_to_one_digit := (three_digits + 50) / 100 * 100
	if ((rounded_to_one_digit * 255 / 100 + 5) / 10) != u32(value) {
		return [color_nth_digit(rounded_to_two_digits, 3), color_nth_digit(rounded_to_two_digits, 2)].bytestr()
	}

	return [color_nth_digit(rounded_to_one_digit, 3)].bytestr()
}

// https://www.w3.org/TR/css-color-4/#serializing-sRGB-values
pub fn (color Color) serialize_a_srgb_value() string {
	// The serialized form is derived from the computed value and thus, uses either the rgb() or rgba() form
	// (depending on whether the alpha is exactly 1, or not), with lowercase letters for the function name.
	// NOTE: Since we use Gfx::Color, having an "alpha of 1" means its value is 255.
	if color.a == 0 {
		return 'rgba(${color.r}, ${color.g}, ${color.b}, 0)'
	}
	if color.a == 255 {
		return 'rgb(${color.r}, ${color.g}, ${color.b})'
	}
	return 'rgba(${color.r}, ${color.g}, ${color.b}, 0.${color_format_to_8bit_compatible(color.a)})'
}

pub fn Color.from_hsla(h_degrees f64, s_ f64, l_ f64, a_ f64) Color {
	// Algorithm from https://www.w3.org/TR/css-color-3/#hsl-color
	mut h := math.fmod(h_degrees, 360.0)
	if h < 0.0 {
		h += 360.0
	}

	s := color_clamp_f64(s_, 0.0, 1.0)
	l := color_clamp_f64(l_, 0.0, 1.0)
	a := color_clamp_f64(a_, 0.0, 1.0)

	to_rgb := fn (h f64, s f64, l f64, offset f64) f64 {
		k := math.fmod(offset + h / 30.0, 12.0)
		a := s * math.min(l, 1.0 - l)
		return l - a * math.max(-1.0, math.min(math.min(k - 3.0, 9.0 - k), 1.0))
	}

	r := to_rgb(h, s, l, 0.0)
	g := to_rgb(h, s, l, 8.0)
	b := to_rgb(h, s, l, 4.0)

	return Color.rgba(color_round_to_u8(r * 255.0), color_round_to_u8(g * 255.0),
		color_round_to_u8(b * 255.0), color_round_to_u8(a * 255.0))
}

pub fn Color.from_hsv(hue f64, saturation f64, value f64) Color {
	mut normalized_hue := math.fmod(hue, 360.0)
	if normalized_hue < 0.0 {
		normalized_hue += 360.0
	}
	s := color_clamp_f64(saturation, 0.0, 1.0)
	v := color_clamp_f64(value, 0.0, 1.0)

	high := int(normalized_hue / 60.0) % 6
	f := (normalized_hue / 60.0) - f64(high)
	c1 := v * (1.0 - s)
	c2 := v * (1.0 - s * f)
	c3 := v * (1.0 - s * (1.0 - f))

	mut r := 0.0
	mut g := 0.0
	mut b := 0.0
	match high {
		0 {
			r = v
			g = c3
			b = c1
		}
		1 {
			r = c2
			g = v
			b = c1
		}
		2 {
			r = c1
			g = v
			b = c3
		}
		3 {
			r = c1
			g = c2
			b = v
		}
		4 {
			r = c3
			g = c1
			b = v
		}
		5 {
			r = v
			g = c1
			b = c2
		}
		else {}
	}

	return Color.rgb(color_round_to_u8(r * 255.0), color_round_to_u8(g * 255.0),
		color_round_to_u8(b * 255.0))
}

pub fn (color Color) with_opacity(opacity f64) Color {
	return Color.rgba(color.r, color.g, color.b, color_round_to_u8(f64(color.a) * opacity))
}

pub fn (color Color) with_alpha(alpha u8) Color {
	return Color.rgba(color.r, color.g, color.b, alpha)
}

pub fn Color.from_linear_srgb(red_ f64, green_ f64, blue_ f64, alpha f64) Color {
	linear_to_srgb := fn (c f64) f64 {
		if c <= 0.04045 / 12.92 {
			return c * 12.92
		}
		return math.pow(c, 10.0 / 24.0) * 1.055 - 0.055
	}

	red := linear_to_srgb(red_) * 255.0
	green := linear_to_srgb(green_) * 255.0
	blue := linear_to_srgb(blue_) * 255.0

	return Color.rgba(color_round_to_u8(red), color_round_to_u8(green), color_round_to_u8(blue),
		color_round_to_u8(alpha * 255.0))
}

pub fn Color.from_linear_display_p3(r f64, g f64, b f64, alpha f64) Color {
	x := 0.48657095 * r + 0.26566769 * g + 0.19821729 * b
	y := 0.22897456 * r + 0.69173852 * g + 0.07928691 * b
	z := 0.00000000 * r + 0.04511338 * g + 1.04394437 * b

	return Color.from_xyz65(x, y, z, alpha)
}

// https://www.w3.org/TR/css-color-4/#predefined-a98-rgb
pub fn Color.from_a98rgb(r f64, g f64, b f64, alpha f64) Color {
	to_linear := fn (c f64) f64 {
		return math.pow(c, 563.0 / 256.0)
	}

	linear_r := to_linear(r)
	linear_g := to_linear(g)
	linear_b := to_linear(b)

	x := 0.57666904 * linear_r + 0.18555824 * linear_g + 0.18822865 * linear_b
	y := 0.29734498 * linear_r + 0.62736357 * linear_g + 0.07529146 * linear_b
	z := 0.02703136 * linear_r + 0.07068885 * linear_g + 0.99133754 * linear_b

	return Color.from_xyz65(x, y, z, alpha)
}

// https://www.w3.org/TR/css-color-4/#predefined-a98-rgb
pub fn Color.from_display_p3(r f64, g f64, b f64, alpha f64) Color {
	to_linear := fn (c f64) f64 {
		if c < 0.04045 {
			return c / 12.92
		}
		return math.pow((c + 0.055) / 1.055, 2.4)
	}

	linear_r := to_linear(r)
	linear_g := to_linear(g)
	linear_b := to_linear(b)

	return Color.from_linear_display_p3(linear_r, linear_g, linear_b, alpha)
}

// https://www.w3.org/TR/css-color-4/#predefined-prophoto-rgb
pub fn Color.from_pro_photo_rgb(r f64, g f64, b f64, alpha f64) Color {
	to_linear := fn (c f64) f64 {
		sign := if c < 0 { -1.0 } else { 1.0 }
		absolute := math.abs(c)

		if absolute <= 16.0 / 252.0 {
			return c / 16.0
		}
		return sign * math.pow(c, 1.8)
	}

	linear_r := to_linear(r)
	linear_g := to_linear(g)
	linear_b := to_linear(b)

	x := 0.79776664 * linear_r + 0.13518130 * linear_g + 0.03134773 * linear_b
	y := 0.28807483 * linear_r + 0.71183523 * linear_g + 0.00008994 * linear_b
	z := 0.00000000 * linear_r + 0.00000000 * linear_g + 0.82510460 * linear_b

	return Color.from_xyz50(x, y, z, alpha)
}

// https://www.w3.org/TR/css-color-4/#predefined-rec2020
pub fn Color.from_rec2020(r f64, g f64, b f64, alpha f64) Color {
	to_linear := fn (c f64) f64 {
		alpha_value := 1.09929682680944
		beta := 0.018053968510807

		sign := if c < 0 { -1.0 } else { 1.0 }
		absolute := math.abs(c)

		if absolute < beta * 4.5 {
			return c / 4.5
		}

		return sign * math.pow((absolute + alpha_value - 1.0) / alpha_value, 1.0 / 0.45)
	}

	linear_r := to_linear(r)
	linear_g := to_linear(g)
	linear_b := to_linear(b)

	x := 0.63695805 * linear_r + 0.14461690 * linear_g + 0.16888098 * linear_b
	y := 0.26270021 * linear_r + 0.67799807 * linear_g + 0.05930172 * linear_b
	z := 0.00000000 * linear_r + 0.02807269 * linear_g + 1.06098506 * linear_b

	return Color.from_xyz65(x, y, z, alpha)
}

pub fn Color.from_xyz50(x f64, y f64, z f64, alpha f64) Color {
	// See commit description for these values.
	r := 3.134136 * x - 1.617386 * y - 0.490662 * z
	g := -0.978795 * x + 1.916254 * y + 0.033443 * z
	b := 0.071955 * x - 0.228977 * y + 1.405386 * z

	return Color.from_linear_srgb(r, g, b, alpha)
}

pub fn Color.from_xyz65(x f64, y f64, z f64, alpha f64) Color {
	// See commit description for these values.
	r := 3.240970 * x - 1.537383 * y - 0.498611 * z
	g := -0.969244 * x + 1.875968 * y + 0.041555 * z
	b := 0.055630 * x - 0.203977 * y + 1.056972 * z

	return Color.from_linear_srgb(r, g, b, alpha)
}

pub fn Color.from_lab(l_value f64, a_value f64, b_value f64, alpha f64) Color {
	// Third edition of "Colorimetry" by the CIE
	// 8.2.1 CIE 1976 (L*a*b*) colour space; CIELAB colour space
	mut y := (l_value + 16.0) / 116.0
	mut x := y + a_value / 500.0
	mut z := y - b_value / 200.0

	f_inv := fn (t f64) f64 {
		delta := 24.0 / 116.0
		if t > delta {
			return t * t * t
		}
		return (108.0 / 841.0) * (t - 116.0 / 16.0)
	}

	// D50
	x_n := 0.96422
	y_n := 1.0
	z_n := 0.82521

	x = x_n * f_inv(x)
	y = y_n * f_inv(y)
	z = z_n * f_inv(z)

	return Color.from_xyz50(x, y, z, alpha)
}

// https://bottosson.github.io/posts/oklab/
pub fn Color.from_oklab(l_value f64, a_value f64, b_value f64, alpha f64) Color {
	mut l := l_value + 0.3963377774 * a_value + 0.2158037573 * b_value
	mut m := l_value - 0.1055613458 * a_value - 0.0638541728 * b_value
	mut s := l_value - 0.0894841775 * a_value - 1.2914855480 * b_value

	l = l * l * l
	m = m * m * m
	s = s * s * s

	red := 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	green := -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	blue := -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

	return Color.from_linear_srgb(red, green, blue, alpha)
}

// https://bottosson.github.io/posts/oklab/
pub fn (color Color) to_oklab() Oklab {
	srgb_to_linear := fn (c f64) f64 {
		if c >= 0.04045 {
			return math.pow((c + 0.055) / 1.055, 2.4)
		}
		return c / 12.92
	}

	r := srgb_to_linear(f64(color.red()) / 255.0)
	g := srgb_to_linear(f64(color.green()) / 255.0)
	b := srgb_to_linear(f64(color.blue()) / 255.0)

	l := math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	m := math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	s := math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)

	return Oklab{
		l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
		a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
		b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	}
}

pub fn (color Color) to_premultiplied_oklab() Oklab {
	oklab := color.to_oklab()
	alpha := f64(color.alpha()) / 255.0
	return Oklab{
		l: oklab.l * alpha
		a: oklab.a * alpha
		b: oklab.b * alpha
	}
}

pub enum ValueType {
	anchor
	anchor_size
	angle
	angle_percentage
	background_position
	basic_shape
	color
	corner_shape
	counter
	counter_style
	custom_ident
	dashed_ident
	easing_function
	filter_value_list
	fit_content
	flex
	font_style
	font_variant_alternates
	font_variant_east_asian
	font_variant_ligatures
	font_variant_numeric
	frequency
	frequency_percentage
	image
	integer
	length
	length_percentage
	number
	opacity
	opentype_tag
	paint
	percentage
	position
	ratio
	rect
	resolution
	scroll_function
	string
	time
	time_percentage
	transform_function
	transform_list
	url
	view_function
	view_timeline_inset
}

pub fn value_type_from_string(value string) ?ValueType {
	return match to_ascii_lowercase(value) {
		'anchor-size' { ValueType.anchor_size }
		'angle' { ValueType.angle }
		'angle-percentage' { ValueType.angle_percentage }
		'background-position' { ValueType.background_position }
		'basic-shape' { ValueType.basic_shape }
		'color' { ValueType.color }
		'counter' { ValueType.counter }
		'counter-style' { ValueType.counter_style }
		'custom-ident' { ValueType.custom_ident }
		'dashed-ident' { ValueType.dashed_ident }
		'easing-function' { ValueType.easing_function }
		'filter-value-list' { ValueType.filter_value_list }
		'fit-content' { ValueType.fit_content }
		'flex' { ValueType.flex }
		'font-variant-alternates' { ValueType.font_variant_alternates }
		'font-variant-east-asian' { ValueType.font_variant_east_asian }
		'font-variant-ligatures' { ValueType.font_variant_ligatures }
		'font-variant-numeric' { ValueType.font_variant_numeric }
		'frequency' { ValueType.frequency }
		'frequency-percentage' { ValueType.frequency_percentage }
		'image' { ValueType.image }
		'integer' { ValueType.integer }
		'length' { ValueType.length }
		'length-percentage' { ValueType.length_percentage }
		'number' { ValueType.number }
		'opacity' { ValueType.opacity }
		'opentype-tag' { ValueType.opentype_tag }
		'paint' { ValueType.paint }
		'percentage' { ValueType.percentage }
		'position' { ValueType.position }
		'ratio' { ValueType.ratio }
		'rect' { ValueType.rect }
		'resolution' { ValueType.resolution }
		'scroll-function' { ValueType.scroll_function }
		'string' { ValueType.string }
		'time' { ValueType.time }
		'time-percentage' { ValueType.time_percentage }
		'transform-function' { ValueType.transform_function }
		'transform-list' { ValueType.transform_list }
		'url' { ValueType.url }
		'view-function' { ValueType.view_function }
		'view-timeline-inset' { ValueType.view_timeline_inset }
		else { none }
	}
}

pub fn value_type_to_string(value_type ValueType) string {
	return match value_type {
		.anchor { 'Anchor' }
		.anchor_size { 'AnchorSize' }
		.angle { 'Angle' }
		.angle_percentage { 'AnglePercentage' }
		.background_position { 'BackgroundPosition' }
		.basic_shape { 'BasicShape' }
		.color { 'Color' }
		.corner_shape { 'CornerShape' }
		.counter { 'Counter' }
		.counter_style { 'CounterStyle' }
		.custom_ident { 'CustomIdent' }
		.dashed_ident { 'DashedIdent' }
		.easing_function { 'EasingFunction' }
		.filter_value_list { 'FilterValueList' }
		.fit_content { 'FitContent' }
		.flex { 'Flex' }
		.font_style { 'FontStyle' }
		.font_variant_alternates { 'FontVariantAlternates' }
		.font_variant_east_asian { 'FontVariantEastAsian' }
		.font_variant_ligatures { 'FontVariantLigatures' }
		.font_variant_numeric { 'FontVariantNumeric' }
		.frequency { 'Frequency' }
		.frequency_percentage { 'FrequencyPercentage' }
		.image { 'Image' }
		.integer { 'Integer' }
		.length { 'Length' }
		.length_percentage { 'LengthPercentage' }
		.number { 'Number' }
		.opacity { 'Opacity' }
		.opentype_tag { 'OpenTypeTag' }
		.paint { 'Paint' }
		.percentage { 'Percentage' }
		.position { 'Position' }
		.ratio { 'Ratio' }
		.rect { 'Rect' }
		.resolution { 'Resolution' }
		.scroll_function { 'ScrollFunction' }
		.string { 'String' }
		.time { 'Time' }
		.time_percentage { 'TimePercentage' }
		.transform_function { 'TransformFunction' }
		.transform_list { 'TransformList' }
		.url { 'Url' }
		.view_function { 'ViewFunction' }
		.view_timeline_inset { 'ViewTimelineInset' }
	}
}
