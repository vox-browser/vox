module optimizedsites

pub struct Site {
pub:
	title string
	address string
	host string
}

// Keep this catalog aligned with the confirmed comparisons in OPTIMIZED_SITES.md.
pub const wikipedia_address = 'https://en.wikipedia.org/wiki/Main_Page'
pub const reddit_address = 'https://old.reddit.com/r/programming/'

pub const sites = [
	Site{'Wikipedia', wikipedia_address, 'wikipedia.org'},
	Site{'Old Reddit', reddit_address, 'old.reddit.com'},
	Site{'vlang.io', 'https://vlang.io/', 'vlang.io'},
	Site{'Hacker News', 'https://news.ycombinator.com/', 'news.ycombinator.com'},
]
