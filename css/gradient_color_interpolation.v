module css

import math

// Color coordinates used while interpolating CSS gradients. The first three
// components are rectangular coordinates, except for polar spaces where c3 is
// the hue angle in degrees.
struct GradientColorCoordinates {
mut:
	c1               f64
	c2               f64
	c3               f64
	hue_is_powerless bool
}

fn gradient_srgb_to_linear(component f64) f64 {
	sign := if component < 0 { -1.0 } else { 1.0 }
	absolute := math.abs(component)
	if absolute >= 0.04045 {
		return sign * math.pow((absolute + 0.055) / 1.055, 2.4)
	}
	return component / 12.92
}

fn gradient_linear_to_srgb(component f64) f64 {
	sign := if component < 0 { -1.0 } else { 1.0 }
	absolute := math.abs(component)
	if absolute <= 0.04045 / 12.92 {
		return component * 12.92
	}
	return sign * (math.pow(absolute, 10.0 / 24.0) * 1.055 - 0.055)
}

fn gradient_signed_pow(value f64, exponent f64) f64 {
	if value < 0 {
		return -math.pow(-value, exponent)
	}
	return math.pow(value, exponent)
}

fn gradient_normalize_hue(hue f64) f64 {
	mut normalized := math.fmod(hue, 360.0)
	if normalized < 0 {
		normalized += 360.0
	}
	return normalized
}

fn gradient_srgb_coordinates(color Color) GradientColorCoordinates {
	return GradientColorCoordinates{
		c1: f64(color.r) / 255.0
		c2: f64(color.g) / 255.0
		c3: f64(color.b) / 255.0
	}
}

fn gradient_linear_srgb_coordinates(color Color) GradientColorCoordinates {
	srgb := gradient_srgb_coordinates(color)
	return GradientColorCoordinates{
		c1: gradient_srgb_to_linear(srgb.c1)
		c2: gradient_srgb_to_linear(srgb.c2)
		c3: gradient_srgb_to_linear(srgb.c3)
	}
}

fn gradient_xyz65_coordinates(color Color) GradientColorCoordinates {
	linear := gradient_linear_srgb_coordinates(color)
	return GradientColorCoordinates{
		c1: 0.41239080 * linear.c1 + 0.35758434 * linear.c2 + 0.18048079 * linear.c3
		c2: 0.21263901 * linear.c1 + 0.71516868 * linear.c2 + 0.07219232 * linear.c3
		c3: 0.01933082 * linear.c1 + 0.11919478 * linear.c2 + 0.95053215 * linear.c3
	}
}

fn gradient_xyz50_coordinates(color Color) GradientColorCoordinates {
	linear := gradient_linear_srgb_coordinates(color)
	// This is the inverse of Color.from_xyz50(), including chromatic adaptation.
	return GradientColorCoordinates{
		c1: 0.43606574 * linear.c1 + 0.38515147 * linear.c2 + 0.14307845 * linear.c3
		c2: 0.22249319 * linear.c1 + 0.71688705 * linear.c2 + 0.06061979 * linear.c3
		c3: 0.01392390 * linear.c1 + 0.09708129 * linear.c2 + 0.71409936 * linear.c3
	}
}

fn gradient_lab_coordinates(color Color) GradientColorCoordinates {
	xyz := gradient_xyz50_coordinates(color)
	x_n := 0.96422
	y_n := 1.0
	z_n := 0.82521
	epsilon := 216.0 / 24389.0
	kappa := 24389.0 / 27.0
	f := fn [epsilon, kappa] (value f64) f64 {
		if value > epsilon {
			return math.pow(value, 1.0 / 3.0)
		}
		return (kappa * value + 16.0) / 116.0
	}
	fx := f(xyz.c1 / x_n)
	fy := f(xyz.c2 / y_n)
	fz := f(xyz.c3 / z_n)
	return GradientColorCoordinates{
		c1: 116.0 * fy - 16.0
		c2: 500.0 * (fx - fy)
		c3: 200.0 * (fy - fz)
	}
}

fn gradient_oklab_coordinates(color Color) GradientColorCoordinates {
	oklab := color.to_oklab()
	return GradientColorCoordinates{
		c1: oklab.l
		c2: oklab.a
		c3: oklab.b
	}
}

fn gradient_display_p3_coordinates(color Color) GradientColorCoordinates {
	xyz := gradient_xyz65_coordinates(color)
	return GradientColorCoordinates{
		c1: gradient_linear_to_srgb(2.49349691 * xyz.c1 - 0.93138362 * xyz.c2 - 0.40271078 * xyz.c3)
		c2: gradient_linear_to_srgb(-0.82948897 * xyz.c1 + 1.76266406 * xyz.c2 + 0.02362469 * xyz.c3)
		c3: gradient_linear_to_srgb(0.03584583 * xyz.c1 - 0.07617239 * xyz.c2 + 0.95688452 * xyz.c3)
	}
}

