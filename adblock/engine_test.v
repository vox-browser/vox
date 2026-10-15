module adblock

fn test_full_engine_network_options_and_exceptions() {
	mut engine := new_engine('||advert.example^$third-party,script,domain=theverge.com\n@@||advert.example/allowed.js$script\n||important.example^$important\n@@||important.example^\n||disabled.example^\n||disabled.example^$badfilter\n||first.example^$first-party\n||regex.example^$image\n/collect\\d+/$xmlhttprequest\n') or { panic(err) }
	defer { engine.close() }
	cases := [
		Request{url: 'https://advert.example/ad.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://advert.example/allowed.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://advert.example/ad.js', source_url: 'https://other.example/', request_type: 'script'},
		Request{url: 'https://advert.example/ad.png', source_url: 'https://www.theverge.com/', request_type: 'image'},
		Request{url: 'https://important.example/ad.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://disabled.example/ad.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://first.example/ad.js', source_url: 'https://sub.first.example/', request_type: 'script'},
		Request{url: 'https://first.example/ad.js', source_url: 'https://www.theverge.com/', request_type: 'script'},
		Request{url: 'https://metrics.example/collect123/', source_url: 'https://www.theverge.com/', request_type: 'xmlhttprequest'},
	]
	expected := [true, false, false, false, true, false, true, false, true]
	for index, request in cases {
		decision := engine.check(request)
		assert decision.error == '', decision.error
		assert decision.blocked == expected[index], '${request}: ${decision}'
		if decision.blocked { assert decision.rule != '' }
	}
	assert engine.check(cases[1]).exception
}

fn test_redirect_resources_and_query_filtering() {
	mut engine := new_engine('||redirect.example^$script,redirect=noop.js\n||query.example^$removeparam=tracking\n') or { panic(err) }
	defer { engine.close() }
	redirect := engine.check(Request{url: 'https://redirect.example/ad.js', source_url: 'https://www.theverge.com/', request_type: 'script'})
	assert redirect.error == '', redirect.error
	assert redirect.blocked
	assert redirect.redirect_url.starts_with('data:'), redirect.redirect_url
	query := engine.check(Request{url: 'https://query.example/article?tracking=id&content=story', source_url: 'https://www.theverge.com/', request_type: 'xmlhttprequest'})
	assert query.error == '', query.error
	assert !query.blocked
	assert query.redirect_url == 'https://query.example/article?content=story'
}

fn test_adblock_default_enabled_and_switch() {
	assert is_enabled()
	set_enabled(false)
	assert !check(Request{url: 'https://doubleclick.net/ads.js', source_url: 'https://www.theverge.com/', request_type: 'script'}).blocked
	set_enabled(true)
	assert is_enabled()
	decision := check(Request{url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url: 'https://www.theverge.com/', request_type: 'script'})
	assert decision.error == '', decision.error
	assert decision.blocked
	assert decision.rule != ''
}
