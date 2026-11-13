module platform

import vunicode

pub struct TextMappingEdit {
pub mut:
	source_start    int
	source_length   int
	rendered_start  int
	rendered_length int
}

pub struct CaseMappedText {
pub:
	units []u16
	edits []TextMappingEdit
}

pub fn transform_text_case_with_edits(units []u16, locale string, transform TextCaseTransform) CaseMappedText {
	mapped := vunicode.map_case(units, locale, match transform {
		.uppercase { .uppercase }
		.lowercase { .lowercase }
		.titlecase { .titlecase }
	})
	return CaseMappedText{mapped.units, mapped.edits.map(TextMappingEdit{it.source_start, it.source_length, it.rendered_start, it.rendered_length})}
}
