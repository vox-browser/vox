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
	did_resolve_font_relative_length bool
	did_resolve_font_face_relative_length bool
}

pub fn (mut context ComputationContext) reset_viewport_metric_dependency_tracking() {
	context.did_resolve_viewport_relative_length = false
	context.did_resolve_font_relative_length = false
	context.did_resolve_font_face_relative_length = false
	context.length_resolution_context.set_did_resolve_viewport_relative_length(&context.did_resolve_viewport_relative_length)
	context.length_resolution_context.set_did_resolve_font_relative_length(&context.did_resolve_font_relative_length)
	context.length_resolution_context.set_did_resolve_font_face_relative_length(&context.did_resolve_font_face_relative_length)
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
	if lowercase_value.len == 0 || !is_valid_custom_ident(value, []) {
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
			if value.keyword() == .fit_content {
				property_accepts_type(property_id, .fit_content)
			} else {
				property_accepts_keyword_string(property_id, value.to_string())
			}
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
		FunctionStyleValue {
			match value.name() {
				'add' { property_id == .math_depth }
				'fit-content' { property_accepts_type(property_id, .fit_content) }
				'image', '-webkit-cross-fade' { property_accepts_type(property_id, .image) }
				'stylistic', 'styleset', 'character-variant', 'swash', 'ornaments', 'annotation' {
					property_id == .font_variant_alternates
				}
				'scroll' { property_accepts_type(property_id, .scroll_function) }
				'view' { property_accepts_type(property_id, .view_function) }
				else { false }
			}
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
		ImageSetStyleValue {
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
	mut first_uppercase := -1
	for i, byte in value {
		if byte >= `A` && byte <= `Z` {
			first_uppercase = i
			break
		}
	}
	if first_uppercase < 0 {
		return value
	}
	mut bytes := value.bytes()
	for i := first_uppercase; i < bytes.len; i++ {
		byte := bytes[i]
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
	if retain_length_unit_iteration { return string_to_length_unit_iterated(unit) }
	if length_unit_lookup_diagnostics { report_packed_length_unit_lookup() }
	return packed_length_unit(unit)
}

fn string_to_length_unit_iterated(unit string) ?LengthUnit {
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

// Every numeric-type operation visits the same seven dimensions. Keep their
// spec order in a value array instead of allocating a vector for each visit.
fn numeric_base_types() [7]NumericBaseType {
	return [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]!
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
	if !retain_numeric_dimension_iteration {
		report_numeric_dimension_direct()
		// Reject invalid powers and duplicate unit entries as soon as they appear.
		// Preserve absent and explicit-zero entries without constructing options
		// or dispatching through the dimension iterator for each field.
		mut unit := -1
		length := t.length_ or { 0 }
		if length != 0 {
			if length != 1 { return none }
			unit = int(NumericBaseType.length)
		}
		angle := t.angle_ or { 0 }
		if angle != 0 {
			if angle != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.angle)
		}
		time := t.time_ or { 0 }
		if time != 0 {
			if time != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.time)
		}
		frequency := t.frequency_ or { 0 }
		if frequency != 0 {
			if frequency != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.frequency)
		}
		resolution := t.resolution_ or { 0 }
		if resolution != 0 {
			if resolution != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.resolution)
		}
		flex := t.flex_ or { 0 }
		if flex != 0 {
			if flex != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.flex)
		}
		percent := t.percent_ or { 0 }
		if percent != 0 {
			if percent != 1 || unit != -1 { return none }
			unit = int(NumericBaseType.percent)
		}
		if unit == -1 { return none }
		// The sentinel has been rejected; every remaining assignment is a valid enum.
		return unsafe { NumericBaseType(unit) }
	}
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
	libweb_quirk_inherit
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
	webkit_box
	webkit_inline_box
	webkit_legacy
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
	antialiased
	anywhere
	appworkspace
	arabic_abjad
	arabic_indic
	ari
	armenian
	auto
	auto_add
	avoid
	avoid_column
	avoid_page
	avoid_region
	balance_all
	clone
	page
	recto
	region
	slice
	verso
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
	fit_content
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
	mandatory
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
	no_ellipsis
	no_historical_ligatures
	no_open_quote
	no_overflow
	no_preference
	no_referrer
	no_referrer_when_downgrade
	no_repeat
	none_
	non_scaling_stroke
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
	proximity
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
	subpixel_antialiased
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
	manual
	oblique_only
	cap
	ex
	trim_start
	trim_end
	trim_both
	grid_lanes
	inline_grid_lanes
	fill_reverse
	track_reverse
	dense
	chain
	first
	last
	anchor_center
	flow_start
	flow_end
	flip_x
	flip_y
	any
	numeric_only
	allow_keywords
	loose
	bounding_box
	visible_painted
	visible_fill
	visible_stroke
	painted
	mixed
	sideways
	no_limit
	over
	filled
	open
	dot
	double_circle
	triangle
	sesame
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

// https://drafts.csswg.org/css-values-4/#identifier-value
pub fn is_valid_custom_ident(ident string, blacklist []string) bool {
	if is_css_wide_keyword_string(ident) || equals_ignoring_ascii_case(ident, 'default') {
		return false
	}
	for value in blacklist {
		if equals_ignoring_ascii_case(ident, value) {
			return false
		}
	}
	return true
}

pub fn string_from_keyword(keyword Keyword) string {
	return match keyword {
		.mixed { 'mixed' }
		.sideways { 'sideways' }
		.cap { 'cap' }
		.ex { 'ex' }
		.trim_start { 'trim-start' }
		.trim_end { 'trim-end' }
		.trim_both { 'trim-both' }
		.oblique_only { 'oblique-only' }
		.invalid { '' }
		.negative_infinity { '-infinity' }
		.libweb_buttonfacedisabled { '-libweb-buttonfacedisabled' }
		.libweb_buttonfacehover { '-libweb-buttonfacehover' }
		.libweb_center { '-libweb-center' }
		.libweb_inherit_or_center { '-libweb-inherit-or-center' }
		.libweb_quirk_inherit { '-libweb-quirk-inherit' }
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
		.webkit_box { '-webkit-box' }
		.webkit_inline_box { '-webkit-inline-box' }
		.webkit_legacy { '-webkit-legacy' }
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
		.antialiased { 'antialiased' }
		.anywhere { 'anywhere' }
		.appworkspace { 'appworkspace' }
		.arabic_abjad { 'arabic-abjad' }
		.arabic_indic { 'arabic-indic' }
		.ari { 'ari' }
		.armenian { 'armenian' }
		.auto { 'auto' }
		.auto_add { 'auto-add' }
		.avoid { 'avoid' }
		.avoid_column { 'avoid-column' }
		.avoid_page { 'avoid-page' }
		.avoid_region { 'avoid-region' }
		.balance_all { 'balance-all' }
		.clone { 'clone' }
		.page { 'page' }
		.recto { 'recto' }
		.region { 'region' }
		.slice { 'slice' }
		.verso { 'verso' }
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
		.fit_content { 'fit-content' }
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
		.mandatory { 'mandatory' }
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
		.no_ellipsis { 'no-ellipsis' }
		.no_historical_ligatures { 'no-historical-ligatures' }
		.no_open_quote { 'no-open-quote' }
		.no_overflow { 'no-overflow' }
		.no_preference { 'no-preference' }
		.no_referrer { 'no-referrer' }
		.no_referrer_when_downgrade { 'no-referrer-when-downgrade' }
		.no_repeat { 'no-repeat' }
		.none_ { 'none' }
		.non_scaling_stroke { 'non-scaling-stroke' }
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
		.proximity { 'proximity' }
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
		.subpixel_antialiased { 'subpixel-antialiased' }
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
		.manual { 'manual' }
		.grid_lanes { 'grid-lanes' }
		.inline_grid_lanes { 'inline-grid-lanes' }
		.fill_reverse { 'fill-reverse' }
		.track_reverse { 'track-reverse' }
		.dense { 'dense' }
		.chain { 'chain' }
		.first { 'first' }
		.last { 'last' }
		.anchor_center { 'anchor-center' }
		.flow_start { 'flow-start' }
		.flow_end { 'flow-end' }
		.flip_x { 'flip-x' }
		.flip_y { 'flip-y' }
		.any { 'any' }
		.numeric_only { 'numeric-only' }
		.allow_keywords { 'allow-keywords' }
		.loose { 'loose' }
		.bounding_box { 'bounding-box' }
		.visible_painted { 'visiblepainted' }
		.visible_fill { 'visiblefill' }
		.visible_stroke { 'visiblestroke' }
		.painted { 'painted' }
		.filled { 'filled' }
		.open { 'open' }
		.dot { 'dot' }
		.double_circle { 'double-circle' }
		.triangle { 'triangle' }
		.sesame { 'sesame' }
		.over { 'over' }
		.no_limit { 'no-limit' }
	}
}

pub fn keyword_from_string(input string) ?Keyword {
	name := to_ascii_lowercase(input)
	if name == 'mixed' { return .mixed }
	if name == 'sideways' { return .sideways }
	if name == 'cap' { return .cap }
	if name == 'ex' { return .ex }
	if name == 'trim-start' { return .trim_start }
	if name == 'trim-end' { return .trim_end }
	if name == 'trim-both' { return .trim_both }
	if name == 'oblique-only' { return .oblique_only }
	if name == 'manual' { return .manual }
	if name == 'dense' { return .dense }
	if name == 'grid-lanes' { return .grid_lanes }
	if name == 'inline-grid-lanes' { return .inline_grid_lanes }
	if name == 'fill-reverse' { return .fill_reverse }
	if name == 'track-reverse' { return .track_reverse }
	if name == 'chain' { return .chain }
	if name == 'first' { return .first }
	if name == 'last' { return .last }
	if name == 'anchor-center' { return .anchor_center }
	if name == 'flow-start' { return .flow_start }
	if name == 'flow-end' { return .flow_end }
	if name == 'flip-x' { return .flip_x }
	if name == 'flip-y' { return .flip_y }
	if name == 'any' { return .any }
	if name == 'numeric-only' { return .numeric_only }
	if name == 'allow-keywords' { return .allow_keywords }
	if name == 'loose' { return .loose }
	if name == 'bounding-box' { return .bounding_box }
	if name == 'visiblepainted' { return .visible_painted }
	if name == 'visiblefill' { return .visible_fill }
	if name == 'visiblestroke' { return .visible_stroke }
	if name == 'painted' { return .painted }
	if name == 'filled' { return .filled }
	if name == 'open' { return .open }
	if name == 'dot' { return .dot }
	if name == 'double-circle' { return .double_circle }
	if name == 'triangle' { return .triangle }
	if name == 'sesame' { return .sesame }
	if name == 'over' { return .over }
	if name == 'no-limit' { return .no_limit }
	// Keep bucket selection scalar; wrap the result once after a full match.
	mut value := Keyword.negative_infinity
	mut found := false
	match name.len {
		1 {
			match name[0] {
				0x65 {
					match name {
						'e' {
							value = Keyword.e
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'x' {
							value = Keyword.x
							found = true
						}
						else {}
					}
				}
				0x79 {
					match name {
						'y' {
							value = Keyword.y
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		2 {
			match name[0] {
				0x61 {
					match name {
						'a3' {
							value = Keyword.a3
							found = true
						}
						'a4' {
							value = Keyword.a4
							found = true
						}
						'a5' {
							value = Keyword.a5
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'b4' {
							value = Keyword.b4
							found = true
						}
						'b5' {
							value = Keyword.b5
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'on' {
							value = Keyword.on
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'p3' {
							value = Keyword.p3
							found = true
						}
						'pi' {
							value = Keyword.pi
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'up' {
							value = Keyword.up
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		3 {
			match name[0] {
				0x61 {
					match name {
						'add' {
							value = Keyword.add
							found = true
						}
						'all' {
							value = Keyword.all
							found = true
						}
						'ari' {
							value = Keyword.ari
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'end' {
							value = Keyword.end_
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hsl' {
							value = Keyword.hsl
							found = true
						}
						'hue' {
							value = Keyword.hue
							found = true
						}
						'hwb' {
							value = Keyword.hwb
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lab' {
							value = Keyword.lab
							found = true
						}
						'lao' {
							value = Keyword.lao
							found = true
						}
						'lch' {
							value = Keyword.lch
							found = true
						}
						'ltr' {
							value = Keyword.ltr
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'mro' {
							value = Keyword.mro
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'nan' {
							value = Keyword.nan
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'off' {
							value = Keyword.off
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'pre' {
							value = Keyword.pre
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'row' {
							value = Keyword.row
							found = true
						}
						'rtl' {
							value = Keyword.rtl
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'sub' {
							value = Keyword.sub
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'top' {
							value = Keyword.top
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'xyz' {
							value = Keyword.xyz
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		4 {
			match name[0] {
				0x61 {
					match name {
						'afar' {
							value = Keyword.afar
							found = true
						}
						'agaw' {
							value = Keyword.agaw
							found = true
						}
						'auto' {
							value = Keyword.auto
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'back' {
							value = Keyword.back
							found = true
						}
						'blin' {
							value = Keyword.blin
							found = true
						}
						'bodo' {
							value = Keyword.bodo
							found = true
						}
						'bold' {
							value = Keyword.bold
							found = true
						}
						'both' {
							value = Keyword.both
							found = true
						}
						'butt' {
							value = Keyword.butt
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'cell' {
							value = Keyword.cell
							found = true
						}
						'clip' {
							value = Keyword.clip
							found = true
						}
						'copy' {
							value = Keyword.copy
							found = true
						}
						'crop' {
							value = Keyword.crop
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'dark' {
							value = Keyword.dark
							found = true
						}
						'disc' {
							value = Keyword.disc
							found = true
						}
						'dizi' {
							value = Keyword.dizi
							found = true
						}
						'down' {
							value = Keyword.down
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ease' {
							value = Keyword.ease
							found = true
						}
						'else' {
							value = Keyword.else_
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fast' {
							value = Keyword.fast
							found = true
						}
						'fill' {
							value = Keyword.fill
							found = true
						}
						'fine' {
							value = Keyword.fine
							found = true
						}
						'flat' {
							value = Keyword.flat
							found = true
						}
						'flex' {
							value = Keyword.flex
							found = true
						}
						'flow' {
							value = Keyword.flow
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grab' {
							value = Keyword.grab
							found = true
						}
						'grid' {
							value = Keyword.grid
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'help' {
							value = Keyword.help
							found = true
						}
						'hide' {
							value = Keyword.hide
							found = true
						}
						'high' {
							value = Keyword.high
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'left' {
							value = Keyword.left
							found = true
						}
						'less' {
							value = Keyword.less
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'mark' {
							value = Keyword.mark
							found = true
						}
						'math' {
							value = Keyword.math
							found = true
						}
						'meen' {
							value = Keyword.meen
							found = true
						}
						'menu' {
							value = Keyword.menu
							found = true
						}
						'more' {
							value = Keyword.more
							found = true
						}
						'move' {
							value = Keyword.move
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'newa' {
							value = Keyword.newa
							found = true
						}
						'none' {
							value = Keyword.none_
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'odia' {
							value = Keyword.odia
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'page' {
							value = Keyword.page
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'root' {
							value = Keyword.root
							found = true
						}
						'ruby' {
							value = Keyword.ruby
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'safe' {
							value = Keyword.safe
							found = true
						}
						'saho' {
							value = Keyword.saho
							found = true
						}
						'self' {
							value = Keyword.self
							found = true
						}
						'shan' {
							value = Keyword.shan
							found = true
						}
						'show' {
							value = Keyword.show
							found = true
						}
						'size' {
							value = Keyword.size
							found = true
						}
						'slow' {
							value = Keyword.slow
							found = true
						}
						'srgb' {
							value = Keyword.srgb
							found = true
						}
						'swap' {
							value = Keyword.swap
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text' {
							value = Keyword.text
							found = true
						}
						'thai' {
							value = Keyword.thai
							found = true
						}
						'thin' {
							value = Keyword.thin
							found = true
						}
						'true' {
							value = Keyword.true_
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'urdu' {
							value = Keyword.urdu
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'wait' {
							value = Keyword.wait
							found = true
						}
						'wavy' {
							value = Keyword.wavy
							found = true
						}
						'wrap' {
							value = Keyword.wrap
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		5 {
			match name[0] {
				0x61 {
					match name {
						'adlam' {
							value = Keyword.adlam
							found = true
						}
						'alias' {
							value = Keyword.alias
							found = true
						}
						'alpha' {
							value = Keyword.alpha
							found = true
						}
						'avar2' {
							value = Keyword.avar2
							found = true
						}
						'avoid' {
							value = Keyword.avoid
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'bamum' {
							value = Keyword.bamum
							found = true
						}
						'bevel' {
							value = Keyword.bevel
							found = true
						}
						'blink' {
							value = Keyword.blink
							found = true
						}
						'block' {
							value = Keyword.block
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'clone' {
							value = Keyword.clone
							found = true
						}
						'color' {
							value = Keyword.color
							found = true
						}
						'cover' {
							value = Keyword.cover
							found = true
						}
						'cross' {
							value = Keyword.cross
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'dogri' {
							value = Keyword.dogri
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'embed' {
							value = Keyword.embed
							found = true
						}
						'emoji' {
							value = Keyword.emoji
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'false' {
							value = Keyword.false_
							found = true
						}
						'field' {
							value = Keyword.field
							found = true
						}
						'fixed' {
							value = Keyword.fixed
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'gedeo' {
							value = Keyword.gedeo
							found = true
						}
						'gumuz' {
							value = Keyword.gumuz
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hindi' {
							value = Keyword.hindi
							found = true
						}
						'hover' {
							value = Keyword.hover
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset' {
							value = Keyword.inset
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'jis04' {
							value = Keyword.jis04
							found = true
						}
						'jis78' {
							value = Keyword.jis78
							found = true
						}
						'jis83' {
							value = Keyword.jis83
							found = true
						}
						'jis90' {
							value = Keyword.jis90
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'kaffa' {
							value = Keyword.kaffa
							found = true
						}
						'khmer' {
							value = Keyword.khmer
							found = true
						}
						'konso' {
							value = Keyword.konso
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'large' {
							value = Keyword.large
							found = true
						}
						'legal' {
							value = Keyword.legal
							found = true
						}
						'light' {
							value = Keyword.light
							found = true
						}
						'limbu' {
							value = Keyword.limbu
							found = true
						}
						'local' {
							value = Keyword.local
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'meter' {
							value = Keyword.meter
							found = true
						}
						'miter' {
							value = Keyword.miter
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'notch' {
							value = Keyword.notch
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'octal' {
							value = Keyword.octal
							found = true
						}
						'oklab' {
							value = Keyword.oklab
							found = true
						}
						'oklch' {
							value = Keyword.oklch
							found = true
						}
						'oriya' {
							value = Keyword.oriya
							found = true
						}
						'oromo' {
							value = Keyword.oromo
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'paged' {
							value = Keyword.paged
							found = true
						}
						'paint' {
							value = Keyword.paint
							found = true
						}
						'pan-x' {
							value = Keyword.pan_x
							found = true
						}
						'pan-y' {
							value = Keyword.pan_y
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'radio' {
							value = Keyword.radio
							found = true
						}
						'recto' {
							value = Keyword.recto
							found = true
						}
						'ridge' {
							value = Keyword.ridge
							found = true
						}
						'right' {
							value = Keyword.right
							found = true
						}
						'round' {
							value = Keyword.round
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scoop' {
							value = Keyword.scoop
							found = true
						}
						'serif' {
							value = Keyword.serif
							found = true
						}
						'silti' {
							value = Keyword.silti
							found = true
						}
						'slice' {
							value = Keyword.slice
							found = true
						}
						'small' {
							value = Keyword.small
							found = true
						}
						'solid' {
							value = Keyword.solid
							found = true
						}
						'space' {
							value = Keyword.space
							found = true
						}
						'start' {
							value = Keyword.start
							found = true
						}
						'style' {
							value = Keyword.style
							found = true
						}
						'super' {
							value = Keyword.super
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table' {
							value = Keyword.table
							found = true
						}
						'tamil' {
							value = Keyword.tamil
							found = true
						}
						'thick' {
							value = Keyword.thick
							found = true
						}
						'tigre' {
							value = Keyword.tigre
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'under' {
							value = Keyword.under
							found = true
						}
						'unset' {
							value = Keyword.unset
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'verso' {
							value = Keyword.verso
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'width' {
							value = Keyword.width
							found = true
						}
						'words' {
							value = Keyword.words
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'x-end' {
							value = Keyword.x_end
							found = true
						}
						else {}
					}
				}
				0x79 {
					match name {
						'y-end' {
							value = Keyword.y_end
							found = true
						}
						'yemsa' {
							value = Keyword.yemsa
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		6 {
			match name[0] {
				0x61 {
					match name {
						'active' {
							value = Keyword.active
							found = true
						}
						'always' {
							value = Keyword.always
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'bangla' {
							value = Keyword.bangla
							found = true
						}
						'binary' {
							value = Keyword.binary
							found = true
						}
						'bolder' {
							value = Keyword.bolder
							found = true
						}
						'bottom' {
							value = Keyword.bottom
							found = true
						}
						'button' {
							value = Keyword.button
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'canvas' {
							value = Keyword.canvas
							found = true
						}
						'center' {
							value = Keyword.center
							found = true
						}
						'circle' {
							value = Keyword.circle
							found = true
						}
						'coarse' {
							value = Keyword.coarse
							found = true
						}
						'column' {
							value = Keyword.column
							found = true
						}
						'custom' {
							value = Keyword.custom
							found = true
						}
						'cyclic' {
							value = Keyword.cyclic
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'darken' {
							value = Keyword.darken
							found = true
						}
						'dashed' {
							value = Keyword.dashed
							found = true
						}
						'dotted' {
							value = Keyword.dotted
							found = true
						}
						'double' {
							value = Keyword.double_
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'groove' {
							value = Keyword.groove
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hangul' {
							value = Keyword.hangul
							found = true
						}
						'harari' {
							value = Keyword.harari
							found = true
						}
						'hebrew' {
							value = Keyword.hebrew
							found = true
						}
						'height' {
							value = Keyword.height
							found = true
						}
						'hidden' {
							value = Keyword.hidden
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inline' {
							value = Keyword.inline_
							found = true
						}
						'inside' {
							value = Keyword.inside
							found = true
						}
						'invert' {
							value = Keyword.invert
							found = true
						}
						'italic' {
							value = Keyword.italic
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'jis-b4' {
							value = Keyword.jis_b4
							found = true
						}
						'jis-b5' {
							value = Keyword.jis_b5
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'kebena' {
							value = Keyword.kebena
							found = true
						}
						'kunama' {
							value = Keyword.kunama
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'larger' {
							value = Keyword.larger
							found = true
						}
						'layout' {
							value = Keyword.layout
							found = true
						}
						'ledger' {
							value = Keyword.ledger
							found = true
						}
						'legacy' {
							value = Keyword.legacy
							found = true
						}
						'lepcha' {
							value = Keyword.lepcha
							found = true
						}
						'letter' {
							value = Keyword.letter
							found = true
						}
						'linear' {
							value = Keyword.linear
							found = true
						}
						'longer' {
							value = Keyword.longer
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'medium' {
							value = Keyword.medium
							found = true
						}
						'meetei' {
							value = Keyword.meetei
							found = true
						}
						'middle' {
							value = Keyword.middle
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'normal' {
							value = Keyword.normal
							found = true
						}
						'nowrap' {
							value = Keyword.nowrap
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'opaque' {
							value = Keyword.opaque
							found = true
						}
						'origin' {
							value = Keyword.origin
							found = true
						}
						'outset' {
							value = Keyword.outset
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'pan-up' {
							value = Keyword.pan_up
							found = true
						}
						'paused' {
							value = Keyword.paused
							found = true
						}
						'pretty' {
							value = Keyword.pretty
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'reduce' {
							value = Keyword.reduce
							found = true
						}
						'region' {
							value = Keyword.region
							found = true
						}
						'repeat' {
							value = Keyword.repeat
							found = true
						}
						'revert' {
							value = Keyword.revert
							found = true
						}
						'run-in' {
							value = Keyword.run_in
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'screen' {
							value = Keyword.screen
							found = true
						}
						'scroll' {
							value = Keyword.scroll
							found = true
						}
						'sidama' {
							value = Keyword.sidama
							found = true
						}
						'sindhi' {
							value = Keyword.sindhi
							found = true
						}
						'smooth' {
							value = Keyword.smooth
							found = true
						}
						'square' {
							value = Keyword.square
							found = true
						}
						'stable' {
							value = Keyword.stable
							found = true
						}
						'static' {
							value = Keyword.static_
							found = true
						}
						'sticky' {
							value = Keyword.sticky
							found = true
						}
						'strict' {
							value = Keyword.strict
							found = true
						}
						'stroke' {
							value = Keyword.stroke
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'telugu' {
							value = Keyword.telugu
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'unsafe' {
							value = Keyword.unsafe_
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'window' {
							value = Keyword.window
							found = true
						}
						else {}
					}
				}
				0x7a {
					match name {
						'zhuyin' {
							value = Keyword.zhuyin
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		7 {
			match name[0] {
				0x61 {
					match name {
						'a98-rgb' {
							value = Keyword.a98_rgb
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'balance' {
							value = Keyword.balance
							found = true
						}
						'bengali' {
							value = Keyword.bengali
							found = true
						}
						'browser' {
							value = Keyword.browser
							found = true
						}
						'bullets' {
							value = Keyword.bullets
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'central' {
							value = Keyword.central
							found = true
						}
						'compact' {
							value = Keyword.compact
							found = true
						}
						'contain' {
							value = Keyword.contain
							found = true
						}
						'content' {
							value = Keyword.content
							found = true
						}
						'cursive' {
							value = Keyword.cursive
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'decimal' {
							value = Keyword.decimal
							found = true
						}
						'default' {
							value = Keyword.default
							found = true
						}
						'discard' {
							value = Keyword.discard
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ease-in' {
							value = Keyword.ease_in
							found = true
						}
						'enabled' {
							value = Keyword.enabled
							found = true
						}
						'evenodd' {
							value = Keyword.evenodd
							found = true
						}
						'exclude' {
							value = Keyword.exclude
							found = true
						}
						'extends' {
							value = Keyword.extends
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fantasy' {
							value = Keyword.fantasy
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hadiyaa' {
							value = Keyword.hadiyaa
							found = true
						}
						'hanging' {
							value = Keyword.hanging
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inherit' {
							value = Keyword.inherit
							found = true
						}
						'initial' {
							value = Keyword.initial
							found = true
						}
						'isolate' {
							value = Keyword.isolate
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'justify' {
							value = Keyword.justify
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'kannada' {
							value = Keyword.kannada
							found = true
						}
						'kembata' {
							value = Keyword.kembata
							found = true
						}
						'konkani' {
							value = Keyword.konkani
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lighten' {
							value = Keyword.lighten
							found = true
						}
						'lighter' {
							value = Keyword.lighter
							found = true
						}
						'listbox' {
							value = Keyword.listbox
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'marathi' {
							value = Keyword.marathi
							found = true
						}
						'markers' {
							value = Keyword.markers
							found = true
						}
						'myanmar' {
							value = Keyword.myanmar
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'nearest' {
							value = Keyword.nearest
							found = true
						}
						'no-clip' {
							value = Keyword.no_clip
							found = true
						}
						'no-drop' {
							value = Keyword.no_drop
							found = true
						}
						'nonzero' {
							value = Keyword.nonzero
							found = true
						}
						'numbers' {
							value = Keyword.numbers
							found = true
						}
						'numeric' {
							value = Keyword.numeric
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'oblique' {
							value = Keyword.oblique
							found = true
						}
						'ordinal' {
							value = Keyword.ordinal
							found = true
						}
						'outside' {
							value = Keyword.outside
							found = true
						}
						'overlay' {
							value = Keyword.overlay
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'persian' {
							value = Keyword.persian
							found = true
						}
						'pointer' {
							value = Keyword.pointer
							found = true
						}
						'punjabi' {
							value = Keyword.punjabi
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'rec2020' {
							value = Keyword.rec2020
							found = true
						}
						'replace' {
							value = Keyword.replace
							found = true
						}
						'reverse' {
							value = Keyword.reverse
							found = true
						}
						'running' {
							value = Keyword.running
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'santali' {
							value = Keyword.santali
							found = true
						}
						'shorter' {
							value = Keyword.shorter
							found = true
						}
						'smaller' {
							value = Keyword.smaller
							found = true
						}
						'stretch' {
							value = Keyword.stretch
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'tai-lue' {
							value = Keyword.tai_lue
							found = true
						}
						'tibetan' {
							value = Keyword.tibetan
							found = true
						}
						'to-zero' {
							value = Keyword.to_zero
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'unicase' {
							value = Keyword.unicase
							found = true
						}
						'unicode' {
							value = Keyword.unicode
							found = true
						}
						'upright' {
							value = Keyword.upright
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'visible' {
							value = Keyword.visible
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'wolaita' {
							value = Keyword.wolaita
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'x-large' {
							value = Keyword.x_large
							found = true
						}
						'x-small' {
							value = Keyword.x_small
							found = true
						}
						'x-start' {
							value = Keyword.x_start
							found = true
						}
						'xyz-d50' {
							value = Keyword.xyz_d50
							found = true
						}
						'xyz-d65' {
							value = Keyword.xyz_d65
							found = true
						}
						else {}
					}
				}
				0x79 {
					match name {
						'y-start' {
							value = Keyword.y_start
							found = true
						}
						else {}
					}
				}
				0x7a {
					match name {
						'zoom-in' {
							value = Keyword.zoom_in
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		8 {
			match name[0] {
				0x61 {
					match name {
						'absolute' {
							value = Keyword.absolute
							found = true
						}
						'additive' {
							value = Keyword.additive
							found = true
						}
						'anywhere' {
							value = Keyword.anywhere
							found = true
						}
						'armenian' {
							value = Keyword.armenian
							found = true
						}
						'auto-add' {
							value = Keyword.auto_add
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'balinese' {
							value = Keyword.balinese
							found = true
						}
						'baseline' {
							value = Keyword.baseline
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'checkbox' {
							value = Keyword.checkbox
							found = true
						}
						'collapse' {
							value = Keyword.collapse
							found = true
						}
						'contents' {
							value = Keyword.contents
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'e-resize' {
							value = Keyword.e_resize
							found = true
						}
						'ease-out' {
							value = Keyword.ease_out
							found = true
						}
						'ellipsis' {
							value = Keyword.ellipsis
							found = true
						}
						'expanded' {
							value = Keyword.expanded
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fallback' {
							value = Keyword.fallback
							found = true
						}
						'fill-box' {
							value = Keyword.fill_box
							found = true
						}
						'flex-end' {
							value = Keyword.flex_end
							found = true
						}
						'forwards' {
							value = Keyword.forwards
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'georgian' {
							value = Keyword.georgian
							found = true
						}
						'grabbing' {
							value = Keyword.grabbing
							found = true
						}
						'graytext' {
							value = Keyword.graytext
							found = true
						}
						'gujarati' {
							value = Keyword.gujarati
							found = true
						}
						'gurmukhi' {
							value = Keyword.gurmukhi
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hiragana' {
							value = Keyword.hiragana
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'infinite' {
							value = Keyword.infinite
							found = true
						}
						'infinity' {
							value = Keyword.infinity
							found = true
						}
						'infotext' {
							value = Keyword.infotext
							found = true
						}
						'inverted' {
							value = Keyword.inverted
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'javanese' {
							value = Keyword.javanese
							found = true
						}
						'jump-end' {
							value = Keyword.jump_end
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'kashmiri' {
							value = Keyword.kashmiri
							found = true
						}
						'katakana' {
							value = Keyword.katakana
							found = true
						}
						'kayah-li' {
							value = Keyword.kayah_li
							found = true
						}
						'keep-all' {
							value = Keyword.keep_all
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'linktext' {
							value = Keyword.linktext
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'maithili' {
							value = Keyword.maithili
							found = true
						}
						'manipuri' {
							value = Keyword.manipuri
							found = true
						}
						'marktext' {
							value = Keyword.marktext
							found = true
						}
						'menulist' {
							value = Keyword.menulist
							found = true
						}
						'menutext' {
							value = Keyword.menutext
							found = true
						}
						'multiply' {
							value = Keyword.multiply
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'n-resize' {
							value = Keyword.n_resize
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'ol-chiki' {
							value = Keyword.ol_chiki
							found = true
						}
						'optional' {
							value = Keyword.optional
							found = true
						}
						'overline' {
							value = Keyword.overline
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'palettes' {
							value = Keyword.palettes
							found = true
						}
						'pan-down' {
							value = Keyword.pan_down
							found = true
						}
						'pan-left' {
							value = Keyword.pan_left
							found = true
						}
						'portrait' {
							value = Keyword.portrait
							found = true
						}
						'pre-line' {
							value = Keyword.pre_line
							found = true
						}
						'pre-wrap' {
							value = Keyword.pre_wrap
							found = true
						}
						'preserve' {
							value = Keyword.preserve
							found = true
						}
						'progress' {
							value = Keyword.progress
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'relative' {
							value = Keyword.relative
							found = true
						}
						'repeat-x' {
							value = Keyword.repeat_x
							found = true
						}
						'repeat-y' {
							value = Keyword.repeat_y
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						's-resize' {
							value = Keyword.s_resize
							found = true
						}
						'sanskrit' {
							value = Keyword.sanskrit
							found = true
						}
						'self-end' {
							value = Keyword.self_end
							found = true
						}
						'separate' {
							value = Keyword.separate
							found = true
						}
						'span-all' {
							value = Keyword.span_all
							found = true
						}
						'span-end' {
							value = Keyword.span_end
							found = true
						}
						'span-top' {
							value = Keyword.span_top
							found = true
						}
						'squircle' {
							value = Keyword.squircle
							found = true
						}
						'standard' {
							value = Keyword.standard
							found = true
						}
						'subtract' {
							value = Keyword.subtract
							found = true
						}
						'symbolic' {
							value = Keyword.symbolic
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-top' {
							value = Keyword.text_top
							found = true
						}
						'textarea' {
							value = Keyword.textarea
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ui-serif' {
							value = Keyword.ui_serif
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'vertical' {
							value = Keyword.vertical
							found = true
						}
						'view-box' {
							value = Keyword.view_box
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'w-resize' {
							value = Keyword.w_resize
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'xx-large' {
							value = Keyword.xx_large
							found = true
						}
						'xx-small' {
							value = Keyword.xx_small
							found = true
						}
						else {}
					}
				}
				0x7a {
					match name {
						'zoom-out' {
							value = Keyword.zoom_out
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		9 {
			match name[0] {
				0x2d {
					match name {
						'-infinity' {
							value = Keyword.negative_infinity
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'alternate' {
							value = Keyword.alternate
							found = true
						}
						'anonymous' {
							value = Keyword.anonymous
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'backwards' {
							value = Keyword.backwards
							found = true
						}
						'block-end' {
							value = Keyword.block_end
							found = true
						}
						'break-all' {
							value = Keyword.break_all
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'cambodian' {
							value = Keyword.cambodian
							found = true
						}
						'color-svg' {
							value = Keyword.color_svg
							found = true
						}
						'condensed' {
							value = Keyword.condensed
							found = true
						}
						'crosshair' {
							value = Keyword.crosshair
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'each-line' {
							value = Keyword.each_line
							found = true
						}
						'ew-resize' {
							value = Keyword.ew_resize
							found = true
						}
						'exclusion' {
							value = Keyword.exclusion
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fieldtext' {
							value = Keyword.fieldtext
							found = true
						}
						'flow-root' {
							value = Keyword.flow_root
							found = true
						}
						'from-font' {
							value = Keyword.from_font
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'highlight' {
							value = Keyword.highlight
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'interlace' {
							value = Keyword.interlace
							found = true
						}
						'intersect' {
							value = Keyword.intersect
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'jump-both' {
							value = Keyword.jump_both
							found = true
						}
						'jump-none' {
							value = Keyword.jump_none
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'landscape' {
							value = Keyword.landscape
							found = true
						}
						'linearrgb' {
							value = Keyword.linearrgb
							found = true
						}
						'list-item' {
							value = Keyword.list_item
							found = true
						}
						'lowercase' {
							value = Keyword.lowercase
							found = true
						}
						'luminance' {
							value = Keyword.luminance
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'malayalam' {
							value = Keyword.malayalam
							found = true
						}
						'mandatory' {
							value = Keyword.mandatory
							found = true
						}
						'math-auto' {
							value = Keyword.math_auto
							found = true
						}
						'mongolian' {
							value = Keyword.mongolian
							found = true
						}
						'monospace' {
							value = Keyword.monospace
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'ne-resize' {
							value = Keyword.ne_resize
							found = true
						}
						'no-repeat' {
							value = Keyword.no_repeat
							found = true
						}
						'ns-resize' {
							value = Keyword.ns_resize
							found = true
						}
						'nw-resize' {
							value = Keyword.nw_resize
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'pan-right' {
							value = Keyword.pan_right
							found = true
						}
						'pixelated' {
							value = Keyword.pixelated
							found = true
						}
						'plaintext' {
							value = Keyword.plaintext
							found = true
						}
						'proximity' {
							value = Keyword.proximity
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'ruby-base' {
							value = Keyword.ruby_base
							found = true
						}
						'ruby-text' {
							value = Keyword.ruby_text
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scrollbar' {
							value = Keyword.scrollbar
							found = true
						}
						'se-resize' {
							value = Keyword.se_resize
							found = true
						}
						'span-left' {
							value = Keyword.span_left
							found = true
						}
						'spell-out' {
							value = Keyword.spell_out
							found = true
						}
						'sundanese' {
							value = Keyword.sundanese
							found = true
						}
						'sw-resize' {
							value = Keyword.sw_resize
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-row' {
							value = Keyword.table_row
							found = true
						}
						'textfield' {
							value = Keyword.textfield
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'underline' {
							value = Keyword.underline
							found = true
						}
						'uppercase' {
							value = Keyword.uppercase
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'xxx-large' {
							value = Keyword.xxx_large
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		10 {
			match name[0] {
				0x61 {
					match name {
						'accumulate' {
							value = Keyword.accumulate
							found = true
						}
						'activetext' {
							value = Keyword.activetext
							found = true
						}
						'all-scroll' {
							value = Keyword.all_scroll
							found = true
						}
						'alphabetic' {
							value = Keyword.alphabetic
							found = true
						}
						'avoid-page' {
							value = Keyword.avoid_page
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'background' {
							value = Keyword.background
							found = true
						}
						'border-box' {
							value = Keyword.border_box
							found = true
						}
						'both-edges' {
							value = Keyword.both_edges
							found = true
						}
						'break-word' {
							value = Keyword.break_word
							found = true
						}
						'buttonface' {
							value = Keyword.buttonface
							found = true
						}
						'buttontext' {
							value = Keyword.buttontext
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'canvastext' {
							value = Keyword.canvastext
							found = true
						}
						'capitalize' {
							value = Keyword.capitalize
							found = true
						}
						'col-resize' {
							value = Keyword.col_resize
							found = true
						}
						'color-burn' {
							value = Keyword.color_burn
							found = true
						}
						'color-cbdt' {
							value = Keyword.color_cbdt
							found = true
						}
						'color-sbix' {
							value = Keyword.color_sbix
							found = true
						}
						'contextual' {
							value = Keyword.contextual
							found = true
						}
						'crispedges' {
							value = Keyword.crispedges
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'decreasing' {
							value = Keyword.decreasing
							found = true
						}
						'devanagari' {
							value = Keyword.devanagari
							found = true
						}
						'difference' {
							value = Keyword.difference
							found = true
						}
						'display-p3' {
							value = Keyword.display_p3
							found = true
						}
						'distribute' {
							value = Keyword.distribute
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'flex-start' {
							value = Keyword.flex_start
							found = true
						}
						'flip-block' {
							value = Keyword.flip_block
							found = true
						}
						'flip-start' {
							value = Keyword.flip_start
							found = true
						}
						'full-width' {
							value = Keyword.full_width
							found = true
						}
						'fullscreen' {
							value = Keyword.fullscreen
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hard-light' {
							value = Keyword.hard_light
							found = true
						}
						'horizontal' {
							value = Keyword.horizontal
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'increasing' {
							value = Keyword.increasing
							found = true
						}
						'inline-end' {
							value = Keyword.inline_end
							found = true
						}
						'inter-word' {
							value = Keyword.inter_word
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'jump-start' {
							value = Keyword.jump_start
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lanna-hora' {
							value = Keyword.lanna_hora
							found = true
						}
						'lanna-tham' {
							value = Keyword.lanna_tham
							found = true
						}
						'luminosity' {
							value = Keyword.luminosity
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-box' {
							value = Keyword.margin_box
							found = true
						}
						'minimal-ui' {
							value = Keyword.minimal_ui
							found = true
						}
						'most-width' {
							value = Keyword.most_width
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'open-quote' {
							value = Keyword.open_quote
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'row-resize' {
							value = Keyword.row_resize
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'sans-serif' {
							value = Keyword.sans_serif
							found = true
						}
						'saturation' {
							value = Keyword.saturation
							found = true
						}
						'scale-down' {
							value = Keyword.scale_down
							found = true
						}
						'self-block' {
							value = Keyword.self_block
							found = true
						}
						'self-start' {
							value = Keyword.self_start
							found = true
						}
						'self-x-end' {
							value = Keyword.self_x_end
							found = true
						}
						'self-y-end' {
							value = Keyword.self_y_end
							found = true
						}
						'simplified' {
							value = Keyword.simplified
							found = true
						}
						'small-caps' {
							value = Keyword.small_caps
							found = true
						}
						'soft-light' {
							value = Keyword.soft_light
							found = true
						}
						'span-right' {
							value = Keyword.span_right
							found = true
						}
						'span-start' {
							value = Keyword.span_start
							found = true
						}
						'span-x-end' {
							value = Keyword.span_x_end
							found = true
						}
						'span-y-end' {
							value = Keyword.span_y_end
							found = true
						}
						'standalone' {
							value = Keyword.standalone
							found = true
						}
						'stroke-box' {
							value = Keyword.stroke_box
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-cell' {
							value = Keyword.table_cell
							found = true
						}
						'tally-mark' {
							value = Keyword.tally_mark
							found = true
						}
						'thai-alpha' {
							value = Keyword.thai_alpha
							found = true
						}
						'threedface' {
							value = Keyword.threedface
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ui-rounded' {
							value = Keyword.ui_rounded
							found = true
						}
						'unsafe-url' {
							value = Keyword.unsafe_url
							found = true
						}
						'urdu-abjad' {
							value = Keyword.urdu_abjad
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'variations' {
							value = Keyword.variations
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'windowtext' {
							value = Keyword.windowtext
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		11 {
			match name[0] {
				0x2d {
					match name {
						'-webkit-box' {
							value = Keyword.webkit_box
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'accentcolor' {
							value = Keyword.accentcolor
							found = true
						}
						'antialiased' {
							value = Keyword.antialiased
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'balance-all' {
							value = Keyword.balance_all
							found = true
						}
						'block-start' {
							value = Keyword.block_start
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'captiontext' {
							value = Keyword.captiontext
							found = true
						}
						'cjk-decimal' {
							value = Keyword.cjk_decimal
							found = true
						}
						'close-quote' {
							value = Keyword.close_quote
							found = true
						}
						'color-dodge' {
							value = Keyword.color_dodge
							found = true
						}
						'content-box' {
							value = Keyword.content_box
							found = true
						}
						'crisp-edges' {
							value = Keyword.crisp_edges
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ease-in-out' {
							value = Keyword.ease_in_out
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fit-content' {
							value = Keyword.fit_content
							found = true
						}
						'flip-inline' {
							value = Keyword.flip_inline
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'ideographic' {
							value = Keyword.ideographic
							found = true
						}
						'incremental' {
							value = Keyword.incremental
							found = true
						}
						'inline-flex' {
							value = Keyword.inline_flex
							found = true
						}
						'inline-grid' {
							value = Keyword.inline_grid
							found = true
						}
						'inline-size' {
							value = Keyword.inline_size
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lining-nums' {
							value = Keyword.lining_nums
							found = true
						}
						'lower-alpha' {
							value = Keyword.lower_alpha
							found = true
						}
						'lower-greek' {
							value = Keyword.lower_greek
							found = true
						}
						'lower-latin' {
							value = Keyword.lower_latin
							found = true
						}
						'lower-roman' {
							value = Keyword.lower_roman
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'max-content' {
							value = Keyword.max_content
							found = true
						}
						'min-content' {
							value = Keyword.min_content
							found = true
						}
						'most-height' {
							value = Keyword.most_height
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'nag-mundari' {
							value = Keyword.nag_mundari
							found = true
						}
						'nesw-resize' {
							value = Keyword.nesw_resize
							found = true
						}
						'new-base-60' {
							value = Keyword.new_base_60
							found = true
						}
						'no-ellipsis' {
							value = Keyword.no_ellipsis
							found = true
						}
						'no-overflow' {
							value = Keyword.no_overflow
							found = true
						}
						'no-referrer' {
							value = Keyword.no_referrer
							found = true
						}
						'not-allowed' {
							value = Keyword.not_allowed
							found = true
						}
						'nwse-resize' {
							value = Keyword.nwse_resize
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-box' {
							value = Keyword.padding_box
							found = true
						}
						'petite-caps' {
							value = Keyword.petite_caps
							found = true
						}
						'plus-darker' {
							value = Keyword.plus_darker
							found = true
						}
						'preserve-3d' {
							value = Keyword.preserve_3d
							found = true
						}
						'progressive' {
							value = Keyword.progressive
							found = true
						}
						'push-button' {
							value = Keyword.push_button
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'rotate-left' {
							value = Keyword.rotate_left
							found = true
						}
						'row-reverse' {
							value = Keyword.row_reverse
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'same-origin' {
							value = Keyword.same_origin
							found = true
						}
						'searchfield' {
							value = Keyword.searchfield
							found = true
						}
						'self-inline' {
							value = Keyword.self_inline
							found = true
						}
						'sideways-lr' {
							value = Keyword.sideways_lr
							found = true
						}
						'sideways-rl' {
							value = Keyword.sideways_rl
							found = true
						}
						'span-bottom' {
							value = Keyword.span_bottom
							found = true
						}
						'srgb-linear' {
							value = Keyword.srgb_linear
							found = true
						}
						'subtractive' {
							value = Keyword.subtractive
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-bottom' {
							value = Keyword.text_bottom
							found = true
						}
						'traditional' {
							value = Keyword.traditional
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'upper-alpha' {
							value = Keyword.upper_alpha
							found = true
						}
						'upper-latin' {
							value = Keyword.upper_latin
							found = true
						}
						'upper-roman' {
							value = Keyword.upper_roman
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'vertical-lr' {
							value = Keyword.vertical_lr
							found = true
						}
						'vertical-rl' {
							value = Keyword.vertical_rl
							found = true
						}
						'visitedtext' {
							value = Keyword.visitedtext
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'warang-citi' {
							value = Keyword.warang_citi
							found = true
						}
						'windowframe' {
							value = Keyword.windowframe
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		12 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-left' {
							value = Keyword.libweb_left
							found = true
						}
						'-libweb-link' {
							value = Keyword.libweb_link
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'activeborder' {
							value = Keyword.activeborder
							found = true
						}
						'appworkspace' {
							value = Keyword.appworkspace
							found = true
						}
						'arabic-abjad' {
							value = Keyword.arabic_abjad
							found = true
						}
						'arabic-indic' {
							value = Keyword.arabic_indic
							found = true
						}
						'avoid-column' {
							value = Keyword.avoid_column
							found = true
						}
						'avoid-region' {
							value = Keyword.avoid_region
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'break-spaces' {
							value = Keyword.break_spaces
							found = true
						}
						'buttonborder' {
							value = Keyword.buttonborder
							found = true
						}
						'buttonshadow' {
							value = Keyword.buttonshadow
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'closest-side' {
							value = Keyword.closest_side
							found = true
						}
						'color-colrv0' {
							value = Keyword.color_colrv0
							found = true
						}
						'color-colrv1' {
							value = Keyword.color_colrv1
							found = true
						}
						'context-menu' {
							value = Keyword.context_menu
							found = true
						}
						'currentcolor' {
							value = Keyword.currentcolor
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'features-aat' {
							value = Keyword.features_aat
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'high-quality' {
							value = Keyword.high_quality
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'initial-only' {
							value = Keyword.initial_only
							found = true
						}
						'inline-block' {
							value = Keyword.inline_block
							found = true
						}
						'inline-start' {
							value = Keyword.inline_start
							found = true
						}
						'inline-table' {
							value = Keyword.inline_table
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'line-through' {
							value = Keyword.line_through
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'manipulation' {
							value = Keyword.manipulation
							found = true
						}
						'match-parent' {
							value = Keyword.match_parent
							found = true
						}
						'match-source' {
							value = Keyword.match_source
							found = true
						}
						'mathematical' {
							value = Keyword.mathematical
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'nko-cardinal' {
							value = Keyword.nko_cardinal
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'plus-lighter' {
							value = Keyword.plus_lighter
							found = true
						}
						'progress-bar' {
							value = Keyword.progress_bar
							found = true
						}
						'prophoto-rgb' {
							value = Keyword.prophoto_rgb
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'revert-layer' {
							value = Keyword.revert_layer
							found = true
						}
						'rotate-right' {
							value = Keyword.rotate_right
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-state' {
							value = Keyword.scroll_state
							found = true
						}
						'selecteditem' {
							value = Keyword.selecteditem
							found = true
						}
						'self-x-start' {
							value = Keyword.self_x_start
							found = true
						}
						'self-y-start' {
							value = Keyword.self_y_start
							found = true
						}
						'slashed-zero' {
							value = Keyword.slashed_zero
							found = true
						}
						'space-around' {
							value = Keyword.space_around
							found = true
						}
						'space-evenly' {
							value = Keyword.space_evenly
							found = true
						}
						'span-x-start' {
							value = Keyword.span_x_start
							found = true
						}
						'span-y-start' {
							value = Keyword.span_y_start
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-column' {
							value = Keyword.table_column
							found = true
						}
						'tabular-nums' {
							value = Keyword.tabular_nums
							found = true
						}
						'telugu-alpha' {
							value = Keyword.telugu_alpha
							found = true
						}
						'threedshadow' {
							value = Keyword.threedshadow
							found = true
						}
						'titling-caps' {
							value = Keyword.titling_caps
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ui-monospace' {
							value = Keyword.ui_monospace
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'wrap-reverse' {
							value = Keyword.wrap_reverse
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		13 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-right' {
							value = Keyword.libweb_right
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'activecaption' {
							value = Keyword.activecaption
							found = true
						}
						'anchors-valid' {
							value = Keyword.anchors_valid
							found = true
						}
						'ancient-tamil' {
							value = Keyword.ancient_tamil
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'bidi-override' {
							value = Keyword.bidi_override
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'discard-after' {
							value = Keyword.discard_after
							found = true
						}
						'discard-inner' {
							value = Keyword.discard_inner
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'farthest-side' {
							value = Keyword.farthest_side
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grammar-error' {
							value = Keyword.grammar_error
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'highlighttext' {
							value = Keyword.highlighttext
							found = true
						}
						'horizontal-tb' {
							value = Keyword.horizontal_tb
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'kannada-alpha' {
							value = Keyword.kannada_alpha
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-russian' {
							value = Keyword.lower_russian
							found = true
						}
						'lower-serbian' {
							value = Keyword.lower_serbian
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'no-contextual' {
							value = Keyword.no_contextual
							found = true
						}
						'no-open-quote' {
							value = Keyword.no_open_quote
							found = true
						}
						'no-preference' {
							value = Keyword.no_preference
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'oldstyle-nums' {
							value = Keyword.oldstyle_nums
							found = true
						}
						'optimizespeed' {
							value = Keyword.optimizespeed
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'persian-abjad' {
							value = Keyword.persian_abjad
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'semi-expanded' {
							value = Keyword.semi_expanded
							found = true
						}
						'space-between' {
							value = Keyword.space_between
							found = true
						}
						'span-self-end' {
							value = Keyword.span_self_end
							found = true
						}
						'square-button' {
							value = Keyword.square_button
							found = true
						}
						'strict-origin' {
							value = Keyword.strict_origin
							found = true
						}
						'super-decimal' {
							value = Keyword.super_decimal
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-caption' {
							value = Keyword.table_caption
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ui-sans-serif' {
							value = Keyword.ui_sans_serif
							found = true
						}
						'upper-russian' {
							value = Keyword.upper_russian
							found = true
						}
						'upper-serbian' {
							value = Keyword.upper_serbian
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'vertical-text' {
							value = Keyword.vertical_text
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		14 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-center' {
							value = Keyword.libweb_center
							found = true
						}
						'-webkit-legacy' {
							value = Keyword.webkit_legacy
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'all-small-caps' {
							value = Keyword.all_small_caps
							found = true
						}
						'allow-discrete' {
							value = Keyword.allow_discrete
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'cjk-tally-mark' {
							value = Keyword.cjk_tally_mark
							found = true
						}
						'closest-corner' {
							value = Keyword.closest_corner
							found = true
						}
						'column-reverse' {
							value = Keyword.column_reverse
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'discard-before' {
							value = Keyword.discard_before
							found = true
						}
						'dotted-decimal' {
							value = Keyword.dotted_decimal
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'element-shared' {
							value = Keyword.element_shared
							found = true
						}
						'extra-expanded' {
							value = Keyword.extra_expanded
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'full-size-kana' {
							value = Keyword.full_size_kana
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'gujarati-alpha' {
							value = Keyword.gujarati_alpha
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hiragana-iroha' {
							value = Keyword.hiragana_iroha
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inactiveborder' {
							value = Keyword.inactiveborder
							found = true
						}
						'infobackground' {
							value = Keyword.infobackground
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'katakana-iroha' {
							value = Keyword.katakana_iroha
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-armenian' {
							value = Keyword.lower_armenian
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'maghrebi-abjad' {
							value = Keyword.maghrebi_abjad
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'no-close-quote' {
							value = Keyword.no_close_quote
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'self-block-end' {
							value = Keyword.self_block_end
							found = true
						}
						'semi-condensed' {
							value = Keyword.semi_condensed
							found = true
						}
						'span-block-end' {
							value = Keyword.span_block_end
							found = true
						}
						'spelling-error' {
							value = Keyword.spelling_error
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ultra-expanded' {
							value = Keyword.ultra_expanded
							found = true
						}
						'upper-armenian' {
							value = Keyword.upper_armenian
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		15 {
			match name[0] {
				0x61 {
					match name {
						'accentcolortext' {
							value = Keyword.accentcolortext
							found = true
						}
						'all-petite-caps' {
							value = Keyword.all_petite_caps
							found = true
						}
						'anchors-visible' {
							value = Keyword.anchors_visible
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'buttonhighlight' {
							value = Keyword.buttonhighlight
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'circled-decimal' {
							value = Keyword.circled_decimal
							found = true
						}
						'cjk-ideographic' {
							value = Keyword.cjk_ideographic
							found = true
						}
						'cjk-stem-branch' {
							value = Keyword.cjk_stem_branch
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'disclosure-open' {
							value = Keyword.disclosure_open
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'extra-condensed' {
							value = Keyword.extra_condensed
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'farthest-corner' {
							value = Keyword.farthest_corner
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hanifi-rohingya' {
							value = Keyword.hanifi_rohingya
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inactivecaption' {
							value = Keyword.inactivecaption
							found = true
						}
						'inter-character' {
							value = Keyword.inter_character
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'japanese-formal' {
							value = Keyword.japanese_formal
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'khmer-consonant' {
							value = Keyword.khmer_consonant
							found = true
						}
						'korean-syllable' {
							value = Keyword.korean_syllable
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-bulgarian' {
							value = Keyword.lower_bulgarian
							found = true
						}
						'lower-ukrainian' {
							value = Keyword.lower_ukrainian
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'malayalam-alpha' {
							value = Keyword.malayalam_alpha
							found = true
						}
						'menulist-button' {
							value = Keyword.menulist_button
							found = true
						}
						'most-block-size' {
							value = Keyword.most_block_size
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'optimizequality' {
							value = Keyword.optimizequality
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'preserve-breaks' {
							value = Keyword.preserve_breaks
							found = true
						}
						'preserve-spaces' {
							value = Keyword.preserve_spaces
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-position' {
							value = Keyword.scroll_position
							found = true
						}
						'self-inline-end' {
							value = Keyword.self_inline_end
							found = true
						}
						'span-inline-end' {
							value = Keyword.span_inline_end
							found = true
						}
						'span-self-start' {
							value = Keyword.span_self_start
							found = true
						}
						'span-self-x-end' {
							value = Keyword.span_self_x_end
							found = true
						}
						'span-self-y-end' {
							value = Keyword.span_self_y_end
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-row-group' {
							value = Keyword.table_row_group
							found = true
						}
						'threedhighlight' {
							value = Keyword.threedhighlight
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'ultra-condensed' {
							value = Keyword.ultra_condensed
							found = true
						}
						'upper-bulgarian' {
							value = Keyword.upper_bulgarian
							found = true
						}
						'upper-ukrainian' {
							value = Keyword.upper_ukrainian
							found = true
						}
						'urdu-alphabetic' {
							value = Keyword.urdu_alphabetic
							found = true
						}
						'use-credentials' {
							value = Keyword.use_credentials
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		16 {
			match name[0] {
				0x63 {
					match name {
						'circled-katakana' {
							value = Keyword.circled_katakana
							found = true
						}
						'common-ligatures' {
							value = Keyword.common_ligatures
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ethiopic-numeric' {
							value = Keyword.ethiopic_numeric
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'hangul-consonant' {
							value = Keyword.hangul_consonant
							found = true
						}
						'historical-forms' {
							value = Keyword.historical_forms
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'isolate-override' {
							value = Keyword.isolate_override
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'korean-consonant' {
							value = Keyword.korean_consonant
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-macedonian' {
							value = Keyword.lower_macedonian
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'most-inline-size' {
							value = Keyword.most_inline_size
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'selecteditemtext' {
							value = Keyword.selecteditemtext
							found = true
						}
						'self-block-start' {
							value = Keyword.self_block_start
							found = true
						}
						'span-block-start' {
							value = Keyword.span_block_start
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'threeddarkshadow' {
							value = Keyword.threeddarkshadow
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'upper-macedonian' {
							value = Keyword.upper_macedonian
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		17 {
			match name[0] {
				0x61 {
					match name {
						'alternate-reverse' {
							value = Keyword.alternate_reverse
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'circled-ideograph' {
							value = Keyword.circled_ideograph
							found = true
						}
						'cjk-heavenly-stem' {
							value = Keyword.cjk_heavenly_stem
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'disclosure-closed' {
							value = Keyword.disclosure_closed
							found = true
						}
						'display-p3-linear' {
							value = Keyword.display_p3_linear
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ethiopic-halehame' {
							value = Keyword.ethiopic_halehame
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'features-graphite' {
							value = Keyword.features_graphite
							found = true
						}
						'features-opentype' {
							value = Keyword.features_opentype
							found = true
						}
						'fullwidth-decimal' {
							value = Keyword.fullwidth_decimal
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'japanese-informal' {
							value = Keyword.japanese_informal
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-belorussian' {
							value = Keyword.lower_belorussian
							found = true
						}
						'lower-hexadecimal' {
							value = Keyword.lower_hexadecimal
							found = true
						}
						'lower-oromo-qubee' {
							value = Keyword.lower_oromo_qubee
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'proportional-nums' {
							value = Keyword.proportional_nums
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'self-inline-start' {
							value = Keyword.self_inline_start
							found = true
						}
						'slider-horizontal' {
							value = Keyword.slider_horizontal
							found = true
						}
						'span-inline-start' {
							value = Keyword.span_inline_start
							found = true
						}
						'span-self-x-start' {
							value = Keyword.span_self_x_start
							found = true
						}
						'span-self-y-start' {
							value = Keyword.span_self_y_start
							found = true
						}
						'stacked-fractions' {
							value = Keyword.stacked_fractions
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'threedlightshadow' {
							value = Keyword.threedlightshadow
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'upper-belorussian' {
							value = Keyword.upper_belorussian
							found = true
						}
						'upper-hexadecimal' {
							value = Keyword.upper_hexadecimal
							found = true
						}
						'upper-oromo-qubee' {
							value = Keyword.upper_oromo_qubee
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		18 {
			match name[0] {
				0x2d {
					match name {
						'-webkit-inline-box' {
							value = Keyword.webkit_inline_box
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'cjk-earthly-branch' {
							value = Keyword.cjk_earthly_branch
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'diagonal-fractions' {
							value = Keyword.diagonal_fractions
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'geometricprecision' {
							value = Keyword.geometricprecision
							found = true
						}
						'greek-lower-modern' {
							value = Keyword.greek_lower_modern
							found = true
						}
						'greek-upper-modern' {
							value = Keyword.greek_upper_modern
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-russian-full' {
							value = Keyword.lower_russian_full
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'non-scaling-stroke' {
							value = Keyword.non_scaling_stroke
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'optimizelegibility' {
							value = Keyword.optimizelegibility
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'persian-alphabetic' {
							value = Keyword.persian_alphabetic
							found = true
						}
						'picture-in-picture' {
							value = Keyword.picture_in_picture
							found = true
						}
						'proportional-width' {
							value = Keyword.proportional_width
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'simple-lower-roman' {
							value = Keyword.simple_lower_roman
							found = true
						}
						'simple-upper-roman' {
							value = Keyword.simple_upper_roman
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-column-group' {
							value = Keyword.table_column_group
							found = true
						}
						'table-footer-group' {
							value = Keyword.table_footer_group
							found = true
						}
						'table-header-group' {
							value = Keyword.table_header_group
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'upper-russian-full' {
							value = Keyword.upper_russian_full
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		19 {
			match name[0] {
				0x63 {
					match name {
						'circled-lower-latin' {
							value = Keyword.circled_lower_latin
							found = true
						}
						'circled-upper-latin' {
							value = Keyword.circled_upper_latin
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'greek-lower-ancient' {
							value = Keyword.greek_lower_ancient
							found = true
						}
						'greek-upper-ancient' {
							value = Keyword.greek_upper_ancient
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inactivecaptiontext' {
							value = Keyword.inactivecaptiontext
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'korean-hanja-formal' {
							value = Keyword.korean_hanja_formal
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'no-common-ligatures' {
							value = Keyword.no_common_ligatures
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'ruby-base-container' {
							value = Keyword.ruby_base_container
							found = true
						}
						'ruby-text-container' {
							value = Keyword.ruby_text_container
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'simp-chinese-formal' {
							value = Keyword.simp_chinese_formal
							found = true
						}
						'span-self-block-end' {
							value = Keyword.span_self_block_end
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'trad-chinese-formal' {
							value = Keyword.trad_chinese_formal
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		20 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-base' {
							value = Keyword.libweb_palette_base
							found = true
						}
						'-libweb-palette-link' {
							value = Keyword.libweb_palette_link
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'decimal-leading-zero' {
							value = Keyword.decimal_leading_zero
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ethiopic-halehame-am' {
							value = Keyword.ethiopic_halehame_am
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'historical-ligatures' {
							value = Keyword.historical_ligatures
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'korean-hangul-formal' {
							value = Keyword.korean_hangul_formal
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'lower-alpha-symbolic' {
							value = Keyword.lower_alpha_symbolic
							found = true
						}
						'lower-ukrainian-full' {
							value = Keyword.lower_ukrainian_full
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'span-self-inline-end' {
							value = Keyword.span_self_inline_end
							found = true
						}
						'subpixel-antialiased' {
							value = Keyword.subpixel_antialiased
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'upper-alpha-symbolic' {
							value = Keyword.upper_alpha_symbolic
							found = true
						}
						'upper-ukrainian-full' {
							value = Keyword.upper_ukrainian_full
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		21 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-ruler' {
							value = Keyword.libweb_palette_ruler
							found = true
						}
						'-libweb-quirk-inherit' {
							value = Keyword.libweb_quirk_inherit
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fullwidth-lower-alpha' {
							value = Keyword.fullwidth_lower_alpha
							found = true
						}
						'fullwidth-upper-alpha' {
							value = Keyword.fullwidth_upper_alpha
							found = true
						}
						'fullwidth-upper-roman' {
							value = Keyword.fullwidth_upper_roman
							found = true
						}
						else {}
					}
				}
				0x6b {
					match name {
						'korean-hanja-informal' {
							value = Keyword.korean_hanja_informal
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'parenthesized-decimal' {
							value = Keyword.parenthesized_decimal
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'simp-chinese-informal' {
							value = Keyword.simp_chinese_informal
							found = true
						}
						'span-self-block-start' {
							value = Keyword.span_self_block_start
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'trad-chinese-informal' {
							value = Keyword.trad_chinese_informal
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		22 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-button' {
							value = Keyword.libweb_palette_button
							found = true
						}
						'-libweb-palette-window' {
							value = Keyword.libweb_palette_window
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'double-circled-decimal' {
							value = Keyword.double_circled_decimal
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'filled-circled-decimal' {
							value = Keyword.filled_circled_decimal
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'span-self-inline-start' {
							value = Keyword.span_self_inline_start
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		23 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-buttonfacehover' {
							value = Keyword.libweb_buttonfacehover
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'circled-korean-syllable' {
							value = Keyword.circled_korean_syllable
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'discretionary-ligatures' {
							value = Keyword.discretionary_ligatures
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'ethiopic-halehame-ti-er' {
							value = Keyword.ethiopic_halehame_ti_er
							found = true
						}
						'ethiopic-halehame-ti-et' {
							value = Keyword.ethiopic_halehame_ti_et
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'no-historical-ligatures' {
							value = Keyword.no_historical_ligatures
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'parenthesized-ideograph' {
							value = Keyword.parenthesized_ideograph
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		24 {
			match name[0] {
				0x63 {
					match name {
						'circled-korean-consonant' {
							value = Keyword.circled_korean_consonant
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'origin-when-cross-origin' {
							value = Keyword.origin_when_cross_origin
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		25 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-inherit-or-center' {
							value = Keyword.libweb_inherit_or_center
							found = true
						}
						'-libweb-palette-base-text' {
							value = Keyword.libweb_palette_base_text
							found = true
						}
						'-libweb-palette-menu-base' {
							value = Keyword.libweb_palette_menu_base
							found = true
						}
						'-libweb-palette-selection' {
							value = Keyword.libweb_palette_selection
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'parenthesized-lower-latin' {
							value = Keyword.parenthesized_lower_latin
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		26 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-buttonfacedisabled' {
							value = Keyword.libweb_buttonfacedisabled
							found = true
						}
						else {}
					}
				}
				0x6e {
					match name {
						'no-discretionary-ligatures' {
							value = Keyword.no_discretionary_ligatures
							found = true
						}
						'no-referrer-when-downgrade' {
							value = Keyword.no_referrer_when_downgrade
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		27 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-active-link' {
							value = Keyword.libweb_palette_active_link
							found = true
						}
						'-libweb-palette-button-text' {
							value = Keyword.libweb_palette_button_text
							found = true
						}
						'-libweb-palette-menu-stripe' {
							value = Keyword.libweb_palette_menu_stripe
							found = true
						}
						'-libweb-palette-syntax-type' {
							value = Keyword.libweb_palette_syntax_type
							found = true
						}
						'-libweb-palette-text-cursor' {
							value = Keyword.libweb_palette_text_cursor
							found = true
						}
						'-libweb-palette-window-text' {
							value = Keyword.libweb_palette_window_text
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		28 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-ruler-border' {
							value = Keyword.libweb_palette_ruler_border
							found = true
						}
						'-libweb-palette-visited-link' {
							value = Keyword.libweb_palette_visited_link
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		29 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-focus-outline' {
							value = Keyword.libweb_palette_focus_outline
							found = true
						}
						'-libweb-palette-syntax-number' {
							value = Keyword.libweb_palette_syntax_number
							found = true
						}
						'-libweb-palette-syntax-string' {
							value = Keyword.libweb_palette_syntax_string
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'parenthesized-hangul-syllable' {
							value = Keyword.parenthesized_hangul_syllable
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		30 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-menu-base-text' {
							value = Keyword.libweb_palette_menu_base_text
							found = true
						}
						'-libweb-palette-menu-selection' {
							value = Keyword.libweb_palette_menu_selection
							found = true
						}
						'-libweb-palette-selection-text' {
							value = Keyword.libweb_palette_selection_text
							found = true
						}
						'-libweb-palette-syntax-comment' {
							value = Keyword.libweb_palette_syntax_comment
							found = true
						}
						'-libweb-palette-syntax-keyword' {
							value = Keyword.libweb_palette_syntax_keyword
							found = true
						}
						'-libweb-palette-threed-shadow1' {
							value = Keyword.libweb_palette_threed_shadow1
							found = true
						}
						'-libweb-palette-threed-shadow2' {
							value = Keyword.libweb_palette_threed_shadow2
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'parenthesized-hangul-consonant' {
							value = Keyword.parenthesized_hangul_consonant
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		31 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-hover-highlight' {
							value = Keyword.libweb_palette_hover_highlight
							found = true
						}
						'-libweb-palette-syntax-operator' {
							value = Keyword.libweb_palette_syntax_operator
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'strict-origin-when-cross-origin' {
							value = Keyword.strict_origin_when_cross_origin
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		32 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-rubber-band-fill' {
							value = Keyword.libweb_palette_rubber_band_fill
							found = true
						}
						'-libweb-palette-threed-highlight' {
							value = Keyword.libweb_palette_threed_highlight
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		33 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-ruler-active-text' {
							value = Keyword.libweb_palette_ruler_active_text
							found = true
						}
						'-libweb-palette-syntax-identifier' {
							value = Keyword.libweb_palette_syntax_identifier
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		34 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-desktop-background' {
							value = Keyword.libweb_palette_desktop_background
							found = true
						}
						'-libweb-palette-inactive-selection' {
							value = Keyword.libweb_palette_inactive_selection
							found = true
						}
						'-libweb-palette-rubber-band-border' {
							value = Keyword.libweb_palette_rubber_band_border
							found = true
						}
						'-libweb-palette-syntax-punctuation' {
							value = Keyword.libweb_palette_syntax_punctuation
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		35 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-active-window-title' {
							value = Keyword.libweb_palette_active_window_title
							found = true
						}
						'-libweb-palette-menu-selection-text' {
							value = Keyword.libweb_palette_menu_selection_text
							found = true
						}
						'-libweb-palette-moving-window-title' {
							value = Keyword.libweb_palette_moving_window_title
							found = true
						}
						'-libweb-palette-ruler-inactive-text' {
							value = Keyword.libweb_palette_ruler_inactive_text
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		37 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-active-window-border1' {
							value = Keyword.libweb_palette_active_window_border1
							found = true
						}
						'-libweb-palette-active-window-border2' {
							value = Keyword.libweb_palette_active_window_border2
							found = true
						}
						'-libweb-palette-inactive-window-title' {
							value = Keyword.libweb_palette_inactive_window_title
							found = true
						}
						'-libweb-palette-moving-window-border1' {
							value = Keyword.libweb_palette_moving_window_border1
							found = true
						}
						'-libweb-palette-moving-window-border2' {
							value = Keyword.libweb_palette_moving_window_border2
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		38 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-highlight-window-title' {
							value = Keyword.libweb_palette_highlight_window_title
							found = true
						}
						'-libweb-palette-syntax-control-keyword' {
							value = Keyword.libweb_palette_syntax_control_keyword
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		39 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-inactive-selection-text' {
							value = Keyword.libweb_palette_inactive_selection_text
							found = true
						}
						'-libweb-palette-inactive-window-border1' {
							value = Keyword.libweb_palette_inactive_window_border1
							found = true
						}
						'-libweb-palette-inactive-window-border2' {
							value = Keyword.libweb_palette_inactive_window_border2
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		40 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-highlight-window-border1' {
							value = Keyword.libweb_palette_highlight_window_border1
							found = true
						}
						'-libweb-palette-highlight-window-border2' {
							value = Keyword.libweb_palette_highlight_window_border2
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		41 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-syntax-preprocessor-value' {
							value = Keyword.libweb_palette_syntax_preprocessor_value
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		45 {
			match name[0] {
				0x2d {
					match name {
						'-libweb-palette-syntax-preprocessor-statement' {
							value = Keyword.libweb_palette_syntax_preprocessor_statement
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		else {}
	}
	if !found { return none }
	return value
}

// --- StyleValue ---
pub enum StyleValueType {
	anchor
	anchor_size
	angle
	background_size
	basic_shape
	border_shape
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
	function
	flex
	font_source
	font_style
	frequency
	grid_auto_flow
	grid_template_area
	grid_track_placement
	grid_track_size_list
	guaranteed_invalid
	image
	image_set
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
}

pub type DimensionStyleValue = AngleStyleValue
	| FlexStyleValue
	| FrequencyStyleValue
	| LengthStyleValue
	| PercentageStyleValue
	| ResolutionStyleValue
	| TimeStyleValue

pub type StyleValue = KeywordStyleValue
	| AnchorSizeStyleValue
	| AnchorStyleValue
	| AngleStyleValue
	| CalculatedStyleValue
	| BackgroundSizeStyleValue
	| BasicShapeStyleValue
	| BorderShapeStyleValue
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
	| FunctionStyleValue
	| FlexStyleValue
	| FontSourceStyleValue
	| FontStyleStyleValue
	| FrequencyStyleValue
	| GridAutoFlowStyleValue
	| GridTemplateAreaStyleValue
	| GridTrackPlacementStyleValue
	| GridTrackSizeListStyleValue
	| GuaranteedInvalidStyleValue
	| HSLColorStyleValue
	| HWBColorStyleValue
	| ImageStyleValue
	| ImageSetStyleValue
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
		ImageSetStyleValue {
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

// Read-only dispatch borrows the tagged value rather than copying its largest
// variant into a temporary at each classification or color-conversion call.
pub fn (style_value &StyleValue) type_() StyleValueType {
	return match style_value {
		AnchorSizeStyleValue { .anchor_size }
		AnchorStyleValue { .anchor }
		AngleStyleValue { .angle }
		BackgroundSizeStyleValue { .background_size }
		BasicShapeStyleValue { .basic_shape }
		BorderShapeStyleValue { .border_shape }
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
		FunctionStyleValue { .function }
		FlexStyleValue { .flex }
		FontSourceStyleValue { .font_source }
		FontStyleStyleValue { .font_style }
		FrequencyStyleValue { .frequency }
		GridAutoFlowStyleValue { .grid_auto_flow }
		GridTemplateAreaStyleValue { .grid_template_area }
		GridTrackPlacementStyleValue { .grid_track_placement }
		GridTrackSizeListStyleValue { .grid_track_size_list }
		GuaranteedInvalidStyleValue { .guaranteed_invalid }
		HSLColorStyleValue { .color }
		HWBColorStyleValue { .color }
		ImageStyleValue { .image }
		ImageSetStyleValue { .image_set }
		IntegerStyleValue { .integer }
		KeywordStyleValue { .keyword }
		LabColorStyleValue { .color }
		LCHColorStyleValue { .color }
		LengthStyleValue { .length }
		LightDarkStyleValue { if style_value.image_ { .image } else { .color } }
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
	}
}

pub fn (style_value &StyleValue) is_keyword() bool {
	return style_value.type_() == .keyword
}

pub fn (style_value &StyleValue) is_integer() bool {
	return style_value.type_() == .integer
}

pub fn (style_value &StyleValue) is_number() bool {
	return style_value.type_() == .number
}

pub fn (style_value &StyleValue) is_percentage() bool {
	return style_value.type_() == .percentage
}

pub fn (style_value &StyleValue) is_ratio() bool {
	return style_value.type_() == .ratio
}

pub fn (style_value &StyleValue) is_calculated() bool {
	return style_value.type_() == .calculated
}

pub fn (style_value &StyleValue) is_string() bool {
	return style_value.type_() == .string
}

pub fn (style_value &StyleValue) is_custom_ident() bool {
	return style_value.type_() == .custom_ident
}

pub fn (style_value &StyleValue) is_dimension() bool {
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
pub fn (style_value &StyleValue) is_css_wide_keyword() bool {
	return style_value.is_inherit() || style_value.is_initial() || style_value.is_revert() || style_value.is_unset() || style_value.is_revert_layer()
}

// https://drafts.css-houdini.org/css-properties-values-api/#computationally-independent
// Registered-property initial values may depend on global viewport information,
// but not on an element's font or query container. Token inspection covers those
// length leaves uniformly inside calculations, transforms, gradients, and other
// compound values without losing quoted strings or URL payloads.
pub fn (style_value StyleValue) is_computationally_independent() bool {
	if style_value.is_css_wide_keyword() {
		return false
	}
	match style_value {
		AnchorStyleValue, AnchorSizeStyleValue {
			// These functions locate their anchor only when used; their registered
			// initial-value representation is independent of the target element.
			return true
		}
		GuaranteedInvalidStyleValue, PendingSubstitutionStyleValue, UnresolvedStyleValue {
			return false
		}
		FunctionStyleValue {
			return style_value.value().is_computationally_independent()
		}
		LightDarkStyleValue {
			return style_value.light[0].is_computationally_independent()
				&& style_value.dark[0].is_computationally_independent()
		}
		TreeCountingFunctionStyleValue {
			return false
		}
		// System colors and light-dark() are independent even though the color
		// scheme decides their computed color (CSSWG issue 12735).
		else {}
	}

	for token in Tokenizer.tokenize(style_value.serialize(.normal), 'UTF-8') {
		if !token.is(.dimension) {
			continue
		}
		unit := string_to_length_unit(token.dimension_unit()) or { continue }
		if is_font_relative_length_unit(unit) || is_container_relative_length_unit(unit) {
			return false
		}
	}
	return true
}

pub fn (style_value &StyleValue) is_inherit() bool {
	return style_value.to_keyword() == .inherit
}

pub fn (style_value &StyleValue) is_initial() bool {
	return style_value.to_keyword() == .initial
}

pub fn (style_value &StyleValue) is_revert() bool {
	return style_value.to_keyword() == .revert
}

pub fn (style_value &StyleValue) is_revert_layer() bool {
	return style_value.to_keyword() == .revert_layer
}

pub fn (style_value &StyleValue) is_unset() bool {
	return style_value.to_keyword() == .unset
}

pub fn (style_value &StyleValue) has_auto() bool {
	return style_value.is_keyword() && style_value.as_keyword().keyword() == .auto
}

pub fn (style_value &StyleValue) has_color() bool {
	return match style_value {
		KeywordStyleValue {
			style_value.has_color()
		}
		LightDarkStyleValue { !style_value.image_ }
		ColorFunctionStyleValue, ColorMixStyleValue, ColorStyleValue, HSLColorStyleValue, HWBColorStyleValue, LabColorStyleValue, LCHColorStyleValue, OKLabColorStyleValue, OKLCHColorStyleValue, RGBColorStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value &StyleValue) is_abstract_image() bool {
	return match style_value {
		LightDarkStyleValue { style_value.image_ }
		FunctionStyleValue { style_value.name() in ['image','-webkit-cross-fade'] }
		ImageStyleValue, ImageSetStyleValue, LinearGradientStyleValue, ConicGradientStyleValue, RadialGradientStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value &StyleValue) is_color_function() bool {
	return style_value is ColorFunctionStyleValue
}

pub fn (style_value StyleValue) absolutized(context ComputationContext) StyleValue {
	return match style_value {
		BackgroundSizeStyleValue { style_value.absolutized(context) }
		BasicShapeStyleValue { style_value.absolutized(context) }
		BorderShapeStyleValue { style_value.absolutized(context) }
		BorderRadiusRectStyleValue { style_value.absolutized(context) }
		BorderImageSliceStyleValue { style_value.absolutized(context) }
		BorderRadiusStyleValue { style_value.absolutized(context) }
		CalculatedStyleValue { style_value.absolutized(context) }
		ColorFunctionStyleValue { absolutize_relative_color(style_value, context) or { style_value.absolutized(context) } }
		ColorInterpolationMethodStyleValue { StyleValue(style_value.absolutized(context)) }
		ColorMixStyleValue { style_value.absolutized(context) }
		ContentStyleValue { style_value.absolutized(context) }
		ConicGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		CursorStyleValue { style_value.absolutized(context) }
		EasingStyleValue { style_value.absolutized(context) }
		EdgeStyleValue { style_value.absolutized(context) }
		FilterValueListStyleValue { style_value.absolutized(context) }
		FunctionStyleValue { style_value.absolutized(context) }
		FontStyleStyleValue { style_value.absolutized(context) }
		GridTrackPlacementStyleValue { StyleValue(style_value.absolutized(context)) }
		GridTrackSizeListStyleValue { StyleValue(style_value.absolutized(context)) }
		HSLColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		HWBColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		ImageStyleValue { StyleValue(style_value.absolutized(context)) }
		ImageSetStyleValue { StyleValue(style_value.absolutized(context)) }
		LengthStyleValue { StyleValue(style_value.absolutized(context)) }
		LabColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		LCHColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		LightDarkStyleValue { style_value.absolutized(context) }
		LinearGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		KeywordStyleValue { style_value.absolutized(context) }
		OKLabColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		OKLCHColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		OpenTypeTaggedStyleValue { style_value.absolutized(context) }
		PositionStyleValue { style_value.absolutized(context) }
		RadialGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		RadialSizeStyleValue { style_value.absolutized(context) }
		RandomValueSharingStyleValue { style_value.absolutized(context) }
		RatioStyleValue { style_value.absolutized(context) }
		RectStyleValue { style_value.absolutized(context) }
		RGBColorStyleValue { absolutize_relative_color(style_value, context) or { StyleValue(style_value.absolutized(context)) } }
		ScrollbarColorStyleValue { style_value.absolutized(context) }
		ShadowStyleValue { style_value.absolutized(context) }
		StyleValueList { style_value.absolutized(context) }
		SuperellipseStyleValue { style_value.absolutized(context) }
		TextIndentStyleValue { style_value.absolutized(context) }
		TransformationStyleValue { StyleValue(style_value.absolutized(context)) }
		TreeCountingFunctionStyleValue { style_value.absolutized(context) }
		TupleStyleValue { style_value.absolutized(context) }
		else { style_value }
	}
}

pub fn (style_value &StyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
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

pub fn (style_value &StyleValue) to_keyword() Keyword {
	if style_value is KeywordStyleValue {
		return style_value.keyword()
	}
	return .invalid
}

pub fn (style_value StyleValue) serialize(mode SerializationMode) string {
	return match style_value {
		AnchorSizeStyleValue { style_value.serialize(mode) }
		AnchorStyleValue { style_value.serialize(mode) }
		AngleStyleValue { style_value.serialize(mode) }
		BackgroundSizeStyleValue { style_value.serialize(mode) }
		BasicShapeStyleValue { style_value.serialize(mode) }
		BorderShapeStyleValue { style_value.serialize(mode) }
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
		FlexStyleValue { style_value.serialize(mode) }
		FunctionStyleValue { style_value.serialize(mode) }
		FontSourceStyleValue { style_value.serialize(mode) }
		FontStyleStyleValue { style_value.serialize(mode) }
		FrequencyStyleValue { style_value.serialize(mode) }
		GridAutoFlowStyleValue { style_value.serialize(mode) }
		GridTemplateAreaStyleValue { style_value.serialize(mode) }
		GridTrackPlacementStyleValue { style_value.serialize(mode) }
		GridTrackSizeListStyleValue { style_value.serialize(mode) }
		GuaranteedInvalidStyleValue { style_value.serialize(mode) }
		HSLColorStyleValue { style_value.serialize(mode) }
		HWBColorStyleValue { style_value.serialize(mode) }
		ImageStyleValue { style_value.serialize(mode) }
		ImageSetStyleValue { style_value.serialize(mode) }
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
	// From Ladybird 80f89cee2ac8, Rust/src/css/typed_om.rs.
	// Copyright (c) 2026-present, the Ladybird developers.
	// SPDX-License-Identifier: BSD-2-Clause
	if style_value is ShorthandStyleValue {
		serialized_value := style_value.serialize(.normal)
		if is_css_wide_keyword_string(serialized_value) {
			return CSSStyleValue.from_keyword(CSSKeywordValue.create(serialized_value))
		}
	}
	if style_value is NumberStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is IntegerStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is DisplayStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is StyleValueList {
		return style_value.reify(associated_property)
	}
	if style_value is UnresolvedStyleValue {
		return CSSStyleValue.from_unparsed(style_value.reify(associated_property))
	}
	if style_value is CalculatedStyleValue {
		return reify_calculated_style_value(style_value, associated_property)
	}
	return CSSStyleValue.create(associated_property, style_value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-math-expression
// A calc() whose tree simplified to a single value still reifies as a math
// expression, a CSSMathSum holding that value. Math functions without a
// CSSMath interface fall back to a plain CSSStyleValue.
fn reify_calculated_style_value(value CalculatedStyleValue, associated_property string) CSSStyleValue {
	if value.node.len == 1 {
		if numeric := reify_calc_node(value.node[0]) {
			reified := if numeric is CSSUnitValue {
				type_ := NumericType.create_from_unit(numeric.unit()) or { NumericType.new() }
				CSSNumericValue(CSSMathSum.create(type_, CSSNumericArray.create([numeric])))
			} else {
				numeric
			}
			mut result := CSSStyleValue.from_numeric(reified)
			result.associated_property = associated_property
			return result
		}
	}
	return CSSStyleValue.create(associated_property, StyleValue(value))
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

pub fn (style_value &StyleValue) equals(other &StyleValue) bool {
	if !retain_style_value_union_comparisons {
		return scalar_style_values_equal(style_value, other)
	}
	return style_values_equal_using_union(*style_value, *other)
}

fn style_values_equal_using_union(style_value StyleValue, other StyleValue) bool {
	return match style_value {
		ImageStyleValue {
			if other is ImageStyleValue {
				style_value.equals(other)
			} else {
				false
			}
		}
		ImageSetStyleValue {
			if other is ImageSetStyleValue {
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
		RatioStyleValue {
			if other is RatioStyleValue {
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
	if style_value is PercentageStyleValue {
		return [
			ComponentValue.from_token(Token.create_percentage(Number.with_type(.number, style_value.raw_value()), '')),
		]
	}
	return [
		ComponentValue.from_token(Token.create_dimension_from_double(style_value.raw_value(), style_value.unit_name(), '')),
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
	if document := color_resolution_context.document {
		if document.font_rendering_policy() == .chromium {
			if color := chromium_system_color(style_value.keyword(),scheme) { return color }
		}
	}

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
		document: if element := context.abstract_element { ?&dom.Document(element.document()) } else { none }
	}) or { return StyleValue(style_value) }
	return StyleValue(ColorStyleValue.create_from_color(resolved_color, .legacy, none))
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
	numerator_   []StyleValue = [StyleValue(KeywordStyleValue{})]
	denominator_ []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn RatioStyleValue.create(ratio Ratio) RatioStyleValue {
	return RatioStyleValue.create_from_style_values(StyleValue(NumberStyleValue.create(ratio.numerator())), StyleValue(NumberStyleValue.create(ratio.denominator())))
}

pub fn RatioStyleValue.create_from_style_values(numerator StyleValue, denominator StyleValue) RatioStyleValue {
	return RatioStyleValue{
		numerator_: [numerator]
		denominator_: [denominator]
	}
}

pub fn (style_value RatioStyleValue) numerator() StyleValue {
	return style_value.numerator_[0]
}

pub fn (style_value RatioStyleValue) denominator() StyleValue {
	return style_value.denominator_[0]
}

fn resolved_ratio_component(value StyleValue, context CalculationResolutionContext) ?f64 {
	return match value {
		NumberStyleValue { value.number() }
		CalculatedStyleValue { value.resolve_number(context) }
		else { none }
	}
}

pub fn (style_value RatioStyleValue) resolved_with_context(context CalculationResolutionContext) ?Ratio {
	numerator := resolved_ratio_component(style_value.numerator_[0], context) or { return none }
	denominator := resolved_ratio_component(style_value.denominator_[0], context) or { return none }
	return Ratio.new(numerator, denominator)
}

pub fn (style_value RatioStyleValue) resolved() Ratio {
	return style_value.resolved_with_context(CalculationResolutionContext{}) or {
		panic('VERIFY_NOT_REACHED')
	}
}

pub fn (style_value RatioStyleValue) ratio() Ratio {
	return style_value.resolved()
}

fn absolutized_ratio_component(value StyleValue, context ComputationContext) StyleValue {
	absolutized := value.absolutized(context)
	if absolutized is CalculatedStyleValue && absolutized.resolves_to_number() {
		resolution_context := CalculationResolutionContext.from_computation_context(context, none)
		if number := absolutized.resolve_number(resolution_context) {
			return StyleValue(NumberStyleValue.create(number))
		}
	}
	return absolutized
}

pub fn (style_value RatioStyleValue) absolutized(context ComputationContext) StyleValue {
	absolutized_numerator := absolutized_ratio_component(style_value.numerator_[0], context)
	absolutized_denominator := absolutized_ratio_component(style_value.denominator_[0], context)
	if absolutized_numerator.equals(style_value.numerator_[0])
		&& absolutized_denominator.equals(style_value.denominator_[0]) {
		return StyleValue(style_value)
	}
	return StyleValue(RatioStyleValue.create_from_style_values(absolutized_numerator, absolutized_denominator))
}

pub fn (style_value RatioStyleValue) serialize(mode SerializationMode) string {
	return '${style_value.numerator_[0].serialize(mode)} / ${style_value.denominator_[0].serialize(mode)}'
}

pub fn (style_value RatioStyleValue) tokenize() []ComponentValue {
	mut component_values := style_value.numerator_[0].tokenize()
	component_values << [
		ComponentValue.from_token(Token.create_whitespace(' ')),
		ComponentValue.from_token(Token.create_delim(u32(`/`), '/')),
		ComponentValue.from_token(Token.create_whitespace(' ')),
	]
	component_values << style_value.denominator_[0].tokenize()
	return component_values
}

pub fn (style_value RatioStyleValue) properties_equal(other RatioStyleValue) bool {
	return style_value.numerator_[0].equals(other.numerator_[0])
		&& style_value.denominator_[0].equals(other.denominator_[0])
}

// --- IntegerStyleValue ---
pub struct IntegerStyleValue {
pub mut:
	value_ i64
}

pub fn IntegerStyleValue.create(value i64) IntegerStyleValue {
	return IntegerStyleValue{
		value_: clamp_integer_to_32_bit(value)
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
	// A font family can be a sequence of identifiers. Keep those boundaries
	// for CSSOM serialization while font matching uses the complete name.
	family_identifiers_ []string
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
	if style_value.family_identifiers_.len > 1 {
		return style_value.family_identifiers_.map(serialize_an_identifier(it)).join(' ')
	}
	return serialize_an_identifier(style_value.custom_ident_)
}

pub fn (style_value CustomIdentStyleValue) tokenize() []ComponentValue {
	if style_value.family_identifiers_.len > 1 {
		mut values := []ComponentValue{}
		for index, ident in style_value.family_identifiers_ {
			if index > 0 {
				values << ComponentValue.from_token(Token.create_whitespace(' '))
			}
			values << ComponentValue.from_token(Token.create_ident(ident, serialize_an_identifier(ident)))
		}
		return values
	}
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
	collect_arbitrary_substitution_function_presence(tokens, mut presence) or {
		panic('UnresolvedStyleValue requires validated arbitrary substitution functions')
	}
	return UnresolvedStyleValue.create_with_presence(tokens, presence, original_source_text)
}

pub fn UnresolvedStyleValue.create_with_presence(tokens []ComponentValue, presence SubstitutionFunctionsPresence, original_source_text ?string) UnresolvedStyleValue {
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
}

pub fn URLStyleValue.create(url URL) URLStyleValue {
	return URLStyleValue{
		url_: url
	}
}

pub fn (style_value URLStyleValue) url() URL {
	return style_value.url_
}

pub fn (style_value URLStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.url_.to_string()
}

// https://drafts.csswg.org/css-values-5/#pending-substitution-value
pub struct PendingSubstitutionStyleValue {
pub mut:
	original_shorthand_value []StyleValue = [StyleValue(KeywordStyleValue{})]
}

pub fn PendingSubstitutionStyleValue.create(original_shorthand_value StyleValue) PendingSubstitutionStyleValue {
	return PendingSubstitutionStyleValue{
		original_shorthand_value: [original_shorthand_value]
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
	return style_value.original_shorthand_value[0]
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
	// NB: A box-side shorthand whose longhands all have the same value is that
	//     value, e.g. `margin-block: 10px` reifies as CSS.px(10).
	if whole_value is ShorthandStyleValue && typed_om_reifies_uniform_shorthand(whole_value.shorthand_) {
		longhand_values := whole_value.values()
		if longhand_values.len > 0 && longhand_values.all(it.to_string() == longhand_values[0].to_string())
			&& longhand_values[0] !is ShorthandStyleValue {
			return [longhand_values[0].reify(property.name())]
		}
	}
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
	if perform_type_check == .yes && property.is_custom_property() && value.unparsed_value_ == none {
		return error('Custom properties only accept CSSUnparsedValue objects')
	}
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
		if _ := keyword_from_string(value.value_) {
			if property_accepts_keyword_string(property_id, value.value_) {
				return true
			}
		}
		// Keyword groups, enumerated value types and <custom-ident> are not in
		// the accepted keyword table; the property's own grammar decides.
		return typed_om_text_matches_property(property_id, value.value_)
	}()
	if perform_type_check == .yes && !matches_grammar {
		return error("Property '${property.name()}' does not accept the keyword '${value.value_}'")
	}
	if perform_type_check == .yes && !is_css_wide_keyword_string(value.value_) {
		if property_id := property.id() {
			if !(keyword_from_string(value.value_) != none && property_accepts_keyword_string(property_id, value.value_)) {
				mut parser := Parser.from_css_text(value.value_)
				if parsed := parser.parse_css_value(property_id) {
					return parsed
				}
			}
		}
	}

	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	// NB: Non-applicable.

	//     Return the value.
	if keyword := keyword_from_string(value.value_) {
		if !is_css_wide_keyword_string(value.value_) {
			if property_id := property.id() {
				// Non-CSS-wide `display` keywords always use DisplayStyleValue internally.
				if property_id == .display {
					return StyleValue(DisplayStyleValue.create(Display.from_keyword(keyword)))
				}
			}
		}
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	return StyleValue(CustomIdentStyleValue.create(value.value_))
}

// Typed OM sets <opacity-value> percentages on the opacity properties; the
// shape-image-threshold grammar there is <number> only.
fn typed_om_accepts_opacity_percentage(property_id PropertyID) bool {
	return property_accepts_type(property_id, .opacity) && property_id != .shape_image_threshold
}

fn typed_om_reifies_uniform_shorthand(property_id PropertyID) bool {
	return property_id in [.margin, .margin_block, .margin_inline, .padding, .padding_block, .padding_inline,
		.inset, .inset_block, .inset_inline, .scroll_margin, .scroll_margin_block, .scroll_margin_inline,
		.scroll_padding, .scroll_padding_block, .scroll_padding_inline]
}

// Whether text is a complete, valid value of property_id.
fn typed_om_text_matches_property(property_id PropertyID, text string) bool {
	mut parser := Parser.from_css_text(text)
	return parser.parse_css_value(property_id) != none
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
		CalcAnchor, CalcAnchorSize, CalcRandom, CalcTreeCounting, CalcChannel, CalcSizeKeyword {
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
			// <opacity-value> is <number> | <percentage>.
			if property_accepts_type(property_id, .number) || property_accepts_type(property_id, .opacity) {
				// <opacity-value> is clamped only when computed.
				if property_accepts_number(property_id, value.value()) || property_accepts_type(property_id, .opacity) {
					?StyleValue(StyleValue(NumberStyleValue.create(value.value())))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else if property_accepts_type(property_id, .integer) {
				integer := round_to_nearest_integer(value.value())
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
			if property_accepts_type(property_id, .percentage) || typed_om_accepts_opacity_percentage(property_id) {
				if property_accepts_percentage(property_id, value) || typed_om_accepts_opacity_percentage(property_id) {
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

	result := style_value or { return error('Property does not accept values of this type.') }
	// The value must match the property's grammar on its own: counter-increment
	// takes <integer> only after a counter name, for example.
	if !typed_om_value_matches_property(property_id, result) {
		return error('Property does not accept values of this type.')
	}
	return result
}

// Whether a numeric internal representation is a complete value of property_id.
// Out-of-range values have already been wrapped in calc(), which the grammar
// accepts; in-range values are also probed as calc() so that a range-checked
// literal (like a negative width) does not reject a value set through Typed OM.
fn typed_om_value_matches_property(property_id PropertyID, value StyleValue) bool {
	text := value.to_string()
	if typed_om_text_matches_property(property_id, text) {
		return true
	}
	return !text.starts_with('calc(') && typed_om_text_matches_property(property_id, 'calc(${text})')
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
