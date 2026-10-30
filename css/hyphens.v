module css

pub enum Hyphens {
	manual
	none_
	auto_
}

pub fn (style &ComputedProperties) hyphens() Hyphens {
	value := style.property(.hyphens, .yes) or { return .manual }
	keyword := computed_interpolation_style_value_keyword(value) or { return .manual }
	return match keyword {
		.none_ { Hyphens.none_ }
		.auto { Hyphens.auto_ }
		else { Hyphens.manual }
	}
}

pub fn (values &ComputedValues) hyphens() Hyphens {
	return values.computed_layout_cache().computed_values_hyphens_
}

pub fn (mut values MutableComputedValues) set_hyphens(value Hyphens) {
	values.ensure_computed_layout_cache().computed_values_hyphens_ = value
}
