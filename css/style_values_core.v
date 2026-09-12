// Translated from core LibWeb/CSS StyleValue and Typed OM classes.
module css

import dom
import math

// --- Small parser/JS/WebIDL boundary types ---
pub struct AcceptedTypeRange {
pub mut:
	min f64
	max f64
}

pub struct CalculationContext {
pub mut:
	percentages_resolve_as      ?ValueType
	resolve_numbers_as_integers bool
	accepted_type_ranges        map[ValueType]AcceptedTypeRange
}

pub fn CalculationContext.for_property(property PropertyNameAndID) CalculationContext {
	// FIXME: Handle registered custom properties, which may limit which types they accept.
	property_id := property.id() or { return CalculationContext{} }
	return CalculationContext{
		percentages_resolve_as: property_resolves_percentages_relative_to(property_id)
		resolve_numbers_as_integers: property_accepts_type(property_id, .integer)
		accepted_type_ranges: property_accepted_type_ranges(property_id)
	}
}

pub struct CalculationNode {
pub mut:
	serialization string
	node          []CalcNode
}

fn calculation_node_from_calc(node CalcNode) CalculationNode {
	return CalculationNode{
		serialization: node.serialize_top()
		node: [node]
	}
}

fn (node CalculationNode) typed_node() !CalcNode {
	if node.node.len != 1 {
		return error('CalculationNode has no typed calculation tree')
	}
	return node.node[0]
}

pub fn Color.black() Color {
	return Color.rgb(0, 0, 0)
}

pub fn (c Color) red() u8 {
	return c.r
}

pub fn (c Color) green() u8 {
	return c.g
}

pub fn (c Color) blue() u8 {
	return c.b
}

pub fn (c Color) alpha() u8 {
	return c.a
}

pub fn (c Color) luminosity() u8 {
	return u8(int(math.round(f64(c.red()) * 0.2126 + f64(c.green()) * 0.7152 + f64(c.blue()) * 0.0722)))
}

pub fn (c Color) contrast_ratio(other Color) f64 {
	l1 := c.luminosity()
	l2 := other.luminosity()
	darkest := f64(if l1 < l2 { l1 } else { l2 }) / 255.0
	brightest := f64(if l1 > l2 { l1 } else { l2 }) / 255.0
	return (brightest + 0.05) / (darkest + 0.05)
}

// LibGfx::Color::blend(): composite source over this destination using the
// integer unpremultiplied-alpha arithmetic used by the native renderer.
pub fn (c Color) blend(source Color) Color {
	if c.a == 0 || source.a == 255 {
		return source
	}
	if source.a == 0 {
		return c
	}
	d := 255 * (int(c.a) + int(source.a)) - int(c.a) * int(source.a)
	return Color{
		r: u8((int(c.r) * int(c.a) * (255 - int(source.a)) + int(source.r) * 255 * int(source.a)) / d)
		g: u8((int(c.g) * int(c.a) * (255 - int(source.a)) + int(source.g) * 255 * int(source.a)) / d)
		b: u8((int(c.b) * int(c.a) * (255 - int(source.a)) + int(source.b) * 255 * int(source.a)) / d)
		a: u8(d / 255)
	}
}

pub fn (c Color) darkened(amount f64) Color {
	return Color.rgba(u8(int(f64(c.red()) * amount)), u8(int(f64(c.green()) * amount)), u8(int(f64(c.blue()) * amount)), c.alpha())
}

pub fn (c Color) inverted() Color {
	return Color.rgba(~c.red(), ~c.green(), ~c.blue(), c.alpha())
}

pub fn (c Color) serialize() string {
	if c.a == 255 {
		return 'rgb(${c.r} ${c.g} ${c.b})'
	}
	return 'rgb(${c.r} ${c.g} ${c.b} / ${serialize_a_number(f64(c.a) / 255.0)})'
}

pub struct ComputationContext {
pub mut:
	length_resolution_context            LengthResolutionContext = LengthResolutionContext.default()
	color_scheme                         ?PreferredColorScheme
	abstract_element                     ?dom.AbstractElement
	did_resolve_viewport_relative_length bool
}

pub fn (mut context ComputationContext) reset_viewport_metric_dependency_tracking() {
	context.did_resolve_viewport_relative_length = false
	context.length_resolution_context.set_did_resolve_viewport_relative_length(&context.did_resolve_viewport_relative_length)
}

pub fn (context ComputationContext) depends_on_viewport_metrics() bool {
	return context.did_resolve_viewport_relative_length
}

pub enum PerformTypeCheck {
	no
	yes
}

pub struct PropertyNameAndID {
pub mut:
	name_      string
	id_        ?PropertyID
	is_custom_ bool
}

// Legacy property-name aliases (Properties.json `legacy-alias-for`): these resolve to a
// canonical property so e.g. `-webkit-transform` is treated as `transform`.
pub fn PropertyNameAndID.from_name(name string) ?PropertyNameAndID {
	if is_a_custom_property_name_string(name) {
		return PropertyNameAndID{
			name_: name
			is_custom_: true
		}
	}
	canonical_name := canonical_property_name_from_metadata(to_ascii_lowercase(name))
	property_id := property_id_from_canonical_name(canonical_name) or { return none }
	return PropertyNameAndID{
		name_: canonical_name
		id_: property_id
	}
}

pub fn (p PropertyNameAndID) name() string {
	return p.name_
}

pub fn (p PropertyNameAndID) id() ?PropertyID {
	return p.id_
}

pub fn (p PropertyNameAndID) is_custom_property() bool {
	return p.is_custom_
}

pub fn property_id_from_string(name string) ?PropertyID {
	if property := PropertyNameAndID.from_name(name) {
		return property.id()
	}
	return none
}

fn property_accepts_custom_ident(property_id PropertyID, value string) bool {
	lowercase_value := to_ascii_lowercase(value)
	if lowercase_value.len == 0 || lowercase_value == 'default'
		|| is_css_wide_keyword_string(lowercase_value) {
		return false
	}
	if property_accepts_type(property_id, .custom_ident) {
		return lowercase_value !in property_custom_ident_blacklist(property_id)
	}
	// The compact StyleValue union does not yet have a separate
	// DashedIdentStyleValue. Preserve that representation boundary while using
	// the generated property type table to decide where it is legal.
	if property_accepts_type(property_id, .dashed_ident) {
		return value.starts_with('--')
	}
	return false
}

fn property_accepts_style_value(property_id PropertyID, value StyleValue) bool {
	if value.is_css_wide_keyword() {
		return true
	}
	return match value {
		KeywordStyleValue {
			property_accepts_keyword_string(property_id, value.to_string())
		}
		AnchorSizeStyleValue {
			property_accepts_type(property_id, .anchor_size)
		}
		AnchorStyleValue {
			property_accepts_type(property_id, .anchor)
		}
		CustomIdentStyleValue {
			property_accepts_custom_ident(property_id, value.custom_ident())
		}
		ColorStyleValue {
			property_accepts_type(property_id, .color)
		}
		EasingStyleValue {
			property_accepts_type(property_id, .easing_function)
		}
		FitContentStyleValue {
			property_accepts_type(property_id, .fit_content)
		}
		BackgroundSizeStyleValue {
			property_id in [.background_size, .mask_size]
		}
		BorderImageSliceStyleValue {
			property_id == .border_image_slice
		}
		BorderRadiusStyleValue {
			property_id in [.border_bottom_left_radius, .border_bottom_right_radius,
				.border_end_end_radius, .border_end_start_radius, .border_start_end_radius,
				.border_start_start_radius, .border_top_left_radius, .border_top_right_radius]
		}
		EdgeStyleValue {
			property_id in [.background_position_x, .background_position_y]
		}
		FontStyleStyleValue {
			property_accepts_type(property_id, .font_style)
		}
		ImageStyleValue {
			property_accepts_type(property_id, .image)
		}
		NumberStyleValue {
			property_accepts_type(property_id, .number) && property_accepts_number(property_id, value.number())
		}
		IntegerStyleValue {
			property_accepts_type(property_id, .integer) && property_accepts_integer(property_id, value.integer())
		}
		OpenTypeTaggedStyleValue {
			property_accepts_type(property_id, .opentype_tag)
		}
		PercentageStyleValue {
			property_accepts_type(property_id, .percentage) && property_accepts_percentage(property_id, value.percentage())
		}
		PositionStyleValue {
			property_accepts_type(property_id, .position)
		}
		RatioStyleValue {
			property_accepts_type(property_id, .ratio)
		}
		ScrollbarColorStyleValue {
			property_id == .scrollbar_color
		}
		ScrollbarGutterStyleValue {
			property_id == .scrollbar_gutter
		}
		StringStyleValue {
			property_accepts_type(property_id, .string)
		}
		SuperellipseStyleValue {
			property_accepts_type(property_id, .corner_shape)
		}
		TimeStyleValue {
			property_accepts_type(property_id, .time) && property_accepts_time(property_id, value.time())
		}
		TransformationStyleValue {
			property_accepts_type(property_id, .transform_function)
		}
		RepeatStyleStyleValue {
			property_id in [.background_repeat, .mask_repeat]
		}
		TextIndentStyleValue {
			property_id == .text_indent
		}
		TextUnderlinePositionStyleValue {
			property_id == .text_underline_position
		}
		URLStyleValue {
			property_accepts_type(property_id, .url)
		}
		StyleValueList {
			if property_is_list_valued(property_id) || property_id in [
				.border_image_outset,
				.border_image_repeat,
				.border_image_width,
				.border_spacing,
				.scrollbar_color,
				.scrollbar_gutter,
				.transform_origin,
			] {
				for item in value.values() {
					if !property_accepts_style_value(property_id, item) {
						return false
					}
				}
				true
			} else if property_accepts_type(property_id, .transform_list) {
				for item in value.values() {
					if !property_accepts_style_value(property_id, item) {
						return false
					}
				}
				true
			} else {
				false
			}
		}
		else {
			false
		}
	}
}

pub fn property_accepts_keyword(property_id PropertyID, keyword Keyword) bool {
	return property_accepts_keyword_string(property_id, string_from_keyword(keyword))
}

fn to_ascii_lowercase(value string) string {
	mut bytes := value.bytes()
	for i, byte in bytes {
		if byte >= `A` && byte <= `Z` {
			bytes[i] = byte + 0x20
		}
	}
	return bytes.bytestr()
}

fn component_value_from_text(text string) ComponentValue {
	return ComponentValue.from_token(Token.create_ident(text, text))
}

pub fn (value_type ValueType) to_string() string {
	return value_type_to_string(value_type)
}

// --- Units helpers used by CSSUnitValue and NumericType ---
pub enum DimensionType {
	angle
	flex
	frequency
	length
	resolution
	time
}

pub fn string_to_angle_unit(unit string) ?AngleUnit {
	return match to_ascii_lowercase(unit) {
		'deg' { AngleUnit.deg }
		'grad' { AngleUnit.grad }
		'rad' { AngleUnit.rad }
		'turn' { AngleUnit.turn }
		else { none }
	}
}

pub fn string_to_frequency_unit(unit string) ?FrequencyUnit {
	return match to_ascii_lowercase(unit) {
		'hz' { FrequencyUnit.hz }
		'khz' { FrequencyUnit.khz }
		else { none }
	}
}

pub fn string_to_flex_unit(unit string) ?FlexUnit {
	return match to_ascii_lowercase(unit) {
		'fr' { FlexUnit.fr }
		else { none }
	}
}

pub fn string_to_resolution_unit(unit string) ?ResolutionUnit {
	return match to_ascii_lowercase(unit) {
		'dpcm' { ResolutionUnit.dpcm }
		'dpi' { ResolutionUnit.dpi }
		'dppx' { ResolutionUnit.dppx }
		'x' { ResolutionUnit.x }
		else { none }
	}
}

pub fn string_to_time_unit(unit string) ?TimeUnit {
	return match to_ascii_lowercase(unit) {
		'ms' { TimeUnit.ms }
		's' { TimeUnit.s }
		else { none }
	}
}

pub fn string_to_length_unit(unit string) ?LengthUnit {
	return match to_ascii_lowercase(unit) {
		'cap' { LengthUnit.cap }
		'ch' { LengthUnit.ch }
		'cm' { LengthUnit.cm }
		'cqb' { LengthUnit.cqb }
		'cqh' { LengthUnit.cqh }
		'cqi' { LengthUnit.cqi }
		'cqmax' { LengthUnit.cqmax }
		'cqmin' { LengthUnit.cqmin }
		'cqw' { LengthUnit.cqw }
		'dvb' { LengthUnit.dvb }
		'dvh' { LengthUnit.dvh }
		'dvi' { LengthUnit.dvi }
		'dvmax' { LengthUnit.dvmax }
		'dvmin' { LengthUnit.dvmin }
		'dvw' { LengthUnit.dvw }
		'em' { LengthUnit.em }
		'ex' { LengthUnit.ex }
		'ic' { LengthUnit.ic }
		'in' { LengthUnit.in_ }
		'lh' { LengthUnit.lh }
		'lvb' { LengthUnit.lvb }
		'lvh' { LengthUnit.lvh }
		'lvi' { LengthUnit.lvi }
		'lvmax' { LengthUnit.lvmax }
		'lvmin' { LengthUnit.lvmin }
		'lvw' { LengthUnit.lvw }
		'mm' { LengthUnit.mm }
		'pc' { LengthUnit.pc }
		'pt' { LengthUnit.pt }
		'px' { LengthUnit.px }
		'q' { LengthUnit.q }
		'rcap' { LengthUnit.rcap }
		'rch' { LengthUnit.rch }
		'rem' { LengthUnit.rem }
		'rex' { LengthUnit.rex }
		'ric' { LengthUnit.ric }
		'rlh' { LengthUnit.rlh }
		'svb' { LengthUnit.svb }
		'svh' { LengthUnit.svh }
		'svi' { LengthUnit.svi }
		'svmax' { LengthUnit.svmax }
		'svmin' { LengthUnit.svmin }
		'svw' { LengthUnit.svw }
		'vb' { LengthUnit.vb }
		'vh' { LengthUnit.vh }
		'vi' { LengthUnit.vi }
		'vmax' { LengthUnit.vmax }
		'vmin' { LengthUnit.vmin }
		'vw' { LengthUnit.vw }
		else { none }
	}
}

pub fn canonical_angle_unit() AngleUnit {
	return .deg
}

pub fn canonical_frequency_unit() FrequencyUnit {
	return .hz
}

pub fn canonical_flex_unit() FlexUnit {
	return .fr
}

pub fn canonical_resolution_unit() ResolutionUnit {
	return .dppx
}

pub fn canonical_time_unit() TimeUnit {
	return .s
}

pub fn canonical_length_unit() LengthUnit {
	return .px
}

pub fn dimension_for_unit(unit string) ?DimensionType {
	if _ := string_to_angle_unit(unit) {
		return .angle
	}
	if _ := string_to_flex_unit(unit) {
		return .flex
	}
	if _ := string_to_frequency_unit(unit) {
		return .frequency
	}
	if _ := string_to_length_unit(unit) {
		return .length
	}
	if _ := string_to_resolution_unit(unit) {
		return .resolution
	}
	if _ := string_to_time_unit(unit) {
		return .time
	}
	return none
}

// --- NumericType ---
pub enum NumericBaseType {
	length
	angle
	time
	frequency
	resolution
	flex
	percent
}

pub struct NumericType {
pub mut:
	length_      ?int
	angle_       ?int
	time_        ?int
	frequency_   ?int
	resolution_  ?int
	flex_        ?int
	percent_     ?int
	percent_hint ?NumericBaseType
}

pub fn NumericType.new() NumericType {
	return NumericType{}
}

pub fn NumericType.with_type(type_ NumericBaseType, power int) NumericType {
	mut numeric_type := NumericType.new()
	numeric_type.set_exponent(type_, power)
	return numeric_type
}

pub fn NumericType.base_type_from_value_type(value_type ValueType) ?NumericBaseType {
	return match value_type {
		.angle { NumericBaseType.angle }
		.flex { NumericBaseType.flex }
		.frequency { NumericBaseType.frequency }
		.length { NumericBaseType.length }
		.percentage { NumericBaseType.percent }
		.resolution { NumericBaseType.resolution }
		.time { NumericBaseType.time }
		else { none }
	}
}

pub fn NumericType.base_type_name(base_type NumericBaseType) string {
	return match base_type {
		.length { 'length' }
		.angle { 'angle' }
		.time { 'time' }
		.frequency { 'frequency' }
		.resolution { 'resolution' }
		.flex { 'flex' }
		.percent { 'percent' }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-create-a-type
pub fn NumericType.create_from_unit(unit string) ?NumericType {
	// To create a type from a string unit, follow the appropriate branch of the following:

	// unit is "number"
	if to_ascii_lowercase(unit) == 'number' {
		// Return an empty map.
		return NumericType.new()
	}

	// unit is "percent"
	if to_ascii_lowercase(unit) == 'percent' {
		// Return [ "percent" -> 1 ].
		return NumericType.with_type(.percent, 1)
	}

	if dimension := dimension_for_unit(unit) {
		return match dimension {
			// unit is a <length> unit
			.length {
				NumericType.with_type(.length, 1)
			}

			// unit is an <angle> unit
			.angle {
				NumericType.with_type(.angle, 1)
			}

			// unit is a <time> unit
			.time {
				NumericType.with_type(.time, 1)
			}

			// unit is a <frequency> unit
			.frequency {
				NumericType.with_type(.frequency, 1)
			}

			// unit is a <resolution> unit
			.resolution {
				NumericType.with_type(.resolution, 1)
			}

			// unit is a <flex> unit
			.flex {
				NumericType.with_type(.flex, 1)
			}
		}
	}

	// anything else: return failure.
	return none
	// In all cases, the associated percent hint is null.
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-type-from-a-unit-map
pub fn NumericType.create_from_unit_map(unit_map map[string]int) ?NumericType {
	// To create a type from a unit map unit map:

	// 1. Let types be an initially empty list.
	mut types := []NumericType{}

	// 2. For each unit -> power in unit map:
	for unit, power in unit_map {
		// 1. Let type be the result of creating a type from unit.
		mut type_ := NumericType.create_from_unit(unit) or { return none }

		// 2. Set type's sole value to power.
		sole_type := type_.first_present_base_type() or { return none }
		type_.set_exponent(sole_type, power)

		// 3. Append type to types.
		types << type_
	}

	// 3. Return the result of multiplying all the items of types.
	if types.len == 0 {
		return none
	}
	mut result := types[0]
	for i := 1; i < types.len; i++ {
		if multiplied_type := result.multiplied_by(types[i]) {
			result = multiplied_type
		} else {
			return none
		}
	}
	return result
}

pub fn (t NumericType) exponent(type_ NumericBaseType) ?int {
	return match type_ {
		.length { t.length_ }
		.angle { t.angle_ }
		.time { t.time_ }
		.frequency { t.frequency_ }
		.resolution { t.resolution_ }
		.flex { t.flex_ }
		.percent { t.percent_ }
	}
}

pub fn (mut t NumericType) set_exponent(type_ NumericBaseType, exponent int) {
	match type_ {
		.length {
			t.length_ = exponent
		}
		.angle {
			t.angle_ = exponent
		}
		.time {
			t.time_ = exponent
		}
		.frequency {
			t.frequency_ = exponent
		}
		.resolution {
			t.resolution_ = exponent
		}
		.flex {
			t.flex_ = exponent
		}
		.percent {
			t.percent_ = exponent
		}
	}
}

fn numeric_base_types() []NumericBaseType {
	return [.length, .angle, .time, .frequency, .resolution, .flex, .percent]
}

fn (t NumericType) first_present_base_type() ?NumericBaseType {
	for base_type in numeric_base_types() {
		if _ := t.exponent(base_type) {
			return base_type
		}
	}
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-add-two-types
pub fn (t NumericType) added_to(other NumericType) ?NumericType {
	// To add two types type1 and type2, perform the following steps:

	// 1. Replace type1 with a fresh copy of type1, and type2 with a fresh copy of type2.
	//    Let finalType be a new type with an initially empty ordered map and an initially null percent hint.
	mut type1 := t
	mut type2 := other
	mut final_type := NumericType.new()

	// 2. If both type1 and type2 have non-null percent hints with different values
	if hint1 := type1.percent_hint {
		if hint2 := type2.percent_hint {
			if hint1 != hint2 {
				// The types cannot be added. Return failure.
				return none
			}
		}
	}
	//    If type1 has a non-null percent hint hint and type2 does not
	if hint1 := type1.percent_hint {
		if type2.percent_hint == none {
			// Apply the percent hint hint to type2.
			type2.apply_percent_hint(hint1)
		}
	} else {
		//    Vice versa if type2 has a non-null percent hint and type1 does not.
		if hint2 := type2.percent_hint {
			if type1.percent_hint == none {
				type1.apply_percent_hint(hint2)
			}
		}
	}

	// Otherwise, continue to the next step.

	// 3. If all the entries of type1 with non-zero values are contained in type2 with the same value, and vice-versa
	if type2.contains_all_the_non_zero_entries_of_other_with_the_same_value(type1) && type1.contains_all_the_non_zero_entries_of_other_with_the_same_value(type2) {
		// Copy all of type1's entries to finalType, and then copy all of type2's entries to finalType that
		// finalType does not already contain. Set finalType's percent hint to type1's percent hint. Return finalType.
		final_type.copy_all_entries_from(type1, false)
		final_type.copy_all_entries_from(type2, true)
		final_type.percent_hint = type1.percent_hint
		return final_type
	}
	//    If type1 and/or type2 contain "percent" with a non-zero value,
	//    and type1 and/or type2 contain a key other than "percent" with a non-zero value
	any_percent_is_non_zero := optional_non_zero(type1.exponent(.percent)) || optional_non_zero(type2.exponent(.percent))
	any_non_percent_is_non_zero := type1.contains_a_key_other_than_percent_with_a_non_zero_value() || type2.contains_a_key_other_than_percent_with_a_non_zero_value()
	if any_percent_is_non_zero && any_non_percent_is_non_zero {
		// For each base type other than "percent" hint:
		for hint in numeric_base_types() {
			if hint == .percent {
				continue
			}

			// 1. Provisionally apply the percent hint hint to both type1 and type2.
			mut provisional_type1 := type1
			provisional_type1.apply_percent_hint(hint)
			mut provisional_type2 := type2
			provisional_type2.apply_percent_hint(hint)

			// 2. If, afterwards, all the entries of type1 with non-zero values are contained in type2
			//    with the same value, and vice versa, then copy all of type1's entries to finalType,
			//    and then copy all of type2's entries to finalType that finalType does not already contain.
			//    Set finalType's percent hint to hint. Return finalType.
			if provisional_type2.contains_all_the_non_zero_entries_of_other_with_the_same_value(provisional_type1) && provisional_type1.contains_all_the_non_zero_entries_of_other_with_the_same_value(provisional_type2) {
				final_type.copy_all_entries_from(provisional_type1, false)
				final_type.copy_all_entries_from(provisional_type2, true)
				final_type.percent_hint = hint
				return final_type
			}

			// 3. Otherwise, revert type1 and type2 to their state at the start of this loop.
			// NOTE: We did the modifications to provisional_type1/2 so this is a no-op.
		}

		// If the loop finishes without returning finalType, then the types cannot be added. Return failure.
		return none
	}
	// Otherwise, the types cannot be added. Return failure.
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-multiply-two-types
pub fn (t NumericType) multiplied_by(other NumericType) ?NumericType {
	// To multiply two types type1 and type2, perform the following steps:

	// 1. Replace type1 with a fresh copy of type1, and type2 with a fresh copy of type2.
	//    Let finalType be a new type with an initially empty ordered map and an initially null percent hint.
	mut type1 := t
	mut type2 := other
	mut final_type := NumericType.new()

	// 2. If both type1 and type2 have non-null percent hints with different values,
	//    the types cannot be multiplied. Return failure.
	if hint1 := type1.percent_hint {
		if hint2 := type2.percent_hint {
			if hint1 != hint2 {
				return none
			}
		}
	}

	// 3. If type1 has a non-null percent hint hint and type2 does not, apply the percent hint hint to type2.
	if hint1 := type1.percent_hint {
		if type2.percent_hint == none {
			type2.apply_percent_hint(hint1)
		}
	} else {
		//    Vice versa if type2 has a non-null percent hint and type1 does not.
		if hint2 := type2.percent_hint {
			if type1.percent_hint == none {
				type1.apply_percent_hint(hint2)
			}
		}
	}

	// 4. Copy all of type1's entries to finalType, then for each baseType -> power of type2:
	final_type.copy_all_entries_from(type1, false)
	for base_type in numeric_base_types() {
		power := type2.exponent(base_type) or { continue }

		// 1. If finalType[baseType] exists, increment its value by power.
		if exponent := final_type.exponent(base_type) {
			final_type.set_exponent(base_type, exponent + power)
		} else {
			// 2. Otherwise, set finalType[baseType] to power.
			final_type.set_exponent(base_type, power)
		}
	}
	//    Set finalType's percent hint to type1's percent hint.
	final_type.percent_hint = type1.percent_hint

	// 5. Return finalType.
	return final_type
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-invert-a-type
pub fn (t NumericType) inverted() NumericType {
	// To invert a type type, perform the following steps:

	// 1. Let result be a new type with an initially empty ordered map and a percent hint matching that of type.
	mut result := NumericType.new()
	result.percent_hint = t.percent_hint

	// 2. For each unit -> exponent of type, set result[unit] to (-1 * exponent).
	for base_type in numeric_base_types() {
		power := t.exponent(base_type) or { continue }
		result.set_exponent(base_type, -1 * power)
	}

	// 3. Return result.
	return result
}

// https://drafts.csswg.org/css-values-4/#css-consistent-typec
pub fn (t NumericType) has_consistent_type_with(other NumericType) bool {
	// Two or more calculations have a consistent type if adding the types does not result in failure.
	return t.added_to(other) != none
}

// https://drafts.csswg.org/css-values-4/#css-consistent-typec
pub fn (t NumericType) consistent_type(other NumericType) ?NumericType {
	// The consistent type is the result of the type addition.
	return t.added_to(other)
}

// https://drafts.csswg.org/css-values-4/#css-make-a-type-consistent
pub fn (t NumericType) made_consistent_with(input NumericType) ?NumericType {
	mut base := t

	// 1. If both base and input have different non-null percent hints, they cannot be made consistent. Return failure.
	if base_hint := base.percent_hint {
		if input_hint := input.percent_hint {
			if base_hint != input_hint {
				return none
			}
		}
	}

	// 2. If base has a null percent hint set base's percent hint to input's percent hint.
	if base.percent_hint == none {
		base.percent_hint = input.percent_hint
	}

	// 3. Return base.
	return base
}

// https://drafts.css-houdini.org/css-typed-om-1/#apply-the-percent-hint
pub fn (mut t NumericType) apply_percent_hint(hint NumericBaseType) {
	// To apply the percent hint hint to a type without a percent hint, perform the following steps:
	if t.percent_hint != none {
		return
	}

	// 1. Set type's percent hint to hint.
	t.percent_hint = hint

	// 2. If type does not contain hint, set type[hint] to 0.
	if t.exponent(hint) == none {
		t.set_exponent(hint, 0)
	}

	// 3. If hint is anything other than "percent", and type contains "percent",
	//    add type["percent"] to type[hint], then set type["percent"] to 0.
	if hint != .percent {
		if percent := t.exponent(.percent) {
			hint_exponent := t.exponent(hint) or { 0 }
			t.set_exponent(hint, percent + hint_exponent)
			t.set_exponent(.percent, 0)
		}
	}

	// 4. Return type.
}

fn (t NumericType) contains_all_the_non_zero_entries_of_other_with_the_same_value(other NumericType) bool {
	for base_type in numeric_base_types() {
		other_exponent := other.exponent(base_type) or { continue }
		this_exponent := t.exponent(base_type) or { 0 }
		if other_exponent != 0 && this_exponent != other_exponent {
			return false
		}
	}
	return true
}

fn (t NumericType) contains_a_key_other_than_percent_with_a_non_zero_value() bool {
	for base_type in numeric_base_types() {
		if base_type == .percent {
			continue
		}
		if exponent := t.exponent(base_type) {
			if exponent != 0 {
				return true
			}
		}
	}
	return false
}

fn (mut t NumericType) copy_all_entries_from(other NumericType, skip_if_already_present bool) {
	for base_type in numeric_base_types() {
		exponent := other.exponent(base_type) or { continue }
		if skip_if_already_present && t.exponent(base_type) != none {
			continue
		}
		t.set_exponent(base_type, exponent)
	}
}

pub fn (t NumericType) entry_with_value_1_while_all_others_are_0() ?NumericBaseType {
	mut result := ?NumericBaseType(none)
	for base_type in numeric_base_types() {
		type_exponent := t.exponent(base_type)
		if optional_equals(type_exponent, 1) {
			if result != none {
				return none
			}
			result = base_type
		} else if exponent := type_exponent {
			if exponent != 0 {
				return none
			}
		}
	}
	return result
}

fn numeric_base_type_matches_value_type(base_type NumericBaseType, value_type ValueType) bool {
	return match base_type {
		.length { value_type == .length }
		.angle { value_type == .angle }
		.time { value_type == .time }
		.frequency { value_type == .frequency }
		.resolution { value_type == .resolution }
		.flex { value_type == .flex }
		.percent { value_type == .percentage }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
fn (t NumericType) matches_dimension_base(type_ NumericBaseType, percentages_resolve_as ?ValueType) bool {
	// A type matches <length> if its only non-zero entry is [ "length" -> 1 ].
	// Similarly for <angle>, <time>, <frequency>, <resolution>, and <flex>.
	entry := t.entry_with_value_1_while_all_others_are_0() or { return false }
	if entry != type_ {
		return false
	}

	// If the context in which the value is used allows <percentage> values, and those percentages are resolved
	// against another type, then for the type to be considered matching it must either have a null percent hint,
	// or the percent hint must match the other type.
	if resolves_as := percentages_resolve_as {
		if hint := t.percent_hint {
			return numeric_base_type_matches_value_type(hint, resolves_as)
		}
		return true
	}

	// If the context does not allow <percentage> values to be mixed with <length>/etc values (or does not allow
	// <percentage> values at all, such as border-width), then for the type to be considered matching the percent
	// hint must be null.
	return t.percent_hint == none
}

pub fn (t NumericType) matches_angle(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.angle, percentages_resolve_as)
}

pub fn (t NumericType) matches_angle_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.angle, percentages_resolve_as)
}

pub fn (t NumericType) matches_flex(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.flex, percentages_resolve_as)
}

pub fn (t NumericType) matches_frequency(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.frequency, percentages_resolve_as)
}

pub fn (t NumericType) matches_frequency_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.frequency, percentages_resolve_as)
}

pub fn (t NumericType) matches_length(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.length, percentages_resolve_as)
}

