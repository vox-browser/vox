module encoding

import url

fn gb18030_query(input string, encoding_name string) string {
	base := url.parse('https://example.com/') or { panic('base') }
	parsed := url.parse_with_base_and_encoding('https://example.com/?' + input, &base, encoding_name) or {
		panic('parse')
	}
	return parsed.query or { '' }
}

fn test_url_queries_of_gb18030_and_gbk_documents_use_their_encoders() {
	for input, expected in {
		's':              's'
		'€':         '%A2%E3'
		'丂':         '%81@'
		'':         '%A1@'
		'':         '%FE%FE'
		'':         '%26%2358853%3B'
		'\U0001F4A9':     '%949%DA3'
		'':         '%815%F47'
		'':         '%836%C80'
		'…':         '%A1%AD'
		'︐':         '%A6%D9'
		'龴':         '%FEY'
		'a b"':           'a%20b%22'
	} {
		assert gb18030_query(input, 'gb18030') == expected, input
	}
	assert gb18030_query('€', 'GBK') == '%80'
	assert gb18030_query('\U0001F4A9', 'gbk') == '%26%23128169%3B'
	// UTF-8 documents and non-special schemes keep UTF-8 queries.
	assert gb18030_query('€', 'UTF-8') == '%E2%82%AC'
	base := url.parse('https://example.com/') or { panic('base') }
	opaque := url.parse_with_base_and_encoding('foo://host/?€', &base, 'gb18030') or { panic('parse') }
	assert (opaque.query or { '' }) == '%E2%82%AC'
}
