module http

fn test_combine_appends_when_name_absent() {
	mut list := HeaderList.create()
	list.combine(Header{ name: 'X-Foo', value: 'a' })
	assert list.get('X-Foo')? == 'a'
	assert list.headers().len == 1
}

fn test_combine_merges_when_name_present() {
	mut list := HeaderList.create()
	list.append(Header{ name: 'X-Foo', value: 'a' })
	list.combine(Header{ name: 'X-Foo', value: 'b' })
	// The first matching header's value is extended with ", b" rather than a new entry being added.
	assert list.headers().len == 1
	assert list.headers()[0].value == 'a, b'
	// The name match is ASCII case-insensitive.
	list.combine(Header{ name: 'x-foo', value: 'c' })
	assert list.headers()[0].value == 'a, b, c'
	assert list.headers().len == 1
}

fn test_extract_length_absent_is_null() {
	list := HeaderList.create()
	assert list.extract_length() is ExtractLengthNull
}

fn test_extract_length_single_value() {
	mut list := HeaderList.create()
	list.append(Header{ name: 'Content-Length', value: '42' })
	result := list.extract_length()
	assert result is u64
	if result is u64 {
		assert result == u64(42)
	}
}

fn test_extract_length_agreeing_values() {
	mut list := HeaderList.create()
	list.append(Header{ name: 'Content-Length', value: '42' })
	list.append(Header{ name: 'Content-Length', value: '42' })
	result := list.extract_length()
	assert result is u64
	if result is u64 {
		assert result == u64(42)
	}
}

fn test_extract_length_conflicting_values_is_failure() {
	mut list := HeaderList.create()
	list.append(Header{ name: 'Content-Length', value: '42' })
	list.append(Header{ name: 'Content-Length', value: '43' })
	assert list.extract_length() is ExtractLengthFailure
}

fn test_extract_length_invalid_value_is_null() {
	mut alpha := HeaderList.create()
	alpha.append(Header{ name: 'Content-Length', value: 'abc' })
	assert alpha.extract_length() is ExtractLengthNull

	mut dotted := HeaderList.create()
	dotted.append(Header{ name: 'Content-Length', value: '4.5' })
	assert dotted.extract_length() is ExtractLengthNull
}

fn test_extract_length_overflow_is_null() {
	mut list := HeaderList.create()
	list.append(Header{ name: 'Content-Length', value: '99999999999999999999999' })
	assert list.extract_length() is ExtractLengthNull
}
