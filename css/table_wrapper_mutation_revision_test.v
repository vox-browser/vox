module css

fn test_table_transfer_has_an_independent_observable_property_graph() {
	mut source := computed_properties_with_initial_values()
	margin := parse_css_value(ParsingParams{}, '17px', .margin_left)?
	source.set_property(.margin_left, margin, .no, .no)
	source_revision := source.mutation_revision()
	mut table, wrapper := source.table_box_and_wrapper_properties()
	table_revision := table.mutation_revision()
	wrapper_revision := wrapper.mutation_revision()
	assert table_revision != 0
	assert wrapper_revision != 0
	assert voidptr(table.computed_property_graph_token_) != voidptr(source.computed_property_graph_token_)
	assert voidptr(table.computed_property_graph_token_) != voidptr(wrapper.computed_property_graph_token_)
	assert voidptr(table.property(.margin_left, .no)?) != voidptr(margin)
	assert voidptr(source.property(.margin_left, .no)?) == voidptr(margin)
	mut alias := *table
	red := parse_css_value(ParsingParams{}, 'red', .color)?
	alias.set_property(.color, red, .no, .no)
	assert table.mutation_revision() != table_revision
	assert alias.mutation_revision() == table.mutation_revision()
	assert source.mutation_revision() == source_revision
	assert wrapper.mutation_revision() == wrapper_revision
	assert voidptr(source.property(.color, .no)?) != voidptr(red)
	assert voidptr(wrapper.property(.color, .no)?) != voidptr(red)
	table.set_property(.height, parse_css_value(ParsingParams{}, '29px', .height)?, .no, .no)
	assert alias.mutation_revision() == table.mutation_revision()
	assert source.mutation_revision() == source_revision
}
