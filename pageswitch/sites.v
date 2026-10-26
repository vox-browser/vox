module pageswitch

import net.urllib

// Deliberately small, built-in registry. Rules enable paint comparison, never
// assume that a site's shell is unchanged. Unknown routes use ordinary replay.
pub struct Site {
pub:
	host string
	name string
}

pub const sites = [Site{'old.reddit.com', 'Old Reddit listings'}]

fn listing(address string) ?(string, string) {
	parsed := urllib.parse(address) or { return none }
	if parsed.scheme != 'https' || parsed.host != sites[0].host
		|| address.contains('@') || address.contains('?') || address.contains('#')
		|| parsed.raw_query != '' || parsed.fragment != '' {
		return none
	}
	parts := parsed.path.trim('/').split('/')
	if parts.len < 2 || parts.len > 3 || parts[0] != 'r' || parts[1] == '' { return none }
	if !parts[1].bytes().all((it >= `a` && it <= `z`) || (it >= `A` && it <= `Z`)
		|| (it >= `0` && it <= `9`) || it == `_`) {
		return none
	}
	sort := if parts.len == 2 { 'hot' } else { parts[2] }
	if sort !in ['hot', 'new', 'rising', 'top', 'controversial'] { return none }
	return parts[1].to_lower(), sort
}

pub fn supports(from string, to string) bool {
	community, sort := listing(from) or { return false }
	next_community, next_sort := listing(to) or { return false }
	return community == next_community && sort != next_sort
}
