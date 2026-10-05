module domurl

fn test_urlencoded_parser_preserves_each_tuple_bom_and_replaces_malformed_utf8() {
	params := URLSearchParams.from_string('?%EF%BB%BFname=%EF%BB%BFvalue&bad=%EF%BB%BF%FF&tail=%E2%82')
	assert params.params() == [
		QueryParam{ name: '\ufeffname', value: '\ufeffvalue' },
		QueryParam{ name: 'bad', value: '\ufeff�' },
		QueryParam{ name: 'tail', value: '�' },
	]
	assert params.get('name') == none
	assert params.get('\ufeffname') or { panic('BOM-prefixed name was lost') } == '\ufeffvalue'
	assert params.to_string() == '%EF%BB%BFname=%EF%BB%BFvalue&bad=%EF%BB%BF%EF%BF%BD&tail=%EF%BF%BD'
}

fn test_domurl_query_owner_keeps_bom_across_parse_mutation_and_replacement() {
	mut url := DOMURL.create_from_url('https://query-bom.example.test/?%EF%BB%BFname=%EF%BB%BFvalue', none) or { panic(err) }
	mut params := url.search_params()
	assert params.get('\ufeffname') or { panic('query owner dropped BOM') } == '\ufeffvalue'
	params.append('extra', '\ufeff')
	assert url.search() == '?%EF%BB%BFname=%EF%BB%BFvalue&extra=%EF%BB%BF'
	url.set_search('?a=%EF%BB%BF&%EF%BB%BF=b')
	assert voidptr(url.search_params()) == voidptr(params)
	assert params.params() == [QueryParam{ name: 'a', value: '\ufeff' }, QueryParam{ name: '\ufeff', value: 'b' }]
}
