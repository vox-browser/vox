module optimizedsites

fn test_catalog_matches_the_optimized_sites() {
	assert sites.len == 4
	assert sites.map(it.address) == ['https://en.wikipedia.org/wiki/Main_Page', 'https://old.reddit.com/r/programming/', 'https://vlang.io/', 'https://news.ycombinator.com/']
}

fn test_comparison_bookmarks_follow_the_optimized_sites_once() {
	assert bookmarked_sites.len == 18
	assert bookmarked_sites[..4] == sites
	for site in forum_news_sites {
		assert bookmarked_sites.filter(it.address == site.address).len == 1
	}
}
