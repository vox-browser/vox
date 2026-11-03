module main

import fetch
import http
import requestserver
import strconv
import time

fn install_browser_script_resource_cache() {
	requestserver.install_native_response_cache_provider(browser_cached_script_response)
}

// Reuse explicitly public, fresh responses. Scripts additionally require an
// immutable declaration; ordinary Fetch entries require omitted credentials.
// Credential-specific variants and revalidation modes keep their network path.
fn browser_cached_script_response(request &fetch.Request) ?&fetch.Response {
	script := request.destination_is_script_like()
	anonymous_fetch := request.destination == none && request.credentials_mode == .omit
	if request.method != 'GET' || (!script && !anonymous_fetch)
		|| request.cache_mode != .default || request.header_list.contains('Authorization')
		|| (anonymous_fetch && request.header_list.contains('Cookie'))
		|| request.header_list.contains('Range')
		|| request.current_url().scheme() !in ['http', 'https'] { return none }
	if control := request.header_list.get('Cache-Control') {
		if http.contains_cache_control_directive(control, 'no-store')
			|| http.contains_cache_control_directive(control, 'no-cache') { return none }
	}
	address := request.current_url().serialize()
	keys := if script { [resource_accept_cache_key(address, 'script'), address] } else { [address] }
	for key in keys {
		path := browser_cache_entry_path(browser_cache_root(), 'resources', key)
		if (read_browser_cache_entry(path + '.status') or { continue }) != '200' { continue }
		if (read_browser_cache_entry(path + '.url') or { continue }) != address { continue }
		encoded := read_browser_cache_entry(path + '.headers.json') or { continue }
		headers := decode_browser_cached_response_headers(encoded) or { continue }
		if key == address && resource_response_varies_on_accept(headers) { continue }
		mut fields := http.HeaderList.create()
		for header in headers { fields.append(http.Header{name: header.name, value: header.value}) }
		control := fields.get('Cache-Control') or { continue }
		if !http.contains_cache_control_directive(control, 'public')
			|| (script && !http.contains_cache_control_directive(control, 'immutable'))
			|| http.contains_cache_control_directive(control, 'private')
			|| http.contains_cache_control_directive(control, 'no-store')
			|| http.contains_cache_control_directive(control, 'no-cache')
			|| fields.contains('Set-Cookie') { continue }
		if http.vary_header_names(fields).any(it.to_lower() !in ['accept', 'accept-encoding']) { continue }
		// Date and Age conservatively establish freshness without inventing a
		// receipt timestamp for older cache entries or imported response bytes.
		date := time.parse_rfc2616(fields.get('Date') or { continue }) or { continue }
		now := time.now().unix_milli()
		stamp := if date.unix_milli() < now { date.unix_milli() } else { now }
		seconds := strconv.parse_int(http.extract_cache_control_directive(control, 'max-age') or { continue }, 10, 64) or { continue }
		if seconds <= 0 || seconds > 9223372036854775 { continue }
		mut age_seconds := i64(0)
		if age := fields.get('Age') {
			age_seconds = strconv.parse_int(age, 10, 64) or { continue }
		}
		if age_seconds < 0 || age_seconds >= seconds { continue }
		if now - stamp >= (seconds - age_seconds) * 1000 { continue }
		body := read_browser_cache_entry(path) or { continue }
		mut response := fetch.Response.create()
		response.status = 200
		response.url_list = request.url_list.clone()
		response.header_list = fields
		response.set_body_bytes(body.bytes())
		return response
	}
	return none
}
