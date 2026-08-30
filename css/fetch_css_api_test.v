@[has_globals]
module css

import dom
import fetch

__global css_fetch_response_body = []u8{}

fn css_fetch_test_host(request &fetch.Request) !&fetch.Response {
	assert request.current_url().serialize() == 'https://example.test/assets/font.woff2'
	assert request.mode == .cors
	assert request.credentials_mode == .same_origin
	assert request.destination or { panic('missing destination') } == .font
	assert (request.origin.origin or { panic('missing origin') }).value == 'https://example.test'
	assert (request.referrer.url or { panic('missing referrer') }).serialize() == 'https://example.test/styles/main.css'
	assert request.initiator_type or { panic('missing initiator') } == .script
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	response.body = 'font-data'.bytes()
	return response
}

fn css_fetch_test_process_response(_ &fetch.Response, body fetch.BodyBytes) {
	assert body.kind == .bytes
	css_fetch_response_body = body.bytes.clone()
}

fn test_fetch_a_style_resource_dispatches_through_fetch_runtime() {
	css_fetch_response_body = []
	declaration := &CSSStyleProperties{}
	environment := CSSFetchEnvironmentSettings{
		api_base_url: 'https://example.test/styles/main.css'
		origin: 'https://example.test'
	}
	rule_or_declaration := RuleOrDeclaration.from_style_declaration(declaration, environment)
	host := fetch.FetchHost{
		perform: css_fetch_test_host
	}
	controller := fetch_a_style_resource('../assets/font.woff2', rule_or_declaration, .font, .cors, css_fetch_test_process_response, host) or { panic('fetch was not started') }
	assert controller.state() == .ongoing
	assert css_fetch_response_body == 'font-data'.bytes()
}
