module xlink

fn test_attribute_name_vocabulary_and_order() {
	assert attribute_names.len == 10
	assert attribute_names[0] == 'actuate'
	assert attribute_names[3] == 'href'
	assert attribute_names.last() == 'type'
	assert is_xlink_attribute('arcrole')
	assert !is_xlink_attribute('HREF')
}
