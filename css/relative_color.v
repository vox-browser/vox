module css

import math

// Relative color syntax: `rgb(from <color> r g b / alpha)` and the same form of
// the other color functions, whose channel keywords name the origin color's
// components converted into the function's color space.
// https://drafts.csswg.org/css-color-5/#relative-colors

// The value of one channel keyword of a relative color's origin.
pub struct RelativeColorChannel {
pub:
	name    string
	value   f64
	missing bool
}

// The parts shared by every relative color function.
struct RelativeColorParts {
	target          ConcreteColorType
	origin          StyleValue
	components      []StyleValue
	alpha           StyleValue
	alpha_specified bool
}

fn relative_color_channel_names(target ConcreteColorType) []string {
	return match target {
		.rgb, .srgb, .srgb_linear, .display_p3, .display_p3_linear, .a98_rgb, .pro_photo_rgb,
		.rec2020 {
			['r', 'g', 'b']
		}
		.hsl {
			['h', 's', 'l']
		}
		.hwb {
			['h', 'w', 'b']
		}
		.lab, .oklab {
			['l', 'a', 'b']
		}
		.lch, .oklch {
			['l', 'c', 'h']
		}
		.xyzd50, .xyzd65 {
			['x', 'y', 'z']
		}
		else {
			[]string{}
		}
	}
}

fn relative_color_hue_index(target ConcreteColorType) int {
	return match target {
		.hsl, .hwb { 0 }
		.lch, .oklch { 2 }
		else { -1 }
	}
}

// A channel keyword where a relative color component is expected.
fn (mut parser Parser) parse_relative_color_channel_keyword(mut tokens ComponentValueStream) ?StyleValue {
	if parser.relative_color_channels.len == 0 {
		return none
	}
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	name := to_ascii_lowercase(token.token().ident())
	if name !in parser.relative_color_channels {
		return none
	}
	tokens = transaction
	return StyleValue(CustomIdentStyleValue.create(name))
}

// Parses a color function whose arguments start with `from <color>`.
fn (mut parser Parser) parse_relative_color_function(component_value ComponentValue) ?StyleValue {
	function_name := to_ascii_lowercase(component_value.function().name)
	mut target := match function_name {
		'rgb', 'rgba' { ConcreteColorType.rgb }
		'hsl', 'hsla' { ConcreteColorType.hsl }
		'hwb' { ConcreteColorType.hwb }
		'lab' { ConcreteColorType.lab }
		'oklab' { ConcreteColorType.oklab }
		'lch' { ConcreteColorType.lch }
		'oklch' { ConcreteColorType.oklch }
		'color' { ConcreteColorType.srgb }
		else { return none }
	}
	mut tokens := ComponentValueStream.new(component_value.function().value)
	tokens.consume_whitespace()
	from := tokens.peek() or { return none }
	if !from.is(.ident) || !equals_ignoring_ascii_case(from.token().ident(), 'from') {
		return none
	}
	tokens.consume()
	saved_channels := parser.relative_color_channels
	defer {
		parser.relative_color_channels = saved_channels
	}
	// The origin is a complete color of its own; an enclosing relative color's
	// channel keywords do not reach into it.
	parser.relative_color_channels = []string{}
	origin := parser.parse_color_value(mut tokens) or { return none }
	if function_name == 'color' {
		tokens.consume_whitespace()
		space := tokens.consume() or { return none }
		if !space.is(.ident) {
			return none
		}
		color_space := to_ascii_lowercase(space.token().ident())
		if !color_function_supported_color_space(color_space) {
			return none
		}
		target = color_type_from_color_space(color_space)
	}
	mut channels := relative_color_channel_names(target)
	channels << 'alpha'
	parser.relative_color_channels = channels
	hue_index := relative_color_hue_index(target)
	mut components := []StyleValue{cap: 3}
	for index in 0 .. 3 {
		tokens.consume_whitespace()
		component := if index == hue_index {
			parser.parse_hue_none_value(mut tokens) or { return none }
		} else {
			parser.parse_number_percentage_none_value(mut tokens) or { return none }
		}
		components << component
	}
	tokens.consume_whitespace()
	mut alpha := StyleValue(CustomIdentStyleValue.create('alpha'))
	mut alpha_specified := false
	if tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut tokens) or { return none }
		alpha_specified = true
		if tokens.has_more_tokens() {
			return none
		}
	}
	return relative_color_style_value(RelativeColorParts{
		target:          target
		origin:          origin
		components:      components
		alpha:           alpha
		alpha_specified: alpha_specified
	})
}

