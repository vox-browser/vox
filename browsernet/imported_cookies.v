module browsernet

import net.http
import os
import strconv
import time
import url

// Imported Netscape jars are read-only. They lack SameSite and partition keys,
// so use them only in a same-site context, never for third-party requests.
struct ImportedCookie {
	domain     string
	subdomains bool
	path       string
	secure     bool
	expires    i64
	name       string
	value      string
	order      int
}

fn imported_cookie_file() string {
	if path := os.getenv_opt('VOX_COOKIE_FILE') {
		return path
	}
	root := os.config_dir() or { return '' }
	return os.join_path(root, 'Vox', 'imported-cookies.txt')
}

fn valid_imported_cookie_name(name string) bool {
	if name == '' { return false }
	for byte in name.bytes() {
		if byte <= 32 || byte >= 127 || byte in '()<>@,;:\\"/[]?={}'.bytes() {
			return false
		}
	}
	return true
}

fn valid_imported_cookie_value(value string) bool {
	for byte in value.bytes() {
		if byte < 33 || byte >= 127 || byte in [u8(`"`), `,`, `;`, `\\`] {
			return false
		}
	}
	return true
}

fn parse_imported_cookies(contents string) []ImportedCookie {
	mut cookies := []ImportedCookie{}
	for raw_line in contents.split('\n') {
		line := if raw_line.ends_with('\r') { raw_line[..raw_line.len - 1] } else { raw_line }
		entry := if line.starts_with('#HttpOnly_') { line['#HttpOnly_'.len..] } else { line }
		if entry == '' || entry.starts_with('#') { continue }
		fields := entry.split('\t')
		if fields.len != 7 || fields[1] !in ['TRUE', 'FALSE']
			|| fields[3] !in ['TRUE', 'FALSE'] { continue }
		domain := fields[0].trim_left('.').to_lower()
		parsed := url.parse('https://${domain}/') or { continue }
		host := parsed.host or { continue }
		if domain == '' || host.serialize() != domain || parsed.includes_credentials()
			|| parsed.port != none || parsed.query != none || parsed.fragment != none
			|| parsed.serialize_path() != '/' { continue }
		if fields[1] == 'TRUE' && host.registrable_domain() == none { continue }
		if !fields[2].starts_with('/') || fields[2].contains('\r')
			|| fields[2].contains('\n') { continue }
		expires := strconv.parse_int(fields[4], 10, 64) or { continue }
		if expires < 0 || !valid_imported_cookie_name(fields[5])
			|| !valid_imported_cookie_value(fields[6]) { continue }
		cookies << ImportedCookie{
			domain: domain
			subdomains: fields[1] == 'TRUE'
			path: fields[2]
			secure: fields[3] == 'TRUE'
			expires: expires
			name: fields[5]
			value: fields[6]
			order: cookies.len
		}
	}
	return cookies
}

fn imported_cookie_header(contents string, resource_url string, source_url string, now i64) string {
	request := url.parse(resource_url) or { return '' }
	if request.scheme !in ['http', 'https'] { return '' }
	source := url.parse(source_url) or { return '' }
	if !request.origin().is_same_site(source.origin()) { return '' }
	host := (request.host or { return '' }).serialize().to_lower()
	path := request.serialize_path()
	mut matches := []ImportedCookie{}
	for cookie in parse_imported_cookies(contents) {
		if cookie.expires != 0 && cookie.expires <= now { continue }
		if cookie.secure && request.scheme != 'https' { continue }
		if host != cookie.domain && !(cookie.subdomains && host.ends_with('.' + cookie.domain)) {
			continue
		}
		if path != cookie.path && !(path.starts_with(cookie.path)
			&& (cookie.path.ends_with('/') || (path.len > cookie.path.len
				&& path[cookie.path.len] == `/`))) { continue }
		matches << cookie
	}
	matches.sort_with_compare(fn (a &ImportedCookie, b &ImportedCookie) int {
		if a.path.len != b.path.len { return b.path.len - a.path.len }
		return a.order - b.order
	})
	return matches.map(it.name + '=' + it.value).join('; ')
}

fn imported_cookie_headers(resource_url string, source_url string) http.Header {
	mut headers := http.new_header()
	path := imported_cookie_file()
	if path == '' || os.file_size(path) > 1024 * 1024 { return headers }
	contents := os.read_file(path) or { return headers }
	value := imported_cookie_header(contents, resource_url, source_url, time.now().unix())
	if value != '' { headers.add(.cookie, value) }
	return headers
}
