module css

import math

// PixelUnits.h is expressed with methods instead of C++ operators. Keeping the
// fixed-point arithmetic here makes the saturation and rounding rules explicit.

pub const css_pixels_max_dimension_value = f32(17_895_700)

fn css_pixels_clamp_i64_to_raw(value i64) int {
	if value > i64(css_pixels_raw_max) {
		return css_pixels_raw_max
	}
	if value < i64(css_pixels_raw_min) {
		return css_pixels_raw_min
	}
	return int(value)
}

fn css_pixels_clamp_f64_to_raw(value f64) int {
	if value >= f64(css_pixels_raw_max) {
		return css_pixels_raw_max
	}
	if value <= f64(css_pixels_raw_min) {
		return css_pixels_raw_min
	}
	return int(value)
}

pub fn (p CSSPixels) to_float() f32 {
	return f32(p.raw_value_) / f32(css_pixels_fixed_point_denominator)
}

pub fn (p CSSPixels) to_int() int {
	return int(p.raw_value_) / css_pixels_fixed_point_denominator
}

pub fn (p CSSPixels) compare(other CSSPixels) int {
	if p.raw_value_ < other.raw_value_ {
		return -1
	}
	if p.raw_value_ > other.raw_value_ {
		return 1
	}
	return 0
}

pub fn (p CSSPixels) negated() CSSPixels {
	return CSSPixels.from_raw(css_pixels_clamp_i64_to_raw(-i64(p.raw_value_)))
}

pub fn (p CSSPixels) abs() CSSPixels {
	if p.raw_value_ < 0 {
		return p.negated()
	}
	return p
}

pub fn (p CSSPixels) incremented() CSSPixels {
	return p.plus(CSSPixels.new(1))
}

pub fn (p CSSPixels) decremented() CSSPixels {
	return p.minus(CSSPixels.new(1))
}

pub fn (p CSSPixels) times(other CSSPixels) CSSPixels {
	wide_value := i64(p.raw_value_) * i64(other.raw_value_)
	mut integer_value := css_pixels_clamp_i64_to_raw(wide_value >> css_pixels_fractional_bits)
	if wide_value & i64(1 << (css_pixels_fractional_bits - 1)) != 0 {
		if wide_value & i64(css_pixels_radix_mask >> 1) != 0 {
			integer_value = css_pixels_clamp_i64_to_raw(i64(integer_value) + 1)
		} else {
			integer_value = css_pixels_clamp_i64_to_raw(i64(integer_value) + i64(integer_value & 1))
		}
	}
	return CSSPixels.from_raw(integer_value)
}

pub fn (p CSSPixels) times_fraction(fraction CSSPixelFraction) CSSPixels {
	wide_value := i64(p.raw_value_) * i64(fraction.numerator_.raw_value_)
	return CSSPixels.from_raw(css_pixels_clamp_i64_to_raw(wide_value / i64(fraction.denominator_.raw_value_)))
}

pub fn (p CSSPixels) divided_by(other CSSPixels) CSSPixelFraction {
	return CSSPixelFraction.new(p, other)
}

pub fn (p CSSPixels) divided_by_fraction(fraction CSSPixelFraction) CSSPixels {
	if fraction.numerator_.raw_value_ == 0 {
		panic('cannot divide CSSPixels by a zero fraction')
	}
	wide_value := i64(p.raw_value_) * i64(fraction.denominator_.raw_value_)
	return CSSPixels.from_raw(css_pixels_clamp_i64_to_raw(wide_value / i64(fraction.numerator_.raw_value_)))
}

pub fn (p CSSPixels) scaled(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(p.to_double() * value)
}

pub fn css_pixels_floor(value CSSPixels) CSSPixels {
	return CSSPixels.from_raw(int(value.raw_value_) & ~css_pixels_radix_mask)
}

pub fn css_pixels_ceil(value CSSPixels) CSSPixels {
	floor_value := int(value.raw_value_) & ~css_pixels_radix_mask
	if value.raw_value_ & css_pixels_radix_mask == 0 {
		return CSSPixels.from_raw(floor_value)
	}
	return CSSPixels.from_raw(css_pixels_clamp_i64_to_raw(i64(floor_value) +
		css_pixels_fixed_point_denominator))
}

pub fn css_pixels_round(value CSSPixels) CSSPixels {
	half := CSSPixels.from_raw(css_pixels_fixed_point_denominator >> 1)
	if value.raw_value_ > 0 {
		return css_pixels_floor(value.plus(half))
	}
	return css_pixels_ceil(value.minus(half))
}