pub fn (t NumericType) matches_length_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.length, percentages_resolve_as)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
pub fn (t NumericType) matches_percentage() bool {
	// A type matches <percentage> if its only non-zero entry is [ "percent" -> 1 ], and its percent hint is either
	// null or "percent".
	if hint := t.percent_hint {
		if hint != .percent {
			return false
		}
	}

	entry := t.entry_with_value_1_while_all_others_are_0() or { return false }
	return entry == NumericBaseType.percent
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
fn (t NumericType) matches_dimension_percentage(type_ NumericBaseType, percentages_resolve_as ?ValueType) bool {
	// A type matches <length-percentage> if it matches <length> or matches <percentage>.
	// Same for <angle-percentage>, <time-percentage>, etc.
	return t.matches_percentage() || t.matches_dimension_base(type_, percentages_resolve_as)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
pub fn (t NumericType) matches_number(percentages_resolve_as ?ValueType) bool {
	// A type matches <number> if it has no non-zero entries.
	for base_type in numeric_base_types() {
		if exponent := t.exponent(base_type) {
			if exponent != 0 {
				return false
			}
		}
	}

	// If the context in which the value is used allows <percentage> values, and those percentages are resolved
	// against a type other than <number>, then for the type to be considered matching the percent hint must
	// either be null or match the other type.
	if resolves_as := percentages_resolve_as {
		if resolves_as != .number {
			if hint := t.percent_hint {
				return numeric_base_type_matches_value_type(hint, resolves_as)
			}
			return true
		}
	}

	// If the context allows <percentage> values, but either does not resolve them against another type or resolves
	// them against a <number>, then for the type to be considered matching the percent hint must either be null
	// or "percent".
	if resolves_as := percentages_resolve_as {
		if resolves_as != .number {
			return true
		}
		if hint := t.percent_hint {
			return hint == .percent
		}
		return true
	}

	// If the context does not allow <percentage> values, then for the type to be considered matching the percent
	// hint must be null.
	return t.percent_hint == none
}

pub fn (t NumericType) matches_resolution(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.resolution, percentages_resolve_as)
}

pub fn (t NumericType) matches_time(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.time, percentages_resolve_as)
}

pub fn (t NumericType) matches_time_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.time, percentages_resolve_as)
}

pub fn (t NumericType) matches_dimension() bool {
	// This is not a spec algorithm.
	// A type should match `<dimension>` if there are no non-zero entries,
	// or it has a single non-zero entry (other than percent) which is equal to 1.
	mut number_of_one_exponents := 0
	for base_type in numeric_base_types() {
		type_exponent := t.exponent(base_type) or { continue }

		if type_exponent == 1 {
			if base_type == .percent {
				return false
			}
			number_of_one_exponents++
		} else if type_exponent != 0 {
			return false
		}
	}

	return number_of_one_exponents == 0 || number_of_one_exponents == 1
}

pub fn (t NumericType) dump() string {
	mut result := '{ hint: '
	if hint := t.percent_hint {
		result += NumericType.base_type_name(hint)
	} else {
		result += 'none'
	}

	for base_type in numeric_base_types() {
		if type_exponent := t.exponent(base_type) {
			result += ', "${NumericType.base_type_name(base_type)}" -> ${type_exponent}'
		}
	}

	result += ' }'
	return result
}

pub fn (t NumericType) to_string() string {
	return t.dump()
}

fn optional_non_zero(value ?int) bool {
	if actual := value {
		return actual != 0
	}
	return false
}

