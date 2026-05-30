module css

import dom
import math

// --- CalculatedOr ---

pub fn (c CalculatedStyleValue) resolve_angle(context CalculationResolutionContext) ?Angle {
	inner := c.inner_calculation_text()
	if angle := calculated_parse_angle(inner) {
		return angle
	}
	if percentage := calculated_parse_percentage(inner) {
		if percentage_basis := context.percentage_basis_angle() {
			return percentage_basis.percentage_of(percentage)
		}
	}
	if percentage_basis := context.percentage_basis_angle() {
		return percentage_basis
	}
	return Angle.make_degrees(0)
}

pub fn (c CalculatedStyleValue) resolve_flex(context CalculationResolutionContext) ?Flex {
	_ = context
	inner := c.inner_calculation_text()
	mut parser := Parser.from_css_text(inner)
	mut tokens := ComponentValueStream.new(parser.component_values)
	if style_value := parser.parse_flex_value(mut tokens) {
		if !tokens.has_more_tokens() && style_value is FlexStyleValue {
			return (style_value as FlexStyleValue).flex()
		}
	}
	return Flex.make_fr(0)
}

pub fn (c CalculatedStyleValue) resolve_frequency(context CalculationResolutionContext) ?Frequency {
	inner := c.inner_calculation_text()
	if frequency := calculated_parse_frequency(inner) {
		return frequency
	}
	if percentage := calculated_parse_percentage(inner) {
		if percentage_basis := context.percentage_basis_frequency() {
			return percentage_basis.percentage_of(percentage)
		}
	}
	if percentage_basis := context.percentage_basis_frequency() {
		return percentage_basis
	}
	return Frequency.make_hertz(0)
}

pub fn (c CalculatedStyleValue) resolve_integer(context CalculationResolutionContext) ?i64 {
	if resolved_number := c.resolve_number(context) {
		return i64(math.round(resolved_number))
	}
	return i64(0)
}

pub fn (c CalculatedStyleValue) resolve_number(context CalculationResolutionContext) ?f64 {
	inner := c.inner_calculation_text()
	if number := calculated_parse_number(inner) {
		return number.value()
	}
	if percentage := calculated_parse_percentage(inner) {
		if percentage_basis := context.percentage_basis_number() {
			return percentage_basis.value() * percentage.as_fraction()
		}
	}
	if percentage_basis := context.percentage_basis_number() {
		return percentage_basis.value()
	}
	return 0.0
}

pub fn (c CalculatedStyleValue) resolve_percentage(context CalculationResolutionContext) ?Percentage {
	_ = context
	inner := c.inner_calculation_text()
	if percentage := calculated_parse_percentage(inner) {
		return percentage
	}
	return Percentage.new(0)
}

pub fn (c CalculatedStyleValue) resolve_resolution(context CalculationResolutionContext) ?Resolution {
	_ = context
	inner := c.inner_calculation_text()
	if resolution := calculated_parse_resolution(inner) {
		return resolution
	}
	return Resolution.make_dots_per_pixel(0)
}

pub fn (c CalculatedStyleValue) resolve_time(context CalculationResolutionContext) ?Time {
	inner := c.inner_calculation_text()
	if time := calculated_parse_time(inner) {
		return time
	}
	if percentage := calculated_parse_percentage(inner) {
		if percentage_basis := context.percentage_basis_time() {
			return percentage_basis.percentage_of(percentage)
		}
	}
	if percentage_basis := context.percentage_basis_time() {
		return percentage_basis
	}
	return Time.make_seconds(0)
}

fn empty_style_value() &dom.StyleValue {
	return &dom.StyleValue{}
}

pub type AngleOrCalculatedValue = Angle | CalculatedStyleValue

pub struct AngleOrCalculated {
pub mut:
	value_ AngleOrCalculatedValue
}

pub fn AngleOrCalculated.from_angle(value Angle) AngleOrCalculated {
	return AngleOrCalculated{
		value_: value
	}
}

pub fn AngleOrCalculated.from_calculated(calculated CalculatedStyleValue) AngleOrCalculated {
	return AngleOrCalculated{
		value_: calculated
	}
}