fn gradient_a98_rgb_coordinates(color Color) GradientColorCoordinates {
	xyz := gradient_xyz65_coordinates(color)
	return GradientColorCoordinates{
		c1: gradient_signed_pow(2.04158790 * xyz.c1 - 0.56500697 * xyz.c2 - 0.34473135 * xyz.c3, 1.0 / 2.2)
		c2: gradient_signed_pow(-0.96924364 * xyz.c1 + 1.87596750 * xyz.c2 + 0.04155506 * xyz.c3, 1.0 / 2.2)
		c3: gradient_signed_pow(0.01344428 * xyz.c1 - 0.11836239 * xyz.c2 + 1.01517499 * xyz.c3, 1.0 / 2.2)
	}
}

fn gradient_prophoto_rgb_coordinates(color Color) GradientColorCoordinates {
	xyz := gradient_xyz50_coordinates(color)
	return GradientColorCoordinates{
		c1: gradient_signed_pow(1.34579897 * xyz.c1 - 0.25558010 * xyz.c2 - 0.05110629 * xyz.c3, 1.0 / 1.8)
		c2: gradient_signed_pow(-0.54462249 * xyz.c1 + 1.50823274 * xyz.c2 + 0.02053603 * xyz.c3, 1.0 / 1.8)
		c3: gradient_signed_pow(1.21196755 * xyz.c3, 1.0 / 1.8)
	}
}

fn gradient_rec2020_coordinates(color Color) GradientColorCoordinates {
	xyz := gradient_xyz65_coordinates(color)
	encode := fn (linear f64) f64 {
		alpha := 1.09929682680944
		beta := 0.018053968510807
		if math.abs(linear) < beta {
			return linear * 4.5
		}
		sign := if linear < 0 { -1.0 } else { 1.0 }
		return sign * (alpha * math.pow(math.abs(linear), 0.45) - (alpha - 1.0))
	}
	return GradientColorCoordinates{
		c1: encode(1.71665119 * xyz.c1 - 0.35567078 * xyz.c2 - 0.25336628 * xyz.c3)
		c2: encode(-0.66668435 * xyz.c1 + 1.61648124 * xyz.c2 + 0.01576855 * xyz.c3)
		c3: encode(0.01763986 * xyz.c1 - 0.04277061 * xyz.c2 + 0.94210312 * xyz.c3)
	}
}

fn gradient_hsl_coordinates(color Color) GradientColorCoordinates {
	r := f64(color.r) / 255.0
	g := f64(color.g) / 255.0
	b := f64(color.b) / 255.0
	maximum := math.max(r, math.max(g, b))
	minimum := math.min(r, math.min(g, b))
	delta := maximum - minimum
	lightness := (maximum + minimum) / 2.0
	mut hue := 0.0
	mut saturation := 0.0
	if delta != 0 {
		saturation = delta / (1.0 - math.abs(2.0 * lightness - 1.0))
		if maximum == r {
			hue = 60.0 * math.fmod((g - b) / delta, 6.0)
		} else if maximum == g {
			hue = 60.0 * ((b - r) / delta + 2.0)
		} else {
			hue = 60.0 * ((r - g) / delta + 4.0)
		}
	}
	return GradientColorCoordinates{
		c1: saturation
		c2: lightness
		c3: gradient_normalize_hue(hue)
		hue_is_powerless: saturation == 0
	}
}

fn gradient_hwb_coordinates(color Color) GradientColorCoordinates {
	hsl := gradient_hsl_coordinates(color)
	r := f64(color.r) / 255.0
	g := f64(color.g) / 255.0
	b := f64(color.b) / 255.0
	return GradientColorCoordinates{
		c1: math.min(r, math.min(g, b))
		c2: 1.0 - math.max(r, math.max(g, b))
		c3: hsl.c3
	}
}

fn gradient_polar_coordinates(rectangular GradientColorCoordinates,
	max_chroma_for_powerless_hue f64) GradientColorCoordinates {
	chroma := math.sqrt(rectangular.c2 * rectangular.c2 + rectangular.c3 * rectangular.c3)
	return GradientColorCoordinates{
		c1: rectangular.c1
		c2: chroma
		c3: gradient_normalize_hue(math.atan2(rectangular.c3, rectangular.c2) * 180.0 / math.pi)
		hue_is_powerless: chroma <= max_chroma_for_powerless_hue
	}
}

