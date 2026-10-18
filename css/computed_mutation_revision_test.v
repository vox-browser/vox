module css

fn test_computed_mutation_revision_tracks_writes_through_shared_value_aliases() {
	mut style := ComputedProperties.new()
	before := style.mutation_revision()
	assert before != 0
	mut alias := *style
	alias.set_property(.color, parse_css_value(ParsingParams{}, 'red', .color)?, .no, .no)
	assert style.mutation_revision() != before
	assert alias.mutation_revision() == style.mutation_revision()
}

fn test_computed_mutation_revision_does_not_reuse_unknown_or_saturated_owners() {
	unknown := &ComputedProperties{}
	assert unknown.mutation_revision() == 0
	mut style := ComputedProperties.new()
	_ = style.mutation_revision()
	style.computed_property_graph_token_.generation = ~u64(0)
	style.set_property(.color, parse_css_value(ParsingParams{}, 'blue', .color)?, .no, .no)
	assert style.mutation_revision() == 0
	style.set_property(.color, parse_css_value(ParsingParams{}, 'green', .color)?, .no, .no)
	assert style.mutation_revision() == 0
}
