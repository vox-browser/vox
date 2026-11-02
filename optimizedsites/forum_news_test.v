module optimizedsites

import json2
import os

struct ForumNewsCatalog {
	sites []ForumNewsCatalogSite
}

struct ForumNewsCatalogSite {
	name string
	url string
}

fn test_forum_news_bookmarks_match_every_registered_site_in_catalog_order() {
	catalog := json2.decode[ForumNewsCatalog](os.read_file(os.join_path(@DIR,
		'../Tests/Browser/Brave/forum-news.json'))!)!
	assert forum_news_sites.len == catalog.sites.len
	for index, site in catalog.sites {
		assert forum_news_sites[index].title == site.name
		assert forum_news_sites[index].address == site.url
	}
}