pub fn css_pixels_sqrt(value CSSPixels) CSSPixels {
	return CSSPixels.nearest_value_for(math.sqrt(value.to_double()))
}

pub fn CSSPixelFraction.from_values(numerator f64, denominator f64) CSSPixelFraction {
	if CSSPixels.nearest_value_for(denominator).raw_value_ == 0 {
		return CSSPixelFraction.new(CSSPixels.nearest_value_for(numerator / denominator),
			CSSPixels.new(1))
	}
	return CSSPixelFraction.new(CSSPixels.nearest_value_for(numerator),
		CSSPixels.nearest_value_for(denominator))
}

pub fn (fraction CSSPixelFraction) numerator() CSSPixels {
	return fraction.numerator_
}

pub fn (fraction CSSPixelFraction) denominator() CSSPixels {
	return fraction.denominator_
}

pub fn (fraction CSSPixelFraction) to_css_pixels() CSSPixels {
	wide_value := i64(fraction.numerator_.raw_value_) * i64(css_pixels_fixed_point_denominator)
	return CSSPixels.from_raw(css_pixels_clamp_i64_to_raw(wide_value / i64(fraction.denominator_.raw_value_)))
}

pub fn (fraction CSSPixelFraction) to_float() f32 {
	return fraction.numerator_.to_float() / fraction.denominator_.to_float()
}

pub fn (fraction CSSPixelFraction) to_int() int {
	return fraction.to_css_pixels().to_int()
}

pub fn (fraction CSSPixelFraction) negated() CSSPixelFraction {
	return CSSPixelFraction.new(fraction.numerator_.negated(), fraction.denominator_)
}

pub fn (fraction CSSPixelFraction) plus_pixels(other CSSPixels) CSSPixels {
	return fraction.to_css_pixels().plus(other)
}

pub fn (fraction CSSPixelFraction) minus_pixels(other CSSPixels) CSSPixels {
	return fraction.to_css_pixels().minus(other)
}

pub fn (fraction CSSPixelFraction) compare(other CSSPixelFraction) int {
	left := i64(fraction.numerator_.raw_value_) * i64(other.denominator_.raw_value_)
	right := i64(other.numerator_.raw_value_) * i64(fraction.denominator_.raw_value_)
	if left < right {
		return -1
	}
	if left > right {
		return 1
	}
	return 0
}

pub fn (rect CSSPixelRect) left() CSSPixels {
	return rect.x
}

pub fn (rect CSSPixelRect) top() CSSPixels {
	return rect.y
}

pub fn (rect CSSPixelRect) right() CSSPixels {
	return rect.x.plus(rect.width)
}

pub fn (rect CSSPixelRect) bottom() CSSPixels {
	return rect.y.plus(rect.height)
}

pub fn (rect CSSPixelRect) location() CSSPixelPoint {
	return CSSPixelPoint.new(rect.x, rect.y)
}

pub fn (rect CSSPixelRect) size() CSSPixelSize {
	return CSSPixelSize.new(rect.width, rect.height)
}

pub fn css_pixels_square_distance_between(a CSSPixelPoint, b CSSPixelPoint) CSSPixels {
	delta_x := a.x().minus(b.x()).abs()
	delta_y := a.y().minus(b.y()).abs()
	return delta_x.times(delta_x).plus(delta_y.times(delta_y))
}

fn css_pixels_clamp(value CSSPixels, minimum CSSPixels, maximum CSSPixels) CSSPixels {
	if value.compare(minimum) < 0 {
		return minimum
	}
	if value.compare(maximum) > 0 {
		return maximum
	}
	return value
}

pub fn css_pixel_point_constrained(point CSSPixelPoint, rect CSSPixelRect) CSSPixelPoint {
	one := CSSPixels.new(1)
	return CSSPixelPoint.new(css_pixels_clamp(point.x(), rect.left(), rect.right().minus(one)), css_pixels_clamp(point.y(),
		rect.top(), rect.bottom().minus(one)))
}

pub struct DevicePixels {
pub mut:
	value_ int
}

pub fn DevicePixels.new(value int) DevicePixels {
	return DevicePixels{
		value_: value
	}
}

pub fn (pixels DevicePixels) value() int {
	return pixels.value_
}

pub fn (pixels DevicePixels) plus(other DevicePixels) DevicePixels {
	return DevicePixels.new(pixels.value_ + other.value_)
}

pub fn (pixels DevicePixels) minus(other DevicePixels) DevicePixels {
	return DevicePixels.new(pixels.value_ - other.value_)
}

pub fn (pixels DevicePixels) times(value int) DevicePixels {
	return DevicePixels.new(pixels.value_ * value)
}

