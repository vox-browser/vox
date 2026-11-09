module css

fn test_highlight_universal_selectors_keep_literal_escaped_names_distinct() {
	universal := selector_from_text('::highlight(*)')
	literal := selector_from_text(r'::highlight(\*)')
	assert universal.serialize() == '::highlight(*)'
	assert literal.serialize() == r'::highlight(\*)'
	assert universal.specificity() < literal.specificity()
	for source in ['::highlight(foo).a', '::highlight(foo):hover', '::highlight(foo) div'] {
		assert parse_query_selector_list(source) == none, source
	}
	assert pseudo_element_supports_property(.highlight, .text_underline_offset)
}
