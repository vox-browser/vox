module domurl

fn test_lazy_url_query_owner_keeps_literal_leading_question_mark() {
	mut url := DOMURL.create_from_url('https://query-question.example.test/??name=value', none) or { panic(err) }
	mut params := url.search_params()
	assert params.get('?name') or { panic('lazy query owner stripped a literal question mark') } == 'value'
	assert params.get('name') == none
	params.append('next', '2')
	assert url.search() == '?%3Fname=value&next=2'
	assert params.to_string() == '%3Fname=value&next=2'
}

fn test_lazy_and_observed_query_owners_agree_after_href_and_search_replacement() {
	mut lazy := DOMURL.create_from_url('https://query-question.example.test/?old=1', none) or { panic(err) }
	mut observed := DOMURL.create_from_url(lazy.href(), none) or { panic(err) }
	query := observed.search_params()
	lazy.set_href('https://query-question.example.test/??new=2') or { panic(err) }
	observed.set_href(lazy.href()) or { panic(err) }
	assert lazy.search_params().params() == query.params()
	lazy.set_search('??updated=3')
	observed.set_search('??updated=3')
	assert lazy.search_params().params() == query.params()
	assert query.params() == [QueryParam{ name: '?updated', value: '3' }]
	assert voidptr(observed.search_params()) == voidptr(query)
	assert URLSearchParams.from_string('?updated=3').get('updated') or { '' } == '3'
}
