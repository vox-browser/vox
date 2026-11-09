module css

$if prealloc {
	import platform
}

// Most property grammars build several candidates before selecting the final
// value. Only the explicitly supported immutable graphs below can leave this
// workspace. Other kinds are parsed again in the caller's owner.
fn parse_property_components_with_export(context ParsingParams, property PropertyID, components []ComponentValue, transient bool) ?StyleValue {
	$if prealloc {
		scratch := platform.begin_thread_scratch('CSS typed property value')
		value_context := context.value_context
		mut parser := Parser{
			component_values: components
			context:          context
			value_context:    value_context.clone()
		}
		parsed := parser.parse_css_value(property) or {
			scratch.finish()
			return none
		}
		can_export := property_value_can_export(parsed)
		scratch.leave()
		defer { scratch.finish() }
		if can_export {
			return export_property_value(parsed)
		}
	}

	// A complex typed value can retain strings or component arrays from its
	// input. Preserve the existing publication path, including unresolved trees.
	owned_components := if transient { own_value_components(components) } else { components }
	value_context := context.value_context
	mut parser := Parser{
		component_values: owned_components
		context:          context
		value_context:    value_context.clone()
	}
	mut parsed := parser.parse_css_value(property)?
	if transient {
		if mut parsed is UnresolvedStyleValue {
			parsed.tokens = own_stylesheet_components(parsed.tokens)
			if original := parsed.original_source_text {
				parsed.original_source_text = original.clone()
			}
		}
	}
	return parsed
}

// Inspect the entire graph before allocating anything in the caller's owner:
// a supported parent can still contain an unsupported calculated/image value.
fn property_value_can_export(value StyleValue) bool {
	return match value {
		KeywordStyleValue, LengthStyleValue, NumberStyleValue, IntegerStyleValue,
		AngleStyleValue, PercentageStyleValue, FlexStyleValue, FrequencyStyleValue,
		ResolutionStyleValue, TimeStyleValue, ColorStyleValue, DisplayStyleValue,
		RepeatStyleStyleValue, ScrollbarGutterStyleValue, GuaranteedInvalidStyleValue,
		GridAutoFlowStyleValue {
			true
		}
		UnresolvedStyleValue, StringStyleValue, CustomIdentStyleValue {
			!disable_retained_text_value_export
		}
		CalculatedStyleValue {
			!retain_calculated_value_reparse && calculated_property_value_can_export(value)
		}
		TransformationStyleValue {
			!retain_transform_value_reparse && transformation_property_value_can_export(value)
		}
		RatioStyleValue {
			property_value_can_export(value.numerator_[0])
				&& property_value_can_export(value.denominator_[0])
		}
		StyleValueList {
			property_values_can_export(value.values_)
		}
		ShorthandStyleValue {
			property_values_can_export(value.values_)
		}
		RGBColorStyleValue {
			// A relative color keeps its origin, which the export does not copy.
			value.relative_origin_.len == 0 && property_value_can_export(value.r_.value)
				&& property_value_can_export(value.g_.value)
				&& property_value_can_export(value.b_.value)
				&& property_value_can_export(value.alpha_.value)
		}
		else { false }
	}
}

fn property_values_can_export(values []StyleValue) bool {
	for value in values {
		if !property_value_can_export(value) {
			return false
		}
	}
	return true
}

fn export_property_values(values []StyleValue) []StyleValue {
	mut owned := []StyleValue{cap: values.len}
	for value in values {
		owned << export_property_value(value)
	}
	return owned
}

fn export_property_value(value StyleValue) StyleValue {
	// Reconstruct every concrete payload after leaving scratch. Returning a
	// shallow copy of the sum type would keep its boxed payload in scratch.
	return match value {
		KeywordStyleValue { StyleValue(KeywordStyleValue{ keyword_: value.keyword_ }) }
		LengthStyleValue { StyleValue(LengthStyleValue{ length_: value.length_ }) }
		NumberStyleValue { StyleValue(NumberStyleValue{ value_: value.value_ }) }
		IntegerStyleValue { StyleValue(IntegerStyleValue{ value_: value.value_ }) }
		AngleStyleValue { StyleValue(AngleStyleValue{ angle_: value.angle_ }) }
		PercentageStyleValue { StyleValue(PercentageStyleValue{ percentage_: value.percentage_ }) }
		FlexStyleValue { StyleValue(FlexStyleValue{ flex_: value.flex_ }) }
		FrequencyStyleValue { StyleValue(FrequencyStyleValue{ frequency_: value.frequency_ }) }
		ResolutionStyleValue { StyleValue(ResolutionStyleValue{ resolution_: value.resolution_ }) }
		TimeStyleValue { StyleValue(TimeStyleValue{ time_: value.time_ }) }
		ColorStyleValue { StyleValue(ColorStyleValue{ color_: value.color_ }) }
		DisplayStyleValue { StyleValue(DisplayStyleValue{ display_: value.display_ }) }
		RepeatStyleStyleValue {
			StyleValue(RepeatStyleStyleValue{
				repeat_x_: value.repeat_x_
				repeat_y_: value.repeat_y_
			})
		}
		ScrollbarGutterStyleValue { StyleValue(ScrollbarGutterStyleValue{ value_: value.value_ }) }
		GuaranteedInvalidStyleValue { StyleValue(GuaranteedInvalidStyleValue{}) }
		GridAutoFlowStyleValue {
			StyleValue(GridAutoFlowStyleValue{ row_: value.row_, dense_: value.dense_ })
		}
		UnresolvedStyleValue, StringStyleValue, CustomIdentStyleValue { export_retained_text_value(value) }
		CalculatedStyleValue { StyleValue(export_calculated_property_value(value)) }
		TransformationStyleValue { StyleValue(export_transformation_property_value(value)) }
		RatioStyleValue {
			StyleValue(RatioStyleValue.create_from_style_values(export_property_value(value.numerator_[0]),
				export_property_value(value.denominator_[0])))
		}
		StyleValueList {
			StyleValue(StyleValueList.create(export_property_values(value.values_), value.separator_,
				value.collapsible_))
		}
		ShorthandStyleValue {
			sub_properties := value.sub_properties_
			StyleValue(ShorthandStyleValue.create(value.shorthand_, sub_properties.clone(),
				export_property_values(value.values_)))
		}
		RGBColorStyleValue {
			name := if original_name := value.name_ { ?string(original_name.clone()) } else { none }
			StyleValue(RGBColorStyleValue.create(export_property_value(value.r_.value),
				export_property_value(value.g_.value), export_property_value(value.b_.value),
				export_property_value(value.alpha_.value), value.color_syntax_, name))
		}
		else { panic('unsupported property value export') }
	}
}