fn gradient_rectangular_coordinates(color Color, space RectangularColorSpace) GradientColorCoordinates {
	return match space {
		.srgb { gradient_srgb_coordinates(color) }
		.srgb_linear { gradient_linear_srgb_coordinates(color) }
		.display_p3 { gradient_display_p3_coordinates(color) }
		.a98_rgb { gradient_a98_rgb_coordinates(color) }
		.prophoto_rgb { gradient_prophoto_rgb_coordinates(color) }
		.rec2020 { gradient_rec2020_coordinates(color) }
		.lab { gradient_lab_coordinates(color) }
		.oklab { gradient_oklab_coordinates(color) }
		// DisplayListPlayerSkia currently falls back to OKLab for these spaces.
		.display_p3_linear, .xyz, .xyz_d50, .xyz_d65 { gradient_oklab_coordinates(color) }
	}
}

fn gradient_color_from_rectangular(coordinates GradientColorCoordinates, alpha f64,
	space RectangularColorSpace) Color {
	return match space {
		.srgb {
			Color.rgba(color_round_to_u8(coordinates.c1 * 255.0), color_round_to_u8(coordinates.c2 * 255.0), color_round_to_u8(coordinates.c3 * 255.0), color_round_to_u8(alpha * 255.0))
		}
		.srgb_linear {
			Color.from_linear_srgb(coordinates.c1, coordinates.c2, coordinates.c3, alpha)
		}
		.display_p3 {
			Color.from_linear_display_p3(gradient_srgb_to_linear(coordinates.c1), gradient_srgb_to_linear(coordinates.c2), gradient_srgb_to_linear(coordinates.c3), alpha)
		}
		.a98_rgb {
			linear_r := gradient_signed_pow(coordinates.c1, 2.2)
			linear_g := gradient_signed_pow(coordinates.c2, 2.2)
			linear_b := gradient_signed_pow(coordinates.c3, 2.2)
			Color.from_xyz65(0.57666904 * linear_r + 0.18555824 * linear_g + 0.18822865 * linear_b, 0.29734498 * linear_r + 0.62736357 * linear_g + 0.07529146 * linear_b, 0.02703136 * linear_r + 0.07068885 * linear_g + 0.99133754 * linear_b, alpha)
		}
		.prophoto_rgb {
			linear_r := gradient_signed_pow(coordinates.c1, 1.8)
			linear_g := gradient_signed_pow(coordinates.c2, 1.8)
			linear_b := gradient_signed_pow(coordinates.c3, 1.8)
			Color.from_xyz50(0.79776664 * linear_r + 0.13518130 * linear_g + 0.03134773 * linear_b, 0.28807483 * linear_r + 0.71183523 * linear_g + 0.00008994 * linear_b, 0.82510460 * linear_b, alpha)
		}
		.rec2020 { Color.from_rec2020(coordinates.c1, coordinates.c2, coordinates.c3, alpha) }
		.lab { Color.from_lab(coordinates.c1, coordinates.c2, coordinates.c3, alpha) }
		.oklab { Color.from_oklab(coordinates.c1, coordinates.c2, coordinates.c3, alpha) }
		.display_p3_linear, .xyz, .xyz_d50, .xyz_d65 {
			Color.from_oklab(coordinates.c1, coordinates.c2, coordinates.c3, alpha)
		}
	}
}

fn gradient_color_from_hwb(coordinates GradientColorCoordinates, alpha f64) Color {
	white := coordinates.c1
	black := coordinates.c2
	if white + black >= 1.0 {
		gray := white / (white + black)
		return Color.rgba(color_round_to_u8(gray * 255.0), color_round_to_u8(gray * 255.0), color_round_to_u8(gray * 255.0), color_round_to_u8(alpha * 255.0))
	}
	pure := Color.from_hsla(coordinates.c3, 1.0, 0.5, 1.0)
	factor := 1.0 - white - black
	return Color.rgba(color_round_to_u8((f64(pure.r) / 255.0 * factor + white) * 255.0), color_round_to_u8((f64(pure.g) / 255.0 * factor + white) * 255.0), color_round_to_u8((f64(pure.b) / 255.0 * factor + white) * 255.0), color_round_to_u8(alpha * 255.0))
}

fn gradient_color_from_polar(coordinates GradientColorCoordinates, alpha f64,
	space PolarColorSpace) Color {
	radians := coordinates.c3 * math.pi / 180.0
	return match space {
		.hsl { Color.from_hsla(coordinates.c3, coordinates.c1, coordinates.c2, alpha) }
		.hwb { gradient_color_from_hwb(coordinates, alpha) }
		.lch {
			Color.from_lab(coordinates.c1, coordinates.c2 * math.cos(radians), coordinates.c2 * math.sin(radians), alpha)
		}
		.oklch {
			Color.from_oklab(coordinates.c1, coordinates.c2 * math.cos(radians), coordinates.c2 * math.sin(radians), alpha)
		}
	}
}

