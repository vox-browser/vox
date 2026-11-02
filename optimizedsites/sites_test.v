module optimizedsites

fn test_catalog_matches_the_optimized_sites_and_hosts_are_checked_as_urls() {
	assert sites.len == 4
	assert sites.map(it.address) == ['https://en.wikipedia.org/wiki/Main_Page', 'https://old.reddit.com/r/programming/', 'https://vlang.io/', 'https://news.ycombinator.com/']
	for address in ['https://www.wikipedia.org/', 'https://en.wikipedia.org/wiki/V',
		'https://en.wikipedia.org/wiki/Main_Page',
		'http://WIKIPEDIA.ORG./', 'https://old.reddit.com/r/worldnews/',
		'https://vlang.io/', 'https://docs.vlang.io/', 'https://news.ycombinator.com/',
		'https://news.ycombinator.com/item?id=1'] {
		assert allows(address), address
	}
	for address in ['', 'https://reddit.com.evil.test/', 'https://reddit.com@evil.test/',
		'https://vlang.io.evil.test/', 'https://notwikipedia.org/',
		'https://old.reddit.com@evil.test/', 'https://evil.test/?vlang.io',
		'https://ycombinator.com/', 'https://news.ycombinator.com.evil.test/',
		'https://news.ycombinator.com@evil.test/',
		'file:///tmp/wikipedia.org', 'data:text/html,vlang.io', 'javascript:alert(1)'] {
		assert !allows(address), address
	}
}

fn test_comparison_bookmarks_are_allowed_without_accepting_lookalike_hosts() {
	assert bookmarked_sites.len == 18
	assert bookmarked_sites[..4] == sites
	for site in forum_news_sites {
		assert bookmarked_sites.filter(it.address == site.address).len == 1
		assert allows(site.address), site.address
		assert allows('https://${site.host}/article?test=1'), site.host
		assert !allows('https://${site.host}.evil.test/'), site.host
		assert !allows('https://${site.host}@evil.test/'), site.host
	}
}
