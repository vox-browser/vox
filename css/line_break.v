module css

// https://drafts.csswg.org/css-text-3/#line-break-property
pub enum LineBreak as u8 {
	auto
	loose
	normal
	strict
	anywhere
}

pub fn (style &ComputedProperties) line_break() LineBreak {
	value := style.property(.line_break, .yes) or { return .auto }
	keyword := computed_interpolation_style_value_keyword(value) or { return .auto }
	return match keyword {
		.loose { LineBreak.loose }
		.normal { LineBreak.normal }
		.strict { LineBreak.strict }
		.anywhere { LineBreak.anywhere }
		else { LineBreak.auto }
	}
}
