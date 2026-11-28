module browserextensions

import url

struct MatchPattern {
	scheme     string
	host       string
	subdomains bool
	port       ?u16
	path       string
}

fn parse_match_pattern(source string) !MatchPattern {
	if source == '<all_urls>' {
		return MatchPattern{ scheme: '*', host: '*', path: '/*' }
	}
	if source.len > 2048 || source.bytes().any(it <= 32 || it == 127)
		|| source.contains_any('#\\') {
		return error('Invalid URL match pattern "${source}".')
	}
	scheme, target := source.split_once('://') or {
		return error('URL match pattern needs a scheme: "${source}".')
	}
	if scheme !in ['http', 'https', '*'] {
		return error('Vox supports HTTP and HTTPS extension match patterns: "${source}".')
	}
	end_host := target.index('/') or {
		return error('URL match pattern needs a path: "${source}".')
	}
	authority := target[..end_host]
	host, port := parse_match_authority(authority) or {
		return error('Invalid host or port in URL match pattern "${source}".')
	}
	subdomains := host.starts_with('*.')
	hostname := if subdomains { host[2..] } else { host }
	if hostname == '*' && !subdomains {
		return MatchPattern{ scheme: scheme, host: '*', port: port, path: target[end_host..] }
	}
	parsed := url.parse_host(hostname, false) or {
		return error('Invalid host in URL match pattern "${source}".')
	}
	if hostname == '' || hostname.contains_any('*%@?') || (subdomains && !parsed.is_domain()) {
		return error('Invalid host in URL match pattern "${source}".')
	}
	return MatchPattern{ scheme: scheme, host: parsed.serialize(), subdomains: subdomains, port: port, path: target[end_host..] }
}

fn parse_match_authority(authority string) !(string, ?u16) {
	mut host_end := 0
	if authority.starts_with('[') {
		host_end = (authority.index(']') or { return error('Invalid IPv6 host') }) + 1
	}
	split := authority[host_end..].index(':') or {
		return authority, none
	}
	port_start := host_end + split
	port := authority[port_start + 1..]
	if port == '*' {
		return authority[..port_start], none
	}
	if port == '' || port.len > 5 || !port.bytes().all(it >= `0` && it <= `9`) || port.int() > 65535 {
		return error('Invalid port')
	}
	return authority[..port_start], u16(port.int())
}

fn (pattern MatchPattern) matches(address &url.URL, host string, path string) bool {
	if pattern.scheme != '*' && pattern.scheme != address.scheme {
		return false
	}
	if pattern.host != '*' && pattern.host != host
		&& !(pattern.subdomains && host.ends_with('.' + pattern.host)) {
		return false
	}
	if port := pattern.port {
		if port != address.port_or_default() {
			return false
		}
	}
	return matches_glob(pattern.path, path, false)
}

// The last star can absorb another byte if a later literal fails to match.
// Match pattern paths treat '?' literally, while include/exclude globs allow it.
fn matches_glob(pattern string, value string, question_mark bool) bool {
	mut pattern_index := 0
	mut value_index := 0
	mut star := -1
	mut star_end := 0
	for value_index < value.len {
		if pattern_index < pattern.len && pattern[pattern_index] == `*` {
			star = pattern_index
			star_end = value_index
			pattern_index++
		} else if pattern_index < pattern.len && (pattern[pattern_index] == value[value_index]
			|| (question_mark && pattern[pattern_index] == `?`)) {
			pattern_index++
			value_index++
		} else if star >= 0 {
			star_end++
			value_index = star_end
			pattern_index = star + 1
		} else {
			return false
		}
	}
	for pattern_index < pattern.len && pattern[pattern_index] == `*` {
		pattern_index++
	}
	return pattern_index == pattern.len
}