fn gradient_adjust_hues(from f64, to f64, method HueInterpolationMethod) (f64, f64) {
	mut first := gradient_normalize_hue(from)
	mut second := gradient_normalize_hue(to)
	match method {
		.shorter {
			if second - first > 180.0 {
				first += 360.0
			} else if second - first < -180.0 {
				second += 360.0
			}
		}
		.longer {
			if second - first > 0.0 && second - first < 180.0 {
				first += 360.0
			} else if second - first > -180.0 && second - first <= 0.0 {
				second += 360.0
			}
		}
		.increasing {
			if second < first {
				second += 360.0
			}
		}
		.decreasing {
			if first < second {
				first += 360.0
			}
		}
	}
	return first, second
}

fn gradient_interpolate_premultiplied(from Color, to Color, amount f64,
	from_coordinates GradientColorCoordinates, to_coordinates GradientColorCoordinates,
	is_polar bool, hue_method HueInterpolationMethod) (GradientColorCoordinates, f64) {
	t := math.max(0.0, math.min(amount, 1.0))
	from_alpha := f64(from.a) / 255.0
	to_alpha := f64(to.a) / 255.0
	alpha := from_alpha + (to_alpha - from_alpha) * t
	if alpha == 0 {
		return GradientColorCoordinates{}, 0.0
	}
	mut first := from_coordinates
	mut second := to_coordinates
	first.c1 *= from_alpha
	first.c2 *= from_alpha
	second.c1 *= to_alpha
	second.c2 *= to_alpha
	if !is_polar {
		first.c3 *= from_alpha
		second.c3 *= to_alpha
	} else {
		// SkColor4fXformer duplicates a powerless stop and borrows the hue from
		// the neighbor on each side. Interpolation is performed one resolved
		// stop span at a time here, so borrowing the opposite endpoint is the
		// equivalent operation.
		if first.hue_is_powerless {
			first.c3 = to_coordinates.c3
		}
		if second.hue_is_powerless {
			second.c3 = from_coordinates.c3
		}
		first.c3, second.c3 = gradient_adjust_hues(first.c3, second.c3, hue_method)
	}
	return GradientColorCoordinates{
		c1: (first.c1 + (second.c1 - first.c1) * t) / alpha
		c2: (first.c2 + (second.c2 - first.c2) * t) / alpha
		c3: if is_polar {
			gradient_normalize_hue(first.c3 + (second.c3 - first.c3) * t)
		} else {
			(first.c3 + (second.c3 - first.c3) * t) / alpha
		}
	}, alpha
}

// DisplayListPlayerSkia::to_skia_interpolation() selects the gradient color
// space and always asks Skia to interpolate premultiplied colors. This is the
// equivalent used by the V raster and portable SVG backends.
pub fn interpolate_gradient_color(from Color, to Color, amount f64,
	method ColorInterpolationMethod) Color {
	match method {
		RectangularColorSpace {
			from_coordinates := gradient_rectangular_coordinates(from, method)
			to_coordinates := gradient_rectangular_coordinates(to, method)
			coordinates, alpha := gradient_interpolate_premultiplied(from, to, amount, from_coordinates, to_coordinates, false, .shorter)
			return gradient_color_from_rectangular(coordinates, alpha, method)
		}
		PolarColorInterpolationMethod {
			from_rectangular := match method.color_space {
				.hsl { gradient_hsl_coordinates(from) }
				.hwb { gradient_hwb_coordinates(from) }
				.lch { gradient_polar_coordinates(gradient_lab_coordinates(from), 1e-2) }
				.oklch { gradient_polar_coordinates(gradient_oklab_coordinates(from), 1e-6) }
			}
			to_rectangular := match method.color_space {
				.hsl { gradient_hsl_coordinates(to) }
				.hwb { gradient_hwb_coordinates(to) }
				.lch { gradient_polar_coordinates(gradient_lab_coordinates(to), 1e-2) }
				.oklch { gradient_polar_coordinates(gradient_oklab_coordinates(to), 1e-6) }
			}
			coordinates, alpha := gradient_interpolate_premultiplied(from, to, amount, from_rectangular, to_rectangular, true, method.hue_interpolation_method)
			return gradient_color_from_polar(coordinates, alpha, method.color_space)
		}
	}
}