fn optional_equals(value ?int, expected int) bool {
	if actual := value {
		return actual == expected
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#product-of-two-unit-maps
pub fn product_of_two_unit_maps(units1 map[string]int, units2 map[string]int) map[string]int {
	// 1. Let result be a copy of units1.
	mut result := units1.clone()

	// 2. For each unit -> power in units2:
	for unit, power in units2 {
		// 1. If result[unit] exists, increment result[unit] by power.
		// 2. Otherwise, set result[unit] to power.
		result[unit] = result[unit] + power
	}

	// 3. Return result.
	return result
}

// --- Keywords ---
pub enum Keyword {
	invalid
	negative_infinity
	libweb_buttonfacedisabled
	libweb_buttonfacehover
	libweb_center
	libweb_inherit_or_center
	libweb_left
	libweb_link
	libweb_palette_active_link
	libweb_palette_active_window_border1
	libweb_palette_active_window_border2
	libweb_palette_active_window_title
	libweb_palette_base
	libweb_palette_base_text
	libweb_palette_button
	libweb_palette_button_text
	libweb_palette_desktop_background
	libweb_palette_focus_outline
	libweb_palette_highlight_window_border1
	libweb_palette_highlight_window_border2
	libweb_palette_highlight_window_title
	libweb_palette_hover_highlight
	libweb_palette_inactive_selection
	libweb_palette_inactive_selection_text
	libweb_palette_inactive_window_border1
	libweb_palette_inactive_window_border2
	libweb_palette_inactive_window_title
	libweb_palette_link
	libweb_palette_menu_base
	libweb_palette_menu_base_text
	libweb_palette_menu_selection
	libweb_palette_menu_selection_text
	libweb_palette_menu_stripe
	libweb_palette_moving_window_border1
	libweb_palette_moving_window_border2
	libweb_palette_moving_window_title
	libweb_palette_rubber_band_border
	libweb_palette_rubber_band_fill
	libweb_palette_ruler
	libweb_palette_ruler_active_text
	libweb_palette_ruler_border
	libweb_palette_ruler_inactive_text
	libweb_palette_selection
	libweb_palette_selection_text
	libweb_palette_syntax_comment
	libweb_palette_syntax_control_keyword
	libweb_palette_syntax_identifier
	libweb_palette_syntax_keyword
	libweb_palette_syntax_number
	libweb_palette_syntax_operator
	libweb_palette_syntax_preprocessor_statement
	libweb_palette_syntax_preprocessor_value
	libweb_palette_syntax_punctuation
	libweb_palette_syntax_string
	libweb_palette_syntax_type
	libweb_palette_text_cursor
	libweb_palette_threed_highlight
	libweb_palette_threed_shadow1
	libweb_palette_threed_shadow2
	libweb_palette_visited_link
	libweb_palette_window
	libweb_palette_window_text
	libweb_right
	a3
	a4
	a5
	a98_rgb
	absolute
	accentcolor
	accentcolortext
	accumulate
	active
	activeborder
	activecaption
	activetext
	add
	additive
	adlam
	afar
	agaw
	alias
	all
	all_petite_caps
	all_scroll
	all_small_caps
	allow_discrete
	alpha
	alphabetic
	alternate
	alternate_reverse
	always
	anchors_valid
	anchors_visible
	ancient_tamil
	anonymous
	anywhere
	appworkspace
	arabic_abjad
	arabic_indic
	ari
	armenian
	auto
	auto_add
	avar2
	b4
	b5
	back
	background
	backwards
	balance
	balinese
	bamum
	bangla
	baseline
	bengali
	bevel
	bidi_override
	binary
	blin
	blink
	block
	block_end
	block_start
	bodo
	bold
	bolder
	border_box
	both
	both_edges
	bottom
	break_all
	break_spaces
	break_word
	browser
	bullets
	butt
	button
	buttonborder
	buttonface
	buttonhighlight
	buttonshadow
	buttontext
	cambodian
	canvas
	canvastext
	capitalize
	captiontext
	cell
	center
	central
	checkbox
	circle
	circled_decimal
	circled_ideograph
	circled_katakana
	circled_korean_consonant
	circled_korean_syllable
	circled_lower_latin
	circled_upper_latin
	cjk_decimal
	cjk_earthly_branch
	cjk_heavenly_stem
	cjk_ideographic
	cjk_stem_branch
	cjk_tally_mark
	clip
	close_quote
	closest_corner
	closest_side
	coarse
	col_resize
	collapse
	color
	color_burn
	color_cbdt
	color_colrv0
	color_colrv1
	color_dodge
	color_sbix
	color_svg
	column
	column_reverse
	common_ligatures
	compact
	condensed
	contain
	content
	content_box
	contents
	context_menu
	contextual
	copy
	cover
	crisp_edges
	crispedges
	crop
	cross
	crosshair
	currentcolor
	cursive
	custom
	cyclic
	dark
	darken
	dashed
	decimal
	decimal_leading_zero
	decreasing
	default
	devanagari
	diagonal_fractions
	difference
	disc
	discard
	discard_before
	discard_after
	discard_inner
	disclosure_closed
	disclosure_open
	discretionary_ligatures
	distribute
	display_p3
	display_p3_linear
	dizi
	dogri
	dotted_decimal
	dotted
	double_circled_decimal
	double_
	down
	e
	e_resize
	each_line
	ease
	ease_in
	ease_in_out
	ease_out
	element_shared
	ellipsis
	else_
	embed
	emoji
	enabled
	end_
	ethiopic_halehame_am
	ethiopic_halehame_ti_er
	ethiopic_halehame_ti_et
	ethiopic_halehame
	ethiopic_numeric
	evenodd
	ew_resize
	exclude
	exclusion
	expanded
	extends
	extra_condensed
	extra_expanded
	fallback
	false_
	fantasy
	farthest_corner
	farthest_side
	fast
	features_aat
	features_graphite
	features_opentype
	field
	fieldtext
	fill
	fill_box
	filled_circled_decimal
	fine
	fixed
	flat
	flex
	flex_end
	flex_start
	flip_block
	flip_inline
	flip_start
	flow
	flow_root
	forwards
	from_font
	full_size_kana
	full_width
	fullwidth_decimal
	fullwidth_lower_alpha
	fullwidth_upper_alpha
	fullwidth_upper_roman
	fullscreen
	gedeo
	geometricprecision
	georgian
	grab
	grabbing
	grammar_error
	graytext
	greek_lower_ancient
	greek_lower_modern
	greek_upper_ancient
	greek_upper_modern
	grid
	groove
	gujarati_alpha
	gujarati
	gumuz
	gurmukhi
	hadiyaa
	hanging
	hangul_consonant
	hangul
	hanifi_rohingya
	harari
	hard_light
	hebrew
	height
	help
	hide
	hidden
	high
	high_quality
	highlight
	highlighttext
	hindi
	hiragana_iroha
	hiragana
	historical_forms
	historical_ligatures
	horizontal
	horizontal_tb
	hover
	hsl
	hue
	hwb
	inactiveborder
	inactivecaption
	inactivecaptiontext
	increasing
	ideographic
	incremental
	infinite
	infinity
	infobackground
	infotext
	inherit
	initial
	initial_only
	inline_
	inline_block
	inline_end
	inline_flex
	inline_grid
	inline_size
	inline_start
	inline_table
	inset
	inside
	inter_character
	inter_word
	interlace
	intersect
	invert
	inverted
	isolate
	isolate_override
	italic
	japanese_formal
	japanese_informal
	javanese
	jis_b4
	jis_b5
	jis04
	jis78
	jis83
	jis90
	jump_both
	jump_end
	jump_none
	jump_start
	justify
	kaffa
	kannada_alpha
	kannada
	kashmiri
	katakana_iroha
	katakana
	kayah_li
	kebena
	keep_all
	kembata
	khmer_consonant
	khmer
	konkani
	konso
	korean_consonant
	korean_hangul_formal
	korean_hanja_formal
	korean_hanja_informal
	korean_syllable
	kunama
	landscape
	lanna_hora
	lanna_tham
	lao
	lab
	large
	larger
	layout
	lch
	ledger
	left
	legacy
	legal
	lepcha
	less
	letter
	light
	lighten
	lighter
	limbu
	line_through
	linear
	linearrgb
	lining_nums
	linktext
	list_item
	listbox
	local
	longer
	lower_alpha_symbolic
	lower_alpha
	lower_armenian
	lower_belorussian
	lower_bulgarian
	lower_greek
	lower_hexadecimal
	lower_latin
	lower_macedonian
	lower_oromo_qubee
	lower_roman
	lower_russian_full
	lower_russian
	lower_serbian
	lower_ukrainian_full
	lower_ukrainian
	lowercase
	ltr
	luminance
	luminosity
	maghrebi_abjad
	maithili
	malayalam_alpha
	malayalam
	manipulation
	manipuri
	marathi
	margin_box
	mark
	markers
	marktext
	match_parent
	match_source
	math
	math_auto
	mathematical
	max_content
	medium
	meen
	meetei
	menu
	menulist
	menulist_button
	menutext
	meter
	middle
	min_content
	minimal_ui
	miter
	mongolian
	monospace
	more
	most_block_size
	most_height
	most_inline_size
	most_width
	move
	mro
	multiply
	myanmar
	n_resize
	nag_mundari
	nan
	ne_resize
	nearest
	nesw_resize
	new_base_60
	newa
	nko_cardinal
	no_clip
	no_close_quote
	no_common_ligatures
	no_contextual
	no_discretionary_ligatures
	no_drop
	no_historical_ligatures
	no_open_quote
	no_overflow
	no_preference
	no_referrer
	no_referrer_when_downgrade
	no_repeat
	none_
	nonzero
	normal
	not_allowed
	notch
	nowrap
	ns_resize
	numbers
	numeric
	nw_resize
	nwse_resize
	oblique
	octal
	odia
	off
	oklab
	oklch
	ol_chiki
	oldstyle_nums
	on
	opaque
	open_quote
	optimizelegibility
	optimizequality
	optimizespeed
	optional
	ordinal
	origin
	origin_when_cross_origin
	oriya
	oromo
	outset
	outside
	overlay
	overline
	p3
	padding_box
	paged
	paint
	palettes
	pan_down
	pan_left
	pan_right
	pan_up
	pan_x
	pan_y
	parenthesized_decimal
	parenthesized_hangul_consonant
	parenthesized_hangul_syllable
	parenthesized_ideograph
	parenthesized_lower_latin
	paused
	persian_abjad
	persian_alphabetic
	persian
	petite_caps
	pi
	picture_in_picture
	pixelated
	plaintext
	plus_darker
	plus_lighter
	pointer
	portrait
	pre
	pre_line
	pre_wrap
	preserve
	preserve_3d
	preserve_breaks
	preserve_spaces
	pretty
	progress
	progress_bar
	progressive
	prophoto_rgb
	proportional_nums
	proportional_width
	punjabi
	push_button
	radio
	rec2020
	reduce
	relative
	repeat
	repeat_x
	repeat_y
	replace
	reverse
	revert
	revert_layer
	ridge
	right
	root
	rotate_left
	rotate_right
	round
	row
	row_resize
	row_reverse
	rtl
	ruby
	ruby_base
	ruby_base_container
	ruby_text
	ruby_text_container
	run_in
	running
	s_resize
	safe
	saho
	same_origin
	sans_serif
	sanskrit
	santali
	saturation
	scale_down
	scoop
	screen
	scroll
	scroll_position
	scroll_state
	scrollbar
	se_resize
	searchfield
	selecteditem
	selecteditemtext
	self
	self_block
	self_block_end
	self_block_start
	self_end
	self_inline
	self_inline_end
	self_inline_start
	self_x_end
	self_x_start
	self_y_end
	self_y_start
	self_start
	semi_condensed
	semi_expanded
	separate
	serif
	shan
	shorter
	show
	sidama
	sideways_lr
	sideways_rl
	silti
	simp_chinese_formal
	simp_chinese_informal
	simple_lower_roman
	simple_upper_roman
	simplified
	sindhi
	size
	slashed_zero
	slider_horizontal
	slow
	small
	small_caps
	smaller
	smooth
	soft_light
	solid
	space
	space_around
	space_between
	space_evenly
	span_all
	span_block_end
	span_block_start
	span_bottom
	span_end
	span_inline_end
	span_inline_start
	span_left
	span_right
	span_self_block_end
	span_self_block_start
	span_self_end
	span_self_inline_end
	span_self_inline_start
	span_self_start
	span_self_x_end
	span_self_x_start
	span_self_y_end
	span_self_y_start
	span_start
	span_top
	span_x_end
	span_x_start
	span_y_end
	span_y_start
	spelling_error
	spell_out
	square
	square_button
	squircle
	srgb
	srgb_linear
	stable
	stacked_fractions
	standalone
	standard
	start
	static_
	sticky
	stretch
	strict
	strict_origin
	strict_origin_when_cross_origin
	stroke
	stroke_box
	style
	sub
	subtract
	subtractive
	sundanese
	super_decimal
	super
	sw_resize
	swap
	symbolic
	table
	table_caption
	table_cell
	table_column
	table_column_group
	table_footer_group
	table_header_group
	table_row
	table_row_group
	tabular_nums
	tai_lue
	tally_mark
	tamil
	telugu_alpha
	telugu
	text
	text_bottom
	text_top
	textarea
	textfield
	thai_alpha
	thai
	thick
	thin
	threeddarkshadow
	threedface
	threedhighlight
	threedlightshadow
	threedshadow
	tibetan
	tigre
	titling_caps
	to_zero
	top
	trad_chinese_formal
	trad_chinese_informal
	traditional
	true_
	ui_monospace
	ui_rounded
	ui_sans_serif
	ui_serif
	ultra_condensed
	ultra_expanded
	under
	underline
	unicase
	unicode
	unsafe_
	unsafe_url
	unset
	up
	upper_alpha_symbolic
	upper_alpha
	upper_armenian
	upper_belorussian
	upper_bulgarian
	upper_hexadecimal
	upper_latin
	upper_macedonian
	upper_oromo_qubee
	upper_roman
	upper_russian_full
	upper_russian
	upper_serbian
	upper_ukrainian_full
	upper_ukrainian
	uppercase
	upright
	urdu_abjad
	urdu_alphabetic
	urdu
	use_credentials
	variations
	vertical
	vertical_lr
	vertical_rl
	vertical_text
	view_box
	visible
	visitedtext
	w_resize
	wait
	warang_citi
	wavy
	width
	window
	windowframe
	windowtext
	wolaita
	words
	wrap
	wrap_reverse
	x
	x_end
	x_large
	x_start
	x_small
	xx_large
	xx_small
	xxx_large
	xyz
	xyz_d50
	xyz_d65
	y
	y_end
	y_start
	yemsa
	zhuyin
	zoom_in
	zoom_out
}

pub fn (keyword Keyword) is_css_wide_keyword() bool {
	return keyword in [.inherit, .initial, .revert, .unset, .revert_layer]
}

pub fn is_css_wide_keyword_string(value string) bool {
	return match to_ascii_lowercase(value) {
		'inherit', 'initial', 'revert', 'revert-layer', 'unset' { true }
		else { false }
	}
}

pub fn string_from_keyword(keyword Keyword) string {
	return match keyword {
		.invalid { '' }
		.negative_infinity { '-infinity' }
		.libweb_buttonfacedisabled { '-libweb-buttonfacedisabled' }
		.libweb_buttonfacehover { '-libweb-buttonfacehover' }
		.libweb_center { '-libweb-center' }
		.libweb_inherit_or_center { '-libweb-inherit-or-center' }
		.libweb_left { '-libweb-left' }
		.libweb_link { '-libweb-link' }
		.libweb_palette_active_link { '-libweb-palette-active-link' }
		.libweb_palette_active_window_border1 { '-libweb-palette-active-window-border1' }
		.libweb_palette_active_window_border2 { '-libweb-palette-active-window-border2' }
		.libweb_palette_active_window_title { '-libweb-palette-active-window-title' }
		.libweb_palette_base { '-libweb-palette-base' }
		.libweb_palette_base_text { '-libweb-palette-base-text' }
		.libweb_palette_button { '-libweb-palette-button' }
		.libweb_palette_button_text { '-libweb-palette-button-text' }
		.libweb_palette_desktop_background { '-libweb-palette-desktop-background' }
		.libweb_palette_focus_outline { '-libweb-palette-focus-outline' }
		.libweb_palette_highlight_window_border1 { '-libweb-palette-highlight-window-border1' }
		.libweb_palette_highlight_window_border2 { '-libweb-palette-highlight-window-border2' }
		.libweb_palette_highlight_window_title { '-libweb-palette-highlight-window-title' }
		.libweb_palette_hover_highlight { '-libweb-palette-hover-highlight' }
		.libweb_palette_inactive_selection { '-libweb-palette-inactive-selection' }
		.libweb_palette_inactive_selection_text { '-libweb-palette-inactive-selection-text' }
		.libweb_palette_inactive_window_border1 { '-libweb-palette-inactive-window-border1' }
		.libweb_palette_inactive_window_border2 { '-libweb-palette-inactive-window-border2' }
		.libweb_palette_inactive_window_title { '-libweb-palette-inactive-window-title' }
		.libweb_palette_link { '-libweb-palette-link' }
		.libweb_palette_menu_base { '-libweb-palette-menu-base' }
		.libweb_palette_menu_base_text { '-libweb-palette-menu-base-text' }
		.libweb_palette_menu_selection { '-libweb-palette-menu-selection' }
		.libweb_palette_menu_selection_text { '-libweb-palette-menu-selection-text' }
		.libweb_palette_menu_stripe { '-libweb-palette-menu-stripe' }
		.libweb_palette_moving_window_border1 { '-libweb-palette-moving-window-border1' }
		.libweb_palette_moving_window_border2 { '-libweb-palette-moving-window-border2' }
		.libweb_palette_moving_window_title { '-libweb-palette-moving-window-title' }
		.libweb_palette_rubber_band_border { '-libweb-palette-rubber-band-border' }
		.libweb_palette_rubber_band_fill { '-libweb-palette-rubber-band-fill' }
		.libweb_palette_ruler { '-libweb-palette-ruler' }
		.libweb_palette_ruler_active_text { '-libweb-palette-ruler-active-text' }
		.libweb_palette_ruler_border { '-libweb-palette-ruler-border' }
		.libweb_palette_ruler_inactive_text { '-libweb-palette-ruler-inactive-text' }
		.libweb_palette_selection { '-libweb-palette-selection' }
		.libweb_palette_selection_text { '-libweb-palette-selection-text' }
		.libweb_palette_syntax_comment { '-libweb-palette-syntax-comment' }
		.libweb_palette_syntax_control_keyword { '-libweb-palette-syntax-control-keyword' }
		.libweb_palette_syntax_identifier { '-libweb-palette-syntax-identifier' }
		.libweb_palette_syntax_keyword { '-libweb-palette-syntax-keyword' }
		.libweb_palette_syntax_number { '-libweb-palette-syntax-number' }
		.libweb_palette_syntax_operator { '-libweb-palette-syntax-operator' }
		.libweb_palette_syntax_preprocessor_statement {
			'-libweb-palette-syntax-preprocessor-statement'
		}
		.libweb_palette_syntax_preprocessor_value { '-libweb-palette-syntax-preprocessor-value' }
		.libweb_palette_syntax_punctuation { '-libweb-palette-syntax-punctuation' }
		.libweb_palette_syntax_string { '-libweb-palette-syntax-string' }
		.libweb_palette_syntax_type { '-libweb-palette-syntax-type' }
		.libweb_palette_text_cursor { '-libweb-palette-text-cursor' }
		.libweb_palette_threed_highlight { '-libweb-palette-threed-highlight' }
		.libweb_palette_threed_shadow1 { '-libweb-palette-threed-shadow1' }
		.libweb_palette_threed_shadow2 { '-libweb-palette-threed-shadow2' }
		.libweb_palette_visited_link { '-libweb-palette-visited-link' }
		.libweb_palette_window { '-libweb-palette-window' }
		.libweb_palette_window_text { '-libweb-palette-window-text' }
		.libweb_right { '-libweb-right' }
		.a3 { 'a3' }
		.a4 { 'a4' }
		.a5 { 'a5' }
		.a98_rgb { 'a98-rgb' }
		.absolute { 'absolute' }
		.accentcolor { 'accentcolor' }
		.accentcolortext { 'accentcolortext' }
		.accumulate { 'accumulate' }
		.active { 'active' }
		.activeborder { 'activeborder' }
		.activecaption { 'activecaption' }
		.activetext { 'activetext' }
		.add { 'add' }
		.additive { 'additive' }
		.adlam { 'adlam' }
		.afar { 'afar' }
		.agaw { 'agaw' }
		.alias { 'alias' }
		.all { 'all' }
		.all_petite_caps { 'all-petite-caps' }
		.all_scroll { 'all-scroll' }
		.all_small_caps { 'all-small-caps' }
		.allow_discrete { 'allow-discrete' }
		.alpha { 'alpha' }
		.alphabetic { 'alphabetic' }
		.alternate { 'alternate' }
		.alternate_reverse { 'alternate-reverse' }
		.always { 'always' }
		.anchors_valid { 'anchors-valid' }
		.anchors_visible { 'anchors-visible' }
		.ancient_tamil { 'ancient-tamil' }
		.anonymous { 'anonymous' }
		.anywhere { 'anywhere' }
		.appworkspace { 'appworkspace' }
		.arabic_abjad { 'arabic-abjad' }
		.arabic_indic { 'arabic-indic' }
		.ari { 'ari' }
		.armenian { 'armenian' }
		.auto { 'auto' }
		.auto_add { 'auto-add' }
		.avar2 { 'avar2' }
		.b4 { 'b4' }
		.b5 { 'b5' }
		.back { 'back' }
		.background { 'background' }
		.backwards { 'backwards' }
		.balance { 'balance' }
		.balinese { 'balinese' }
		.bamum { 'bamum' }
		.bangla { 'bangla' }
		.baseline { 'baseline' }
		.bengali { 'bengali' }
		.bevel { 'bevel' }
		.bidi_override { 'bidi-override' }
		.binary { 'binary' }
		.blin { 'blin' }
		.blink { 'blink' }
		.block { 'block' }
		.block_end { 'block-end' }
		.block_start { 'block-start' }
		.bodo { 'bodo' }
		.bold { 'bold' }
		.bolder { 'bolder' }
		.border_box { 'border-box' }
		.both { 'both' }
		.both_edges { 'both-edges' }
		.bottom { 'bottom' }
		.break_all { 'break-all' }
		.break_spaces { 'break-spaces' }
		.break_word { 'break-word' }
		.browser { 'browser' }
		.bullets { 'bullets' }
		.butt { 'butt' }
		.button { 'button' }
		.buttonborder { 'buttonborder' }
		.buttonface { 'buttonface' }
		.buttonhighlight { 'buttonhighlight' }
		.buttonshadow { 'buttonshadow' }
		.buttontext { 'buttontext' }
		.cambodian { 'cambodian' }
		.canvas { 'canvas' }
		.canvastext { 'canvastext' }
		.capitalize { 'capitalize' }
		.captiontext { 'captiontext' }
		.cell { 'cell' }
		.center { 'center' }
		.central { 'central' }
		.checkbox { 'checkbox' }
		.circle { 'circle' }
		.circled_decimal { 'circled-decimal' }
		.circled_ideograph { 'circled-ideograph' }
		.circled_katakana { 'circled-katakana' }
		.circled_korean_consonant { 'circled-korean-consonant' }
		.circled_korean_syllable { 'circled-korean-syllable' }
		.circled_lower_latin { 'circled-lower-latin' }
		.circled_upper_latin { 'circled-upper-latin' }
		.cjk_decimal { 'cjk-decimal' }
		.cjk_earthly_branch { 'cjk-earthly-branch' }
		.cjk_heavenly_stem { 'cjk-heavenly-stem' }
		.cjk_ideographic { 'cjk-ideographic' }
		.cjk_stem_branch { 'cjk-stem-branch' }
		.cjk_tally_mark { 'cjk-tally-mark' }
		.clip { 'clip' }
		.close_quote { 'close-quote' }
		.closest_corner { 'closest-corner' }
		.closest_side { 'closest-side' }
		.coarse { 'coarse' }
		.col_resize { 'col-resize' }
		.collapse { 'collapse' }
		.color { 'color' }
		.color_burn { 'color-burn' }
		.color_cbdt { 'color-cbdt' }
		.color_colrv0 { 'color-colrv0' }
		.color_colrv1 { 'color-colrv1' }
		.color_dodge { 'color-dodge' }
		.color_sbix { 'color-sbix' }
		.color_svg { 'color-svg' }
		.column { 'column' }
		.column_reverse { 'column-reverse' }
		.common_ligatures { 'common-ligatures' }
		.compact { 'compact' }
		.condensed { 'condensed' }
		.contain { 'contain' }
		.content { 'content' }
		.content_box { 'content-box' }
		.contents { 'contents' }
		.context_menu { 'context-menu' }
		.contextual { 'contextual' }
		.copy { 'copy' }
		.cover { 'cover' }
		.crisp_edges { 'crisp-edges' }
		.crispedges { 'crispedges' }
		.crop { 'crop' }
		.cross { 'cross' }
		.crosshair { 'crosshair' }
		.currentcolor { 'currentcolor' }
		.cursive { 'cursive' }
		.custom { 'custom' }
		.cyclic { 'cyclic' }
		.dark { 'dark' }
		.darken { 'darken' }
		.dashed { 'dashed' }
		.decimal { 'decimal' }
		.decimal_leading_zero { 'decimal-leading-zero' }
		.decreasing { 'decreasing' }
		.default { 'default' }
		.devanagari { 'devanagari' }
		.diagonal_fractions { 'diagonal-fractions' }
		.difference { 'difference' }
		.disc { 'disc' }
		.discard { 'discard' }
		.discard_before { 'discard-before' }
		.discard_after { 'discard-after' }
		.discard_inner { 'discard-inner' }
		.disclosure_closed { 'disclosure-closed' }
		.disclosure_open { 'disclosure-open' }
		.discretionary_ligatures { 'discretionary-ligatures' }
		.distribute { 'distribute' }
		.display_p3 { 'display-p3' }
		.display_p3_linear { 'display-p3-linear' }
		.dizi { 'dizi' }
		.dogri { 'dogri' }
		.dotted_decimal { 'dotted-decimal' }
		.dotted { 'dotted' }
		.double_circled_decimal { 'double-circled-decimal' }
		.double_ { 'double' }
		.down { 'down' }
		.e { 'e' }
		.e_resize { 'e-resize' }
		.each_line { 'each-line' }
		.ease { 'ease' }
		.ease_in { 'ease-in' }
		.ease_in_out { 'ease-in-out' }
		.ease_out { 'ease-out' }
		.element_shared { 'element-shared' }
		.ellipsis { 'ellipsis' }
		.else_ { 'else' }
		.embed { 'embed' }
		.emoji { 'emoji' }
		.enabled { 'enabled' }
		.end_ { 'end' }
		.ethiopic_halehame_am { 'ethiopic-halehame-am' }
		.ethiopic_halehame_ti_er { 'ethiopic-halehame-ti-er' }
		.ethiopic_halehame_ti_et { 'ethiopic-halehame-ti-et' }
		.ethiopic_halehame { 'ethiopic-halehame' }
		.ethiopic_numeric { 'ethiopic-numeric' }
		.evenodd { 'evenodd' }
		.ew_resize { 'ew-resize' }
		.exclude { 'exclude' }
		.exclusion { 'exclusion' }
		.expanded { 'expanded' }
		.extends { 'extends' }
		.extra_condensed { 'extra-condensed' }
		.extra_expanded { 'extra-expanded' }
		.fallback { 'fallback' }
		.false_ { 'false' }
		.fantasy { 'fantasy' }
		.farthest_corner { 'farthest-corner' }
		.farthest_side { 'farthest-side' }
		.fast { 'fast' }
		.features_aat { 'features-aat' }
		.features_graphite { 'features-graphite' }
		.features_opentype { 'features-opentype' }
		.field { 'field' }
		.fieldtext { 'fieldtext' }
		.fill { 'fill' }
		.fill_box { 'fill-box' }
		.filled_circled_decimal { 'filled-circled-decimal' }
		.fine { 'fine' }
		.fixed { 'fixed' }
		.flat { 'flat' }
		.flex { 'flex' }
		.flex_end { 'flex-end' }
		.flex_start { 'flex-start' }
		.flip_block { 'flip-block' }
		.flip_inline { 'flip-inline' }
		.flip_start { 'flip-start' }
		.flow { 'flow' }
		.flow_root { 'flow-root' }
		.forwards { 'forwards' }
		.from_font { 'from-font' }
		.full_size_kana { 'full-size-kana' }
		.full_width { 'full-width' }
		.fullwidth_decimal { 'fullwidth-decimal' }
		.fullwidth_lower_alpha { 'fullwidth-lower-alpha' }
		.fullwidth_upper_alpha { 'fullwidth-upper-alpha' }
		.fullwidth_upper_roman { 'fullwidth-upper-roman' }
		.fullscreen { 'fullscreen' }
		.gedeo { 'gedeo' }
		.geometricprecision { 'geometricprecision' }
		.georgian { 'georgian' }
		.grab { 'grab' }
		.grabbing { 'grabbing' }
		.grammar_error { 'grammar-error' }
		.graytext { 'graytext' }
		.greek_lower_ancient { 'greek-lower-ancient' }
		.greek_lower_modern { 'greek-lower-modern' }
		.greek_upper_ancient { 'greek-upper-ancient' }
		.greek_upper_modern { 'greek-upper-modern' }
		.grid { 'grid' }
		.groove { 'groove' }
		.gujarati_alpha { 'gujarati-alpha' }
		.gujarati { 'gujarati' }
		.gumuz { 'gumuz' }
		.gurmukhi { 'gurmukhi' }
		.hadiyaa { 'hadiyaa' }
		.hanging { 'hanging' }
		.hangul_consonant { 'hangul-consonant' }
		.hangul { 'hangul' }
		.hanifi_rohingya { 'hanifi-rohingya' }
		.harari { 'harari' }
		.hard_light { 'hard-light' }
		.hebrew { 'hebrew' }
		.height { 'height' }
		.help { 'help' }
		.hide { 'hide' }
		.hidden { 'hidden' }
		.high { 'high' }
		.high_quality { 'high-quality' }
		.highlight { 'highlight' }
		.highlighttext { 'highlighttext' }
		.hindi { 'hindi' }
		.hiragana_iroha { 'hiragana-iroha' }
		.hiragana { 'hiragana' }
		.historical_forms { 'historical-forms' }
		.historical_ligatures { 'historical-ligatures' }
		.horizontal { 'horizontal' }
		.horizontal_tb { 'horizontal-tb' }
		.hover { 'hover' }
		.hsl { 'hsl' }
		.hue { 'hue' }
		.hwb { 'hwb' }
		.inactiveborder { 'inactiveborder' }
		.inactivecaption { 'inactivecaption' }
		.inactivecaptiontext { 'inactivecaptiontext' }
		.increasing { 'increasing' }
		.ideographic { 'ideographic' }
		.incremental { 'incremental' }
		.infinite { 'infinite' }
		.infinity { 'infinity' }
		.infobackground { 'infobackground' }
		.infotext { 'infotext' }
		.inherit { 'inherit' }
		.initial { 'initial' }
		.initial_only { 'initial-only' }
		.inline_ { 'inline' }
		.inline_block { 'inline-block' }
		.inline_end { 'inline-end' }
		.inline_flex { 'inline-flex' }
		.inline_grid { 'inline-grid' }
		.inline_size { 'inline-size' }
		.inline_start { 'inline-start' }
		.inline_table { 'inline-table' }
		.inset { 'inset' }
		.inside { 'inside' }
		.inter_character { 'inter-character' }
		.inter_word { 'inter-word' }
		.interlace { 'interlace' }
		.intersect { 'intersect' }
		.invert { 'invert' }
		.inverted { 'inverted' }
		.isolate { 'isolate' }
		.isolate_override { 'isolate-override' }
		.italic { 'italic' }
		.japanese_formal { 'japanese-formal' }
		.japanese_informal { 'japanese-informal' }
		.javanese { 'javanese' }
		.jis_b4 { 'jis-b4' }
		.jis_b5 { 'jis-b5' }
		.jis04 { 'jis04' }
		.jis78 { 'jis78' }
		.jis83 { 'jis83' }
		.jis90 { 'jis90' }
		.jump_both { 'jump-both' }
		.jump_end { 'jump-end' }
		.jump_none { 'jump-none' }
		.jump_start { 'jump-start' }
		.justify { 'justify' }
		.kaffa { 'kaffa' }
		.kannada_alpha { 'kannada-alpha' }
		.kannada { 'kannada' }
		.kashmiri { 'kashmiri' }
		.katakana_iroha { 'katakana-iroha' }
		.katakana { 'katakana' }
		.kayah_li { 'kayah-li' }
		.kebena { 'kebena' }
		.keep_all { 'keep-all' }
		.kembata { 'kembata' }
		.khmer_consonant { 'khmer-consonant' }
		.khmer { 'khmer' }
		.konkani { 'konkani' }
		.konso { 'konso' }
		.korean_consonant { 'korean-consonant' }
		.korean_hangul_formal { 'korean-hangul-formal' }
		.korean_hanja_formal { 'korean-hanja-formal' }
		.korean_hanja_informal { 'korean-hanja-informal' }
		.korean_syllable { 'korean-syllable' }
		.kunama { 'kunama' }
		.landscape { 'landscape' }
		.lanna_hora { 'lanna-hora' }
		.lanna_tham { 'lanna-tham' }
		.lao { 'lao' }
		.lab { 'lab' }
		.large { 'large' }
		.larger { 'larger' }
		.layout { 'layout' }
		.lch { 'lch' }
		.ledger { 'ledger' }
		.left { 'left' }
		.legacy { 'legacy' }
		.legal { 'legal' }
		.lepcha { 'lepcha' }
		.less { 'less' }
		.letter { 'letter' }
		.light { 'light' }
		.lighten { 'lighten' }
		.lighter { 'lighter' }
		.limbu { 'limbu' }
		.line_through { 'line-through' }
		.linear { 'linear' }
		.linearrgb { 'linearrgb' }
		.lining_nums { 'lining-nums' }
		.linktext { 'linktext' }
		.list_item { 'list-item' }
		.listbox { 'listbox' }
		.local { 'local' }
		.longer { 'longer' }
		.lower_alpha_symbolic { 'lower-alpha-symbolic' }
		.lower_alpha { 'lower-alpha' }
		.lower_armenian { 'lower-armenian' }
		.lower_belorussian { 'lower-belorussian' }
		.lower_bulgarian { 'lower-bulgarian' }
		.lower_greek { 'lower-greek' }
		.lower_hexadecimal { 'lower-hexadecimal' }
		.lower_latin { 'lower-latin' }
		.lower_macedonian { 'lower-macedonian' }
		.lower_oromo_qubee { 'lower-oromo-qubee' }
		.lower_roman { 'lower-roman' }
		.lower_russian_full { 'lower-russian-full' }
		.lower_russian { 'lower-russian' }
		.lower_serbian { 'lower-serbian' }
		.lower_ukrainian_full { 'lower-ukrainian-full' }
		.lower_ukrainian { 'lower-ukrainian' }
		.lowercase { 'lowercase' }
		.ltr { 'ltr' }
		.luminance { 'luminance' }
		.luminosity { 'luminosity' }
		.maghrebi_abjad { 'maghrebi-abjad' }
		.maithili { 'maithili' }
		.malayalam_alpha { 'malayalam-alpha' }
		.malayalam { 'malayalam' }
		.manipulation { 'manipulation' }
		.manipuri { 'manipuri' }
		.marathi { 'marathi' }
		.margin_box { 'margin-box' }
		.mark { 'mark' }
		.markers { 'markers' }
		.marktext { 'marktext' }
		.match_parent { 'match-parent' }
		.match_source { 'match-source' }
		.math { 'math' }
		.math_auto { 'math-auto' }
		.mathematical { 'mathematical' }
		.max_content { 'max-content' }
		.medium { 'medium' }
		.meen { 'meen' }
		.meetei { 'meetei' }
		.menu { 'menu' }
		.menulist { 'menulist' }
		.menulist_button { 'menulist-button' }
		.menutext { 'menutext' }
		.meter { 'meter' }
		.middle { 'middle' }
		.min_content { 'min-content' }
		.minimal_ui { 'minimal-ui' }
		.miter { 'miter' }
		.mongolian { 'mongolian' }
		.monospace { 'monospace' }
		.more { 'more' }
		.most_block_size { 'most-block-size' }
		.most_height { 'most-height' }
		.most_inline_size { 'most-inline-size' }
		.most_width { 'most-width' }
		.move { 'move' }
		.mro { 'mro' }
		.multiply { 'multiply' }
		.myanmar { 'myanmar' }
		.n_resize { 'n-resize' }
		.nag_mundari { 'nag-mundari' }
		.nan { 'nan' }
		.ne_resize { 'ne-resize' }
		.nearest { 'nearest' }
		.nesw_resize { 'nesw-resize' }
		.new_base_60 { 'new-base-60' }
		.newa { 'newa' }
		.nko_cardinal { 'nko-cardinal' }
		.no_clip { 'no-clip' }
		.no_close_quote { 'no-close-quote' }
		.no_common_ligatures { 'no-common-ligatures' }
		.no_contextual { 'no-contextual' }
		.no_discretionary_ligatures { 'no-discretionary-ligatures' }
		.no_drop { 'no-drop' }
		.no_historical_ligatures { 'no-historical-ligatures' }
		.no_open_quote { 'no-open-quote' }
		.no_overflow { 'no-overflow' }
		.no_preference { 'no-preference' }
		.no_referrer { 'no-referrer' }
		.no_referrer_when_downgrade { 'no-referrer-when-downgrade' }
		.no_repeat { 'no-repeat' }
		.none_ { 'none' }
		.nonzero { 'nonzero' }
		.normal { 'normal' }
		.not_allowed { 'not-allowed' }
		.notch { 'notch' }
		.nowrap { 'nowrap' }
		.ns_resize { 'ns-resize' }
		.numbers { 'numbers' }
		.numeric { 'numeric' }
		.nw_resize { 'nw-resize' }
		.nwse_resize { 'nwse-resize' }
		.oblique { 'oblique' }
		.octal { 'octal' }
		.odia { 'odia' }
		.off { 'off' }
		.oklab { 'oklab' }
		.oklch { 'oklch' }
		.ol_chiki { 'ol-chiki' }
		.oldstyle_nums { 'oldstyle-nums' }
		.on { 'on' }
		.opaque { 'opaque' }
		.open_quote { 'open-quote' }
		.optimizelegibility { 'optimizelegibility' }
		.optimizequality { 'optimizequality' }
		.optimizespeed { 'optimizespeed' }
		.optional { 'optional' }
		.ordinal { 'ordinal' }
		.origin { 'origin' }
		.origin_when_cross_origin { 'origin-when-cross-origin' }
		.oriya { 'oriya' }
		.oromo { 'oromo' }
		.outset { 'outset' }
		.outside { 'outside' }
		.overlay { 'overlay' }
		.overline { 'overline' }
		.p3 { 'p3' }
		.padding_box { 'padding-box' }
		.paged { 'paged' }
		.paint { 'paint' }
		.palettes { 'palettes' }
		.pan_down { 'pan-down' }
		.pan_left { 'pan-left' }
		.pan_right { 'pan-right' }
		.pan_up { 'pan-up' }
		.pan_x { 'pan-x' }
		.pan_y { 'pan-y' }
		.parenthesized_decimal { 'parenthesized-decimal' }
		.parenthesized_hangul_consonant { 'parenthesized-hangul-consonant' }
		.parenthesized_hangul_syllable { 'parenthesized-hangul-syllable' }
		.parenthesized_ideograph { 'parenthesized-ideograph' }
		.parenthesized_lower_latin { 'parenthesized-lower-latin' }
		.paused { 'paused' }
		.persian_abjad { 'persian-abjad' }
		.persian_alphabetic { 'persian-alphabetic' }
		.persian { 'persian' }
		.petite_caps { 'petite-caps' }
		.pi { 'pi' }
		.picture_in_picture { 'picture-in-picture' }
		.pixelated { 'pixelated' }
		.plaintext { 'plaintext' }
		.plus_darker { 'plus-darker' }
		.plus_lighter { 'plus-lighter' }
		.pointer { 'pointer' }
		.portrait { 'portrait' }
		.pre { 'pre' }
		.pre_line { 'pre-line' }
		.pre_wrap { 'pre-wrap' }
		.preserve { 'preserve' }
		.preserve_3d { 'preserve-3d' }
		.preserve_breaks { 'preserve-breaks' }
		.preserve_spaces { 'preserve-spaces' }
		.pretty { 'pretty' }
		.progress { 'progress' }
		.progress_bar { 'progress-bar' }
		.progressive { 'progressive' }
		.prophoto_rgb { 'prophoto-rgb' }
		.proportional_nums { 'proportional-nums' }
		.proportional_width { 'proportional-width' }
		.punjabi { 'punjabi' }
		.push_button { 'push-button' }
		.radio { 'radio' }
		.rec2020 { 'rec2020' }
		.reduce { 'reduce' }
		.relative { 'relative' }
		.repeat { 'repeat' }
		.repeat_x { 'repeat-x' }
		.repeat_y { 'repeat-y' }
		.replace { 'replace' }
		.reverse { 'reverse' }
		.revert { 'revert' }
		.revert_layer { 'revert-layer' }
		.ridge { 'ridge' }
		.right { 'right' }
		.root { 'root' }
		.rotate_left { 'rotate-left' }
		.rotate_right { 'rotate-right' }
		.round { 'round' }
		.row { 'row' }
		.row_resize { 'row-resize' }
		.row_reverse { 'row-reverse' }
		.rtl { 'rtl' }
		.ruby { 'ruby' }
		.ruby_base { 'ruby-base' }
		.ruby_base_container { 'ruby-base-container' }
		.ruby_text { 'ruby-text' }
		.ruby_text_container { 'ruby-text-container' }
		.run_in { 'run-in' }
		.running { 'running' }
		.s_resize { 's-resize' }
		.safe { 'safe' }
		.saho { 'saho' }
		.same_origin { 'same-origin' }
		.sans_serif { 'sans-serif' }
		.sanskrit { 'sanskrit' }
		.santali { 'santali' }
		.saturation { 'saturation' }
		.scale_down { 'scale-down' }
		.scoop { 'scoop' }
		.screen { 'screen' }
		.scroll { 'scroll' }
		.scroll_position { 'scroll-position' }
		.scroll_state { 'scroll-state' }
		.scrollbar { 'scrollbar' }
		.se_resize { 'se-resize' }
		.searchfield { 'searchfield' }
		.selecteditem { 'selecteditem' }
		.selecteditemtext { 'selecteditemtext' }
		.self { 'self' }
		.self_block { 'self-block' }
		.self_block_end { 'self-block-end' }
		.self_block_start { 'self-block-start' }
		.self_end { 'self-end' }
		.self_inline { 'self-inline' }
		.self_inline_end { 'self-inline-end' }
		.self_inline_start { 'self-inline-start' }
		.self_x_end { 'self-x-end' }
		.self_x_start { 'self-x-start' }
		.self_y_end { 'self-y-end' }
		.self_y_start { 'self-y-start' }
		.self_start { 'self-start' }
		.semi_condensed { 'semi-condensed' }
		.semi_expanded { 'semi-expanded' }
		.separate { 'separate' }
		.serif { 'serif' }
		.shan { 'shan' }
		.shorter { 'shorter' }
		.show { 'show' }
		.sidama { 'sidama' }
		.sideways_lr { 'sideways-lr' }
		.sideways_rl { 'sideways-rl' }
		.silti { 'silti' }
		.simp_chinese_formal { 'simp-chinese-formal' }
		.simp_chinese_informal { 'simp-chinese-informal' }
		.simple_lower_roman { 'simple-lower-roman' }
		.simple_upper_roman { 'simple-upper-roman' }
		.simplified { 'simplified' }
		.sindhi { 'sindhi' }
		.size { 'size' }
		.slashed_zero { 'slashed-zero' }
		.slider_horizontal { 'slider-horizontal' }
		.slow { 'slow' }
		.small { 'small' }
		.small_caps { 'small-caps' }
		.smaller { 'smaller' }
		.smooth { 'smooth' }
		.soft_light { 'soft-light' }
		.solid { 'solid' }
		.space { 'space' }
		.space_around { 'space-around' }
		.space_between { 'space-between' }
		.space_evenly { 'space-evenly' }
		.span_all { 'span-all' }
		.span_block_end { 'span-block-end' }
		.span_block_start { 'span-block-start' }
		.span_bottom { 'span-bottom' }
		.span_end { 'span-end' }
		.span_inline_end { 'span-inline-end' }
		.span_inline_start { 'span-inline-start' }
		.span_left { 'span-left' }
		.span_right { 'span-right' }
		.span_self_block_end { 'span-self-block-end' }
		.span_self_block_start { 'span-self-block-start' }
		.span_self_end { 'span-self-end' }
		.span_self_inline_end { 'span-self-inline-end' }
		.span_self_inline_start { 'span-self-inline-start' }
		.span_self_start { 'span-self-start' }
		.span_self_x_end { 'span-self-x-end' }
		.span_self_x_start { 'span-self-x-start' }
		.span_self_y_end { 'span-self-y-end' }
		.span_self_y_start { 'span-self-y-start' }
		.span_start { 'span-start' }
		.span_top { 'span-top' }
		.span_x_end { 'span-x-end' }
		.span_x_start { 'span-x-start' }
		.span_y_end { 'span-y-end' }
		.span_y_start { 'span-y-start' }
		.spelling_error { 'spelling-error' }
		.spell_out { 'spell-out' }
		.square { 'square' }
		.square_button { 'square-button' }
		.squircle { 'squircle' }
		.srgb { 'srgb' }
		.srgb_linear { 'srgb-linear' }
		.stable { 'stable' }
		.stacked_fractions { 'stacked-fractions' }
		.standalone { 'standalone' }
		.standard { 'standard' }
		.start { 'start' }
		.static_ { 'static' }
		.sticky { 'sticky' }
		.stretch { 'stretch' }
		.strict { 'strict' }
		.strict_origin { 'strict-origin' }
		.strict_origin_when_cross_origin { 'strict-origin-when-cross-origin' }
		.stroke { 'stroke' }
		.stroke_box { 'stroke-box' }
		.style { 'style' }
		.sub { 'sub' }
		.subtract { 'subtract' }
		.subtractive { 'subtractive' }
		.sundanese { 'sundanese' }
		.super_decimal { 'super-decimal' }
		.super { 'super' }
		.sw_resize { 'sw-resize' }
		.swap { 'swap' }
		.symbolic { 'symbolic' }
		.table { 'table' }
		.table_caption { 'table-caption' }
		.table_cell { 'table-cell' }
		.table_column { 'table-column' }
		.table_column_group { 'table-column-group' }
		.table_footer_group { 'table-footer-group' }
		.table_header_group { 'table-header-group' }
		.table_row { 'table-row' }
		.table_row_group { 'table-row-group' }
		.tabular_nums { 'tabular-nums' }
		.tai_lue { 'tai-lue' }
		.tally_mark { 'tally-mark' }
		.tamil { 'tamil' }
		.telugu_alpha { 'telugu-alpha' }
		.telugu { 'telugu' }
		.text { 'text' }
		.text_bottom { 'text-bottom' }
		.text_top { 'text-top' }
		.textarea { 'textarea' }
		.textfield { 'textfield' }
		.thai_alpha { 'thai-alpha' }
		.thai { 'thai' }
		.thick { 'thick' }
		.thin { 'thin' }
		.threeddarkshadow { 'threeddarkshadow' }
		.threedface { 'threedface' }
		.threedhighlight { 'threedhighlight' }
		.threedlightshadow { 'threedlightshadow' }
		.threedshadow { 'threedshadow' }
		.tibetan { 'tibetan' }
		.tigre { 'tigre' }
		.titling_caps { 'titling-caps' }
		.to_zero { 'to-zero' }
		.top { 'top' }
		.trad_chinese_formal { 'trad-chinese-formal' }
		.trad_chinese_informal { 'trad-chinese-informal' }
		.traditional { 'traditional' }
		.true_ { 'true' }
		.ui_monospace { 'ui-monospace' }
		.ui_rounded { 'ui-rounded' }
		.ui_sans_serif { 'ui-sans-serif' }
		.ui_serif { 'ui-serif' }
		.ultra_condensed { 'ultra-condensed' }
		.ultra_expanded { 'ultra-expanded' }
		.under { 'under' }
		.underline { 'underline' }
		.unicase { 'unicase' }
		.unicode { 'unicode' }
		.unsafe_ { 'unsafe' }
		.unsafe_url { 'unsafe-url' }
		.unset { 'unset' }
		.up { 'up' }
		.upper_alpha_symbolic { 'upper-alpha-symbolic' }
		.upper_alpha { 'upper-alpha' }
		.upper_armenian { 'upper-armenian' }
		.upper_belorussian { 'upper-belorussian' }
		.upper_bulgarian { 'upper-bulgarian' }
		.upper_hexadecimal { 'upper-hexadecimal' }
		.upper_latin { 'upper-latin' }
		.upper_macedonian { 'upper-macedonian' }
		.upper_oromo_qubee { 'upper-oromo-qubee' }
		.upper_roman { 'upper-roman' }
		.upper_russian_full { 'upper-russian-full' }
		.upper_russian { 'upper-russian' }
		.upper_serbian { 'upper-serbian' }
		.upper_ukrainian_full { 'upper-ukrainian-full' }
		.upper_ukrainian { 'upper-ukrainian' }
		.uppercase { 'uppercase' }
		.upright { 'upright' }
		.urdu_abjad { 'urdu-abjad' }
		.urdu_alphabetic { 'urdu-alphabetic' }
		.urdu { 'urdu' }
		.use_credentials { 'use-credentials' }
		.variations { 'variations' }
		.vertical { 'vertical' }
		.vertical_lr { 'vertical-lr' }
		.vertical_rl { 'vertical-rl' }
		.vertical_text { 'vertical-text' }
		.view_box { 'view-box' }
		.visible { 'visible' }
		.visitedtext { 'visitedtext' }
		.w_resize { 'w-resize' }
		.wait { 'wait' }
		.warang_citi { 'warang-citi' }
		.wavy { 'wavy' }
		.width { 'width' }
		.window { 'window' }
		.windowframe { 'windowframe' }
		.windowtext { 'windowtext' }
		.wolaita { 'wolaita' }
		.words { 'words' }
		.wrap { 'wrap' }
		.wrap_reverse { 'wrap-reverse' }
		.x { 'x' }
		.x_end { 'x-end' }
		.x_large { 'x-large' }
		.x_start { 'x-start' }
		.x_small { 'x-small' }
		.xx_large { 'xx-large' }
		.xx_small { 'xx-small' }
		.xxx_large { 'xxx-large' }
		.xyz { 'xyz' }
		.xyz_d50 { 'xyz-d50' }
		.xyz_d65 { 'xyz-d65' }
		.y { 'y' }
		.y_end { 'y-end' }
		.y_start { 'y-start' }
		.yemsa { 'yemsa' }
		.zhuyin { 'zhuyin' }
		.zoom_in { 'zoom-in' }
		.zoom_out { 'zoom-out' }
	}
}

pub fn keyword_from_string(input string) ?Keyword {
	return match to_ascii_lowercase(input) {
		'-infinity' { Keyword.negative_infinity }
		'-libweb-buttonfacedisabled' { Keyword.libweb_buttonfacedisabled }
		'-libweb-buttonfacehover' { Keyword.libweb_buttonfacehover }
		'-libweb-center' { Keyword.libweb_center }
		'-libweb-inherit-or-center' { Keyword.libweb_inherit_or_center }
		'-libweb-left' { Keyword.libweb_left }
		'-libweb-link' { Keyword.libweb_link }
		'-libweb-palette-active-link' { Keyword.libweb_palette_active_link }
		'-libweb-palette-active-window-border1' { Keyword.libweb_palette_active_window_border1 }
		'-libweb-palette-active-window-border2' { Keyword.libweb_palette_active_window_border2 }
		'-libweb-palette-active-window-title' { Keyword.libweb_palette_active_window_title }
		'-libweb-palette-base' { Keyword.libweb_palette_base }
		'-libweb-palette-base-text' { Keyword.libweb_palette_base_text }
		'-libweb-palette-button' { Keyword.libweb_palette_button }
		'-libweb-palette-button-text' { Keyword.libweb_palette_button_text }
		'-libweb-palette-desktop-background' { Keyword.libweb_palette_desktop_background }
		'-libweb-palette-focus-outline' { Keyword.libweb_palette_focus_outline }
		'-libweb-palette-highlight-window-border1' {
			Keyword.libweb_palette_highlight_window_border1
		}
		'-libweb-palette-highlight-window-border2' {
			Keyword.libweb_palette_highlight_window_border2
		}
		'-libweb-palette-highlight-window-title' { Keyword.libweb_palette_highlight_window_title }
		'-libweb-palette-hover-highlight' { Keyword.libweb_palette_hover_highlight }
		'-libweb-palette-inactive-selection' { Keyword.libweb_palette_inactive_selection }
		'-libweb-palette-inactive-selection-text' { Keyword.libweb_palette_inactive_selection_text }
		'-libweb-palette-inactive-window-border1' { Keyword.libweb_palette_inactive_window_border1 }
		'-libweb-palette-inactive-window-border2' { Keyword.libweb_palette_inactive_window_border2 }
		'-libweb-palette-inactive-window-title' { Keyword.libweb_palette_inactive_window_title }
		'-libweb-palette-link' { Keyword.libweb_palette_link }
		'-libweb-palette-menu-base' { Keyword.libweb_palette_menu_base }
		'-libweb-palette-menu-base-text' { Keyword.libweb_palette_menu_base_text }
		'-libweb-palette-menu-selection' { Keyword.libweb_palette_menu_selection }
		'-libweb-palette-menu-selection-text' { Keyword.libweb_palette_menu_selection_text }
		'-libweb-palette-menu-stripe' { Keyword.libweb_palette_menu_stripe }
		'-libweb-palette-moving-window-border1' { Keyword.libweb_palette_moving_window_border1 }
		'-libweb-palette-moving-window-border2' { Keyword.libweb_palette_moving_window_border2 }
		'-libweb-palette-moving-window-title' { Keyword.libweb_palette_moving_window_title }
		'-libweb-palette-rubber-band-border' { Keyword.libweb_palette_rubber_band_border }
		'-libweb-palette-rubber-band-fill' { Keyword.libweb_palette_rubber_band_fill }
		'-libweb-palette-ruler' { Keyword.libweb_palette_ruler }
		'-libweb-palette-ruler-active-text' { Keyword.libweb_palette_ruler_active_text }
		'-libweb-palette-ruler-border' { Keyword.libweb_palette_ruler_border }
		'-libweb-palette-ruler-inactive-text' { Keyword.libweb_palette_ruler_inactive_text }
		'-libweb-palette-selection' { Keyword.libweb_palette_selection }
		'-libweb-palette-selection-text' { Keyword.libweb_palette_selection_text }
		'-libweb-palette-syntax-comment' { Keyword.libweb_palette_syntax_comment }
		'-libweb-palette-syntax-control-keyword' { Keyword.libweb_palette_syntax_control_keyword }
		'-libweb-palette-syntax-identifier' { Keyword.libweb_palette_syntax_identifier }
		'-libweb-palette-syntax-keyword' { Keyword.libweb_palette_syntax_keyword }
		'-libweb-palette-syntax-number' { Keyword.libweb_palette_syntax_number }
		'-libweb-palette-syntax-operator' { Keyword.libweb_palette_syntax_operator }
		'-libweb-palette-syntax-preprocessor-statement' {
			Keyword.libweb_palette_syntax_preprocessor_statement
		}
		'-libweb-palette-syntax-preprocessor-value' {
			Keyword.libweb_palette_syntax_preprocessor_value
		}
		'-libweb-palette-syntax-punctuation' { Keyword.libweb_palette_syntax_punctuation }
		'-libweb-palette-syntax-string' { Keyword.libweb_palette_syntax_string }
		'-libweb-palette-syntax-type' { Keyword.libweb_palette_syntax_type }
		'-libweb-palette-text-cursor' { Keyword.libweb_palette_text_cursor }
		'-libweb-palette-threed-highlight' { Keyword.libweb_palette_threed_highlight }
		'-libweb-palette-threed-shadow1' { Keyword.libweb_palette_threed_shadow1 }
		'-libweb-palette-threed-shadow2' { Keyword.libweb_palette_threed_shadow2 }
		'-libweb-palette-visited-link' { Keyword.libweb_palette_visited_link }
		'-libweb-palette-window' { Keyword.libweb_palette_window }
		'-libweb-palette-window-text' { Keyword.libweb_palette_window_text }
		'-libweb-right' { Keyword.libweb_right }
		'a3' { Keyword.a3 }
		'a4' { Keyword.a4 }
		'a5' { Keyword.a5 }
		'a98-rgb' { Keyword.a98_rgb }
		'absolute' { Keyword.absolute }
		'accentcolor' { Keyword.accentcolor }
		'accentcolortext' { Keyword.accentcolortext }
		'accumulate' { Keyword.accumulate }
		'active' { Keyword.active }
		'activeborder' { Keyword.activeborder }
		'activecaption' { Keyword.activecaption }
		'activetext' { Keyword.activetext }
		'add' { Keyword.add }
		'additive' { Keyword.additive }
		'adlam' { Keyword.adlam }
		'afar' { Keyword.afar }
		'agaw' { Keyword.agaw }
		'alias' { Keyword.alias }
		'all' { Keyword.all }
		'all-petite-caps' { Keyword.all_petite_caps }
		'all-scroll' { Keyword.all_scroll }
		'all-small-caps' { Keyword.all_small_caps }
		'allow-discrete' { Keyword.allow_discrete }
		'alpha' { Keyword.alpha }
		'alphabetic' { Keyword.alphabetic }
		'alternate' { Keyword.alternate }
		'alternate-reverse' { Keyword.alternate_reverse }
		'always' { Keyword.always }
		'anchors-valid' { Keyword.anchors_valid }
		'anchors-visible' { Keyword.anchors_visible }
		'ancient-tamil' { Keyword.ancient_tamil }
		'anonymous' { Keyword.anonymous }
		'anywhere' { Keyword.anywhere }
		'appworkspace' { Keyword.appworkspace }
		'arabic-abjad' { Keyword.arabic_abjad }
		'arabic-indic' { Keyword.arabic_indic }
		'ari' { Keyword.ari }
		'armenian' { Keyword.armenian }
		'auto' { Keyword.auto }
		'auto-add' { Keyword.auto_add }
		'avar2' { Keyword.avar2 }
		'b4' { Keyword.b4 }
		'b5' { Keyword.b5 }
		'back' { Keyword.back }
		'background' { Keyword.background }
		'backwards' { Keyword.backwards }
		'balance' { Keyword.balance }
		'balinese' { Keyword.balinese }
		'bamum' { Keyword.bamum }
		'bangla' { Keyword.bangla }
		'baseline' { Keyword.baseline }
		'bengali' { Keyword.bengali }
		'bevel' { Keyword.bevel }
		'bidi-override' { Keyword.bidi_override }
		'binary' { Keyword.binary }
		'blin' { Keyword.blin }
		'blink' { Keyword.blink }
		'block' { Keyword.block }
		'block-end' { Keyword.block_end }
		'block-start' { Keyword.block_start }
		'bodo' { Keyword.bodo }
		'bold' { Keyword.bold }
		'bolder' { Keyword.bolder }
		'border-box' { Keyword.border_box }
		'both' { Keyword.both }
		'both-edges' { Keyword.both_edges }
		'bottom' { Keyword.bottom }
		'break-all' { Keyword.break_all }
		'break-spaces' { Keyword.break_spaces }
		'break-word' { Keyword.break_word }
		'browser' { Keyword.browser }
		'bullets' { Keyword.bullets }
		'butt' { Keyword.butt }
		'button' { Keyword.button }
		'buttonborder' { Keyword.buttonborder }
		'buttonface' { Keyword.buttonface }
		'buttonhighlight' { Keyword.buttonhighlight }
		'buttonshadow' { Keyword.buttonshadow }
		'buttontext' { Keyword.buttontext }
		'cambodian' { Keyword.cambodian }
		'canvas' { Keyword.canvas }
		'canvastext' { Keyword.canvastext }
		'capitalize' { Keyword.capitalize }
		'captiontext' { Keyword.captiontext }
		'cell' { Keyword.cell }
		'center' { Keyword.center }
		'central' { Keyword.central }
		'checkbox' { Keyword.checkbox }
		'circle' { Keyword.circle }
		'circled-decimal' { Keyword.circled_decimal }
		'circled-ideograph' { Keyword.circled_ideograph }
		'circled-katakana' { Keyword.circled_katakana }
		'circled-korean-consonant' { Keyword.circled_korean_consonant }
		'circled-korean-syllable' { Keyword.circled_korean_syllable }
		'circled-lower-latin' { Keyword.circled_lower_latin }
		'circled-upper-latin' { Keyword.circled_upper_latin }
		'cjk-decimal' { Keyword.cjk_decimal }
		'cjk-earthly-branch' { Keyword.cjk_earthly_branch }
		'cjk-heavenly-stem' { Keyword.cjk_heavenly_stem }
		'cjk-ideographic' { Keyword.cjk_ideographic }
		'cjk-stem-branch' { Keyword.cjk_stem_branch }
		'cjk-tally-mark' { Keyword.cjk_tally_mark }
		'clip' { Keyword.clip }
		'close-quote' { Keyword.close_quote }
		'closest-corner' { Keyword.closest_corner }
		'closest-side' { Keyword.closest_side }
		'coarse' { Keyword.coarse }
		'col-resize' { Keyword.col_resize }
		'collapse' { Keyword.collapse }
		'color' { Keyword.color }
		'color-burn' { Keyword.color_burn }
		'color-cbdt' { Keyword.color_cbdt }
		'color-colrv0' { Keyword.color_colrv0 }
		'color-colrv1' { Keyword.color_colrv1 }
		'color-dodge' { Keyword.color_dodge }
		'color-sbix' { Keyword.color_sbix }
		'color-svg' { Keyword.color_svg }
		'column' { Keyword.column }
		'column-reverse' { Keyword.column_reverse }
		'common-ligatures' { Keyword.common_ligatures }
		'compact' { Keyword.compact }
		'condensed' { Keyword.condensed }
		'contain' { Keyword.contain }
		'content' { Keyword.content }
		'content-box' { Keyword.content_box }
		'contents' { Keyword.contents }
		'context-menu' { Keyword.context_menu }
		'contextual' { Keyword.contextual }
		'copy' { Keyword.copy }
		'cover' { Keyword.cover }
		'crisp-edges' { Keyword.crisp_edges }
		'crispedges' { Keyword.crispedges }
		'crop' { Keyword.crop }
		'cross' { Keyword.cross }
		'crosshair' { Keyword.crosshair }
		'currentcolor' { Keyword.currentcolor }
		'cursive' { Keyword.cursive }
		'custom' { Keyword.custom }
		'cyclic' { Keyword.cyclic }
		'dark' { Keyword.dark }
		'darken' { Keyword.darken }
		'dashed' { Keyword.dashed }
		'decimal' { Keyword.decimal }
		'decimal-leading-zero' { Keyword.decimal_leading_zero }
		'decreasing' { Keyword.decreasing }
		'default' { Keyword.default }
		'devanagari' { Keyword.devanagari }
		'diagonal-fractions' { Keyword.diagonal_fractions }
		'difference' { Keyword.difference }
		'disc' { Keyword.disc }
		'discard' { Keyword.discard }
		'discard-before' { Keyword.discard_before }
		'discard-after' { Keyword.discard_after }
		'discard-inner' { Keyword.discard_inner }
		'disclosure-closed' { Keyword.disclosure_closed }
		'disclosure-open' { Keyword.disclosure_open }
		'discretionary-ligatures' { Keyword.discretionary_ligatures }
		'distribute' { Keyword.distribute }
		'display-p3' { Keyword.display_p3 }
		'display-p3-linear' { Keyword.display_p3_linear }
		'dizi' { Keyword.dizi }
		'dogri' { Keyword.dogri }
		'dotted-decimal' { Keyword.dotted_decimal }
		'dotted' { Keyword.dotted }
		'double-circled-decimal' { Keyword.double_circled_decimal }
		'double' { Keyword.double_ }
		'down' { Keyword.down }
		'e' { Keyword.e }
		'e-resize' { Keyword.e_resize }
		'each-line' { Keyword.each_line }
		'ease' { Keyword.ease }
		'ease-in' { Keyword.ease_in }
		'ease-in-out' { Keyword.ease_in_out }
		'ease-out' { Keyword.ease_out }
		'element-shared' { Keyword.element_shared }
		'ellipsis' { Keyword.ellipsis }
		'else' { Keyword.else_ }
		'embed' { Keyword.embed }
		'emoji' { Keyword.emoji }
		'enabled' { Keyword.enabled }
		'end' { Keyword.end_ }
		'ethiopic-halehame-am' { Keyword.ethiopic_halehame_am }
		'ethiopic-halehame-ti-er' { Keyword.ethiopic_halehame_ti_er }
		'ethiopic-halehame-ti-et' { Keyword.ethiopic_halehame_ti_et }
		'ethiopic-halehame' { Keyword.ethiopic_halehame }
		'ethiopic-numeric' { Keyword.ethiopic_numeric }
		'evenodd' { Keyword.evenodd }
		'ew-resize' { Keyword.ew_resize }
		'exclude' { Keyword.exclude }
		'exclusion' { Keyword.exclusion }
		'expanded' { Keyword.expanded }
		'extends' { Keyword.extends }
		'extra-condensed' { Keyword.extra_condensed }
		'extra-expanded' { Keyword.extra_expanded }
		'fallback' { Keyword.fallback }
		'false' { Keyword.false_ }
		'fantasy' { Keyword.fantasy }
		'farthest-corner' { Keyword.farthest_corner }
		'farthest-side' { Keyword.farthest_side }
		'fast' { Keyword.fast }
		'features-aat' { Keyword.features_aat }
		'features-graphite' { Keyword.features_graphite }
		'features-opentype' { Keyword.features_opentype }
		'field' { Keyword.field }
		'fieldtext' { Keyword.fieldtext }
		'fill' { Keyword.fill }
		'fill-box' { Keyword.fill_box }
		'filled-circled-decimal' { Keyword.filled_circled_decimal }
		'fine' { Keyword.fine }
		'fixed' { Keyword.fixed }
		'flat' { Keyword.flat }
		'flex' { Keyword.flex }
		'flex-end' { Keyword.flex_end }
		'flex-start' { Keyword.flex_start }
		'flip-block' { Keyword.flip_block }
		'flip-inline' { Keyword.flip_inline }
		'flip-start' { Keyword.flip_start }
		'flow' { Keyword.flow }
		'flow-root' { Keyword.flow_root }
		'forwards' { Keyword.forwards }
		'from-font' { Keyword.from_font }
		'full-size-kana' { Keyword.full_size_kana }
		'full-width' { Keyword.full_width }
		'fullwidth-decimal' { Keyword.fullwidth_decimal }
		'fullwidth-lower-alpha' { Keyword.fullwidth_lower_alpha }
		'fullwidth-upper-alpha' { Keyword.fullwidth_upper_alpha }
		'fullwidth-upper-roman' { Keyword.fullwidth_upper_roman }
		'fullscreen' { Keyword.fullscreen }
		'gedeo' { Keyword.gedeo }
		'geometricprecision' { Keyword.geometricprecision }
		'georgian' { Keyword.georgian }
		'grab' { Keyword.grab }
		'grabbing' { Keyword.grabbing }
		'grammar-error' { Keyword.grammar_error }
		'graytext' { Keyword.graytext }
		'greek-lower-ancient' { Keyword.greek_lower_ancient }
		'greek-lower-modern' { Keyword.greek_lower_modern }
		'greek-upper-ancient' { Keyword.greek_upper_ancient }
		'greek-upper-modern' { Keyword.greek_upper_modern }
		'grid' { Keyword.grid }
		'groove' { Keyword.groove }
		'gujarati-alpha' { Keyword.gujarati_alpha }
		'gujarati' { Keyword.gujarati }
		'gumuz' { Keyword.gumuz }
		'gurmukhi' { Keyword.gurmukhi }
		'hadiyaa' { Keyword.hadiyaa }
		'hanging' { Keyword.hanging }
		'hangul-consonant' { Keyword.hangul_consonant }
		'hangul' { Keyword.hangul }
		'hanifi-rohingya' { Keyword.hanifi_rohingya }
		'harari' { Keyword.harari }
		'hard-light' { Keyword.hard_light }
		'hebrew' { Keyword.hebrew }
		'height' { Keyword.height }
		'help' { Keyword.help }
		'hide' { Keyword.hide }
		'hidden' { Keyword.hidden }
		'high' { Keyword.high }
		'high-quality' { Keyword.high_quality }
		'highlight' { Keyword.highlight }
		'highlighttext' { Keyword.highlighttext }
		'hindi' { Keyword.hindi }
		'hiragana-iroha' { Keyword.hiragana_iroha }
		'hiragana' { Keyword.hiragana }
		'historical-forms' { Keyword.historical_forms }
		'historical-ligatures' { Keyword.historical_ligatures }
		'horizontal' { Keyword.horizontal }
		'horizontal-tb' { Keyword.horizontal_tb }
		'hover' { Keyword.hover }
		'hsl' { Keyword.hsl }
		'hue' { Keyword.hue }
		'hwb' { Keyword.hwb }
		'inactiveborder' { Keyword.inactiveborder }
		'inactivecaption' { Keyword.inactivecaption }
		'inactivecaptiontext' { Keyword.inactivecaptiontext }
		'increasing' { Keyword.increasing }
		'ideographic' { Keyword.ideographic }
		'incremental' { Keyword.incremental }
		'infinite' { Keyword.infinite }
		'infinity' { Keyword.infinity }
		'infobackground' { Keyword.infobackground }
		'infotext' { Keyword.infotext }
		'inherit' { Keyword.inherit }
		'initial' { Keyword.initial }
		'initial-only' { Keyword.initial_only }
		'inline' { Keyword.inline_ }
		'inline-block' { Keyword.inline_block }
		'inline-end' { Keyword.inline_end }
		'inline-flex' { Keyword.inline_flex }
		'inline-grid' { Keyword.inline_grid }
		'inline-size' { Keyword.inline_size }
		'inline-start' { Keyword.inline_start }
		'inline-table' { Keyword.inline_table }
		'inset' { Keyword.inset }
		'inside' { Keyword.inside }
		'inter-character' { Keyword.inter_character }
		'inter-word' { Keyword.inter_word }
		'interlace' { Keyword.interlace }
		'intersect' { Keyword.intersect }
		'invert' { Keyword.invert }
		'inverted' { Keyword.inverted }
		'isolate' { Keyword.isolate }
		'isolate-override' { Keyword.isolate_override }
		'italic' { Keyword.italic }
		'japanese-formal' { Keyword.japanese_formal }
		'japanese-informal' { Keyword.japanese_informal }
		'javanese' { Keyword.javanese }
		'jis-b4' { Keyword.jis_b4 }
		'jis-b5' { Keyword.jis_b5 }
		'jis04' { Keyword.jis04 }
		'jis78' { Keyword.jis78 }
		'jis83' { Keyword.jis83 }
		'jis90' { Keyword.jis90 }
		'jump-both' { Keyword.jump_both }
		'jump-end' { Keyword.jump_end }
		'jump-none' { Keyword.jump_none }
		'jump-start' { Keyword.jump_start }
		'justify' { Keyword.justify }
		'kaffa' { Keyword.kaffa }
		'kannada-alpha' { Keyword.kannada_alpha }
		'kannada' { Keyword.kannada }
		'kashmiri' { Keyword.kashmiri }
		'katakana-iroha' { Keyword.katakana_iroha }
		'katakana' { Keyword.katakana }
		'kayah-li' { Keyword.kayah_li }
		'kebena' { Keyword.kebena }
		'keep-all' { Keyword.keep_all }
		'kembata' { Keyword.kembata }
		'khmer-consonant' { Keyword.khmer_consonant }
		'khmer' { Keyword.khmer }
		'konkani' { Keyword.konkani }
		'konso' { Keyword.konso }
		'korean-consonant' { Keyword.korean_consonant }
		'korean-hangul-formal' { Keyword.korean_hangul_formal }
		'korean-hanja-formal' { Keyword.korean_hanja_formal }
		'korean-hanja-informal' { Keyword.korean_hanja_informal }
		'korean-syllable' { Keyword.korean_syllable }
		'kunama' { Keyword.kunama }
		'landscape' { Keyword.landscape }
		'lanna-hora' { Keyword.lanna_hora }
		'lanna-tham' { Keyword.lanna_tham }
		'lao' { Keyword.lao }
		'lab' { Keyword.lab }
		'large' { Keyword.large }
		'larger' { Keyword.larger }
		'layout' { Keyword.layout }
		'lch' { Keyword.lch }
		'ledger' { Keyword.ledger }
		'left' { Keyword.left }
		'legacy' { Keyword.legacy }
		'legal' { Keyword.legal }
		'lepcha' { Keyword.lepcha }
		'less' { Keyword.less }
		'letter' { Keyword.letter }
		'light' { Keyword.light }
		'lighten' { Keyword.lighten }
		'lighter' { Keyword.lighter }
		'limbu' { Keyword.limbu }
		'line-through' { Keyword.line_through }
		'linear' { Keyword.linear }
		'linearrgb' { Keyword.linearrgb }
		'lining-nums' { Keyword.lining_nums }
		'linktext' { Keyword.linktext }
		'list-item' { Keyword.list_item }
		'listbox' { Keyword.listbox }
		'local' { Keyword.local }
		'longer' { Keyword.longer }
		'lower-alpha-symbolic' { Keyword.lower_alpha_symbolic }
		'lower-alpha' { Keyword.lower_alpha }
		'lower-armenian' { Keyword.lower_armenian }
		'lower-belorussian' { Keyword.lower_belorussian }
		'lower-bulgarian' { Keyword.lower_bulgarian }
		'lower-greek' { Keyword.lower_greek }
		'lower-hexadecimal' { Keyword.lower_hexadecimal }
		'lower-latin' { Keyword.lower_latin }
		'lower-macedonian' { Keyword.lower_macedonian }
		'lower-oromo-qubee' { Keyword.lower_oromo_qubee }
		'lower-roman' { Keyword.lower_roman }
		'lower-russian-full' { Keyword.lower_russian_full }
		'lower-russian' { Keyword.lower_russian }
		'lower-serbian' { Keyword.lower_serbian }
		'lower-ukrainian-full' { Keyword.lower_ukrainian_full }
		'lower-ukrainian' { Keyword.lower_ukrainian }
		'lowercase' { Keyword.lowercase }
		'ltr' { Keyword.ltr }
		'luminance' { Keyword.luminance }
		'luminosity' { Keyword.luminosity }
		'maghrebi-abjad' { Keyword.maghrebi_abjad }
		'maithili' { Keyword.maithili }
		'malayalam-alpha' { Keyword.malayalam_alpha }
		'malayalam' { Keyword.malayalam }
		'manipulation' { Keyword.manipulation }
		'manipuri' { Keyword.manipuri }
		'marathi' { Keyword.marathi }
		'margin-box' { Keyword.margin_box }
		'mark' { Keyword.mark }
		'markers' { Keyword.markers }
		'marktext' { Keyword.marktext }
		'match-parent' { Keyword.match_parent }
		'match-source' { Keyword.match_source }
		'math' { Keyword.math }
		'math-auto' { Keyword.math_auto }
		'mathematical' { Keyword.mathematical }
		'max-content' { Keyword.max_content }
		'medium' { Keyword.medium }
		'meen' { Keyword.meen }
		'meetei' { Keyword.meetei }
		'menu' { Keyword.menu }
		'menulist' { Keyword.menulist }
		'menulist-button' { Keyword.menulist_button }
		'menutext' { Keyword.menutext }
		'meter' { Keyword.meter }
		'middle' { Keyword.middle }
		'min-content' { Keyword.min_content }
		'minimal-ui' { Keyword.minimal_ui }
		'miter' { Keyword.miter }
		'mongolian' { Keyword.mongolian }
		'monospace' { Keyword.monospace }
		'more' { Keyword.more }
		'most-block-size' { Keyword.most_block_size }
		'most-height' { Keyword.most_height }
		'most-inline-size' { Keyword.most_inline_size }
		'most-width' { Keyword.most_width }
		'move' { Keyword.move }
		'mro' { Keyword.mro }
		'multiply' { Keyword.multiply }
		'myanmar' { Keyword.myanmar }
		'n-resize' { Keyword.n_resize }
		'nag-mundari' { Keyword.nag_mundari }
		'nan' { Keyword.nan }
		'ne-resize' { Keyword.ne_resize }
		'nearest' { Keyword.nearest }
		'nesw-resize' { Keyword.nesw_resize }
		'new-base-60' { Keyword.new_base_60 }
		'newa' { Keyword.newa }
		'nko-cardinal' { Keyword.nko_cardinal }
		'no-clip' { Keyword.no_clip }
		'no-close-quote' { Keyword.no_close_quote }
		'no-common-ligatures' { Keyword.no_common_ligatures }
		'no-contextual' { Keyword.no_contextual }
		'no-discretionary-ligatures' { Keyword.no_discretionary_ligatures }
		'no-drop' { Keyword.no_drop }
		'no-historical-ligatures' { Keyword.no_historical_ligatures }
		'no-open-quote' { Keyword.no_open_quote }
		'no-overflow' { Keyword.no_overflow }
		'no-preference' { Keyword.no_preference }
		'no-referrer' { Keyword.no_referrer }
		'no-referrer-when-downgrade' { Keyword.no_referrer_when_downgrade }
		'no-repeat' { Keyword.no_repeat }
		'none' { Keyword.none_ }
		'nonzero' { Keyword.nonzero }
		'normal' { Keyword.normal }
		'not-allowed' { Keyword.not_allowed }
		'notch' { Keyword.notch }
		'nowrap' { Keyword.nowrap }
		'ns-resize' { Keyword.ns_resize }
		'numbers' { Keyword.numbers }
		'numeric' { Keyword.numeric }
		'nw-resize' { Keyword.nw_resize }
		'nwse-resize' { Keyword.nwse_resize }
		'oblique' { Keyword.oblique }
		'octal' { Keyword.octal }
		'odia' { Keyword.odia }
		'off' { Keyword.off }
		'oklab' { Keyword.oklab }
		'oklch' { Keyword.oklch }
		'ol-chiki' { Keyword.ol_chiki }
		'oldstyle-nums' { Keyword.oldstyle_nums }
		'on' { Keyword.on }
		'opaque' { Keyword.opaque }
		'open-quote' { Keyword.open_quote }
		'optimizelegibility' { Keyword.optimizelegibility }
		'optimizequality' { Keyword.optimizequality }
		'optimizespeed' { Keyword.optimizespeed }
		'optional' { Keyword.optional }
		'ordinal' { Keyword.ordinal }
		'origin' { Keyword.origin }
		'origin-when-cross-origin' { Keyword.origin_when_cross_origin }
		'oriya' { Keyword.oriya }
		'oromo' { Keyword.oromo }
		'outset' { Keyword.outset }
		'outside' { Keyword.outside }
		'overlay' { Keyword.overlay }
		'overline' { Keyword.overline }
		'p3' { Keyword.p3 }
		'padding-box' { Keyword.padding_box }
		'paged' { Keyword.paged }
		'paint' { Keyword.paint }
		'palettes' { Keyword.palettes }
		'pan-down' { Keyword.pan_down }
		'pan-left' { Keyword.pan_left }
		'pan-right' { Keyword.pan_right }
		'pan-up' { Keyword.pan_up }
		'pan-x' { Keyword.pan_x }
		'pan-y' { Keyword.pan_y }
		'parenthesized-decimal' { Keyword.parenthesized_decimal }
		'parenthesized-hangul-consonant' { Keyword.parenthesized_hangul_consonant }
		'parenthesized-hangul-syllable' { Keyword.parenthesized_hangul_syllable }
		'parenthesized-ideograph' { Keyword.parenthesized_ideograph }
		'parenthesized-lower-latin' { Keyword.parenthesized_lower_latin }
		'paused' { Keyword.paused }
		'persian-abjad' { Keyword.persian_abjad }
		'persian-alphabetic' { Keyword.persian_alphabetic }
		'persian' { Keyword.persian }
		'petite-caps' { Keyword.petite_caps }
		'pi' { Keyword.pi }
		'picture-in-picture' { Keyword.picture_in_picture }
		'pixelated' { Keyword.pixelated }
		'plaintext' { Keyword.plaintext }
		'plus-darker' { Keyword.plus_darker }
		'plus-lighter' { Keyword.plus_lighter }
		'pointer' { Keyword.pointer }
		'portrait' { Keyword.portrait }
		'pre' { Keyword.pre }
		'pre-line' { Keyword.pre_line }
		'pre-wrap' { Keyword.pre_wrap }
		'preserve' { Keyword.preserve }
		'preserve-3d' { Keyword.preserve_3d }
		'preserve-breaks' { Keyword.preserve_breaks }
		'preserve-spaces' { Keyword.preserve_spaces }
		'pretty' { Keyword.pretty }
		'progress' { Keyword.progress }
		'progress-bar' { Keyword.progress_bar }
		'progressive' { Keyword.progressive }
		'prophoto-rgb' { Keyword.prophoto_rgb }
		'proportional-nums' { Keyword.proportional_nums }
		'proportional-width' { Keyword.proportional_width }
		'punjabi' { Keyword.punjabi }
		'push-button' { Keyword.push_button }
		'radio' { Keyword.radio }
		'rec2020' { Keyword.rec2020 }
		'reduce' { Keyword.reduce }
		'relative' { Keyword.relative }
		'repeat' { Keyword.repeat }
		'repeat-x' { Keyword.repeat_x }
		'repeat-y' { Keyword.repeat_y }
		'replace' { Keyword.replace }
		'reverse' { Keyword.reverse }
		'revert' { Keyword.revert }
		'revert-layer' { Keyword.revert_layer }
		'ridge' { Keyword.ridge }
		'right' { Keyword.right }
		'root' { Keyword.root }
		'rotate-left' { Keyword.rotate_left }
		'rotate-right' { Keyword.rotate_right }
		'round' { Keyword.round }
		'row' { Keyword.row }
		'row-resize' { Keyword.row_resize }
		'row-reverse' { Keyword.row_reverse }
		'rtl' { Keyword.rtl }
		'ruby' { Keyword.ruby }
		'ruby-base' { Keyword.ruby_base }
		'ruby-base-container' { Keyword.ruby_base_container }
		'ruby-text' { Keyword.ruby_text }
		'ruby-text-container' { Keyword.ruby_text_container }
		'run-in' { Keyword.run_in }
		'running' { Keyword.running }
		's-resize' { Keyword.s_resize }
		'safe' { Keyword.safe }
		'saho' { Keyword.saho }
		'same-origin' { Keyword.same_origin }
		'sans-serif' { Keyword.sans_serif }
		'sanskrit' { Keyword.sanskrit }
		'santali' { Keyword.santali }
		'saturation' { Keyword.saturation }
		'scale-down' { Keyword.scale_down }
		'scoop' { Keyword.scoop }
		'screen' { Keyword.screen }
		'scroll' { Keyword.scroll }
		'scroll-position' { Keyword.scroll_position }
		'scroll-state' { Keyword.scroll_state }
		'scrollbar' { Keyword.scrollbar }
		'se-resize' { Keyword.se_resize }
		'searchfield' { Keyword.searchfield }
		'selecteditem' { Keyword.selecteditem }
		'selecteditemtext' { Keyword.selecteditemtext }
		'self' { Keyword.self }
		'self-block' { Keyword.self_block }
		'self-block-end' { Keyword.self_block_end }
		'self-block-start' { Keyword.self_block_start }
		'self-end' { Keyword.self_end }
		'self-inline' { Keyword.self_inline }
		'self-inline-end' { Keyword.self_inline_end }
		'self-inline-start' { Keyword.self_inline_start }
		'self-x-end' { Keyword.self_x_end }
		'self-x-start' { Keyword.self_x_start }
		'self-y-end' { Keyword.self_y_end }
		'self-y-start' { Keyword.self_y_start }
		'self-start' { Keyword.self_start }
		'semi-condensed' { Keyword.semi_condensed }
		'semi-expanded' { Keyword.semi_expanded }
		'separate' { Keyword.separate }
		'serif' { Keyword.serif }
		'shan' { Keyword.shan }
		'shorter' { Keyword.shorter }
		'show' { Keyword.show }
		'sidama' { Keyword.sidama }
		'sideways-lr' { Keyword.sideways_lr }
		'sideways-rl' { Keyword.sideways_rl }
		'silti' { Keyword.silti }
		'simp-chinese-formal' { Keyword.simp_chinese_formal }
		'simp-chinese-informal' { Keyword.simp_chinese_informal }
		'simple-lower-roman' { Keyword.simple_lower_roman }
		'simple-upper-roman' { Keyword.simple_upper_roman }
		'simplified' { Keyword.simplified }
		'sindhi' { Keyword.sindhi }
		'size' { Keyword.size }
		'slashed-zero' { Keyword.slashed_zero }
		'slider-horizontal' { Keyword.slider_horizontal }
		'slow' { Keyword.slow }
		'small' { Keyword.small }
		'small-caps' { Keyword.small_caps }
		'smaller' { Keyword.smaller }
		'smooth' { Keyword.smooth }
		'soft-light' { Keyword.soft_light }
		'solid' { Keyword.solid }
		'space' { Keyword.space }
		'space-around' { Keyword.space_around }
		'space-between' { Keyword.space_between }
		'space-evenly' { Keyword.space_evenly }
		'span-all' { Keyword.span_all }
		'span-block-end' { Keyword.span_block_end }
		'span-block-start' { Keyword.span_block_start }
		'span-bottom' { Keyword.span_bottom }
		'span-end' { Keyword.span_end }
		'span-inline-end' { Keyword.span_inline_end }
		'span-inline-start' { Keyword.span_inline_start }
		'span-left' { Keyword.span_left }
		'span-right' { Keyword.span_right }
		'span-self-block-end' { Keyword.span_self_block_end }
		'span-self-block-start' { Keyword.span_self_block_start }
		'span-self-end' { Keyword.span_self_end }
		'span-self-inline-end' { Keyword.span_self_inline_end }
		'span-self-inline-start' { Keyword.span_self_inline_start }
		'span-self-start' { Keyword.span_self_start }
		'span-self-x-end' { Keyword.span_self_x_end }
		'span-self-x-start' { Keyword.span_self_x_start }
		'span-self-y-end' { Keyword.span_self_y_end }
		'span-self-y-start' { Keyword.span_self_y_start }
		'span-start' { Keyword.span_start }
		'span-top' { Keyword.span_top }
		'span-x-end' { Keyword.span_x_end }
		'span-x-start' { Keyword.span_x_start }
		'span-y-end' { Keyword.span_y_end }
		'span-y-start' { Keyword.span_y_start }
		'spelling-error' { Keyword.spelling_error }
		'spell-out' { Keyword.spell_out }
		'square' { Keyword.square }
		'square-button' { Keyword.square_button }
		'squircle' { Keyword.squircle }
		'srgb' { Keyword.srgb }
		'srgb-linear' { Keyword.srgb_linear }
		'stable' { Keyword.stable }
		'stacked-fractions' { Keyword.stacked_fractions }
		'standalone' { Keyword.standalone }
		'standard' { Keyword.standard }
		'start' { Keyword.start }
		'static' { Keyword.static_ }
		'sticky' { Keyword.sticky }
		'stretch' { Keyword.stretch }
		'strict' { Keyword.strict }
		'strict-origin' { Keyword.strict_origin }
		'strict-origin-when-cross-origin' { Keyword.strict_origin_when_cross_origin }
		'stroke' { Keyword.stroke }
		'stroke-box' { Keyword.stroke_box }
		'style' { Keyword.style }
		'sub' { Keyword.sub }
		'subtract' { Keyword.subtract }
		'subtractive' { Keyword.subtractive }
		'sundanese' { Keyword.sundanese }
		'super-decimal' { Keyword.super_decimal }
		'super' { Keyword.super }
		'sw-resize' { Keyword.sw_resize }
		'swap' { Keyword.swap }
		'symbolic' { Keyword.symbolic }
		'table' { Keyword.table }
		'table-caption' { Keyword.table_caption }
		'table-cell' { Keyword.table_cell }
		'table-column' { Keyword.table_column }
		'table-column-group' { Keyword.table_column_group }
		'table-footer-group' { Keyword.table_footer_group }
		'table-header-group' { Keyword.table_header_group }
		'table-row' { Keyword.table_row }
		'table-row-group' { Keyword.table_row_group }
		'tabular-nums' { Keyword.tabular_nums }
		'tai-lue' { Keyword.tai_lue }
		'tally-mark' { Keyword.tally_mark }
		'tamil' { Keyword.tamil }
		'telugu-alpha' { Keyword.telugu_alpha }
		'telugu' { Keyword.telugu }
		'text' { Keyword.text }
		'text-bottom' { Keyword.text_bottom }
		'text-top' { Keyword.text_top }
		'textarea' { Keyword.textarea }
		'textfield' { Keyword.textfield }
		'thai-alpha' { Keyword.thai_alpha }
		'thai' { Keyword.thai }
		'thick' { Keyword.thick }
		'thin' { Keyword.thin }
		'threeddarkshadow' { Keyword.threeddarkshadow }
		'threedface' { Keyword.threedface }
		'threedhighlight' { Keyword.threedhighlight }
		'threedlightshadow' { Keyword.threedlightshadow }
		'threedshadow' { Keyword.threedshadow }
		'tibetan' { Keyword.tibetan }
		'tigre' { Keyword.tigre }
		'titling-caps' { Keyword.titling_caps }
		'to-zero' { Keyword.to_zero }
		'top' { Keyword.top }
		'trad-chinese-formal' { Keyword.trad_chinese_formal }
		'trad-chinese-informal' { Keyword.trad_chinese_informal }
		'traditional' { Keyword.traditional }
		'true' { Keyword.true_ }
		'ui-monospace' { Keyword.ui_monospace }
		'ui-rounded' { Keyword.ui_rounded }
		'ui-sans-serif' { Keyword.ui_sans_serif }
		'ui-serif' { Keyword.ui_serif }
		'ultra-condensed' { Keyword.ultra_condensed }
		'ultra-expanded' { Keyword.ultra_expanded }
		'under' { Keyword.under }
		'underline' { Keyword.underline }
		'unicase' { Keyword.unicase }
		'unicode' { Keyword.unicode }
		'unsafe' { Keyword.unsafe_ }
		'unsafe-url' { Keyword.unsafe_url }
		'unset' { Keyword.unset }
		'up' { Keyword.up }
		'upper-alpha-symbolic' { Keyword.upper_alpha_symbolic }
		'upper-alpha' { Keyword.upper_alpha }
		'upper-armenian' { Keyword.upper_armenian }
		'upper-belorussian' { Keyword.upper_belorussian }
		'upper-bulgarian' { Keyword.upper_bulgarian }
		'upper-hexadecimal' { Keyword.upper_hexadecimal }
		'upper-latin' { Keyword.upper_latin }
		'upper-macedonian' { Keyword.upper_macedonian }
		'upper-oromo-qubee' { Keyword.upper_oromo_qubee }
		'upper-roman' { Keyword.upper_roman }
		'upper-russian-full' { Keyword.upper_russian_full }
		'upper-russian' { Keyword.upper_russian }
		'upper-serbian' { Keyword.upper_serbian }
		'upper-ukrainian-full' { Keyword.upper_ukrainian_full }
		'upper-ukrainian' { Keyword.upper_ukrainian }
		'uppercase' { Keyword.uppercase }
		'upright' { Keyword.upright }
		'urdu-abjad' { Keyword.urdu_abjad }
		'urdu-alphabetic' { Keyword.urdu_alphabetic }
		'urdu' { Keyword.urdu }
		'use-credentials' { Keyword.use_credentials }
		'variations' { Keyword.variations }
		'vertical' { Keyword.vertical }
		'vertical-lr' { Keyword.vertical_lr }
		'vertical-rl' { Keyword.vertical_rl }
		'vertical-text' { Keyword.vertical_text }
		'view-box' { Keyword.view_box }
		'visible' { Keyword.visible }
		'visitedtext' { Keyword.visitedtext }
		'w-resize' { Keyword.w_resize }
		'wait' { Keyword.wait }
		'warang-citi' { Keyword.warang_citi }
		'wavy' { Keyword.wavy }
		'width' { Keyword.width }
		'window' { Keyword.window }
		'windowframe' { Keyword.windowframe }
		'windowtext' { Keyword.windowtext }
		'wolaita' { Keyword.wolaita }
		'words' { Keyword.words }
		'wrap' { Keyword.wrap }
		'wrap-reverse' { Keyword.wrap_reverse }
		'x' { Keyword.x }
		'x-end' { Keyword.x_end }
		'x-large' { Keyword.x_large }
		'x-start' { Keyword.x_start }
		'x-small' { Keyword.x_small }
		'xx-large' { Keyword.xx_large }
		'xx-small' { Keyword.xx_small }
		'xxx-large' { Keyword.xxx_large }
		'xyz' { Keyword.xyz }
		'xyz-d50' { Keyword.xyz_d50 }
		'xyz-d65' { Keyword.xyz_d65 }
		'y' { Keyword.y }
		'y-end' { Keyword.y_end }
		'y-start' { Keyword.y_start }
		'yemsa' { Keyword.yemsa }
		'zhuyin' { Keyword.zhuyin }
		'zoom-in' { Keyword.zoom_in }
		'zoom-out' { Keyword.zoom_out }
		else { none }
	}
}

// --- StyleValue ---
pub enum StyleValueType {
	add_function
	anchor
	anchor_size
	angle
	background_size
	basic_shape
	border_image_slice
	border_radius
	border_radius_rect
	calculated
	color_interpolation_method
	color_scheme
	color
	conic_gradient
	content
	counter
	counter_style
	counter_definitions
	counter_style_system
	cursor
	custom_ident
	display
	easing
	edge
	filter_value_list
	fit_content
	flex
	font_source
	font_style
	font_variant_alternates_function
	frequency
	grid_auto_flow
	grid_template_area
	grid_track_placement
	grid_track_size_list
	guaranteed_invalid
	image
	integer
	keyword
	length
	linear_gradient
	number
	open_type_tagged
	pending_substitution
	percentage
	position
	radial_gradient
	radial_size
	random_value_sharing
	ratio
	rect
	repeat_style
	resolution
	scrollbar_color
	scrollbar_gutter
	scroll_function
	shadow
	shorthand
	string
	superellipse
	text_indent
	text_underline_position
	time
	transformation
	tree_counting_function
	tuple
	unicode_range
	unresolved
	url
	value_list
	view_function
}

pub type DimensionStyleValue = AngleStyleValue
	| FlexStyleValue
	| FrequencyStyleValue
	| LengthStyleValue
	| PercentageStyleValue
	| ResolutionStyleValue
	| TimeStyleValue

pub type StyleValue = KeywordStyleValue
	| AddFunctionStyleValue
	| AnchorSizeStyleValue
	| AnchorStyleValue
	| AngleStyleValue
	| CalculatedStyleValue
	| BackgroundSizeStyleValue
	| BasicShapeStyleValue
	| BorderImageSliceStyleValue
	| BorderRadiusRectStyleValue
	| BorderRadiusStyleValue
	| ColorFunctionStyleValue
	| ColorInterpolationMethodStyleValue
	| ColorMixStyleValue
	| ColorSchemeStyleValue
	| ColorStyleValue
	| ConicGradientStyleValue
	| ContentStyleValue
	| CounterDefinitionsStyleValue
	| CounterStyleStyleValue
	| CounterStyleValue
	| CursorStyleValue
	| CustomIdentStyleValue
	| DisplayStyleValue
	| EasingStyleValue
	| EdgeStyleValue
	| FilterValueListStyleValue
	| FitContentStyleValue
	| FlexStyleValue
	| FontSourceStyleValue
	| FontStyleStyleValue
	| FontVariantAlternatesFunctionStyleValue
	| FrequencyStyleValue
	| GridAutoFlowStyleValue
	| GridTemplateAreaStyleValue
	| GridTrackPlacementStyleValue
	| GridTrackSizeListStyleValue
	| GuaranteedInvalidStyleValue
	| HSLColorStyleValue
	| HWBColorStyleValue
	| ImageStyleValue
	| IntegerStyleValue
	| LabColorStyleValue
	| LCHColorStyleValue
	| LengthStyleValue
	| LightDarkStyleValue
	| LinearGradientStyleValue
	| NumberStyleValue
	| OKLabColorStyleValue
	| OKLCHColorStyleValue
	| OpenTypeTaggedStyleValue
	| PendingSubstitutionStyleValue
	| PercentageStyleValue
	| PositionStyleValue
	| RadialGradientStyleValue
	| RadialSizeStyleValue
	| RandomValueSharingStyleValue
	| RatioStyleValue
	| RectStyleValue
	| RepeatStyleStyleValue
	| ResolutionStyleValue
	| RGBColorStyleValue
	| ScrollFunctionStyleValue
	| ScrollbarColorStyleValue
	| ScrollbarGutterStyleValue
	| ShadowStyleValue
	| ShorthandStyleValue
	| StringStyleValue
	| StyleValueList
	| SuperellipseStyleValue
	| TextIndentStyleValue
	| TextUnderlinePositionStyleValue
	| TimeStyleValue
	| TransformationStyleValue
	| TreeCountingFunctionStyleValue
	| TupleStyleValue
	| UnicodeRangeStyleValue
	| UnresolvedStyleValue
	| URLStyleValue
	| ViewFunctionStyleValue

pub type StyleValueVector = []StyleValue

// StyleValue::set_style_sheet and the four upstream overrides. V sum types are
// values rather than GC references, so write the mutated concrete value back
// into the sum after propagating ownership.
pub fn (mut style_value StyleValue) set_style_sheet(style_sheet ?&CSSStyleSheet) {
	match style_value {
		ImageStyleValue {
			mut value := style_value
			value.set_style_sheet(style_sheet)
			style_value = StyleValue(value)
		}
		ContentStyleValue {
			mut value := style_value
			value.set_style_sheet(style_sheet)
			style_value = StyleValue(value)
		}
		ShorthandStyleValue {
			mut value := style_value
			value.set_style_sheet(style_sheet)
			style_value = StyleValue(value)
		}
		StyleValueList {
			mut value := style_value
			value.set_style_sheet(style_sheet)
			style_value = StyleValue(value)
		}
		else {}
	}
}

pub fn (style_value StyleValue) type_() StyleValueType {
	return match style_value {
		AddFunctionStyleValue { .add_function }
		AnchorSizeStyleValue { .anchor_size }
		AnchorStyleValue { .anchor }
		AngleStyleValue { .angle }
		BackgroundSizeStyleValue { .background_size }
		BasicShapeStyleValue { .basic_shape }
		BorderImageSliceStyleValue { .border_image_slice }
		BorderRadiusRectStyleValue { .border_radius_rect }
		BorderRadiusStyleValue { .border_radius }
		CalculatedStyleValue { .calculated }
		ColorFunctionStyleValue { .color }
		ColorInterpolationMethodStyleValue { .color_interpolation_method }
		ColorMixStyleValue { .color }
		ColorSchemeStyleValue { .color_scheme }
		ColorStyleValue { .color }
		ConicGradientStyleValue { .conic_gradient }
		ContentStyleValue { .content }
		CounterDefinitionsStyleValue { .counter_definitions }
		CounterStyleStyleValue { .counter_style }
		CounterStyleValue { .counter }
		CursorStyleValue { .cursor }
		CustomIdentStyleValue { .custom_ident }
		DisplayStyleValue { .display }
		EasingStyleValue { .easing }
		EdgeStyleValue { .edge }
		FilterValueListStyleValue { .filter_value_list }
		FitContentStyleValue { .fit_content }
		FlexStyleValue { .flex }
		FontSourceStyleValue { .font_source }
		FontStyleStyleValue { .font_style }
		FontVariantAlternatesFunctionStyleValue { .font_variant_alternates_function }
		FrequencyStyleValue { .frequency }
		GridAutoFlowStyleValue { .grid_auto_flow }
		GridTemplateAreaStyleValue { .grid_template_area }
		GridTrackPlacementStyleValue { .grid_track_placement }
		GridTrackSizeListStyleValue { .grid_track_size_list }
		GuaranteedInvalidStyleValue { .guaranteed_invalid }
		HSLColorStyleValue { .color }
		HWBColorStyleValue { .color }
		ImageStyleValue { .image }
		IntegerStyleValue { .integer }
		KeywordStyleValue { .keyword }
		LabColorStyleValue { .color }
		LCHColorStyleValue { .color }
		LengthStyleValue { .length }
		LightDarkStyleValue { .color }
		LinearGradientStyleValue { .linear_gradient }
		NumberStyleValue { .number }
		OKLabColorStyleValue { .color }
		OKLCHColorStyleValue { .color }
		OpenTypeTaggedStyleValue { .open_type_tagged }
		PendingSubstitutionStyleValue { .pending_substitution }
		PercentageStyleValue { .percentage }
		PositionStyleValue { .position }
		RadialGradientStyleValue { .radial_gradient }
		RadialSizeStyleValue { .radial_size }
		RandomValueSharingStyleValue { .random_value_sharing }
		RatioStyleValue { .ratio }
		RectStyleValue { .rect }
		RepeatStyleStyleValue { .repeat_style }
		ResolutionStyleValue { .resolution }
		RGBColorStyleValue { .color }
		ScrollFunctionStyleValue { .scroll_function }
		ScrollbarColorStyleValue { .scrollbar_color }
		ScrollbarGutterStyleValue { .scrollbar_gutter }
		ShadowStyleValue { .shadow }
		ShorthandStyleValue { .shorthand }
		StringStyleValue { .string }
		StyleValueList { .value_list }
		SuperellipseStyleValue { .superellipse }
		TextIndentStyleValue { .text_indent }
		TextUnderlinePositionStyleValue { .text_underline_position }
		TimeStyleValue { .time }
		TransformationStyleValue { .transformation }
		TreeCountingFunctionStyleValue { .tree_counting_function }
		TupleStyleValue { .tuple }
		UnicodeRangeStyleValue { .unicode_range }
		UnresolvedStyleValue { .unresolved }
		URLStyleValue { .url }
		ViewFunctionStyleValue { .view_function }
	}
}

pub fn (style_value StyleValue) is_keyword() bool {
	return style_value.type_() == .keyword
}

pub fn (style_value StyleValue) is_integer() bool {
	return style_value.type_() == .integer
}

pub fn (style_value StyleValue) is_number() bool {
	return style_value.type_() == .number
}

pub fn (style_value StyleValue) is_percentage() bool {
	return style_value.type_() == .percentage
}

pub fn (style_value StyleValue) is_ratio() bool {
	return style_value.type_() == .ratio
}

pub fn (style_value StyleValue) is_calculated() bool {
	return style_value.type_() == .calculated
}

pub fn (style_value StyleValue) is_string() bool {
	return style_value.type_() == .string
}

pub fn (style_value StyleValue) is_custom_ident() bool {
	return style_value.type_() == .custom_ident
}

pub fn (style_value StyleValue) is_dimension() bool {
	return match style_value {
		AngleStyleValue, FlexStyleValue, FrequencyStyleValue, LengthStyleValue, PercentageStyleValue, ResolutionStyleValue, TimeStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value StyleValue) as_keyword() KeywordStyleValue {
	value := style_value
	if value is KeywordStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_integer() IntegerStyleValue {
	value := style_value
	if value is IntegerStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_number() NumberStyleValue {
	value := style_value
	if value is NumberStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_percentage() PercentageStyleValue {
	value := style_value
	if value is PercentageStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_ratio() RatioStyleValue {
	value := style_value
	if value is RatioStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_calculated() CalculatedStyleValue {
	value := style_value
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_string() StringStyleValue {
	value := style_value
	if value is StringStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_custom_ident() CustomIdentStyleValue {
	value := style_value
	if value is CustomIdentStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_dimension() DimensionStyleValue {
	return match style_value {
		AngleStyleValue { DimensionStyleValue(style_value) }
		FlexStyleValue { DimensionStyleValue(style_value) }
		FrequencyStyleValue { DimensionStyleValue(style_value) }
		LengthStyleValue { DimensionStyleValue(style_value) }
		PercentageStyleValue { DimensionStyleValue(style_value) }
		ResolutionStyleValue { DimensionStyleValue(style_value) }
		TimeStyleValue { DimensionStyleValue(style_value) }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

// https://www.w3.org/TR/css-values-4/#common-keywords
// https://drafts.csswg.org/css-cascade-4/#valdef-all-revert
pub fn (style_value StyleValue) is_css_wide_keyword() bool {
	return style_value.is_inherit() || style_value.is_initial() || style_value.is_revert() || style_value.is_unset() || style_value.is_revert_layer()
}

pub fn (style_value StyleValue) is_inherit() bool {
	return style_value.to_keyword() == .inherit
}

pub fn (style_value StyleValue) is_initial() bool {
	return style_value.to_keyword() == .initial
}

pub fn (style_value StyleValue) is_revert() bool {
	return style_value.to_keyword() == .revert
}

pub fn (style_value StyleValue) is_revert_layer() bool {
	return style_value.to_keyword() == .revert_layer
}

pub fn (style_value StyleValue) is_unset() bool {
	return style_value.to_keyword() == .unset
}

pub fn (style_value StyleValue) has_auto() bool {
	return style_value.is_keyword() && style_value.as_keyword().keyword() == .auto
}

pub fn (style_value StyleValue) has_color() bool {
	return match style_value {
		KeywordStyleValue {
			style_value.has_color()
		}
		ColorFunctionStyleValue, ColorMixStyleValue, ColorStyleValue, HSLColorStyleValue, HWBColorStyleValue, LabColorStyleValue, LCHColorStyleValue, LightDarkStyleValue, OKLabColorStyleValue, OKLCHColorStyleValue, RGBColorStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value StyleValue) is_abstract_image() bool {
	return match style_value {
		ImageStyleValue, LinearGradientStyleValue, ConicGradientStyleValue, RadialGradientStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value StyleValue) is_color_function() bool {
	return style_value is ColorFunctionStyleValue
}

pub fn (style_value StyleValue) absolutized(context ComputationContext) StyleValue {
	return match style_value {
		AddFunctionStyleValue { style_value.absolutized(context) }
		BackgroundSizeStyleValue { style_value.absolutized(context) }
		BasicShapeStyleValue { style_value.absolutized(context) }
		BorderRadiusRectStyleValue { style_value.absolutized(context) }
		BorderRadiusStyleValue { style_value.absolutized(context) }
		CalculatedStyleValue { style_value.absolutized(context) }
		ColorFunctionStyleValue { style_value.absolutized(context) }
		ColorInterpolationMethodStyleValue { StyleValue(style_value.absolutized(context)) }
		ColorMixStyleValue { style_value.absolutized(context) }
		ConicGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		CursorStyleValue { style_value.absolutized(context) }
		EasingStyleValue { style_value.absolutized(context) }
		EdgeStyleValue { style_value.absolutized(context) }
		FilterValueListStyleValue { style_value.absolutized(context) }
		FontStyleStyleValue { style_value.absolutized(context) }
		FontVariantAlternatesFunctionStyleValue { style_value.absolutized(context) }
		GridTrackPlacementStyleValue { StyleValue(style_value.absolutized(context)) }
		GridTrackSizeListStyleValue { StyleValue(style_value.absolutized(context)) }
		HSLColorStyleValue { StyleValue(style_value.absolutized(context)) }
		HWBColorStyleValue { StyleValue(style_value.absolutized(context)) }
		ImageStyleValue { StyleValue(style_value.absolutized(context)) }
		LengthStyleValue { StyleValue(style_value.absolutized(context)) }
		LabColorStyleValue { StyleValue(style_value.absolutized(context)) }
		LCHColorStyleValue { StyleValue(style_value.absolutized(context)) }
		LightDarkStyleValue { style_value.absolutized(context) }
		LinearGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		KeywordStyleValue { style_value.absolutized(context) }
		OKLabColorStyleValue { StyleValue(style_value.absolutized(context)) }
		OKLCHColorStyleValue { StyleValue(style_value.absolutized(context)) }
		OpenTypeTaggedStyleValue { style_value.absolutized(context) }
		PositionStyleValue { style_value.absolutized(context) }
		RadialGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		RadialSizeStyleValue { style_value.absolutized(context) }
		RandomValueSharingStyleValue { style_value.absolutized(context) }
		RGBColorStyleValue { StyleValue(style_value.absolutized(context)) }
		ShadowStyleValue { style_value.absolutized(context) }
		StyleValueList { style_value.absolutized(context) }
		SuperellipseStyleValue { style_value.absolutized(context) }
		TextIndentStyleValue { style_value.absolutized(context) }
		TransformationStyleValue { StyleValue(style_value.absolutized(context)) }
		TreeCountingFunctionStyleValue { style_value.absolutized(context) }
		TupleStyleValue { style_value.absolutized(context) }
		ViewFunctionStyleValue { style_value.absolutized(context) }
		else { style_value }
	}
}

pub fn (style_value StyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	return match style_value {
		ColorFunctionStyleValue { style_value.to_color(color_resolution_context) }
		ColorMixStyleValue { style_value.to_color(color_resolution_context) }
		KeywordStyleValue { style_value.to_color(color_resolution_context) }
		ColorStyleValue { style_value.color() }
		HSLColorStyleValue { style_value.to_color(color_resolution_context) }
		HWBColorStyleValue { style_value.to_color(color_resolution_context) }
		LabColorStyleValue { style_value.to_color(color_resolution_context) }
		LCHColorStyleValue { style_value.to_color(color_resolution_context) }
		LightDarkStyleValue { style_value.to_color(color_resolution_context) }
		OKLabColorStyleValue { style_value.to_color(color_resolution_context) }
		OKLCHColorStyleValue { style_value.to_color(color_resolution_context) }
		RGBColorStyleValue { style_value.to_color(color_resolution_context) }
		else { none }
	}
}

pub fn (style_value StyleValue) to_keyword() Keyword {
	if style_value is KeywordStyleValue {
		return style_value.keyword()
	}
	return .invalid
}

pub fn (style_value StyleValue) serialize(mode SerializationMode) string {
	return match style_value {
		AddFunctionStyleValue { style_value.serialize(mode) }
		AnchorSizeStyleValue { style_value.serialize(mode) }
		AnchorStyleValue { style_value.serialize(mode) }
		AngleStyleValue { style_value.serialize(mode) }
		BackgroundSizeStyleValue { style_value.serialize(mode) }
		BasicShapeStyleValue { style_value.serialize(mode) }
		BorderImageSliceStyleValue { style_value.serialize(mode) }
		BorderRadiusRectStyleValue { style_value.serialize(mode) }
		BorderRadiusStyleValue { style_value.serialize(mode) }
		CalculatedStyleValue { style_value.serialize(mode) }
		ColorFunctionStyleValue { style_value.serialize(mode) }
		ColorInterpolationMethodStyleValue { style_value.serialize(mode) }
		ColorMixStyleValue { style_value.serialize(mode) }
		ColorSchemeStyleValue { style_value.serialize(mode) }
		ColorStyleValue { style_value.serialize(mode) }
		ConicGradientStyleValue { style_value.serialize(mode) }
		ContentStyleValue { style_value.serialize(mode) }
		CounterDefinitionsStyleValue { style_value.serialize(mode) }
		CounterStyleStyleValue { style_value.serialize(mode) }
		CounterStyleValue { style_value.serialize(mode) }
		CursorStyleValue { style_value.serialize(mode) }
		CustomIdentStyleValue { style_value.serialize(mode) }
		DisplayStyleValue { style_value.serialize(mode) }
		EasingStyleValue { style_value.serialize(mode) }
		EdgeStyleValue { style_value.serialize(mode) }
		FilterValueListStyleValue { style_value.serialize(mode) }
		FitContentStyleValue { style_value.serialize(mode) }
		FlexStyleValue { style_value.serialize(mode) }
		FontSourceStyleValue { style_value.serialize(mode) }
		FontStyleStyleValue { style_value.serialize(mode) }
		FontVariantAlternatesFunctionStyleValue { style_value.serialize(mode) }
		FrequencyStyleValue { style_value.serialize(mode) }
		GridAutoFlowStyleValue { style_value.serialize(mode) }
		GridTemplateAreaStyleValue { style_value.serialize(mode) }
		GridTrackPlacementStyleValue { style_value.serialize(mode) }
		GridTrackSizeListStyleValue { style_value.serialize(mode) }
		GuaranteedInvalidStyleValue { style_value.serialize(mode) }
		HSLColorStyleValue { style_value.serialize(mode) }
		HWBColorStyleValue { style_value.serialize(mode) }
		ImageStyleValue { style_value.serialize(mode) }
		IntegerStyleValue { style_value.serialize(mode) }
		KeywordStyleValue { style_value.serialize(mode) }
		LabColorStyleValue { style_value.serialize(mode) }
		LCHColorStyleValue { style_value.serialize(mode) }
		LengthStyleValue { style_value.serialize(mode) }
		LightDarkStyleValue { style_value.serialize(mode) }
		LinearGradientStyleValue { style_value.serialize(mode) }
		NumberStyleValue { style_value.serialize(mode) }
		OKLabColorStyleValue { style_value.serialize(mode) }
		OKLCHColorStyleValue { style_value.serialize(mode) }
		OpenTypeTaggedStyleValue { style_value.serialize(mode) }
		PendingSubstitutionStyleValue { style_value.serialize(mode) }
		PercentageStyleValue { style_value.serialize(mode) }
		PositionStyleValue { style_value.serialize(mode) }
		RadialGradientStyleValue { style_value.serialize(mode) }
		RadialSizeStyleValue { style_value.serialize(mode) }
		RandomValueSharingStyleValue { style_value.serialize(mode) }
		RatioStyleValue { style_value.serialize(mode) }
		RectStyleValue { style_value.serialize(mode) }
		RepeatStyleStyleValue { style_value.serialize(mode) }
		ResolutionStyleValue { style_value.serialize(mode) }
		RGBColorStyleValue { style_value.serialize(mode) }
		ScrollFunctionStyleValue { style_value.serialize(mode) }
		ScrollbarColorStyleValue { style_value.serialize(mode) }
		ScrollbarGutterStyleValue { style_value.serialize(mode) }
		ShadowStyleValue { style_value.serialize(mode) }
		ShorthandStyleValue { style_value.serialize(mode) }
		StringStyleValue { style_value.serialize(mode) }
		StyleValueList { style_value.serialize(mode) }
		SuperellipseStyleValue { style_value.serialize(mode) }
		TextIndentStyleValue { style_value.serialize(mode) }
		TextUnderlinePositionStyleValue { style_value.serialize(mode) }
		TimeStyleValue { style_value.serialize(mode) }
		TransformationStyleValue { style_value.serialize(mode) }
		TreeCountingFunctionStyleValue { style_value.serialize(mode) }
		TupleStyleValue { style_value.serialize(mode) }
		UnicodeRangeStyleValue { style_value.serialize(mode) }
		UnresolvedStyleValue { style_value.serialize(mode) }
		URLStyleValue { style_value.serialize(mode) }
		ViewFunctionStyleValue { style_value.serialize(mode) }
	}
}

pub fn (style_value StyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value StyleValue) to_string_with_mode(mode SerializationMode) string {
	return style_value.serialize(mode)
}

pub fn (style_value StyleValue) tokenize() []ComponentValue {
	// This is an inefficient way of producing ComponentValues, but it's guaranteed to work for types that round-trip.
	// FIXME: Implement better versions in the subclasses.
	if style_value.is_dimension() {
		return style_value.as_dimension().tokenize()
	}
	if style_value is KeywordStyleValue {
		return style_value.tokenize()
	}
	if style_value is NumberStyleValue {
		return style_value.tokenize()
	}
	if style_value is IntegerStyleValue {
		return style_value.tokenize()
	}
	if style_value is StyleValueList {
		return style_value.tokenize()
	}
	if style_value is RatioStyleValue {
		return style_value.tokenize()
	}
	if style_value is GuaranteedInvalidStyleValue {
		return style_value.tokenize()
	}
	if style_value is PendingSubstitutionStyleValue {
		return style_value.tokenize()
	}
	if style_value is UnresolvedStyleValue {
		return style_value.tokenize()
	}
	return parse_component_values_for_value_logic(style_value.to_string())
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-as-a-cssstylevalue
pub fn (style_value StyleValue) reify(associated_property string) CSSStyleValue {
	// 1. Return a new CSSStyleValue object representing value whose [[associatedProperty]] internal slot is set to property.
	if style_value.is_dimension() {
		return style_value.as_dimension().reify(associated_property)
	}
	if style_value is KeywordStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is NumberStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is IntegerStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is StyleValueList {
		return style_value.reify(associated_property)
	}
	if style_value is UnresolvedStyleValue {
		return CSSStyleValue.from_unparsed(style_value.reify(associated_property))
	}
	return CSSStyleValue.create(associated_property, style_value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#subdivide-into-iterations
pub fn (style_value StyleValue) subdivide_into_iterations(property PropertyNameAndID) StyleValueVector {
	// To subdivide into iterations a CSS value whole value for a property property, execute the following steps:
	// 1. If property is a single-valued property, return a list containing whole value.
	// 2. Otherwise, divide whole value into individual iterations, as appropriate for property, and return a list
	//    containing the iterations in order.
	// NB: We do this by type. By default, we assume step 1 applies. For step 2, override this method.
	return match style_value {
		StyleValueList {
			style_value.subdivide_into_iterations(property)
		}
		else {
			[style_value]
		}
	}
}

pub fn (style_value StyleValue) equals(other StyleValue) bool {
	return match style_value {
		ImageStyleValue {
			if other is ImageStyleValue {
				style_value.equals(other)
			} else {
				false
			}
		}
		UnresolvedStyleValue {
			if other is UnresolvedStyleValue {
				style_value.equals(other)
			} else {
				false
			}
		}
		StyleValueList {
			if other is StyleValueList {
				style_value.properties_equal(other)
			} else {
				false
			}
		}
		TransformationStyleValue {
			if other is TransformationStyleValue {
				style_value.properties_equal(other)
			} else {
				false
			}
		}
		else {
			style_value == other
		}
	}
}

pub fn int_from_style_value(style_value StyleValue) i64 {
	if style_value.is_integer() {
		return style_value.as_integer().integer()
	}

	if style_value.is_calculated() {
		return style_value.as_calculated().resolve_integer(CalculationResolutionContext{}) or { 0 }
	}

	panic('VERIFY_NOT_REACHED')
}

pub fn number_from_style_value(style_value StyleValue, percentage_basis ?f64) f64 {
	if style_value.is_number() {
		return style_value.as_number().number()
	}

	if style_value.is_calculated() {
		calculated_style_value := style_value.as_calculated()

		if calculated_style_value.resolves_to_number() {
			return calculated_style_value.resolve_number(CalculationResolutionContext{}) or { 0.0 }
		}

		if calculated_style_value.resolves_to_percentage() {
			basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
			percentage := calculated_style_value.resolve_percentage(CalculationResolutionContext{}) or {
				Percentage.new(0)
			}
			return percentage.as_fraction() * basis
		}

		panic('VERIFY_NOT_REACHED')
	}

	if style_value.is_percentage() {
		basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
		return basis * style_value.as_percentage().percentage().as_fraction()
	}

	panic('VERIFY_NOT_REACHED')
}

pub fn string_from_style_value(style_value StyleValue) string {
	if style_value.is_string() {
		return style_value.as_string().string_value()
	}

	if style_value.is_custom_ident() {
		return style_value.as_custom_ident().custom_ident()
	}

	panic('VERIFY_NOT_REACHED')
}

// --- DimensionStyleValue ---
pub fn (style_value DimensionStyleValue) raw_value() f64 {
	return match style_value {
		AngleStyleValue { style_value.raw_value() }
		FlexStyleValue { style_value.raw_value() }
		FrequencyStyleValue { style_value.raw_value() }
		LengthStyleValue { style_value.raw_value() }
		PercentageStyleValue { style_value.raw_value() }
		ResolutionStyleValue { style_value.raw_value() }
		TimeStyleValue { style_value.raw_value() }
	}
}

pub fn (style_value DimensionStyleValue) unit_name() string {
	return match style_value {
		AngleStyleValue { style_value.unit_name() }
		FlexStyleValue { style_value.unit_name() }
		FrequencyStyleValue { style_value.unit_name() }
		LengthStyleValue { style_value.unit_name() }
		PercentageStyleValue { style_value.unit_name() }
		ResolutionStyleValue { style_value.unit_name() }
		TimeStyleValue { style_value.unit_name() }
	}
}

pub fn (style_value DimensionStyleValue) tokenize() []ComponentValue {
	return [
		component_value_from_text('${serialize_a_number(style_value.raw_value())}${style_value.unit_name()}'),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value DimensionStyleValue) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	// NB: Steps 1 and 2 do not apply here.
	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	// FIXME: Reify computed value correctly. That sounds like it should work by computing the value properly before we
	//        reach this point.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(style_value.raw_value(), style_value.unit_name()))
}

// --- KeywordStyleValue ---
pub struct KeywordStyleValue {
pub mut:
	keyword_ Keyword = .invalid
}

pub fn KeywordStyleValue.create(keyword Keyword) KeywordStyleValue {
	return KeywordStyleValue{
		keyword_: keyword
	}
}

pub fn (style_value KeywordStyleValue) keyword() Keyword {
	return style_value.keyword_
}

pub fn (style_value KeywordStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return string_from_keyword(style_value.keyword())
}

pub fn (style_value KeywordStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn KeywordStyleValue.is_color(keyword Keyword) bool {
	return match keyword {
		.accentcolor, .accentcolortext, .activeborder, .activecaption, .activetext, .appworkspace, .background, .buttonborder, .buttonface, .buttonhighlight, .buttonshadow, .buttontext, .canvas, .canvastext, .captiontext, .currentcolor, .field, .fieldtext, .graytext, .highlight, .highlighttext, .inactiveborder, .inactivecaption, .inactivecaptiontext, .infobackground, .infotext, .libweb_buttonfacedisabled, .libweb_buttonfacehover, .libweb_link, .libweb_palette_active_link, .libweb_palette_active_window_border1, .libweb_palette_active_window_border2, .libweb_palette_active_window_title, .libweb_palette_base, .libweb_palette_base_text, .libweb_palette_button, .libweb_palette_button_text, .libweb_palette_desktop_background, .libweb_palette_focus_outline, .libweb_palette_highlight_window_border1, .libweb_palette_highlight_window_border2, .libweb_palette_highlight_window_title, .libweb_palette_hover_highlight, .libweb_palette_inactive_selection, .libweb_palette_inactive_selection_text, .libweb_palette_inactive_window_border1, .libweb_palette_inactive_window_border2, .libweb_palette_inactive_window_title, .libweb_palette_link, .libweb_palette_menu_base, .libweb_palette_menu_base_text, .libweb_palette_menu_selection, .libweb_palette_menu_selection_text, .libweb_palette_menu_stripe, .libweb_palette_moving_window_border1, .libweb_palette_moving_window_border2, .libweb_palette_moving_window_title, .libweb_palette_rubber_band_border, .libweb_palette_rubber_band_fill, .libweb_palette_ruler, .libweb_palette_ruler_active_text, .libweb_palette_ruler_border, .libweb_palette_ruler_inactive_text, .libweb_palette_selection, .libweb_palette_selection_text, .libweb_palette_syntax_comment, .libweb_palette_syntax_control_keyword, .libweb_palette_syntax_identifier, .libweb_palette_syntax_keyword, .libweb_palette_syntax_number, .libweb_palette_syntax_operator, .libweb_palette_syntax_preprocessor_statement, .libweb_palette_syntax_preprocessor_value, .libweb_palette_syntax_punctuation, .libweb_palette_syntax_string, .libweb_palette_syntax_type, .libweb_palette_text_cursor, .libweb_palette_threed_highlight, .libweb_palette_threed_shadow1, .libweb_palette_threed_shadow2, .libweb_palette_visited_link, .libweb_palette_window, .libweb_palette_window_text, .linktext, .mark, .marktext, .menu, .menutext, .scrollbar, .selecteditem, .selecteditemtext, .threeddarkshadow, .threedface, .threedhighlight, .threedlightshadow, .threedshadow, .visitedtext, .window, .windowframe, .windowtext {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value KeywordStyleValue) has_color() bool {
	return KeywordStyleValue.is_color(style_value.keyword())
}

pub fn (style_value KeywordStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	if style_value.keyword() == .currentcolor {
		return color_resolution_context.current_color or { Color.black() }
	}

	scheme := color_resolution_context.color_scheme or { PreferredColorScheme.light }

	// Calculate accent_color_text based on contrast to accent_color
	if style_value.keyword() == .accentcolortext {
		// min_contrast = 10.2 is a magic number which provides the best accessibility trade-off based on:
		// 1. https://webaim.org/resources/contrastchecker/
		// 2. Current implementation of luminosity() and contrast_ratio() methods for Color instances
		//
		// the baseline colors with the least contrast from black and white are #757575 and #767676
		// which score over 4.5 ratio for #fff and #000 accent_color_text values correspondingly
		min_contrast := 10.2
		system_accent_text := SystemColor.accent_color_text(scheme)

		accent_color := color_resolution_context.accent_color or {
			SystemColor.accent_color(scheme)
		}

		if accent_color.contrast_ratio(system_accent_text) < min_contrast {
			return system_accent_text.inverted()
		}

		return system_accent_text
	}

	// First, handle <system-color>s, since they do not strictly require a node.
	// https://www.w3.org/TR/css-color-4/#css-system-colors
	// https://www.w3.org/TR/css-color-4/#deprecated-system-colors
	match style_value.keyword() {
		.accentcolor {
			return color_resolution_context.accent_color or { SystemColor.accent_color(scheme) }
		}
		.buttonborder, .activeborder, .inactiveborder, .threeddarkshadow, .threedhighlight, .threedlightshadow, .threedshadow, .windowframe {
			return SystemColor.button_border(scheme)
		}
		.buttonface, .buttonhighlight, .buttonshadow, .threedface {
			return SystemColor.button_face(scheme)
		}
		.buttontext {
			return SystemColor.button_text(scheme)
		}
		.canvas, .appworkspace, .background, .inactivecaption, .infobackground, .menu, .scrollbar, .window {
			return SystemColor.canvas(scheme)
		}
		.canvastext, .activecaption, .captiontext, .infotext, .menutext, .windowtext {
			return SystemColor.canvas_text(scheme)
		}
		.field {
			return SystemColor.field(scheme)
		}
		.fieldtext {
			return SystemColor.field_text(scheme)
		}
		.graytext, .inactivecaptiontext {
			return SystemColor.gray_text(scheme)
		}
		.highlight {
			return SystemColor.highlight(scheme)
		}
		.highlighttext {
			return SystemColor.highlight_text(scheme)
		}
		.activetext {
			return SystemColor.active_text(scheme)
		}
		.linktext, .libweb_link, .libweb_palette_link {
			return SystemColor.link_text(scheme)
		}
		.mark {
			return SystemColor.mark(scheme)
		}
		.marktext {
			return SystemColor.mark_text(scheme)
		}
		.selecteditem {
			return SystemColor.selected_item(scheme)
		}
		.selecteditemtext {
			return SystemColor.selected_item_text(scheme)
		}
		.visitedtext, .libweb_palette_visited_link {
			return SystemColor.visited_text(scheme)
		}
		.libweb_buttonfacedisabled {
			return SystemColor.button_face(scheme).with_alpha(128)
		}
		.libweb_buttonfacehover {
			return SystemColor.button_face(scheme).darkened(0.8)
		}
		else {}
	}

	// Boundary: The remaining -libweb-palette-* colors resolve through the
	// document/page palette. ColorResolutionContext does not carry a Document
	// yet, so those follow the C++ no-document fallback.
	if style_value.has_color() {
		return Color.black()
	}
	return none
}

pub fn (style_value KeywordStyleValue) absolutized(context ComputationContext) StyleValue {
	_ = context
	if !style_value.has_color() {
		return StyleValue(style_value)
	}

	// The currentcolor keyword computes to itself.
	// https://drafts.csswg.org/css-color-4/#resolving-other-colors
	if style_value.keyword() == .currentcolor {
		return StyleValue(style_value)
	}

	resolved_color := style_value.to_color(ColorResolutionContext{
		color_scheme: context.color_scheme
	}) or { return StyleValue(style_value) }
	return StyleValue(ColorStyleValue.create(resolved_color))
}

pub fn (style_value KeywordStyleValue) tokenize() []ComponentValue {
	keyword_string := string_from_keyword(style_value.keyword_)
	return [
		ComponentValue.from_token(Token.create_ident(keyword_string, keyword_string)),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-ident
pub fn (style_value KeywordStyleValue) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	// 1. Return a new CSSKeywordValue with its value internal slot set to the serialization of ident.
	return CSSStyleValue.from_keyword(CSSKeywordValue.create(string_from_keyword(style_value.keyword_)))
}

pub fn (style_value KeywordStyleValue) properties_equal(other KeywordStyleValue) bool {
	return style_value.keyword_ == other.keyword_
}

// --- LengthStyleValue ---
pub struct LengthStyleValue {
pub mut:
	length_ Length
}

pub fn LengthStyleValue.create(length Length) LengthStyleValue {
	return LengthStyleValue{
		length_: length
	}
}

pub fn (style_value LengthStyleValue) length() Length {
	return style_value.length_
}

pub fn (style_value LengthStyleValue) raw_value() f64 {
	return style_value.length_.raw_value()
}

pub fn (style_value LengthStyleValue) unit_name() string {
	return style_value.length_.unit_name()
}

pub fn (style_value LengthStyleValue) serialize(mode SerializationMode) string {
	return style_value.length_.serialize(mode)
}

pub fn (style_value LengthStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value LengthStyleValue) absolutized(computation_context ComputationContext) LengthStyleValue {
	if length := style_value.length_.absolutize(computation_context.length_resolution_context) {
		return LengthStyleValue.create(length)
	}
	return style_value
}

// --- NumberStyleValue ---
pub struct NumberStyleValue {
pub mut:
	value_ f64
}

pub fn NumberStyleValue.create(value f64) NumberStyleValue {
	return NumberStyleValue{
		value_: value
	}
}

pub fn (style_value NumberStyleValue) number() f64 {
	return style_value.value_
}

pub fn (style_value NumberStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_a_number(style_value.value_)
}

pub fn (style_value NumberStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value NumberStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.number, style_value.value_), style_value.serialize(.normal))),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value NumberStyleValue) reify(associated_property string) CSSStyleValue {
	// NB: Step 1 does not apply here.
	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	if style_value.value_ == 0 {
		// NB: Determine whether the associated property expects 0 to be a <length>.
		// FIXME: Do this for registered custom properties.
		if property_id := property_id_from_string(associated_property) {
			if property_accepts_type(property_id, .length) {
				return CSSStyleValue.from_numeric(CSSUnitValue.create(0, 'px'))
			}
		}
	}

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(style_value.value_, 'number'))
}

// --- RatioStyleValue ---
pub struct RatioStyleValue {
pub mut:
	ratio_ Ratio
}

pub fn RatioStyleValue.create(ratio Ratio) RatioStyleValue {
	return RatioStyleValue{
		ratio_: ratio
	}
}

pub fn (style_value RatioStyleValue) ratio() Ratio {
	return style_value.ratio_
}

pub fn (style_value RatioStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.ratio_.to_string()
}

pub fn (style_value RatioStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.number, style_value.ratio_.numerator()), serialize_a_number(style_value.ratio_.numerator()))),
		ComponentValue.from_token(Token.create_whitespace(' ')),
		ComponentValue.from_token(Token.create_delim(u32(`/`), '/')),
		ComponentValue.from_token(Token.create_whitespace(' ')),
		ComponentValue.from_token(Token.create_number(Number.with_type(.number, style_value.ratio_.denominator()), serialize_a_number(style_value.ratio_.denominator()))),
	]
}

// --- IntegerStyleValue ---
pub struct IntegerStyleValue {
pub mut:
	value_ i64
}

pub fn IntegerStyleValue.create(value i64) IntegerStyleValue {
	return IntegerStyleValue{
		value_: value
	}
}

pub fn (style_value IntegerStyleValue) integer() i64 {
	return style_value.value_
}

pub fn (style_value IntegerStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return '${style_value.value_}'
}

pub fn (style_value IntegerStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value IntegerStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.integer, f64(style_value.value_)), style_value.serialize(.normal))),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value IntegerStyleValue) reify(associated_property string) CSSStyleValue {
	// NB: Step 1 does not apply here.
	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	if style_value.value_ == 0 {
		// NB: Determine whether the associated property expects 0 to be a <length>.
		// FIXME: Do this for registered custom properties.
		if property_id := property_id_from_string(associated_property) {
			if property_accepts_type(property_id, .length) {
				return CSSStyleValue.from_numeric(CSSUnitValue.create(0, 'px'))
			}
		}
	}

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(f64(style_value.value_), 'number'))
}

// --- AngleStyleValue ---
pub struct AngleStyleValue {
pub mut:
	angle_ Angle
}

pub fn AngleStyleValue.create(angle Angle) AngleStyleValue {
	return AngleStyleValue{
		angle_: angle
	}
}

pub fn (style_value AngleStyleValue) angle() Angle {
	return style_value.angle_
}

pub fn (style_value AngleStyleValue) raw_value() f64 {
	return style_value.angle_.raw_value()
}

pub fn (style_value AngleStyleValue) unit_name() string {
	return style_value.angle_.unit_name()
}

pub fn (style_value AngleStyleValue) serialize(mode SerializationMode) string {
	return style_value.angle_.serialize(mode)
}

pub fn (style_value AngleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

// --- PercentageStyleValue ---
pub struct PercentageStyleValue {
pub mut:
	percentage_ Percentage
}

pub fn PercentageStyleValue.create(percentage Percentage) PercentageStyleValue {
	return PercentageStyleValue{
		percentage_: percentage
	}
}

pub fn (style_value PercentageStyleValue) percentage() Percentage {
	return style_value.percentage_
}

pub fn (style_value PercentageStyleValue) raw_value() f64 {
	return style_value.percentage_.value()
}

pub fn (style_value PercentageStyleValue) unit_name() string {
	return 'percent'
}

pub fn (style_value PercentageStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.percentage_.to_string()
}

pub fn (style_value PercentageStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

// --- Additional dimension style value wrappers needed by CSSUnitValue ---
pub struct FlexStyleValue {
pub mut:
	flex_ Flex
}

pub fn FlexStyleValue.create(flex Flex) FlexStyleValue {
	return FlexStyleValue{
		flex_: flex
	}
}

pub fn (style_value FlexStyleValue) flex() Flex {
	return style_value.flex_
}

pub fn (style_value FlexStyleValue) raw_value() f64 {
	return style_value.flex_.raw_value()
}

pub fn (style_value FlexStyleValue) unit_name() string {
	return style_value.flex_.unit_name()
}

pub fn (style_value FlexStyleValue) serialize(mode SerializationMode) string {
	return style_value.flex_.serialize(mode)
}

pub struct FrequencyStyleValue {
pub mut:
	frequency_ Frequency
}

pub fn FrequencyStyleValue.create(frequency Frequency) FrequencyStyleValue {
	return FrequencyStyleValue{
		frequency_: frequency
	}
}

pub fn (style_value FrequencyStyleValue) frequency() Frequency {
	return style_value.frequency_
}

pub fn (style_value FrequencyStyleValue) raw_value() f64 {
	return style_value.frequency_.raw_value()
}

pub fn (style_value FrequencyStyleValue) unit_name() string {
	return style_value.frequency_.unit_name()
}

pub fn (style_value FrequencyStyleValue) serialize(mode SerializationMode) string {
	return style_value.frequency_.serialize(mode)
}

pub struct ResolutionStyleValue {
pub mut:
	resolution_ Resolution
}

pub fn ResolutionStyleValue.create(resolution Resolution) ResolutionStyleValue {
	return ResolutionStyleValue{
		resolution_: resolution
	}
}

pub fn (style_value ResolutionStyleValue) resolution() Resolution {
	return style_value.resolution_
}

pub fn (style_value ResolutionStyleValue) raw_value() f64 {
	return style_value.resolution_.raw_value()
}

pub fn (style_value ResolutionStyleValue) unit_name() string {
	return style_value.resolution_.unit_name()
}

pub fn (style_value ResolutionStyleValue) serialize(mode SerializationMode) string {
	return style_value.resolution_.serialize(mode)
}

pub struct TimeStyleValue {
pub mut:
	time_ Time
}

pub fn TimeStyleValue.create(time Time) TimeStyleValue {
	return TimeStyleValue{
		time_: time
	}
}

pub fn (style_value TimeStyleValue) time() Time {
	return style_value.time_
}

pub fn (style_value TimeStyleValue) raw_value() f64 {
	return style_value.time_.raw_value()
}

pub fn (style_value TimeStyleValue) unit_name() string {
	return style_value.time_.unit_name()
}

pub fn (style_value TimeStyleValue) serialize(mode SerializationMode) string {
	return style_value.time_.serialize(mode)
}

// --- Core scalar and substitution StyleValue subclasses ---
pub struct ColorStyleValue {
pub mut:
	color_ Color
}

pub fn ColorStyleValue.create(color Color) ColorStyleValue {
	return ColorStyleValue{
		color_: color
	}
}

pub fn (style_value ColorStyleValue) color() Color {
	return style_value.color_
}

pub fn (style_value ColorStyleValue) color_type() ConcreteColorType {
	return .rgb
}

pub fn (style_value ColorStyleValue) color_syntax() ColorSyntax {
	return .legacy
}

pub fn (style_value ColorStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.color_.serialize()
}

pub struct CustomIdentStyleValue {
pub mut:
	custom_ident_ string
}

pub fn CustomIdentStyleValue.create(custom_ident string) CustomIdentStyleValue {
	return CustomIdentStyleValue{
		custom_ident_: custom_ident
	}
}

pub fn (style_value CustomIdentStyleValue) custom_ident() string {
	return style_value.custom_ident_
}

pub fn (style_value CustomIdentStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_an_identifier(style_value.custom_ident_)
}

pub fn (style_value CustomIdentStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_ident(style_value.custom_ident_, style_value.custom_ident_)),
	]
}

pub fn (style_value CustomIdentStyleValue) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	return CSSStyleValue.from_keyword(CSSKeywordValue.create(style_value.custom_ident_))
}

pub struct StringStyleValue {
pub mut:
	string_value_ string
}

pub fn StringStyleValue.create(value string) StringStyleValue {
	return StringStyleValue{
		string_value_: value
	}
}

pub fn (style_value StringStyleValue) string_value() string {
	return style_value.string_value_
}

pub fn (style_value StringStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_a_string(style_value.string_value_)
}

pub fn (style_value StringStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_string(style_value.string_value_, style_value.serialize(.normal))),
	]
}

pub struct UnresolvedStyleValue {
pub mut:
	tokens                          []ComponentValue
	substitution_functions_presence SubstitutionFunctionsPresence
	// A custom property's declared value is kept verbatim: `set decl's original
	// text to the segment of the original source text string corresponding to
	// the tokens of decl's value`. Serializing it re-emits that text, so its
	// white space, comments and quote style survive the round trip.
	original_source_text ?string
}

pub fn UnresolvedStyleValue.create(tokens []ComponentValue) UnresolvedStyleValue {
	return UnresolvedStyleValue.create_with_original_source_text(tokens, none)
}

pub fn UnresolvedStyleValue.create_with_original_source_text(tokens []ComponentValue, original_source_text ?string) UnresolvedStyleValue {
	mut presence := SubstitutionFunctionsPresence{}
	for token in tokens {
		if token.is_function() {
			token.function().contains_arbitrary_substitution_function(mut presence)
		}
		if token.is_block() {
			token.block().contains_arbitrary_substitution_function(mut presence)
		}
	}
	return UnresolvedStyleValue{
		tokens: tokens
		substitution_functions_presence: presence
		original_source_text: original_source_text
	}
}

pub fn (style_value UnresolvedStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	if original_source_text := style_value.original_source_text {
		return original_source_text
	}
	return serialize_a_series_of_component_values(style_value.tokens).trim_space()
}

pub fn (style_value UnresolvedStyleValue) equals(other UnresolvedStyleValue) bool {
	return style_value.tokens == other.tokens
}

// https://drafts.csswg.org/css-variables/#guaranteed-invalid-value
pub struct GuaranteedInvalidStyleValue {}

pub fn GuaranteedInvalidStyleValue.create() GuaranteedInvalidStyleValue {
	return GuaranteedInvalidStyleValue{}
}

pub fn (style_value GuaranteedInvalidStyleValue) serialize(mode SerializationMode) string {
	_ = style_value
	_ = mode
	return ''
}

pub fn (style_value GuaranteedInvalidStyleValue) tokenize() []ComponentValue {
	_ = style_value
	return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
}

pub struct URLStyleValue {
pub mut:
	url_ URL
	// Optional SVG paint fallback (0 or 1 element), e.g. the `red` in `fill: url(#g) red`.
	paint_fallback_ []StyleValue
}

pub fn URLStyleValue.create(url URL) URLStyleValue {
	return URLStyleValue{
		url_: url
	}
}

pub fn URLStyleValue.create_with_paint_fallback(url URL, paint_fallback StyleValue) URLStyleValue {
	return URLStyleValue{
		url_: url
		paint_fallback_: [paint_fallback]
	}
}

pub fn (style_value URLStyleValue) url() URL {
	return style_value.url_
}

pub fn (style_value URLStyleValue) paint_fallback() ?StyleValue {
	if style_value.paint_fallback_.len == 1 {
		return style_value.paint_fallback_[0]
	}
	return none
}

pub fn (style_value URLStyleValue) serialize(mode SerializationMode) string {
	mut serialized := style_value.url_.to_string()
	if style_value.paint_fallback_.len == 1 {
		serialized += ' ${style_value.paint_fallback_[0].serialize(mode)}'
	}
	return serialized
}

// https://drafts.csswg.org/css-values-5/#pending-substitution-value
pub struct PendingSubstitutionStyleValue {
pub mut:
	original_shorthand_value StyleValue
}

pub fn PendingSubstitutionStyleValue.create(original_shorthand_value StyleValue) PendingSubstitutionStyleValue {
	return PendingSubstitutionStyleValue{
		original_shorthand_value: original_shorthand_value
	}
}

pub fn (style_value PendingSubstitutionStyleValue) serialize(mode SerializationMode) string {
	_ = style_value
	_ = mode
	return ''
}

pub fn (style_value PendingSubstitutionStyleValue) tokenize() []ComponentValue {
	_ = style_value
	// Not sure what to do here, but this isn't valid so returning GIV seems the most correct.
	return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
}

pub fn (style_value PendingSubstitutionStyleValue) original_shorthand_value_ref() StyleValue {
	return style_value.original_shorthand_value
}

pub fn (c CalculatedStyleValue) resolves_to_number() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_number(c.calculation_context.percentages_resolve_as)
	}
	return true
}

pub fn (c CalculatedStyleValue) resolves_to_percentage() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_percentage()
	}
	return c.serialization.trim_space().ends_with('%)')
}

// --- CSSStyleValue ---
pub enum CSSStyleValueKind {
	style
	keyword
	numeric
	transform
	unparsed
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue
pub struct CSSStyleValue {
pub mut:
	kind_               CSSStyleValueKind
	associated_property ?string
	source_value_       ?StyleValue
	keyword_value_      ?CSSKeywordValue
	numeric_value_      ?CSSNumericValue
	transform_value_    ?CSSTransformValue
	unparsed_value_     ?&CSSUnparsedValue
}

pub fn CSSStyleValue.create(associated_property string, source_value StyleValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .style
		associated_property: associated_property
		source_value_: source_value
	}
}

pub fn CSSStyleValue.from_source(source_value StyleValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .style
		source_value_: source_value
	}
}

pub fn CSSStyleValue.from_keyword(value CSSKeywordValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .keyword
		keyword_value_: value
	}
}

pub fn CSSStyleValue.from_numeric(value CSSNumericValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .numeric
		numeric_value_: value
	}
}

