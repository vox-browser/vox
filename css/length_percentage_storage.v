module css

import dom

// Simple values need no heap owner. A nonnegative code is a LengthUnit; the
// two negative codes distinguish a percentage and an owned calculation.
union LengthPercentagePayload {
mut:
	number      f64
	calculation &CalculatedStyleValue = unsafe { nil }
}

pub struct LengthPercentage {
	unit_code_ i32 = i32(LengthUnit.px)
	payload_ LengthPercentagePayload
}

pub fn LengthPercentage.from_length(length Length) LengthPercentage {
	mut value := LengthPercentage{unit_code_:i32(length.unit_)}
	unsafe { value.payload_.number = length.value_ }
	return value
}

pub fn LengthPercentage.from_percentage(percentage Percentage) LengthPercentage {
	mut value := LengthPercentage{unit_code_:-1}
	unsafe { value.payload_.number = percentage.value() }
	return value
}

pub fn LengthPercentage.from_calculated(calculated CalculatedStyleValue) LengthPercentage {
	mut value := LengthPercentage{unit_code_:-2}
	unsafe { value.payload_.calculation = &CalculatedStyleValue{...calculated} }
	return value
}

pub fn LengthPercentage.from_style_value(style_value &dom.StyleValue) LengthPercentage {
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return LengthPercentage.from_style_value_logic(parsed_value)
	}
	return LengthPercentage.from_length(Length.make_px(0))
}

pub fn (lp LengthPercentage) is_length() bool { return lp.unit_code_ >= 0 }
pub fn (lp LengthPercentage) is_percentage() bool { return lp.unit_code_ == -1 }
pub fn (lp LengthPercentage) is_calculated() bool { return lp.unit_code_ == -2 }

pub fn (lp LengthPercentage) contains_percentage() bool {
	if lp.is_percentage() { return true }
	if lp.is_calculated() { return lp.calculated().contains_percentage() }
	return false
}

pub fn (lp LengthPercentage) length() Length {
	if !lp.is_length() { panic('VERIFY_NOT_REACHED') }
	return Length.new(unsafe { lp.payload_.number }, unsafe { LengthUnit(lp.unit_code_) })
}

pub fn (lp LengthPercentage) percentage() Percentage {
	if !lp.is_percentage() { panic('VERIFY_NOT_REACHED') }
	return Percentage.new(unsafe { lp.payload_.number })
}

pub fn (lp LengthPercentage) calculated() CalculatedStyleValue {
	if !lp.is_calculated() { panic('VERIFY_NOT_REACHED') }
	return unsafe { *lp.payload_.calculation }
}

pub fn (lp LengthPercentage) to_px(context LengthResolutionContext, reference_value CSSPixels) CSSPixels {
	if lp.is_calculated() {
		resolved := Length.resolve_calculated_with_px(lp.calculated(), context, reference_value)
		return CSSPixels.truncated_value_for(resolved.to_px_without_rounding(context))
	}
	return lp.resolved(context, reference_value).to_px(context)
}

pub fn (lp LengthPercentage) resolved(context LengthResolutionContext, reference_value CSSPixels) Length {
	if lp.is_length() { return lp.length() }
	if lp.is_percentage() {
		return Length.make_css_px(CSSPixels.truncated_value_for(reference_value.to_double() * lp.percentage().as_fraction()))
	}
	return Length.resolve_calculated_with_px(lp.calculated(), context, reference_value)
}

pub fn (lp LengthPercentage) serialize(mode SerializationMode) string {
	if lp.is_length() { return lp.length().serialize(mode) }
	if lp.is_percentage() { return lp.percentage().serialize(mode) }
	return lp.calculated().serialize(mode)
}

pub fn (lp LengthPercentage) to_string() string { return lp.serialize(.normal) }
pub fn (lp LengthPercentage) to_string_with_mode(mode SerializationMode) string { return lp.serialize(mode) }

pub fn (a LengthPercentage) == (b LengthPercentage) bool {
	if a.unit_code_ != b.unit_code_ { return false }
	if a.is_calculated() { return a.calculated() == b.calculated() }
	return unsafe { a.payload_.number == b.payload_.number }
}