fn relative_color_style_value(parts RelativeColorParts) StyleValue {
	c := parts.components
	origin := [parts.origin]
	return match parts.target {
		.rgb {
			StyleValue(RGBColorStyleValue{
				...RGBColorStyleValue.create(c[0], c[1], c[2], parts.alpha, .modern, none)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.hsl {
			StyleValue(HSLColorStyleValue{
				...HSLColorStyleValue.create(c[0], c[1], c[2], parts.alpha, .modern)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.hwb {
			StyleValue(HWBColorStyleValue{
				...HWBColorStyleValue.create(c[0], c[1], c[2], parts.alpha, .modern)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.lab {
			StyleValue(LabColorStyleValue{
				...LabColorStyleValue.create(c[0], c[1], c[2], parts.alpha)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.oklab {
			StyleValue(OKLabColorStyleValue{
				...OKLabColorStyleValue.create(c[0], c[1], c[2], parts.alpha)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.lch {
			StyleValue(LCHColorStyleValue{
				...LCHColorStyleValue.create(c[0], c[1], c[2], parts.alpha)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		.oklch {
			StyleValue(OKLCHColorStyleValue{
				...OKLCHColorStyleValue.create(c[0], c[1], c[2], parts.alpha)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
		else {
			StyleValue(ColorFunctionStyleValue{
				...ColorFunctionStyleValue.create(color_space_from_color_type(parts.target),
					c[0], c[1], c[2], parts.alpha)
				relative_origin_: origin
				relative_alpha_:  parts.alpha_specified
			})
		}
	}
}

fn relative_parts(target ConcreteColorType, origin []StyleValue, components []StyleValue, alpha StyleValue, alpha_specified bool) ?RelativeColorParts {
	if origin.len == 0 {
		return none
	}
	return RelativeColorParts{
		target:          target
		origin:          origin[0]
		components:      components
		alpha:           alpha
		alpha_specified: alpha_specified
	}
}

// The relative color parts of a color style value, or none for an absolute color.
fn relative_color_parts(style_value StyleValue) ?RelativeColorParts {
	return match style_value {
		RGBColorStyleValue {
			relative_parts(.rgb, style_value.relative_origin_, [style_value.r_.value, style_value.g_.value,
				style_value.b_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		HSLColorStyleValue {
			relative_parts(.hsl, style_value.relative_origin_, [style_value.h_.value, style_value.s_.value,
				style_value.l_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		HWBColorStyleValue {
			relative_parts(.hwb, style_value.relative_origin_, [style_value.h_.value, style_value.w_.value,
				style_value.b_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		LabColorStyleValue {
			relative_parts(.lab, style_value.relative_origin_, [style_value.l_.value, style_value.a_.value,
				style_value.b_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		OKLabColorStyleValue {
			relative_parts(.oklab, style_value.relative_origin_, [style_value.l_.value, style_value.a_.value,
				style_value.b_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		LCHColorStyleValue {
			relative_parts(.lch, style_value.relative_origin_, [style_value.l_.value, style_value.c_.value,
				style_value.h_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		OKLCHColorStyleValue {
			relative_parts(.oklch, style_value.relative_origin_, [style_value.l_.value, style_value.c_.value,
				style_value.h_.value], style_value.alpha_.value, style_value.relative_alpha_)
		}
		ColorFunctionStyleValue {
			if style_value.alpha_function_ && style_value.relative_origin_.len > 0 {
				alpha_color_parts(style_value, style_value.relative_origin_[0])
			} else {
				relative_parts(style_value.color_type_, style_value.relative_origin_, style_value.channels_,
					style_value.alpha_.value, style_value.relative_alpha_)
			}
		}
		else {
			none
		}
	}
}

fn is_relative_color(style_value StyleValue) bool {
	return match style_value {
		RGBColorStyleValue, HSLColorStyleValue, HWBColorStyleValue, LabColorStyleValue,
		OKLabColorStyleValue, LCHColorStyleValue, OKLCHColorStyleValue, ColorFunctionStyleValue {
			style_value.relative_origin_.len > 0
		}
		else {
			false
		}
	}
}

// https://drafts.csswg.org/css-color-5/#serial-relative-color
fn serialize_relative_color(parts RelativeColorParts, mode SerializationMode) string {
	function_name := match parts.target {
		.rgb { 'rgb' }
		.hsl { 'hsl' }
		.hwb { 'hwb' }
		.lab { 'lab' }
		.oklab { 'oklab' }
		.lch { 'lch' }
		.oklch { 'oklch' }
		else { 'color' }
	}
	mut result := function_name + '(from ' + parts.origin.serialize(mode)
	if function_name == 'color' {
		result += ' ' + color_space_from_color_type(parts.target)
	}
	for component in parts.components {
		result += ' ' + component.serialize(mode)
	}
	if parts.alpha_specified {
		result += ' / ' + parts.alpha.serialize(mode)
	}
	return result + ')'
}

fn relative_target_matches_origin(target ConcreteColorType, origin ConcreteColorType) bool {
	if target == origin {
		return true
	}
	return (target == .rgb && origin == .srgb) || (target == .srgb && origin == .rgb)
}

fn srgb_to_relative_color_target(srgb InterpolationColorComponents, target ConcreteColorType) InterpolationColorComponents {
	return match target {
		.rgb, .srgb { srgb }
		.hsl { srgb_to_polar_color_space(srgb, .hsl) }
		.hwb { srgb_to_polar_color_space(srgb, .hwb) }
		.lch { srgb_to_polar_color_space(srgb, .lch) }
		.oklch { srgb_to_polar_color_space(srgb, .oklch) }
		.lab { srgb_to_rectangular_color_space(srgb, .lab) }
		.oklab { srgb_to_rectangular_color_space(srgb, .oklab) }
		.srgb_linear { srgb_to_rectangular_color_space(srgb, .srgb_linear) }
		.display_p3 { srgb_to_rectangular_color_space(srgb, .display_p3) }
		.display_p3_linear { srgb_to_rectangular_color_space(srgb, .display_p3_linear) }
		.a98_rgb { srgb_to_rectangular_color_space(srgb, .a98_rgb) }
		.pro_photo_rgb { srgb_to_rectangular_color_space(srgb, .prophoto_rgb) }
		.rec2020 { srgb_to_rectangular_color_space(srgb, .rec2020) }
		.xyzd50 { srgb_to_rectangular_color_space(srgb, .xyz_d50) }
		.xyzd65 { srgb_to_rectangular_color_space(srgb, .xyz_d65) }
		else { srgb }
	}
}

fn relative_finite(value f64) f64 {
	return if math.is_nan(value) || math.is_inf(value, 0) { 0 } else { value }
}

// The channel keyword values of origin in the target color space, in the units
// the keywords use there: 0-255 for rgb(), 0-100 for the hsl() and hwb()
// percentages, degrees for hues and the space's own units otherwise.
fn relative_color_channels(origin StyleValue, target ConcreteColorType, context ColorResolutionContext) ?[]RelativeColorChannel {
	names := relative_color_channel_names(target)
	if names.len != 3 {
		return none
	}
	mut values := [3]f64{}
	mut missing := [3]bool{}
	mut alpha_missing := false
	mut alpha := 1.0
	origin_type := concrete_color_type(origin)
	mut native := ?InterpolationColorComponents(none)
	if !is_relative_color(origin) {
		native = style_value_to_color_components(origin, context.calculation_resolution_context)
	}
	mut same_space := false
	if components := native {
		if source := origin_type {
			same_space = relative_target_matches_origin(target, source)
		}
	}
	if same_space {
		components := native or { return none }
		origin_missing := extract_missing_components(origin)
		for index in 0 .. 3 {
			values[index] = components.component(index)
			missing[index] = origin_missing.components[index]
		}
		alpha = components.alpha()
		alpha_missing = origin_missing.alpha
		// The origin contributes its computed value.
		match target {
			.lab, .lch {
				values[0] = image_color_clamp(values[0], 0, 100)
			}
			.oklab, .oklch {
				values[0] = image_color_clamp(values[0], 0, 1)
			}
			else {}
		}
		if (target == .lch || target == .oklch) && values[1] < 0 {
			values[1] = 0
		}
	} else {
		mut srgb := InterpolationColorComponents{}
		mut converted_native := ?InterpolationColorComponents(none)
		mut converted_missing := MissingColorComponents{}
		if components := native {
			source := origin_type or { return none }
			mut source_components := components
			mut source_missing := extract_missing_components(origin)
			relative_make_powerless_hue_missing(source,mut source_components,mut source_missing)
			converted_missing = carry_forward_missing_components(source_missing,categories_for_color_type(source),categories_for_color_type(target))
			srgb = native_components_to_srgb(source_components, source)
			converted_native = convert_native_color_components(source_components,source,target)
		} else {
			color := origin.to_color(context) or { return none }
			srgb = interpolation_color_components(f64(color.r) / 255, f64(color.g) / 255,
				f64(color.b) / 255, f64(color.a) / 255)
		}
		mut converted := converted_native or { srgb_to_relative_color_target(srgb, target) }
		relative_make_powerless_hue_missing(target,mut converted,mut converted_missing)
		for index in 0 .. 3 {
			values[index] = relative_finite(converted.component(index))
			missing[index] = converted_missing.components[index]
		}
		alpha = srgb.alpha()
		alpha_missing = converted_missing.alpha
	}
	match target {
		.rgb {
			for index in 0 .. 3 {
				values[index] *= 255
			}
		}
		.hsl, .hwb {
			values[1] *= 100
			values[2] *= 100
		}
		else {}
	}
	mut channels := []RelativeColorChannel{cap: 4}
	for index in 0 .. 3 {
		channels << RelativeColorChannel{
			name:    names[index]
			value:   if missing[index] { 0 } else { relative_finite(values[index]) }
			missing: missing[index]
		}
	}
	channels << RelativeColorChannel{
		name:    'alpha'
		value:   if alpha_missing { 0 } else { image_color_clamp(relative_finite(alpha), 0, 1) }
		missing: alpha_missing
	}
	return channels
}

// A component with its channel keywords replaced by the origin's values.
fn substitute_relative_color_component(component StyleValue, channels []RelativeColorChannel, context CalculationResolutionContext) ?StyleValue {
	if component is CustomIdentStyleValue {
		for channel in channels {
			if channel.name == component.custom_ident_ {
				if channel.missing {
					return StyleValue(KeywordStyleValue.create(.none_))
				}
				return StyleValue(NumberStyleValue.create(channel.value))
			}
		}
		return none
	}
	if component is CalculatedStyleValue {
		mut channel_context := context
		channel_context.relative_color_channels = channels
		if component.resolves_to_number() {
			return StyleValue(NumberStyleValue.create(component.resolve_number(channel_context)?))
		}
		if component.resolves_to_percentage() {
			return StyleValue(PercentageStyleValue.create(component.resolve_percentage(channel_context)?))
		}
		if component.resolves_to_angle() {
			return StyleValue(AngleStyleValue.create(component.resolve_angle(channel_context)?))
		}
	}
	return component
}

fn relative_number_or_none(value StyleValue, one_hundred_percent f64, scale f64) StyleValue {
	if style_value_is_none_keyword(value) {
		return value
	}
	resolved := resolve_with_reference_value(value, one_hundred_percent, CalculationResolutionContext{}) or {
		0
	}
	return StyleValue(NumberStyleValue.create(resolved * scale))
}

fn relative_alpha_or_none(value StyleValue) StyleValue {
	if style_value_is_none_keyword(value) {
		return value
	}
	resolved := resolve_alpha(value, CalculationResolutionContext{}) or { 1 }
	return StyleValue(NumberStyleValue.create(resolved))
}

fn relative_hue_or_none(value StyleValue) StyleValue {
	if style_value_is_none_keyword(value) {
		return value
	}
	resolved := resolve_hue(value, CalculationResolutionContext{}) or { 0 }
	return StyleValue(NumberStyleValue.create(resolved))
}

fn relative_component_value(value StyleValue, one_hundred_percent f64) f64 {
	if style_value_is_none_keyword(value) {
		return 0
	}
	return resolve_with_reference_value(value, one_hundred_percent, CalculationResolutionContext{}) or {
		0
	}
}

// The computed value of a relative color whose origin has been computed.
// https://drafts.csswg.org/css-color-5/#resolving-rcs
fn resolve_relative_color_parts(parts RelativeColorParts, origin StyleValue, context ColorResolutionContext) ?StyleValue {
	channels := relative_color_channels(origin, parts.target, context)?
	mut c := []StyleValue{cap: 3}
	for component in parts.components {
		c << substitute_relative_color_component(component, channels, context.calculation_resolution_context)?
	}
	alpha := relative_alpha_or_none(substitute_relative_color_component(parts.alpha, channels,
		context.calculation_resolution_context)?)
	has_missing := c.any(style_value_is_none_keyword(it)) || style_value_is_none_keyword(alpha)
	match parts.target {
		.rgb {
			return StyleValue(ColorFunctionStyleValue.create('srgb', relative_number_or_none(c[0],
				255, 1.0 / 255), relative_number_or_none(c[1], 255, 1.0 / 255), relative_number_or_none(c[2],
				255, 1.0 / 255), alpha))
		}
		.hsl, .hwb {
			hue := relative_hue_or_none(c[0])
			second := relative_number_or_none(c[1], 100, 1)
			third := relative_number_or_none(c[2], 100, 1)
			if has_missing {
				if parts.target == .hsl {
					return StyleValue(HSLColorStyleValue{
						...HSLColorStyleValue.create(hue, second, third, alpha, .modern)
						missing_component_form_: true
					})
				}
				return StyleValue(HWBColorStyleValue{
					...HWBColorStyleValue.create(hue, second, third, alpha, .modern)
					missing_component_form_: true
				})
			}
			components := interpolation_color_components(relative_component_value(hue,
				1), relative_component_value(second, 100) / 100, relative_component_value(third,
				100) / 100, relative_component_value(alpha, 1))
			srgb := if parts.target == .hsl {
				ci_hsl_to_srgb(components)
			} else {
				ci_hwb_to_srgb(components)
			}
			return StyleValue(ColorFunctionStyleValue.create('srgb', StyleValue(NumberStyleValue.create(srgb.component(0))),
				StyleValue(NumberStyleValue.create(srgb.component(1))), StyleValue(NumberStyleValue.create(srgb.component(2))),
				alpha))
		}
		.lab {
			return StyleValue(LabColorStyleValue.create(c[0], c[1], c[2], alpha))
		}
		.oklab {
			return StyleValue(OKLabColorStyleValue.create(c[0], c[1], c[2], alpha))
		}
		.lch {
			return StyleValue(LCHColorStyleValue.create(c[0], c[1], c[2], alpha))
		}
		.oklch {
			return StyleValue(OKLCHColorStyleValue.create(c[0], c[1], c[2], alpha))
		}
		else {
			return StyleValue(ColorFunctionStyleValue.create(color_space_from_color_type(parts.target),
				relative_number_or_none(c[0], 1, 1), relative_number_or_none(c[1], 1, 1), relative_number_or_none(c[2],
				1, 1), alpha))
		}
	}
}

// The computed value of a relative color. An origin that still depends on
// currentcolor keeps the relative form until the color is used.
fn absolutize_relative_color(style_value StyleValue, context ComputationContext) ?StyleValue {
	// Every computed color passes through here; absolute ones leave at once.
	if !is_relative_color(style_value) {
		if preserved := preserve_missing_polar_color(style_value,context) { return preserved }
		if is_missing_component_form(style_value) {
			return style_value
		}
		return none
	}
	mut parts := relative_color_parts(style_value) or { return none }
	// hsl() and hwb() compute to 8-bit rgb(); their channels come from the
	// specified components instead.
	origin := if (parts.origin is HSLColorStyleValue || parts.origin is HWBColorStyleValue)
		&& !is_relative_color(parts.origin) {
		parts.origin
	} else {
		parts.origin.absolutized(context)
	}
	if style_value is ColorFunctionStyleValue && style_value.alpha_function_ {
		parts = alpha_color_parts(style_value, origin)
	}
	color_context := ColorResolutionContext{
		color_scheme:                   context.color_scheme
		calculation_resolution_context: CalculationResolutionContext{
			length_resolution_context: context.length_resolution_context
			abstract_element:          context.abstract_element
		}
	}
	if !color_depends_on_current_color(origin) {
		if resolved := resolve_relative_color_parts(parts, origin, color_context) {
			return resolved
		}
	}
	if style_value is ColorFunctionStyleValue && style_value.alpha_function_ {
		return StyleValue(ColorFunctionStyleValue{...style_value,relative_origin_:[origin],alpha_:style_value_slot(parts.alpha.absolutized(context))})
	}
	return relative_color_style_value(RelativeColorParts{
		...parts
		origin: origin
	})
}

fn relative_color_to_color(style_value StyleValue, context ColorResolutionContext) ?Color {
	parts := relative_color_parts(style_value)?
	resolved := resolve_relative_color_parts(parts, parts.origin, context)?
	return resolved.to_color(context)
}

// https://drafts.csswg.org/css-color-5/#resolving-rcs: a computed relative
// color with missing components keeps its function, serialized with numbers.
fn serialize_missing_component_form(function_name string, components []StyleValue, alpha StyleValue, mode SerializationMode) string {
	mut result := function_name + '('
	for index, component in components {
		if index > 0 {
			result += ' '
		}
		result += component.serialize(mode)
		if function_name in ['hsl','hwb'] && index in [1,2] && component is NumberStyleValue { result += '%' }
	}
	if style_value_is_none_keyword(alpha) || alpha_needs_serialization(alpha) {
		result += ' / ' + alpha.serialize(mode)
	}
	return result + ')'
}

// currentcolor resolves only once the color is used, so a color made from it
// keeps its specified form as its computed value.
fn color_depends_on_current_color(value StyleValue) bool {
	match value {
		KeywordStyleValue {
			return value.keyword() == .currentcolor
		}
		ColorMixStyleValue {
			return color_depends_on_current_color(value.first_component[0].color)
				|| color_depends_on_current_color(value.second_component[0].color)
		}
		LightDarkStyleValue {
			return color_depends_on_current_color(value.light[0])
				|| color_depends_on_current_color(value.dark[0])
		}
		else {
			if parts := relative_color_parts(value) {
				return color_depends_on_current_color(parts.origin)
			}
			return false
		}
	}
}

// A relative color resolved with the context of its use, for interpolation
// and resolved values; other colors are returned unchanged.
fn resolve_relative_color_for_use(value StyleValue, context ColorResolutionContext) StyleValue {
	parts := relative_color_parts(value) or { return value }
	return resolve_relative_color_parts(parts, parts.origin, context) or { value }
}

fn is_missing_component_form(value StyleValue) bool {
	return match value {
		HSLColorStyleValue, HWBColorStyleValue { value.missing_component_form_ }
		else { false }
	}
}