pub fn (v AngleOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v AngleOrCalculated) value() Angle {
	value := v.value_
	if value is Angle {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v AngleOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v AngleOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v AngleOrCalculated) resolved(context CalculationResolutionContext) ?Angle {
	value := v.value_
	return match value {
		Angle { value }
		CalculatedStyleValue { value.resolve_angle(context) }
	}
}

pub fn (v AngleOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Angle { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v AngleOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v AngleOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type FlexOrCalculatedValue = CalculatedStyleValue | Flex

pub struct FlexOrCalculated {
pub mut:
	value_ FlexOrCalculatedValue
}

pub fn FlexOrCalculated.from_flex(value Flex) FlexOrCalculated {
	return FlexOrCalculated{
		value_: value
	}
}

pub fn FlexOrCalculated.from_calculated(calculated CalculatedStyleValue) FlexOrCalculated {
	return FlexOrCalculated{
		value_: calculated
	}
}

pub fn (v FlexOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v FlexOrCalculated) value() Flex {
	value := v.value_
	if value is Flex {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v FlexOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v FlexOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v FlexOrCalculated) resolved(context CalculationResolutionContext) ?Flex {
	value := v.value_
	return match value {
		Flex { value }
		CalculatedStyleValue { value.resolve_flex(context) }
	}
}

pub fn (v FlexOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Flex { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v FlexOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v FlexOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type FrequencyOrCalculatedValue = CalculatedStyleValue | Frequency

pub struct FrequencyOrCalculated {
pub mut:
	value_ FrequencyOrCalculatedValue
}

pub fn FrequencyOrCalculated.from_frequency(value Frequency) FrequencyOrCalculated {
	return FrequencyOrCalculated{
		value_: value
	}
}

pub fn FrequencyOrCalculated.from_calculated(calculated CalculatedStyleValue) FrequencyOrCalculated {
	return FrequencyOrCalculated{
		value_: calculated
	}
}

pub fn (v FrequencyOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v FrequencyOrCalculated) value() Frequency {
	value := v.value_
	if value is Frequency {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v FrequencyOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v FrequencyOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v FrequencyOrCalculated) resolved(context CalculationResolutionContext) ?Frequency {
	value := v.value_
	return match value {
		Frequency { value }
		CalculatedStyleValue { value.resolve_frequency(context) }
	}
}

pub fn (v FrequencyOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Frequency { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v FrequencyOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v FrequencyOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type IntegerOrCalculatedValue = CalculatedStyleValue | i64

pub struct IntegerOrCalculated {
pub mut:
	value_ IntegerOrCalculatedValue
}

pub fn IntegerOrCalculated.from_integer(value i64) IntegerOrCalculated {
	return IntegerOrCalculated{
		value_: value
	}
}

pub fn IntegerOrCalculated.from_calculated(calculated CalculatedStyleValue) IntegerOrCalculated {
	return IntegerOrCalculated{
		value_: calculated
	}
}

pub fn (v IntegerOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v IntegerOrCalculated) value() i64 {
	value := v.value_
	if value is i64 {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v IntegerOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v IntegerOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v IntegerOrCalculated) resolved(context CalculationResolutionContext) ?i64 {
	value := v.value_
	return match value {
		i64 { value }
		CalculatedStyleValue { value.resolve_integer(context) }
	}
}

pub fn (v IntegerOrCalculated) serialize(mode SerializationMode) string {
	_ = mode
	value := v.value_
	return match value {
		i64 { '${value}' }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v IntegerOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v IntegerOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type LengthOrCalculatedValue = CalculatedStyleValue | Length

pub struct LengthOrCalculated {
pub mut:
	value_ LengthOrCalculatedValue
}

pub fn LengthOrCalculated.from_length(value Length) LengthOrCalculated {
	return LengthOrCalculated{
		value_: value
	}
}

pub fn LengthOrCalculated.from_calculated(calculated CalculatedStyleValue) LengthOrCalculated {
	return LengthOrCalculated{
		value_: calculated
	}
}

pub fn (v LengthOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v LengthOrCalculated) value() Length {
	value := v.value_
	if value is Length {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v LengthOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v LengthOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v LengthOrCalculated) resolved(context CalculationResolutionContext) ?Length {
	value := v.value_
	return match value {
		Length { value }
		CalculatedStyleValue { value.resolve_length(context) }
	}
}

pub fn (v LengthOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Length { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v LengthOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v LengthOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type LengthOrAutoOrCalculatedValue = CalculatedStyleValue | LengthOrAuto

pub struct LengthOrAutoOrCalculated {
pub mut:
	value_ LengthOrAutoOrCalculatedValue
}

pub fn LengthOrAutoOrCalculated.from_length_or_auto(value LengthOrAuto) LengthOrAutoOrCalculated {
	return LengthOrAutoOrCalculated{
		value_: value
	}
}

pub fn LengthOrAutoOrCalculated.from_calculated(calculated CalculatedStyleValue) LengthOrAutoOrCalculated {
	return LengthOrAutoOrCalculated{
		value_: calculated
	}
}

pub fn (v LengthOrAutoOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v LengthOrAutoOrCalculated) value() LengthOrAuto {
	value := v.value_
	if value is LengthOrAuto {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v LengthOrAutoOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v LengthOrAutoOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v LengthOrAutoOrCalculated) resolved(context CalculationResolutionContext) ?LengthOrAuto {
	value := v.value_
	return match value {
		LengthOrAuto {
			value
		}
		CalculatedStyleValue {
			length := value.resolve_length(context) or { return none }
			LengthOrAuto.new(length)
		}
	}
}

pub fn (v LengthOrAutoOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		LengthOrAuto { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v LengthOrAutoOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v LengthOrAutoOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub fn (v LengthOrAutoOrCalculated) is_auto() bool {
	return !v.is_calculated() && v.value().is_auto()
}

pub fn (v LengthOrAutoOrCalculated) without_auto() LengthOrCalculated {
	if v.is_auto() {
		panic('VERIFY_NOT_REACHED')
	}
	if v.is_calculated() {
		return LengthOrCalculated.from_calculated(v.calculated())
	}
	length := v.value().length() or { panic('VERIFY_NOT_REACHED') }
	return LengthOrCalculated.from_length(length)
}

pub type NumberOrCalculatedValue = CalculatedStyleValue | f64

pub struct NumberOrCalculated {
pub mut:
	value_ NumberOrCalculatedValue
}

pub fn NumberOrCalculated.from_number(value f64) NumberOrCalculated {
	return NumberOrCalculated{
		value_: value
	}
}

pub fn NumberOrCalculated.from_calculated(calculated CalculatedStyleValue) NumberOrCalculated {
	return NumberOrCalculated{
		value_: calculated
	}
}

pub fn (v NumberOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v NumberOrCalculated) value() f64 {
	value := v.value_
	if value is f64 {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v NumberOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v NumberOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v NumberOrCalculated) resolved(context CalculationResolutionContext) ?f64 {
	value := v.value_
	return match value {
		f64 { value }
		CalculatedStyleValue { value.resolve_number(context) }
	}
}

pub fn (v NumberOrCalculated) serialize(mode SerializationMode) string {
	_ = mode
	value := v.value_
	return match value {
		f64 { '${value}' }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v NumberOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v NumberOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type PercentageOrCalculatedValue = CalculatedStyleValue | Percentage

pub struct PercentageOrCalculated {
pub mut:
	value_ PercentageOrCalculatedValue
}

pub fn PercentageOrCalculated.from_percentage(value Percentage) PercentageOrCalculated {
	return PercentageOrCalculated{
		value_: value
	}
}

pub fn PercentageOrCalculated.from_calculated(calculated CalculatedStyleValue) PercentageOrCalculated {
	return PercentageOrCalculated{
		value_: calculated
	}
}

pub fn (v PercentageOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v PercentageOrCalculated) value() Percentage {
	value := v.value_
	if value is Percentage {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v PercentageOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v PercentageOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v PercentageOrCalculated) resolved(context CalculationResolutionContext) ?Percentage {
	value := v.value_
	return match value {
		Percentage { value }
		CalculatedStyleValue { value.resolve_percentage(context) }
	}
}

pub fn (v PercentageOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Percentage { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v PercentageOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v PercentageOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type ResolutionOrCalculatedValue = CalculatedStyleValue | Resolution

pub struct ResolutionOrCalculated {
pub mut:
	value_ ResolutionOrCalculatedValue
}

pub fn ResolutionOrCalculated.from_resolution(value Resolution) ResolutionOrCalculated {
	return ResolutionOrCalculated{
		value_: value
	}
}

pub fn ResolutionOrCalculated.from_calculated(calculated CalculatedStyleValue) ResolutionOrCalculated {
	return ResolutionOrCalculated{
		value_: calculated
	}
}

pub fn (v ResolutionOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v ResolutionOrCalculated) value() Resolution {
	value := v.value_
	if value is Resolution {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v ResolutionOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v ResolutionOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v ResolutionOrCalculated) resolved(context CalculationResolutionContext) ?Resolution {
	value := v.value_
	return match value {
		Resolution { value }
		CalculatedStyleValue { value.resolve_resolution(context) }
	}
}

pub fn (v ResolutionOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Resolution { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v ResolutionOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v ResolutionOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}

pub type TimeOrCalculatedValue = CalculatedStyleValue | Time

pub struct TimeOrCalculated {
pub mut:
	value_ TimeOrCalculatedValue
}

pub fn TimeOrCalculated.from_time(value Time) TimeOrCalculated {
	return TimeOrCalculated{
		value_: value
	}
}

pub fn TimeOrCalculated.from_calculated(calculated CalculatedStyleValue) TimeOrCalculated {
	return TimeOrCalculated{
		value_: calculated
	}
}

pub fn (v TimeOrCalculated) is_calculated() bool {
	return v.value_ is CalculatedStyleValue
}

pub fn (v TimeOrCalculated) value() Time {
	value := v.value_
	if value is Time {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v TimeOrCalculated) calculated() CalculatedStyleValue {
	value := v.value_
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (v TimeOrCalculated) as_style_value() &dom.StyleValue {
	return empty_style_value()
}

pub fn (v TimeOrCalculated) resolved(context CalculationResolutionContext) ?Time {
	value := v.value_
	return match value {
		Time { value }
		CalculatedStyleValue { value.resolve_time(context) }
	}
}

pub fn (v TimeOrCalculated) serialize(mode SerializationMode) string {
	value := v.value_
	return match value {
		Time { value.serialize(mode) }
		CalculatedStyleValue { value.serialize(mode) }
	}
}

pub fn (v TimeOrCalculated) to_string() string {
	return v.serialize(.normal)
}

pub fn (v TimeOrCalculated) to_string_with_mode(mode SerializationMode) string {
	return v.serialize(mode)
}
