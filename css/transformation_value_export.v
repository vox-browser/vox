module css

import os
import sync.stdatomic

const retain_transform_value_reparse = os.getenv('VOX_RETAIN_TRANSFORM_VALUE_REPARSE') != ''
const transform_value_export_diagnostics = os.getenv('VOX_TRANSFORM_VALUE_EXPORT_DIAGNOSTICS') != ''
__global transform_value_export_reported stdatomic.AtomicVal[bool]

// Transform grammars publish at most sixteen numeric arguments. Validate the
// complete argument vector before leaving the parsing workspace. Relative
// lengths and percentages remain specified values; export does not resolve them.
fn transformation_property_value_can_export(value TransformationStyleValue) bool {
	if value.values_.len == 0 || value.values_.len > 16 { return false }
	for argument in value.values_ {
		match argument {
			LengthStyleValue, NumberStyleValue, AngleStyleValue, PercentageStyleValue {}
			CalculatedStyleValue {
				if retain_calculated_value_reparse || !calculated_property_value_can_export(argument) {
					return false
				}
			}
			else { return false }
		}
	}
	return true
}

fn export_transformation_property_value(value TransformationStyleValue) TransformationStyleValue {
	if !retain_transform_value_reparse && transform_value_export_diagnostics
		&& transform_value_export_reported.compare_and_swap(false, true) {
		eprintln('Vox transform value export: copied numeric arguments without reparsing')
	}
	return TransformationStyleValue.create(value.property_, value.transform_function_,
		export_property_values(value.values_))
}
