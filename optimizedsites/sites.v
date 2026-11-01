module optimizedsites

import url

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
]

pub fn allows(address string) bool {
	parsed := url.parse(address) or { return false }
	if parsed.scheme !in ['http', 'https'] { return false }
	host := parsed.host or { return false }
	name := host.serialize().trim_right('.').to_lower()
	for site in sites {
		if name == site.host || name.ends_with('.' + site.host) { return true }
	}
	return false
}
