module loader

import dom
import fetch
import http

fn observed_fetch_user_agent(address string, explicit string) !string {
	url := dom.URL{value: address}
	mut request := fetch.Request.create()
	request.set_url(url)
	request.origin = fetch.RequestOrigin{is_client: false, origin: url.origin()}
	request.mode = .same_origin
	request.cache_mode = .no_store
	if explicit != '' { request.header_list.append(http.Header{name: 'User-Agent', value: explicit}) }
	host := &fetch.FetchHost{perform: fn (actual &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.url_list = actual.url_list.clone()
		response.set_body_bytes((actual.header_list.get('User-Agent') or { return error('Missing user agent') }).bytes())
		return response
	}}
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), host).response() or { return error('Missing response') }
	assert !response.is_network_error()
	// The network request is a clone; adding its default must not mutate input.
	assert request.header_list.contains('User-Agent') == (explicit != '')
	body := response.unsafe_response().fetch_response_body_bytes() or { return error('Missing response body') }
	return body.bytestr()
}

fn test_fetch_and_navigator_loader_identity_share_configuration_and_site_rules() {
	mut resource := initialize()
	defer { initialize() }
	plain := dom.URL{value: 'https://identity.test/data'}
	compat := dom.URL{value: 'https://compat-identity.test/data'}
	assert observed_fetch_user_agent(plain.serialize(), '')! == resource.user_agent_for_url(plain)
	resource.set_user_agent('Mozilla/5.0 Ladybird/1.0 Chrome/146.0.0.0 Safari/537.36')
	mut rules := SiteCompatibilityData{}
	rules.add_rule(SiteCompatibilityRule.create(['https://compat-identity.test/*'], [.hide_ladybird], [])!)
	resource.set_site_compatibility_data(rules)
	assert observed_fetch_user_agent(compat.serialize(), '')! == 'Mozilla/5.0 Chrome/146.0.0.0 Safari/537.36'
	assert observed_fetch_user_agent(plain.serialize(), '')! == resource.user_agent_for_url(plain)
	resource.set_user_agent('Configured Agent/2')
	assert observed_fetch_user_agent(plain.serialize(), '')! == 'Configured Agent/2'
	assert observed_fetch_user_agent(compat.serialize(), 'Explicit Agent/3')! == 'Explicit Agent/3'
}

fn test_worker_fetch_identity_uses_browser_default_before_loader_initialization() {
	previous := loader_global_resource_loader
	loader_global_resource_loader = unsafe { nil }
	defer { loader_global_resource_loader = previous }
	install_fetch_user_agent_provider()
	assert observed_fetch_user_agent('https://worker-identity.test/entry.js', '')! == default_user_agent()
}