pub fn CSSStyleValue.from_transform(value CSSTransformValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .transform
		transform_value_: value
	}
}

pub fn CSSStyleValue.from_unparsed(value &CSSUnparsedValue) CSSStyleValue {
	return CSSStyleValue{
		kind_: .unparsed
		unparsed_value_: value
	}
}

pub fn (value CSSStyleValue) source_value() ?StyleValue {
	return value.source_value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylevalue-parse
pub fn CSSStyleValue.parse(property string, css_text string) !CSSStyleValue {
	// The parse(property, cssText) method, when invoked, must parse a CSSStyleValue with property property, cssText
	// cssText, and parseMultiple set to false, and return the result.
	result := CSSStyleValue.parse_a_css_style_value(property, css_text, false)!
	return result[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylevalue-parseall
pub fn CSSStyleValue.parse_all(property string, css_text string) ![]CSSStyleValue {
	// The parseAll(property, cssText) method, when invoked, must parse a CSSStyleValue with property property, cssText
	// cssText, and parseMultiple set to true, and return the result.
	return CSSStyleValue.parse_a_css_style_value(property, css_text, true)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#parse-a-cssstylevalue
pub fn CSSStyleValue.parse_a_css_style_value(property_name string, css_text string, parse_multiple bool) ![]CSSStyleValue {
	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. Attempt to parse cssText according to property's grammar.
	//    If this fails, throw a TypeError.
	//    Otherwise, let whole value be the parsed result.
	mut parser := Parser.from_css_text(css_text)
	whole_value := if property.is_custom_property() {
		StyleValue(UnresolvedStyleValue.create(parser.component_values))
	} else {
		property_id := property.id() or {
			return error("'${property_name}' is not a valid CSS property")
		}
		parser.parse_css_value(property_id) or {
			return error("Failed to parse '${css_text}' as a value for '${property.name()}' property")
		}
	}

	// 4. Subdivide into iterations whole value, according to property, and let values be the result.
	values := whole_value.subdivide_into_iterations(property)

	// 5. For each value in values, replace it with the result of reifying value for property.
	mut reified_values := []CSSStyleValue{cap: values.len}
	for value in values {
		reified_values << value.reify(property.name())
	}

	// 6. If parseMultiple is false, return values[0]. Otherwise, return values.
	// FIXME: We need to somehow store the source css_text on the returned CSSStyleValue.
	//        https://github.com/w3c/css-houdini-drafts/issues/1156
	if !parse_multiple {
		if reified_values.len == 0 {
			return error("Failed to parse '${css_text}' as a value for '${property.name()}' property")
		}
		return [reified_values[0]]
	}
	return reified_values
}

// https://drafts.css-houdini.org/css-typed-om-1/#stylevalue-serialization
pub fn (value CSSStyleValue) to_string() !string {
	// FIXME: if the value was constructed from a USVString
	{
		// the serialization is the USVString from which the value was constructed.
	}
	// otherwise, if the value was constructed using an IDL constructor
	{
		// the serialization is specified in the sections below.
	}
	if source_value := value.source_value_ {
		return source_value.to_string()
	}
	if keyword_value := value.keyword_value_ {
		return keyword_value.to_string()
	}
	if numeric_value := value.numeric_value_ {
		return numeric_value.to_string()
	}
	if transform_value := value.transform_value_ {
		return transform_value.to_string()!
	}
	if unparsed_value := value.unparsed_value_ {
		return unparsed_value.to_string()!
	}
	{
		// the serialization is specified in section 6.7 Serialization from CSSOM Values below.
	}
	return ''
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value CSSStyleValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	_ = property
	_ = perform_type_check
	// If value is a direct CSSStyleValue,
	//     Return value's associated value.
	if source_value := value.source_value_ {
		return source_value
	}
	if keyword_value := value.keyword_value_ {
		return keyword_value.create_an_internal_representation(property, perform_type_check)!
	}
	if numeric_value := value.numeric_value_ {
		return numeric_value.create_an_internal_representation(property, perform_type_check)!
	}
	if transform_value := value.transform_value_ {
		return transform_value.create_an_internal_representation(property, perform_type_check)!
	}
	if unparsed_value := value.unparsed_value_ {
		return unparsed_value.create_an_internal_representation(property, perform_type_check)!
	}
	return error('Missing CSSStyleValue.create_an_internal_representation() overload')
}

// --- CSSKeywordValue ---
pub type CSSKeywordish = CSSKeywordValue | string

// https://drafts.css-houdini.org/css-typed-om-1/#csskeywordvalue
pub struct CSSKeywordValue {
pub mut:
	value_ string
}

pub fn CSSKeywordValue.create(value string) CSSKeywordValue {
	return CSSKeywordValue{
		value_: value
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csskeywordvalue-csskeywordvalue
pub fn CSSKeywordValue.construct_impl(value string) !CSSKeywordValue {
	// 1. If value is an empty string, throw a TypeError.
	if value.len == 0 {
		return error('Cannot create a CSSKeywordValue with an empty string as the value')
	}

	// 2. Otherwise, return a new CSSKeywordValue with its value internal slot set to value.
	return CSSKeywordValue.create(value)
}

pub fn (value CSSKeywordValue) value() string {
	return value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csskeywordvalue-value
pub fn (mut value CSSKeywordValue) set_value(new_value string) ! {
	// 1. If value is an empty string, throw a TypeError.
	if new_value.len == 0 {
		return error('Cannot set CSSKeywordValue.value to an empty string')
	}

	// 2. Otherwise, set this's value internal slot, to value.
	value.value_ = new_value
}

// https://drafts.css-houdini.org/css-typed-om-1/#keywordvalue-serialization
pub fn (value CSSKeywordValue) serialize() string {
	// To serialize a CSSKeywordValue this:
	// 1. Return this's value internal slot.
	// AD-HOC: Serialize it as an identifier. Spec issue: https://github.com/w3c/csswg-drafts/issues/12545
	return serialize_an_identifier(value.value_)
}

pub fn (value CSSKeywordValue) to_string() string {
	return value.serialize()
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value CSSKeywordValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	matches_grammar := fn [value, property] () bool {
		// https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue-match-a-grammar
		// A CSSKeywordValue matches an <ident> specified in a grammar if its value internal slot matches the
		// identifier.
		// If case-folding rules are in effect normally for that <ident> (such as Auto matching the keyword auto
		// specified in the grammar for width), they apply to this comparison as well.
		if is_css_wide_keyword_string(value.value_) {
			return true
		}
		if property.is_custom_property() {
			// FIXME: If this is a registered custom property, check if that allows the keyword.
			return true
		}
		property_id := property.id() or { return false }
		keyword_from_string(value.value_) or { return false }
		return property_accepts_keyword_string(property_id, value.value_)
	}()
	if perform_type_check == .yes && !matches_grammar {
		return error("Property '${property.name()}' does not accept the keyword '${value.value_}'")
	}

	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	// NB: Non-applicable.

	//     Return the value.
	if keyword := keyword_from_string(value.value_) {
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	return StyleValue(CustomIdentStyleValue.create(value.value_))
}

// https://drafts.css-houdini.org/css-typed-om-1/#rectify-a-keywordish-value
pub fn rectify_a_keywordish_value(keywordish CSSKeywordish) CSSKeywordValue {
	// To rectify a keywordish value val, perform the following steps:
	return match keywordish {
		// 1. If val is a CSSKeywordValue, return val.
		CSSKeywordValue { keywordish }
		// 2. If val is a DOMString, return a new CSSKeywordValue with its value internal slot set to val.
		string { CSSKeywordValue.create(keywordish) }
	}
}

// --- CSSNumericValue ---
pub struct CSSNumericType {
pub mut:
	length       ?int
	angle        ?int
	time         ?int
	frequency    ?int
	resolution   ?int
	flex         ?int
	percent      ?int
	percent_hint ?NumericBaseType
}

pub struct SumValueItem {
pub mut:
	value    f64
	unit_map map[string]int
}

pub type SumValue = []SumValueItem

pub struct CSSNumericSerializationParams {
pub mut:
	minimum   ?f64
	maximum   ?f64
	nested    bool
	parenless bool
}

pub type CSSNumericValue = CSSUnitValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum

pub type CSSNumberish = CSSUnitValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum
	| f64

pub fn (value CSSNumericValue) type_() NumericType {
	return match value {
		CSSUnitValue { value.type_ }
		CSSMathSum { value.type_ }
		CSSMathProduct { value.type_ }
		CSSMathNegate { value.type_ }
		CSSMathInvert { value.type_ }
		CSSMathMin { value.type_ }
		CSSMathMax { value.type_ }
		CSSMathClamp { value.type_ }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-add
pub fn (value CSSNumericValue) add(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathSum object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.

	// NB: We reorder the steps a little to avoid the awkward prepending.
	mut values := []CSSNumericValue{}
	if value is CSSMathSum {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the sum of the value internal slots of
	//    the items in values. This addition must be done "left to right".
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return a + b
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to add numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathSum object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathSum.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-sub
pub fn (value CSSNumericValue) sub(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item, then negating the value.
	mut values := []CSSNumberish{}
	for item in initial_values {
		values << rectify_a_numberish_value(item).negate()
	}

	// 2. Return the result of calling the add() internal algorithm with this and values.
	return value.add(values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssmath-negate-a-cssnumericvalue
pub fn (value CSSNumericValue) negate() CSSNumberish {
	// 1. If this is a CSSMathNegate object, return this's value internal slot.
	if value is CSSMathNegate {
		return css_numberish_from_numeric_value(value.value())
	}

	// 2. If this is a CSSUnitValue object, return a new CSSUnitValue with the same unit internal slot as this, and a
	//    value internal slot set to the negation of this's.
	value_to_negate := value
	if value_to_negate is CSSUnitValue {
		return CSSNumberish(CSSUnitValue.create(-value_to_negate.value(), value_to_negate.unit()))
	}

	// 3. Otherwise, return a new CSSMathNegate object whose value internal slot is set to this.
	return CSSNumberish(CSSMathNegate.create(value.type_(), value))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-mul
pub fn (value CSSNumericValue) mul(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathProduct object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.

	// NB: We reorder the steps a little to avoid the awkward prepending.
	mut values := []CSSNumericValue{}
	if value is CSSMathProduct {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues with unit internal slot set to "number", return a new
	//    CSSUnitValue whose unit internal slot is set to "number", and value internal slot is set to the product of the
	//    value internal slots of the items in values.
	// 4. If all of the items in values are CSSUnitValues with unit internal slot set to "number" except one which is
	//    set to unit, return a new CSSUnitValue whose unit internal slot is set to unit, and value internal slot is set
	//    to the product of the value internal slots of the items in values.
	if all_values_are_css_unit_values(values) {
		mut multiple_units_found := false
		mut non_number_unit_index := ?int(none)
		for i, item in values {
			unit_value := item as CSSUnitValue
			unit := unit_value.unit()
			if unit == 'number' {
				continue
			}
			if non_number_unit_index != none {
				multiple_units_found = true
				break
			}
			non_number_unit_index = i
		}
		if !multiple_units_found {
			mut product := 1.0
			for item in values {
				product *= (item as CSSUnitValue).value()
			}
			unit := if index := non_number_unit_index {
				(values[index] as CSSUnitValue).unit()
			} else {
				'number'
			}
			return CSSNumericValue(CSSUnitValue.create(product, unit))
		}
	}

	// 5. Let type be the result of multiplying the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.multiplied_by(values[i].type_()) or {
			return error('Unable to multiply numeric values with inconsistent types')
		}
	}

	// 6. Return a new CSSMathProduct object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathProduct.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-div
pub fn (value CSSNumericValue) div(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item, then inverting the value.
	mut values := []CSSNumberish{}
	for item in initial_values {
		values << rectify_a_numberish_value(item).invert()!
	}

	// 2. Return the result of calling the mul() internal algorithm with this and values.
	return value.mul(values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssmath-invert-a-cssnumericvalue
pub fn (value CSSNumericValue) invert() !CSSNumberish {
	// 1. If this is a CSSMathInvert object, return this's value internal slot.
	if value is CSSMathInvert {
		return css_numberish_from_numeric_value(value.value())
	}

	// 2. If this is a CSSUnitValue object with unit internal slot set to "number":
	value_to_invert := value
	if value_to_invert is CSSUnitValue {
		if value_to_invert.unit() == 'number' {
			// 1. If this's value internal slot is set to 0 or -0, throw a RangeError.
			if value_to_invert.value() == 0 {
				return error('Zero has no multiplicative inverse')
			}

			// 2. Else return a new CSSUnitValue with the unit internal slot set to "number", and a value internal slot set
			//    to 1 divided by this's CSSUnitValue/value internal slot.
			return CSSNumberish(CSSUnitValue.create(1.0 / value_to_invert.value(), 'number'))
		}
	}

	// 3. Otherwise, return a new CSSMathInvert object whose value internal slot is set to this.
	return CSSNumberish(CSSMathInvert.create(value.type_().inverted(), value))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-min
pub fn (value CSSNumericValue) min(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathMin object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.
	mut values := []CSSNumericValue{}
	if value is CSSMathMin {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the minimum of the value internal slots
	//    of the items in values.
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return math.min(a, b)
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to compare numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathMin object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathMin.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-max
pub fn (value CSSNumericValue) max(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathMax object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.
	mut values := []CSSNumericValue{}
	if value is CSSMathMax {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the maximum of the value internal slots
	//    of the items in values.
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return math.max(a, b)
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to compare numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathMax object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathMax.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-equals
pub fn (value CSSNumericValue) equals_for_bindings(values []CSSNumberish) bool {
	// The equals(...values) method, when called on a CSSNumericValue this, must perform the following steps:

	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. For each item in values, if the item is not an equal numeric value to this, return false.
	for item in values {
		rectified_value := rectify_a_numberish_value(item)
		if !value.is_equal_numeric_value(rectified_value) {
			return false
		}
	}

	// 3. Return true.
	return true
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-to
pub fn (value CSSNumericValue) to(unit string) !CSSUnitValue {
	// The to(unit) method converts an existing CSSNumericValue this into another one with the specified unit, if
	// possible. When called, it must perform the following steps:

	// 1. Let type be the result of creating a type from unit. If type is failure, throw a SyntaxError.
	if NumericType.create_from_unit(unit) == none {
		return error("Unrecognized unit '${unit}'")
	}

	// 2. Let sum be the result of creating a sum value from this. If sum is failure, throw a TypeError.
	sum := value.create_a_sum_value() or {
		return error("Unable to create a sum from input '${value.to_string()}'")
	}

	// 3. If sum has more than one item, throw a TypeError.
	//    Otherwise, let item be the result of creating a CSSUnitValue from the sole item in sum, then converting it to
	//    unit. If item is failure, throw a TypeError.
	if sum.len > 1 {
		return error('Sum contains more than one item')
	}
	item := CSSUnitValue.create_from_sum_value_item(sum[0]) or {
		return error("Unable to create CSSUnitValue from input '${value.to_string()}'")
	}

	converted_item := item.converted_to_unit(unit) or {
		return error("Unable to convert input '${value.to_string()}' to unit '${unit}'")
	}

	// 4. Return item.
	return converted_item
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-type
pub fn (value CSSNumericValue) type_for_bindings() CSSNumericType {
	// 1. Let result be a new CSSNumericType.
	mut result := CSSNumericType{}
	type_ := value.type_()

	// 2. For each baseType -> power in the type of this,
	if power := type_.length_ {
		if power != 0 {
			result.length = power
		}
	}
	if power := type_.angle_ {
		if power != 0 {
			result.angle = power
		}
	}
	if power := type_.time_ {
		if power != 0 {
			result.time = power
		}
	}
	if power := type_.frequency_ {
		if power != 0 {
			result.frequency = power
		}
	}
	if power := type_.resolution_ {
		if power != 0 {
			result.resolution = power
		}
	}
	if power := type_.flex_ {
		if power != 0 {
			result.flex = power
		}
	}
	if power := type_.percent_ {
		if power != 0 {
			result.percent = power
		}
	}

	// 3. If the percent hint of this is not null,
	if percent_hint := type_.percent_hint {
		// 1. Set result[percentHint] to the percent hint of this.
		result.percent_hint = percent_hint
	}

	// 4. Return result.
	return result
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssnumericvalue
pub fn (value CSSNumericValue) serialize(params CSSNumericSerializationParams) string {
	// To serialize a CSSNumericValue this, given an optional minimum, a numeric value, and optional maximum, a numeric value:
	// 1. If this is a CSSUnitValue, serialize a CSSUnitValue from this, passing minimum and maximum. Return the result.
	return match value {
		CSSUnitValue {
			value.serialize_unit_value(params.minimum, params.maximum)
		}

		// 2. Otherwise, serialize a CSSMathValue from this, and return the result.
		CSSMathSum {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathProduct {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathNegate {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathInvert {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathMin {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathMax {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathClamp {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
	}
}

pub fn (value CSSNumericValue) to_string() string {
	return value.serialize(CSSNumericSerializationParams{})
}

pub fn (value CSSNumericValue) is_equal_numeric_value(other CSSNumericValue) bool {
	return match value {
		CSSUnitValue {
			other_value := other
			if other_value is CSSUnitValue {
				value.unit() == other_value.unit() && value.value() == other_value.value()
			} else {
				false
			}
		}
		CSSMathSum {
			value.is_equal_numeric_value(other)
		}
		CSSMathProduct {
			value.is_equal_numeric_value(other)
		}
		CSSMathNegate {
			value.is_equal_numeric_value(other)
		}
		CSSMathInvert {
			value.is_equal_numeric_value(other)
		}
		CSSMathMin {
			value.is_equal_numeric_value(other)
		}
		CSSMathMax {
			value.is_equal_numeric_value(other)
		}
		CSSMathClamp {
			value.is_equal_numeric_value(other)
		}
	}
}

pub fn (value CSSNumericValue) create_a_sum_value() ?SumValue {
	return match value {
		CSSUnitValue { value.create_a_sum_value() }
		CSSMathSum { value.create_a_sum_value() }
		CSSMathProduct { value.create_a_sum_value() }
		CSSMathNegate { value.create_a_sum_value() }
		CSSMathInvert { value.create_a_sum_value() }
		CSSMathMin { value.create_a_sum_value() }
		CSSMathMax { value.create_a_sum_value() }
		CSSMathClamp { value.create_a_sum_value() }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-parse
pub fn CSSNumericValue.parse(css_text string) !CSSNumericValue {
	// The parse(cssText) method, when called, must perform the following steps:

	// 1. Parse a component value from cssText and let result be the result. If result is a syntax error, throw a
	//    SyntaxError and abort this algorithm.
	mut parser := RuleSelectorParser.create(ParsingParams{}, css_text, 'utf-8')
	result := parser.parse_as_component_value() or {
		return error('SyntaxError: Unable to parse input as a component value.')
	}

	// 2. If result is not a <number-token>, <percentage-token>, <dimension-token>, or a math function, throw a
	//    SyntaxError and abort this algorithm.
	if !(result.is(.number) || result.is(.percentage) || result.is(.dimension) || css_numeric_value_is_math_function(result)) {
		return error('SyntaxError: Input not a <number-token>, <percentage-token>, <dimension-token>, or a math function.')
	}

	// 3. If result is a <dimension-token> and creating a type from result's unit returns failure, throw a SyntaxError
	//    and abort this algorithm.
	if result.is(.dimension) {
		if NumericType.create_from_unit(result.token().dimension_unit()) == none {
			return error('SyntaxError: Input is <dimension> with an unrecognized unit.')
		}
	}

	// 4. Reify a numeric value result, and return the result.
	return css_numeric_value_reify_component_value(result)!
}

fn css_numeric_value_is_math_function(component_value ComponentValue) bool {
	if !component_value.is_function() {
		return false
	}

	return match to_ascii_lowercase(component_value.function().name) {
		'abs', 'acos', 'asin', 'atan', 'atan2', 'clamp', 'calc', 'cos', 'exp', 'hypot', 'log', 'max', 'min', 'mod', 'pow', 'random', 'rem', 'round', 'sign', 'sin', 'sqrt', 'tan' {
			true
		}
		else {
			false
		}
	}
}

fn css_numeric_value_reify_component_value(numeric_value ComponentValue) !CSSNumericValue {
	// To reify a numeric value num:
	// 1. If num is a math function, reify a math expression from num and return the result.
	if numeric_value.is_function() {
		return css_numeric_value_reify_math_function(numeric_value)!
	}

	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	// FIXME: What does this mean? We just have a component value, it doesn't have any knowledge about whether 0 should
	//        be interpreted as a dimension.

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	// NB: The computed value part is irrelevant here, I think.
	if numeric_value.is(.number) {
		return CSSNumericValue(CSSUnitValue.create(numeric_value.token().number_value(), 'number'))
	}
	if numeric_value.is(.percentage) {
		return CSSNumericValue(CSSUnitValue.create(numeric_value.token().percentage(), 'percent'))
	}
	if !numeric_value.is(.dimension) {
		panic('VERIFY_NOT_REACHED')
	}
	return CSSNumericValue(CSSUnitValue.create(numeric_value.token().dimension_value(), numeric_value.token().dimension_unit()))
}

fn reify_children(children []CalcNode) ![]CSSNumericValue {
	mut reified := []CSSNumericValue{cap: children.len}
	for child in children {
		reified << reify_calc_node(child)!
	}
	return reified
}

// CalculationNode::reify(), translated for every node represented by CSS Typed OM.
// Functions without a corresponding CSSMath interface deliberately fail, matching the
// C++ fallback from CalculatedStyleValue::reify() to a plain CSSStyleValue.
fn reify_calc_node(node CalcNode) !CSSNumericValue {
	match node {
		CalcNumeric {
			unit := match node.kind {
				.number { 'number' }
				.percentage { 'percent' }
				else { node.unit }
			}
			return CSSNumericValue(CSSUnitValue.create(node.value, unit))
		}
		CalcSum {
			type_ := CalcNode(node).numeric_type() or {
				return error('Unable to reify this math function.')
			}
			return CSSNumericValue(CSSMathSum.create(type_, CSSNumericArray.create(reify_children(node.children)!)))
		}
		CalcProduct {
			type_ := CalcNode(node).numeric_type() or {
				return error('Unable to reify this math function.')
			}
			return CSSNumericValue(CSSMathProduct.create(type_, CSSNumericArray.create(reify_children(node.children)!)))
		}
		CalcNegate {
			type_ := CalcNode(node).numeric_type() or {
				return error('Unable to reify this math function.')
			}
			return CSSNumericValue(CSSMathNegate.create(type_, reify_calc_node(node.children[0])!))
		}
		CalcInvert {
			type_ := CalcNode(node).numeric_type() or {
				return error('Unable to reify this math function.')
			}
			return CSSNumericValue(CSSMathInvert.create(type_, reify_calc_node(node.children[0])!))
		}
		CalcFunction {
			type_ := CalcNode(node).numeric_type() or {
				return error('Unable to reify this math function.')
			}
			children := reify_children(node.children)!
			return match node.name {
				'min' {
					CSSNumericValue(CSSMathMin.create(type_, CSSNumericArray.create(children)))
				}
				'max' {
					CSSNumericValue(CSSMathMax.create(type_, CSSNumericArray.create(children)))
				}
				'clamp' {
					CSSNumericValue(CSSMathClamp.create(type_, children[0], children[1], children[2]))
				}
				else {
					return error('Unable to reify this math function.')
				}
			}
		}
		CalcRandom, CalcTreeCounting {
			return error('Unable to reify this math function.')
		}
	}
}

fn css_numeric_value_reify_math_function(numeric_value ComponentValue) !CSSNumericValue {
	mut tokens := ComponentValueStream.new([numeric_value])
	calculated := parse_calculated_value(mut tokens) or {
		return error('SyntaxError: Unable to parse input as a calculation tree.')
	}
	if calculated !is CalculatedStyleValue || calculated.node.len != 1 {
		return error('SyntaxError: Unable to parse input as a calculation tree.')
	}
	return reify_calc_node(calculated.node[0]) or {
		return error('SyntaxError: Unable to reify this math function.')
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#rectify-a-numberish-value
pub fn rectify_a_numberish_value(numberish CSSNumberish) CSSNumericValue {
	// To rectify a numberish value num, optionally to a given unit unit (defaulting to "number"), perform the following steps:
	return rectify_a_numberish_value_with_unit(numberish, none)
}

pub fn rectify_a_numberish_value_with_unit(numberish CSSNumberish, unit ?string) CSSNumericValue {
	// To rectify a numberish value num, optionally to a given unit unit (defaulting to "number"), perform the following steps:
	return match numberish {
		// 1. If num is a CSSNumericValue, return num.
		CSSUnitValue { CSSNumericValue(numberish) }
		CSSMathSum { CSSNumericValue(numberish) }
		CSSMathProduct { CSSNumericValue(numberish) }
		CSSMathNegate { CSSNumericValue(numberish) }
		CSSMathInvert { CSSNumericValue(numberish) }
		CSSMathMin { CSSNumericValue(numberish) }
		CSSMathMax { CSSNumericValue(numberish) }
		CSSMathClamp { CSSNumericValue(numberish) }
		// 2. If num is a double, return a new CSSUnitValue with its value internal slot set to num and its unit
		//    internal slot set to unit.
		f64 { CSSNumericValue(CSSUnitValue.create(numberish, unit or { 'number' })) }
	}
}

fn all_values_are_css_unit_values(values []CSSNumericValue) bool {
	for value in values {
		if value !is CSSUnitValue {
			return false
		}
	}
	return true
}

fn all_values_are_css_unit_values_with_the_same_unit(values []CSSNumericValue) bool {
	if values.len == 0 {
		return false
	}
	first_value := values[0]
	if first_value !is CSSUnitValue {
		return false
	}
	first := first_value as CSSUnitValue
	for value in values {
		if value !is CSSUnitValue {
			return false
		}
		unit_value := value as CSSUnitValue
		if unit_value.unit() != first.unit() {
			return false
		}
	}
	return true
}

fn apply_math_operation_on_css_unit_values(values []CSSNumericValue, operation fn (f64, f64) f64) CSSUnitValue {
	first_unit_value := values[0] as CSSUnitValue
	unit := first_unit_value.unit()

	mut result := first_unit_value.value()
	for i := 1; i < values.len; i++ {
		result = operation(result, (values[i] as CSSUnitValue).value())
	}
	return CSSUnitValue.create(result, unit)
}

fn numeric_values_join(values []CSSNumericValue, separator string) string {
	mut parts := []string{}
	for value in values {
		parts << value.to_string()
	}
	return parts.join(separator)
}

// --- CSSUnitValue ---
pub type NumericPrimitiveValue = Angle
	| Flex
	| Frequency
	| Length
	| Number
	| Percentage
	| Resolution
	| Time

// https://drafts.css-houdini.org/css-typed-om-1/#cssunitvalue
pub struct CSSUnitValue {
pub mut:
	value_ f64
	unit_  string
	type_  NumericType
}

pub fn CSSUnitValue.create(value f64, unit string) CSSUnitValue {
	// The type of a CSSUnitValue is the result of creating a type from its unit internal slot.
	// https://drafts.css-houdini.org/css-typed-om-1/#type-of-a-cssunitvalue
	numeric_type := NumericType.create_from_unit(unit) or { NumericType.new() }
	return CSSUnitValue{
		value_: value
		// AD-HOC: WPT expects the unit to be lowercase but this does not seem to be specified anywhere.
		unit_: to_ascii_lowercase(unit)
		type_: numeric_type
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-cssunitvalue-from-a-sum-value-item
pub fn CSSUnitValue.create_from_sum_value_item(item SumValueItem) ?CSSUnitValue {
	// 1. If item has more than one entry in its unit map, return failure.
	if item.unit_map.len > 1 {
		return none
	}

	// 2. If item has no entries in its unit map, return a new CSSUnitValue whose unit internal slot is set to
	//    "number", and whose value internal slot is set to item's value.
	if item.unit_map.len == 0 {
		return CSSUnitValue.create(item.value, 'number')
	}

	// 3. Otherwise, item has a single entry in its unit map. If that entry's value is anything other than 1, return
	//    failure.
	for unit, power in item.unit_map {
		if power != 1 {
			return none
		}

		// 4. Otherwise, return a new CSSUnitValue whose unit internal slot is set to that entry's key, and whose value
		//    internal slot is set to item's value.
		return CSSUnitValue.create(item.value, unit)
	}
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunitvalue-cssunitvalue
pub fn CSSUnitValue.construct_impl(value f64, unit string) !CSSUnitValue {
	// 1. If creating a type from unit returns failure, throw a TypeError and abort this algorithm.
	numeric_type := NumericType.create_from_unit(unit) or {
		return error("Cannot create CSSUnitValue with unrecognized unit '${unit}'")
	}

	// 2. Return a new CSSUnitValue with its value internal slot set to value and its unit set to unit.
	return CSSUnitValue{
		value_: value
		unit_: to_ascii_lowercase(unit)
		type_: numeric_type
	}
}

pub fn (unit_value CSSUnitValue) value() f64 {
	return unit_value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunitvalue-value
pub fn (mut unit_value CSSUnitValue) set_value(value f64) {
	// AD-HOC: No definition: https://github.com/w3c/css-houdini-drafts/issues/1146
	unit_value.value_ = value
}

pub fn (unit_value CSSUnitValue) unit() string {
	return unit_value.unit_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssunitvalue
pub fn (unit_value CSSUnitValue) serialize_unit_value(minimum ?f64, maximum ?f64) string {
	// To serialize a CSSUnitValue this, with optional arguments minimum, a numeric value, and maximum, a numeric value:

	// 1. Let value and unit be this's value and unit internal slots.

	// 4. If minimum was passed and this is less than minimum, or if maximum was passed and this is greater than
	//    maximum, or either minimum and/or maximum were passed and the relative size of this and minimum/maximum cannot
	//    be determined with the available information at this time, prepend "calc(" to s, then append ")" to s.
	// NB: This step is done first to avoid prepending to the StringBuilder.
	// FIXME: "or either minimum and/or maximum were passed and the relative size of this and minimum/maximum cannot be determined with the available information at this time"
	needs_calc_wrapper := (minimum != none && unit_value.value_ < minimum or { 0 }) || (maximum != none && unit_value.value_ > maximum or {
		0
	})

	mut serialized := ''
	if needs_calc_wrapper {
		serialized += 'calc('
	}

	// 2. Set s to the result of serializing a <number> from value, per CSSOM section 6.7.2 Serializing CSS Values.
	serialized += serialize_a_number(unit_value.value_)

	// 3. If unit is:
	// -> "number"
	if unit_value.unit_ == 'number' {
		// Do nothing.
	} else if unit_value.unit_ == 'percent' {
		// -> "percent"
		// Append "%" to s.
		serialized += '%'
	} else {
		// -> anything else
		// Append unit to s.
		serialized += to_ascii_lowercase(unit_value.unit_)
	}

	if needs_calc_wrapper {
		serialized += ')'
	}

	// 5. Return s.
	return serialized
}

// https://drafts.css-houdini.org/css-typed-om-1/#convert-a-cssunitvalue
pub fn (unit_value CSSUnitValue) converted_to_unit(unit string) ?CSSUnitValue {
	// 1. Let old unit be the value of this's unit internal slot, and old value be the value of this's value internal
	//    slot.
	old_unit := unit_value.unit_
	old_value := unit_value.value_
	new_unit := to_ascii_lowercase(unit)

	// 2. If old unit and unit are not compatible units, return failure.
	mut ratio := 1.0
	// NB: If the units are identical, they are always compatible. That also covers cases of `number` and `percent`
	//     which are not actually units.
	if old_unit != new_unit {
		old_dimension_type := dimension_for_unit(old_unit) or { return none }
		new_dimension_type := dimension_for_unit(new_unit) or { return none }
		if old_dimension_type != new_dimension_type {
			return none
		}

		match new_dimension_type {
			.angle {
				from := string_to_angle_unit(old_unit) or { return none }
				to := string_to_angle_unit(new_unit) or { return none }
				if !angle_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_angle_units(from, to)
			}
			.flex {
				from := string_to_flex_unit(old_unit) or { return none }
				to := string_to_flex_unit(new_unit) or { return none }
				if !flex_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_flex_units(from, to)
			}
			.frequency {
				from := string_to_frequency_unit(old_unit) or { return none }
				to := string_to_frequency_unit(new_unit) or { return none }
				if !frequency_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_frequency_units(from, to)
			}
			.length {
				from := string_to_length_unit(old_unit) or { return none }
				to := string_to_length_unit(new_unit) or { return none }
				if !length_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_length_units(from, to)
			}
			.resolution {
				from := string_to_resolution_unit(old_unit) or { return none }
				to := string_to_resolution_unit(new_unit) or { return none }
				if !resolution_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_resolution_units(from, to)
			}
			.time {
				from := string_to_time_unit(old_unit) or { return none }
				to := string_to_time_unit(new_unit) or { return none }
				if !time_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_time_units(from, to)
			}
		}
	}

	// 3. Return a new CSSUnitValue whose unit internal slot is set to unit, and whose value internal slot is set to
	//    old value multiplied by the conversion ratio between old unit and unit.
	return CSSUnitValue.create(old_value * ratio, new_unit)
}

pub fn (unit_value CSSUnitValue) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 2 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	other_unit_value := other
	if other_unit_value !is CSSUnitValue {
		return false
	}
	other_value := other_unit_value as CSSUnitValue

	// 2. If value1 and value2 are both CSSUnitValues, return true if they have equal unit and value internal slots,
	//    or false otherwise.
	return unit_value.unit_ == other_value.unit_ && unit_value.value_ == other_value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (unit_value CSSUnitValue) create_a_sum_value() ?SumValue {
	// 1. Let unit be the value of this's unit internal slot, and value be the value of this's value internal slot.
	mut unit := unit_value.unit_
	mut value := unit_value.value_

	// 2. If unit is a member of a set of compatible units, and is not the set's canonical unit, multiply value
	//    by the conversion ratio between unit and the canonical unit, and change unit to the canonical unit.
	if dimension_type := dimension_for_unit(unit) {
		match dimension_type {
			.angle {
				angle_unit := string_to_angle_unit(unit) or { return none }
				canonical_unit := canonical_angle_unit()
				if angle_unit != canonical_unit && angle_units_are_compatible(angle_unit, canonical_unit) {
					value *= ratio_between_angle_units(angle_unit, canonical_unit)
					unit = angle_unit_name(canonical_unit)
				}
			}
			.flex {
				flex_unit := string_to_flex_unit(unit) or { return none }
				canonical_unit := canonical_flex_unit()
				if flex_unit != canonical_unit && flex_units_are_compatible(flex_unit, canonical_unit) {
					value *= ratio_between_flex_units(flex_unit, canonical_unit)
					unit = flex_unit_name(canonical_unit)
				}
			}
			.frequency {
				frequency_unit := string_to_frequency_unit(unit) or { return none }
				canonical_unit := canonical_frequency_unit()
				if frequency_unit != canonical_unit && frequency_units_are_compatible(frequency_unit, canonical_unit) {
					value *= ratio_between_frequency_units(frequency_unit, canonical_unit)
					unit = to_ascii_lowercase(frequency_unit_name(canonical_unit))
				}
			}
			.length {
				length_unit := string_to_length_unit(unit) or { return none }
				canonical_unit := canonical_length_unit()
				if length_unit != canonical_unit && length_units_are_compatible(length_unit, canonical_unit) {
					value *= ratio_between_length_units(length_unit, canonical_unit)
					unit = length_unit_name(canonical_unit)
				}
			}
			.resolution {
				resolution_unit := string_to_resolution_unit(unit) or { return none }
				canonical_unit := canonical_resolution_unit()
				if resolution_unit != canonical_unit && resolution_units_are_compatible(resolution_unit, canonical_unit) {
					value *= ratio_between_resolution_units(resolution_unit, canonical_unit)
					unit = resolution_unit_name(canonical_unit)
				}
			}
			.time {
				time_unit := string_to_time_unit(unit) or { return none }
				canonical_unit := canonical_time_unit()
				if time_unit != canonical_unit && time_units_are_compatible(time_unit, canonical_unit) {
					value *= ratio_between_time_units(time_unit, canonical_unit)
					unit = time_unit_name(canonical_unit)
				}
			}
		}
	}

	// 3. If unit is "number", return [(value, [])].
	if unit == 'number' {
		return [SumValueItem{
			value: value
			unit_map: map[string]int{}
		}]
	}

	// 4. Otherwise, return [(value, [unit -> 1])].
	return [SumValueItem{
		value: value
		unit_map: {
			unit: 1
		}
	}]
}

fn create_numeric_value(value f64, unit string) ?NumericPrimitiveValue {
	if unit == 'number' {
		return NumericPrimitiveValue(Number.with_type(.number, value))
	}

	if unit == 'percent' {
		return NumericPrimitiveValue(Percentage.new(value))
	}

	if dimension_type := dimension_for_unit(unit) {
		match dimension_type {
			.angle {
				return NumericPrimitiveValue(Angle.new(value, string_to_angle_unit(unit) or {
					return none
				}))
			}
			.flex {
				return NumericPrimitiveValue(Flex.new(value, string_to_flex_unit(unit) or {
					return none
				}))
			}
			.frequency {
				return NumericPrimitiveValue(Frequency.new(value, string_to_frequency_unit(unit) or {
					return none
				}))
			}
			.length {
				return NumericPrimitiveValue(Length.new(value, string_to_length_unit(unit) or {
					return none
				}))
			}
			.resolution {
				return NumericPrimitiveValue(Resolution.new(value, string_to_resolution_unit(unit) or {
					return none
				}))
			}
			.time {
				return NumericPrimitiveValue(Time.new(value, string_to_time_unit(unit) or {
					return none
				}))
			}
		}
	}

	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (unit_value CSSUnitValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	//
	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	//
	//     Return the value.

	// NB: We store all custom properties as UnresolvedStyleValue, so we always need to create one here.
	if perform_type_check == .yes && property.is_custom_property() {
		token := if unit_value.unit_ == 'number' {
			component_value_from_text(serialize_a_number(unit_value.value_))
		} else if unit_value.unit_ == 'percent' {
			component_value_from_text('${serialize_a_number(unit_value.value_)}%')
		} else {
			component_value_from_text('${serialize_a_number(unit_value.value_)}${unit_value.unit_}')
		}
		return StyleValue(UnresolvedStyleValue.create([token]))
	}

	context := CalculationContext.for_property(property)
	wrap_in_math_sum := fn [context] (primitive NumericPrimitiveValue) StyleValue {
		type_ := NumericType.create_from_unit(match primitive {
			Number { 'number' }
			Percentage { 'percent' }
			Angle { primitive.unit_name() }
			Flex { primitive.unit_name() }
			Frequency { primitive.unit_name() }
			Length { primitive.unit_name() }
			Resolution { primitive.unit_name() }
			Time { primitive.unit_name() }
		}) or { NumericType.new() }
		calculation_node := calculation_node_from_numeric_primitive(primitive)
		return StyleValue(CalculatedStyleValue.create(calculation_node, type_, context))
	}

	value := create_numeric_value(unit_value.value_, unit_value.unit_) or {
		return error("Unrecognized unit '${unit_value.unit_}'.")
	}

	if perform_type_check == .no {
		return match value {
			Number { StyleValue(NumberStyleValue.create(value.value())) }
			Percentage { StyleValue(PercentageStyleValue.create(value)) }
			Angle { StyleValue(AngleStyleValue.create(value)) }
			Flex { StyleValue(FlexStyleValue.create(value)) }
			Frequency { StyleValue(FrequencyStyleValue.create(value)) }
			Length { StyleValue(LengthStyleValue.create(value)) }
			Resolution { StyleValue(ResolutionStyleValue.create(value)) }
			Time { StyleValue(TimeStyleValue.create(value)) }
		}
	}

	property_id := property.id() or {
		return error('Property does not accept values of this type.')
	}
	style_value := match value {
		Number {
			// NB: Number before Integer, because a custom property accepts either and we want to avoid rounding in that case.
			if property_accepts_type(property_id, .number) {
				if property_accepts_number(property_id, value.value()) {
					?StyleValue(StyleValue(NumberStyleValue.create(value.value())))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else if property_accepts_type(property_id, .integer) {
				// NB: Same rounding as CalculatedStyleValue::resolve_integer(). Maybe this should go somewhere central?
				integer := i64(math.round(value.value()))
				if property_accepts_integer(property_id, integer) {
					?StyleValue(StyleValue(IntegerStyleValue.create(integer)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Percentage {
			if property_accepts_type(property_id, .percentage) {
				if property_accepts_percentage(property_id, value) {
					?StyleValue(StyleValue(PercentageStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Angle {
			if property_accepts_type(property_id, .angle) {
				if property_accepts_angle(property_id, value) {
					?StyleValue(StyleValue(AngleStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Flex {
			if property_accepts_type(property_id, .flex) {
				if property_accepts_flex(property_id, value) {
					?StyleValue(StyleValue(FlexStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Frequency {
			if property_accepts_type(property_id, .frequency) {
				if property_accepts_frequency(property_id, value) {
					?StyleValue(StyleValue(FrequencyStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Length {
			if property_accepts_type(property_id, .length) {
				if property_accepts_length(property_id, value) {
					?StyleValue(StyleValue(LengthStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Resolution {
			if property_accepts_type(property_id, .resolution) {
				if property_accepts_resolution(property_id, value) {
					?StyleValue(StyleValue(ResolutionStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Time {
			if property_accepts_type(property_id, .time) {
				if property_accepts_time(property_id, value) {
					?StyleValue(StyleValue(TimeStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
	}

	return style_value or { error('Property does not accept values of this type.') }
}

pub fn (unit_value CSSUnitValue) create_calculation_node(context CalculationContext) !CalculationNode {
	_ = context
	value := create_numeric_value(unit_value.value_, unit_value.unit_) or {
		return error('Unable to create calculation node from `${unit_value.value_}${unit_value.unit_}`.')
	}
	return calculation_node_from_numeric_primitive(value)
}

fn calculation_node_from_numeric_primitive(value NumericPrimitiveValue) CalculationNode {
	leaf := match value {
		Number {
			CalcNumeric{
				kind: .number
				value: value.value()
				unit: ''
				type_: NumericType.new()
			}
		}
		Percentage {
			CalcNumeric{
				kind: .percentage
				value: value.value()
				unit: '%'
				type_: NumericType.with_type(.percent, 1)
			}
		}
		Angle {
			CalcNumeric{
				kind: .angle
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.angle, 1)
			}
		}
		Flex {
			CalcNumeric{
				kind: .flex
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.flex, 1)
			}
		}
		Frequency {
			CalcNumeric{
				kind: .frequency
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.frequency, 1)
			}
		}
		Length {
			CalcNumeric{
				kind: .length
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.length, 1)
			}
		}
		Resolution {
			CalcNumeric{
				kind: .resolution
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.resolution, 1)
			}
		}
		Time {
			CalcNumeric{
				kind: .time
				value: value.raw_value()
				unit: value.unit_name()
				type_: NumericType.with_type(.time, 1)
			}
		}
	}
	return calculation_node_from_calc(CalcNode(leaf))
}

// --- CSSNumericArray ---

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericarray
pub struct CSSNumericArray {
pub mut:
	values_ []CSSNumericValue
}

pub fn CSSNumericArray.create(values []CSSNumericValue) CSSNumericArray {
	return CSSNumericArray{
		values_: values
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericarray-length
pub fn (array CSSNumericArray) length() u32 {
	// The length attribute of CSSNumericArray indicates how many CSSNumericValues are contained within the CSSNumericArray.
	return u32(array.values_.len)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericarray-indexed-property-getter
pub fn (array CSSNumericArray) item_value(index int) ?CSSNumericValue {
	// The indexed property getter of CSSNumericArray retrieves the CSSNumericValue at the provided index.
	if index < 0 || index >= array.values_.len {
		return none
	}
	return array.values_[index]
}

pub fn (array CSSNumericArray) values() []CSSNumericValue {
	return array.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (array CSSNumericArray) is_equal_numeric_values(other CSSNumericArray) bool {
	// NB: This is just step 3, moved here to reduce repetition.
	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	{
		// 1. If value1's values and value2s values internal slots have different sizes, return false.
		if array.values_.len != other.values_.len {
			return false
		}

		// 2. If any item in value1's values internal slot is not an equal numeric value to the item in value2's values
		//    internal slot at the same index, return false.
		for index := 0; index < array.values_.len; index++ {
			if !array.values_[index].is_equal_numeric_value(other.values_[index]) {
				return false
			}
		}

		// 3. Return true.
		return true
	}
}
