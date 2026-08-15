module http

fn range_of(value string) ?ContentRangeValues {
	mut list := HeaderList.create()
	list.append(Header{ name: 'Content-Range', value: value })
	return list.extract_content_range_values()
}

fn test_extract_content_range_basic() {
	values := range_of('bytes 0-499/1234') or { panic('expected a parse') }
	assert values.first_byte_pos == u64(0)
	assert values.last_byte_pos == u64(499)
	assert values.complete_length? == u64(1234)
}

fn test_extract_content_range_star_complete_length() {
	values := range_of('bytes 200-999/*') or { panic('expected a parse') }
	assert values.first_byte_pos == u64(200)
	assert values.last_byte_pos == u64(999)
	// "*" means the complete length is unknown (none).
	assert values.complete_length == none
}

fn test_extract_content_range_large_values() {
	values := range_of('bytes 0-999999/1000000') or { panic('expected a parse') }
	assert values.first_byte_pos == u64(0)
	assert values.last_byte_pos == u64(999999)
	assert values.complete_length? == u64(1000000)
}

fn test_extract_content_range_absent_is_failure() {
	list := HeaderList.create()
	assert list.extract_content_range_values() == none
}

fn test_extract_content_range_malformed_is_failure() {
	// Missing prefix / wrong separator.
	assert range_of('0-499/1234') == none
	assert range_of('bytes=0-499/1234') == none
	// Missing components.
	assert range_of('bytes 0-499') == none
	assert range_of('bytes -499/1234') == none
	assert range_of('bytes 0-/1234') == none
	assert range_of('bytes 0-499/') == none
	// Trailing garbage / non-digit content must fail (the whole value is consumed).
	assert range_of('bytes 0-499/12x') == none
	assert range_of('bytes 0-499/**') == none
	assert range_of('bytes a-499/1234') == none
}
