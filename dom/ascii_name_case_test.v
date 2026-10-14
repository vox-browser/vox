module dom

fn test_ascii_name_folding_borrows_lowercase_and_preserves_non_ascii() {
	lower := 'data-name-café'
	assert to_ascii_lowercase(lower).str == lower.str
	assert to_ascii_lowercase('DATA-CafÉ') == 'data-cafÉ'
	assert to_ascii_lowercase('ÉK') == 'ÉK'
	assert to_ascii_lowercase('') == ''
	name := QualifiedName.new('DATA-CafÉ', none, none)
	assert name.local_name == 'DATA-CafÉ'
	assert name.lowercased_local_name == 'data-cafÉ'
}

fn test_qualified_name_hash_keeps_existing_utf8_byte_hash() {
	assert qualified_name_hash_string('') == u64(1469598103934665603)
	assert qualified_name_hash_string('hello') == u64(25347132070217633)
	assert qualified_name_hash_string('é') == u64(11062259058118930795)
}
