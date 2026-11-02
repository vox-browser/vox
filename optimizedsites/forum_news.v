module optimizedsites

// Navigation and bookmark coverage for the forum/news comparison session.
// Membership records a comparison target, not a completed optimization.
// Keep the addresses aligned with Tests/Browser/Brave/forum-news.json.
pub const forum_news_sites = [
	Site{'Hacker News', 'https://news.ycombinator.com/', 'news.ycombinator.com'},
	Site{'Reddit', 'https://www.reddit.com/', 'reddit.com'},
	Site{'Lobsters', 'https://lobste.rs/', 'lobste.rs'},
	Site{'Slashdot', 'https://slashdot.org/', 'slashdot.org'},
	Site{'Stack Overflow', 'https://stackoverflow.com/questions', 'stackoverflow.com'},
	Site{'BBC News', 'https://www.bbc.com/news', 'bbc.com'},
	Site{'CNN', 'https://edition.cnn.com/', 'cnn.com'},
	Site{'The Guardian', 'https://www.theguardian.com/international', 'theguardian.com'},
	Site{'The Verge', 'https://www.theverge.com/', 'theverge.com'},
	Site{'Pikabu', 'https://pikabu.ru/', 'pikabu.ru'},
	Site{'TechCrunch', 'https://techcrunch.com/', 'techcrunch.com'},
	Site{'Engadget', 'https://www.engadget.com/', 'engadget.com'},
	Site{'The Register', 'https://www.theregister.com/', 'theregister.com'},
	Site{'Slate', 'https://slate.com/', 'slate.com'},
	Site{'WIRED', 'https://www.wired.com/', 'wired.com'},
]

pub const bookmarked_sites = collect_bookmarked_sites()

fn collect_bookmarked_sites() []Site {
	mut result := sites.clone()
	for site in forum_news_sites {
		if !result.any(it.address == site.address) { result << site }
	}
	return result
}
