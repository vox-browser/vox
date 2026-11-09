module main

import cachepolicy
import fetch
import http
import requestserver
import time

fn install_browser_script_resource_cache() {
	requestserver.install_native_response_cache_provider(browser_cached_script_response)
}

// Reuse explicitly public, fresh responses. Scripts additionally require an
// immutable declaration; credentialed Fetch entries require one as well.
// Credential-specific variants and revalidation modes keep their network path.
fn browser_cached_script_response(request &fetch.Request) ?&fetch.Response {
	script := request.destination_is_script_like()
	ordinary_fetch := request.destination == none
	require_immutable := script || request.credentials_mode != .omit
	if (!script && !ordinary_fetch)
		|| request.current_url().scheme() !in ['http', 'https'] { return none }
	address := request.current_url().serialize()
	accept := request.header_list.get('Accept') or { '*/*' }
	keys := if script { [resource_accept_cache_key_for_header(address, accept), address] } else { [address] }
	for key in keys {
		path := browser_cache_entry_path(browser_cache_root(), 'resources', key)
		entry := browser_resource_cache_entry(path) or { continue }
		if entry.final_url != address { continue }
		headers := entry.headers
		if key == address && resource_response_varies_on_accept(headers) { continue }
		decision := cachepolicy.evaluate(request.cache_policy_request(), entry.metadata,
			cachepolicy.ReuseOptions{storage: .disk, require_immutable: require_immutable}, time.now().unix_milli())
		if !decision.can_reuse() { continue }
		mut fields := http.HeaderList.create()
		for header in headers {
			if header.name.to_lower() != 'age' { fields.append(http.Header{name: header.name, value: header.value}) }
		}
		fields.append(http.Header{name: 'Age', value: decision.age_header_value()})
		mut response := fetch.Response.create()
		response.status = 200
		response.url_list = request.url_list.clone()
		response.header_list = fields
		response.set_body_bytes(entry.body.bytes())
		return response
	}
	return none
}
