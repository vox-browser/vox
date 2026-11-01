module optimizedsites

fn test_catalog_matches_the_optimized_sites_and_hosts_are_checked_as_urls() {
	assert sites.len == 3
	assert sites.map(it.address) == ['https://en.wikipedia.org/wiki/Main_Page', 'https://old.reddit.com/r/programming/', 'https://vlang.io/']
	for address in ['https://www.wikipedia.org/', 'https://en.wikipedia.org/wiki/V',
		'https://en.wikipedia.org/wiki/Main_Page',
		'http://WIKIPEDIA.ORG./', 'https://old.reddit.com/r/worldnews/',
		'https://vlang.io/', 'https://docs.vlang.io/'] {
		assert allows(address), address
	}
	for address in ['', 'https://reddit.com/', 'https://new.reddit.com/',
		'https://vlang.io.evil.test/', 'https://notwikipedia.org/',
		'https://old.reddit.com@evil.test/', 'https://evil.test/?vlang.io',
		'file:///tmp/wikipedia.org', 'data:text/html,vlang.io', 'javascript:alert(1)'] {
		assert !allows(address), address
	}
}
