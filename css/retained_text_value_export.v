module css

import os

const disable_retained_text_value_export = os.getenv('VOX_DISABLE_RETAINED_TEXT_VALUE_EXPORT') != ''
const retained_text_value_export_diagnostics = os.getenv('VOX_RETAINED_TEXT_VALUE_EXPORT_DIAGNOSTICS') != ''
__global retained_text_value_export_reported bool

// Unresolved properties publish validated tokens and scalar dependency flags.
// Export that graph once instead of cloning input and parsing the same grammar
// again. Text leaves likewise need only their retained strings and identifiers.
fn export_retained_text_value(value StyleValue) StyleValue {
	if retained_text_value_export_diagnostics && !retained_text_value_export_reported {
		retained_text_value_export_reported = true
		eprintln('Vox property export: retained validated text graph without reparsing')
	}
	return match value {
		UnresolvedStyleValue {
			StyleValue(UnresolvedStyleValue.create_with_presence(
				own_stylesheet_components(value.tokens), value.substitution_functions_presence,
				if text := value.original_source_text { ?string(text.clone()) } else { none }))
		}
		StringStyleValue { StyleValue(StringStyleValue.create(value.string_value_.clone())) }
		CustomIdentStyleValue {
			StyleValue(CustomIdentStyleValue{
				custom_ident_: value.custom_ident_.clone()
				family_identifiers_: value.family_identifiers_.map(it.clone())
			})
		}
		else { panic('unsupported retained text value export') }
	}
}
