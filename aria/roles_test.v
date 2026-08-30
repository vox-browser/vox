module aria

fn test_role_names_parsing_and_categories() {
	for role in all_roles {
		name := role_name(role)
		assert role_from_string(name)? == role
		assert role_from_string(name.to_upper_ascii())? == role
	}
	assert role_from_string('BuTtOn')? == .button
	assert role_from_string('graphics-document')? == .graphicsdocument
	assert role_name(.switch_) == 'switch'
	assert role_from_string('missing') == none
	assert is_abstract_role(.command)
	assert !is_abstract_role(.button)
	assert is_widget_role(.slider)
	assert is_document_structure_role(.article)
	assert is_landmark_role(.navigation)
	assert is_live_region_role(.status)
	assert is_window_role(.dialog)
	assert is_windows_role(.dialog)
	assert !is_windows_role(.button)
	assert allows_name_from_content(.treeitem)
	assert !allows_name_from_content(.application)
	assert is_aria_attribute_name('aria-labelledby')
	assert !is_aria_attribute_name('aria-madeup')
}
