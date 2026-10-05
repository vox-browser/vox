@[has_globals]
module html

import css
import dom
import fetch
import http

__global (
	security_policy_host_calls       int
	security_policy_host_url         string
	security_policy_violation_events int
)

fn security_policy_host(request &fetch.Request) !&fetch.Response {
	security_policy_host_calls++
	security_policy_host_url = request.current_url().serialize()
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'image/png' })
	return response
}

fn security_policy_settings(policy string, disposition CSPPolicyDisposition) &EnvironmentSettingsObject {
	mut document := dom.Document.create(dom.URL{value: 'https://source.test/page'})
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body() or { panic(err) }
	window := WindowModel.create_top_level(document, none, 'security-policy') or { panic(err) }
	mut realm := &ScriptingRealm{}
	mut settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	settings.set_policy_container(&PolicyContainer{
		csp_list: if policy == '' { []SerializedCSPPolicy{} } else { [
				parse_response_csp_policy(policy, disposition, document.origin()),
			] }
	})
	return settings
}

fn security_policy_request(settings &EnvironmentSettingsObject, target string, destination fetch.Destination) &fetch.Request {
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.set_url(dom.URL{value: target})
	request.destination = destination
	request.cache_mode = .no_store
	fetch.populate_request_from_client(mut request)
	security_policy_host_calls = 0
	return request
}

fn test_main_fetch_enforces_client_csp_before_the_host_runs() {
	settings := security_policy_settings("img-src 'self'", .enforce)
	request := security_policy_request(settings, 'https://other.test/image.png', .image)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	}).response()?
	assert response.is_network_error()
	assert security_policy_host_calls == 0
	global := request.csp_global?
	assert global.reports.len == 1
	assert global.reports[0].effective_directive == 'img-src'
	assert global.reports[0].disposition == .enforce
}

fn test_main_fetch_reports_before_mixed_content_upgrade_and_allows_report_only() {
	settings := security_policy_settings('img-src https:', .report)
	request := security_policy_request(settings, 'http://other.test/image.png', .image)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	}).response()?
	assert !response.is_network_error()
	assert security_policy_host_calls == 1
	assert security_policy_host_url == 'https://other.test/image.png'
	global := request.csp_global?
	assert global.reports.len == 1
	assert global.reports[0].blocked_uri == 'http://other.test/image.png'
	assert global.reports[0].disposition == .report
}

fn test_main_fetch_blocks_active_mixed_content_and_ip_or_imageset_passive_content() {
	settings := security_policy_settings('', .enforce)
	for target in ['http://other.test/script.js', 'http://0.0.0.0/image.png'] {
		request := security_policy_request(settings, target, if target.ends_with('.js') {
			.script
		} else {
			.image
		})
		response := fetch.main_fetch(fetch.FetchParams.create(request,
			fetch.FetchTimingInfo.create()), fetch.FetchHost{ perform: security_policy_host }).response()?
		assert response.is_network_error()
		assert security_policy_host_calls == 0
	}
	mut imageset := security_policy_request(settings, 'http://other.test/image.png', .image)
	imageset.initiator = .image_set
	response := fetch.main_fetch(fetch.FetchParams.create(imageset, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	}).response()?
	assert response.is_network_error()
	assert security_policy_host_calls == 0
}

fn test_main_fetch_enforces_integrity_policy_and_ignores_report_only_block() {
	mut settings := security_policy_settings('', .enforce)
	settings.set_policy_container(&PolicyContainer{
		integrity_policy: IntegrityPolicy{
			sources:              ['inline']
			blocked_destinations: [.script]
		}
	})
	request := security_policy_request(settings, 'https://other.test/script.js', .script)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	}).response()?
	assert response.is_network_error()
	assert security_policy_host_calls == 0
	mut allowed := security_policy_request(settings, 'data:text/javascript,1', .script)
	assert !fetch.main_fetch(fetch.FetchParams.create(allowed, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	}).response()?.is_network_error()
}

fn test_css_fetch_preserves_its_real_settings_client_and_applies_policy() {
	settings := security_policy_settings("img-src 'none'", .enforce)
	document := settings.responsible_document()?
	environment := css.CSSFetchEnvironmentSettings.from_document(document)
	assert environment.client != none
	declaration := css.CSSStyleProperties.create()
	context := css.RuleOrDeclaration.from_style_declaration(declaration, environment)
	security_policy_host_calls = 0
	controller := css.fetch_a_style_resource(css.StyleResourceURL('https://other.test/image.png'),
		context, .image, .no_cors, fn (_ &fetch.Response, _ fetch.BodyBytes) {}, fetch.FetchHost{
		perform: security_policy_host
	})?
	assert security_policy_host_calls == 0
	assert controller.state() == .ongoing
}

fn test_main_fetch_checks_the_internal_response_security_before_exposing_it() {
	settings := security_policy_settings("img-src 'self'", .enforce)
	for target in ['https://other.test/image.png', 'http://source.test/image.png'] {
		request := security_policy_request(settings, 'https://source.test/image.png', .image)
		mut preloaded := fetch.Response.create()
		preloaded.url_list = [dom.URL{value: target}]
		mut params := fetch.FetchParams.create(request, fetch.FetchTimingInfo.create())
		params.set_preloaded_response_candidate(fetch.PreloadedResponseCandidate{
			kind:     .response
			response: preloaded
		})
		response :=
			fetch.main_fetch(params, fetch.FetchHost{ perform: security_policy_host }).response()?
		assert response.is_network_error()
		assert security_policy_host_calls == 0
		if target.starts_with('https:') { assert request.csp_global?.reports.len == 1
		 }
	}
}

fn test_csp_violation_dispatches_at_document_after_the_request_task() {
	mut loop := main_thread_event_loop()
	loop.task_queue_.tasks.clear()
	settings := security_policy_settings("img-src 'none'", .enforce)
	document := settings.responsible_document()?
	security_policy_violation_events = 0
	callback := &dom.CallbackType{
		handle_event: fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'securitypolicyviolation'
			assert event.is_trusted()
			security_policy_violation_events++
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(document) }.add_event_listener_without_options('securitypolicyviolation',
		dom.IDLEventListener.create(callback))

	request := security_policy_request(settings, 'https://other.test/image.png', .image)
	fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: security_policy_host
	})
	assert security_policy_violation_events == 0
	loop.process()
	assert security_policy_violation_events == 1
}

fn test_blocked_preload_does_not_wait_for_pending_preloaded_response() {
	settings := security_policy_settings("img-src 'none'", .enforce)
	request := security_policy_request(settings, 'https://other.test/image.png', .image)
	mut params := fetch.FetchParams.create(request, fetch.FetchTimingInfo.create())
	params.set_preloaded_response_candidate(fetch.PreloadedResponseCandidate{ kind: .pending })
	pending := fetch.main_fetch(params, fetch.FetchHost{ perform: security_policy_host })
	assert pending.is_resolved()
	assert pending.response()?.is_network_error()
}