pub fn (pixels DevicePixels) divided_by(value int) DevicePixels {
	return DevicePixels.new(pixels.value_ / value)
}

pub fn (pixels DevicePixels) modulo(value int) DevicePixels {
	return DevicePixels.new(pixels.value_ % value)
}

pub fn (pixels DevicePixels) abs() DevicePixels {
	return DevicePixels.new(if pixels.value_ < 0 { -pixels.value_ } else { pixels.value_ })
}

pub struct DevicePixelPoint {
pub mut:
	x_ DevicePixels
	y_ DevicePixels
}

pub fn DevicePixelPoint.new(x DevicePixels, y DevicePixels) DevicePixelPoint {
	return DevicePixelPoint{
		x_: x
		y_: y
	}
}

pub fn (point DevicePixelPoint) x() DevicePixels {
	return point.x_
}

pub fn (point DevicePixelPoint) y() DevicePixels {
	return point.y_
}

pub struct DevicePixelSize {
pub mut:
	width_  DevicePixels
	height_ DevicePixels
}

pub fn DevicePixelSize.new(width DevicePixels, height DevicePixels) DevicePixelSize {
	return DevicePixelSize{
		width_:  width
		height_: height
	}
}

pub fn (size DevicePixelSize) width() DevicePixels {
	return size.width_
}

pub fn (size DevicePixelSize) height() DevicePixels {
	return size.height_
}

pub struct DevicePixelRect {
pub mut:
	x_      DevicePixels
	y_      DevicePixels
	width_  DevicePixels
	height_ DevicePixels
}

pub fn DevicePixelRect.new(location DevicePixelPoint, size DevicePixelSize) DevicePixelRect {
	return DevicePixelRect{
		x_:      location.x()
		y_:      location.y()
		width_:  size.width()
		height_: size.height()
	}
}

pub fn (rect DevicePixelRect) location() DevicePixelPoint {
	return DevicePixelPoint.new(rect.x_, rect.y_)
}

pub fn (rect DevicePixelRect) size() DevicePixelSize {
	return DevicePixelSize.new(rect.width_, rect.height_)
}

// PixelUnits.cpp plugs these scalar components into LibIPC's generic encoder.
// The V port has no IPC module yet, so these helpers expose the same wire order
// without coupling pixel units to a particular byte encoding. DevicePixels uses
// LibIPC's generic distinct-numeric codec upstream, while CSSPixelPoint keeps an
// explicit raw fixed-point representation on the wire.
pub fn encode_device_pixels(value DevicePixels) []int {
	return [value.value()]
}

pub fn decode_device_pixels(components []int) !DevicePixels {
	if components.len != 1 {
		return error('DevicePixels requires one IPC component')
	}
	return DevicePixels.new(components[0])
}

pub fn encode_css_pixel_point(value CSSPixelPoint) []int {
	return [value.x().raw_value(), value.y().raw_value()]
}

pub fn decode_css_pixel_point(components []int) !CSSPixelPoint {
	if components.len != 2 {
		return error('CSSPixelPoint requires two IPC components')
	}
	return CSSPixelPoint.new(CSSPixels.from_raw(components[0]), CSSPixels.from_raw(components[1]))
}

pub fn encode_device_pixel_point(value DevicePixelPoint) []int {
	return [value.x().value(), value.y().value()]
}

pub fn decode_device_pixel_point(components []int) !DevicePixelPoint {
	if components.len != 2 {
		return error('DevicePixelPoint requires two IPC components')
	}
	return DevicePixelPoint.new(DevicePixels.new(components[0]), DevicePixels.new(components[1]))
}

pub fn encode_device_pixel_size(value DevicePixelSize) []int {
	return [value.width().value(), value.height().value()]
}

pub fn decode_device_pixel_size(components []int) !DevicePixelSize {
	if components.len != 2 {
		return error('DevicePixelSize requires two IPC components')
	}
	return DevicePixelSize.new(DevicePixels.new(components[0]), DevicePixels.new(components[1]))
}

pub fn encode_device_pixel_rect(value DevicePixelRect) []int {
	location := value.location()
	size := value.size()
	return [location.x().value(), location.y().value(), size.width().value(),
		size.height().value()]
}

pub fn decode_device_pixel_rect(components []int) !DevicePixelRect {
	if components.len != 4 {
		return error('DevicePixelRect requires four IPC components')
	}
	return DevicePixelRect.new(DevicePixelPoint.new(DevicePixels.new(components[0]),
		DevicePixels.new(components[1])), DevicePixelSize.new(DevicePixels.new(components[2]),
		DevicePixels.new(components[3])))
}
