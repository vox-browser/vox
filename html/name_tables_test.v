module html

fn test_generated_html_name_tables_match_upstream_counts_and_spellings() {
	attributes := html_attribute_names()
	events := html_event_names()
	tags := html_tag_names()
	assert attributes.len == 314
	assert events.len == 140
	assert tags.len == 146
	assert 'accept-charset' in attributes
	assert 'DOMContentLoaded' in events
	assert 'begin' in events
	assert 'repeat' in events
	assert 'selectedcontent' in tags
	assert 'template' in tags
}

fn test_html_boolean_attribute_lookup_is_ascii_case_insensitive() {
	assert is_boolean_attribute('disabled')
	assert is_boolean_attribute('CHECKED')
	assert is_boolean_attribute('switch')
	assert !is_boolean_attribute('href')
	assert !is_boolean_attribute('disabled-value')
}

fn test_custom_element_reaction_name_table() {
	names := custom_element_reaction_names()
	assert names.len == 9
	assert names[0] == 'connectedCallback'
	assert names.last() == 'formStateRestoreCallback'
}
