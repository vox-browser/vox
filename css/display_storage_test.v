module css

fn test_display_tags_fit_in_the_compact_display_record() {
	assert sizeof(Display) == 6
	assert u8(DisplayOutside.run_in) == 2
	assert u8(DisplayInside.webkit_box) == 7
	assert u8(DisplayInternal.ruby_text_container) == 11
	for short in [DisplayShort.none_, .contents, .block, .flow, .flow_root, .inline_,
		.inline_block, .run_in, .list_item, .inline_list_item, .flex, .inline_flex,
		.grid, .inline_grid, .ruby, .table, .inline_table, .math] {
		display := Display.from_short(short)
		parsed := parse_css_value_logic(.display, display.to_string()) or {
			panic('display did not round trip: ${display.to_string()}')
		}
		assert parsed is DisplayStyleValue
		assert parsed.display_ == display
	}
}
