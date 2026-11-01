module optimizedsites

import encoding.base64
import url

// Embedded originals make the default bar complete before any navigation.
const wikipedia_icon = 'data:image/x-icon;base64,' + base64.encode($embed_file('assets/wikipedia.ico').to_bytes())
const reddit_icon = 'data:image/png;base64,' + base64.encode($embed_file('assets/reddit.png').to_bytes())
const vlang_icon = 'data:image/png;base64,' + base64.encode($embed_file('assets/vlang.png').to_bytes())

pub fn favicon_data_url(address string) string {
	parsed := url.parse(address) or { return '' }
	if parsed.scheme !in ['http', 'https'] { return '' }
	host := parsed.host or { return '' }
	name := host.serialize().trim_right('.').to_lower()
	for site in sites {
		if name != site.host && !name.ends_with('.' + site.host) { continue }
		return match site.host {
			'wikipedia.org' { wikipedia_icon }
			'old.reddit.com' { reddit_icon }
			'vlang.io' { vlang_icon }
			else { '' }
		}
	}
	return ''
}
