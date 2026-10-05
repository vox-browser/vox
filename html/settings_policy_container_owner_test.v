module html

import dom
import fetch
import http
import page

fn source_settings_policy_document(address string) !(&dom.Document, &WindowModel, &EnvironmentSettingsObject) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	install_document_csp_hook(document)
	native := document.get_window() or { return error('missing actual Window') }
	window := unsafe { &WindowModel(native) }
	return document, window, window.environment_settings_.settings
}

fn source_settings_policy_response(address dom.URL, policy string, referrer string) &fetch.Response {
	mut response := fetch.Response.create()
	response.url_list = [address]
	if policy != '' {
		response.header_list.append(http.Header{'Content-Security-Policy', policy})
	}
	if referrer != '' {
		response.header_list.append(http.Header{'Referrer-Policy', referrer})
	}
	return response
}

fn source_settings_policy_forbidden_transport(_ &fetch.Request) !&fetch.Response {
	panic('Source owning settings must block this image before transport')
}

fn test_window_settings_return_actual_document_owner_for_header_meta_and_consumers() {
	mut document, window, settings := source_settings_policy_document('https://settings-policy-owner.test/page')!
	defer { document.finalize() }
	container := create_a_policy_container_from_fetch_response(source_settings_policy_response(document.url,
		"img-src 'none'; trusted-types header-name", 'no-referrer'))
	document.set_policy_container(container)
	assert voidptr(settings.policy_container()) == voidptr(container)
	assert voidptr(window.environment_settings_.policy_container()) == voidptr(container)
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'content-security-policy')
	meta.set_attribute_value('content', "style-src 'none'; trusted-types meta-name")
	head := document.head()?
	mut head_node := head.as_node()
	head_node.append_child(meta.as_node())!
	assert voidptr(document.policy_container()) == voidptr(container)
	assert container.csp_list.len == 2
	assert container.csp_list[0].source == .header && container.csp_list[1].source == .meta
	assert document_csp_policies(document).len == 2
	assert trusted_types_meta_policies(document).len == 2
	assert settings.fetch_request_client_csp_global().policy_list.policies.len == 2
	assert settings.serialize().policy_container.csp_list.len == 2
	assert settings.fetch_request_client_policy_container().referrer_policy == 'no-referrer'
	style := document.create_element('style')!
	assert document.should_block_inline_content(style, 'style', 'body { color: red }')
	mut request := fetch.Request.create()
	request.set_client(settings)
	request.set_url(dom.URL{value: 'https://other-settings-policy.test/image.png'})
	request.destination = .image
	request.cache_mode = .no_store
	fetch.populate_request_from_client(mut request)
	response := fetch.main_fetch(fetch.FetchParams.create(request, fetch.FetchTimingInfo.create()), fetch.FetchHost{
		perform: source_settings_policy_forbidden_transport
	}).response()?
	assert response.is_network_error()
}

fn test_window_settings_follow_current_associated_document_and_setter_routes_actual_owner() {
	mut original, mut window, mut settings := source_settings_policy_document('https://old-settings-policy.test/page')!
	mut replacement, _, replacement_settings := source_settings_policy_document('https://new-settings-policy.test/page')!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	old_container := create_a_policy_container_from_fetch_response(source_settings_policy_response(original.url,
		"style-src 'none'", 'no-referrer'))
	new_header := create_a_policy_container_from_fetch_response(source_settings_policy_response(replacement.url,
		"style-src 'unsafe-inline'", 'origin'))
	new_container := &dom.PolicyContainer{
		csp_list:                     new_header.csp_list
		referrer_policy:              .origin
		embedder_policy:              dom.EmbedderPolicy{ value: .credentialless }
		integrity_policy:             dom.IntegrityPolicy{ blocked_destinations: [.style] }
		report_only_integrity_policy: dom.IntegrityPolicy{ blocked_destinations: [.script] }
	}
	original.set_policy_container(old_container)
	replacement.set_policy_container(new_container)
	assert voidptr(settings.policy_container()) == voidptr(old_container)
	window.set_associated_document(replacement)
	assert voidptr(settings.policy_container()) == voidptr(new_container)
	assert voidptr(window.environment_settings_.policy_container()) == voidptr(new_container)
	assert voidptr(replacement_settings.policy_container()) == voidptr(new_container)
	assert voidptr(original.policy_container()) == voidptr(old_container)
	assert settings.serialize().policy_container.referrer_policy == .origin
	assert settings.fetch_request_client_embedder_policy_credentialless()
	projected := settings.fetch_request_client_policy_container()
	assert projected.referrer_policy == 'origin'
	assert projected.csp_list.policies[0].pre_parsed_policy_string() == "style-src 'unsafe-inline'"
	assert projected.integrity_policy.blocked_destinations == [.style]
	assert projected.report_only_integrity_policy.blocked_destinations == [.script]
	assert settings.fetch_request_client_csp_global().policy_list.policies[0].self_origin?.serialize() == replacement.origin().serialize()
	third := &dom.PolicyContainer{ referrer_policy: .strict_origin }
	settings.set_policy_container(third)
	assert voidptr(replacement.policy_container()) == voidptr(third)
	assert voidptr(settings.policy_container()) == voidptr(third)
	assert voidptr(original.policy_container()) == voidptr(old_container)
	window.set_associated_document(original)
	assert voidptr(settings.policy_container()) == voidptr(old_container)
	assert settings.fetch_request_client_policy_container().referrer_policy == 'no-referrer'
}

fn test_worker_settings_return_live_global_scope_container_instead_of_outside_snapshot() {
	mut document, _, outside_settings := source_settings_policy_document('https://outside-settings-policy.test/page')!
	defer { document.finalize() }
	document.set_policy_container(create_a_policy_container_from_fetch_response(source_settings_policy_response(document.url,
		"script-src 'none'", 'origin')))
	mut realm := &ScriptingRealm{}
	worker_url := dom.URL{value: 'https://worker-settings-policy.test/worker.js'}
	mut scope := WorkerGlobalScope.create(worker_url, .classic, '', realm)
	object := WorkerEnvironmentSettingsObject.setup(scope, mut realm, outside_settings.serialize(), 0)
	mut settings := object.settings
	assert voidptr(settings.policy_container()) == voidptr(scope.policy_container())
	assert settings.policy_container().csp_list.len == 0
	scope.initialize_policy_container(source_settings_policy_response(worker_url, "img-src 'none'", 'no-referrer'), outside_settings)
	first := scope.policy_container()
	assert voidptr(settings.policy_container()) == voidptr(first)
	assert voidptr(object.policy_container()) == voidptr(first)
	assert settings.serialize().policy_container.csp_list[0].pre_parsed_policy_string == "img-src 'none'"
	assert settings.fetch_request_client_csp_global().policy_list.policies[0].self_origin?.serialize() == worker_url.origin().serialize()
	assert settings.fetch_request_client_policy_container().referrer_policy == 'no-referrer'
	scope.initialize_policy_container(source_settings_policy_response(worker_url, "style-src 'none'", 'strict-origin'), outside_settings)
	second := scope.policy_container()
	assert voidptr(second) != voidptr(first)
	assert voidptr(settings.policy_container()) == voidptr(second)
	assert settings.serialize().policy_container.referrer_policy == .strict_origin
	assert settings.fetch_request_client_policy_container().csp_list.policies[0].pre_parsed_policy_string() == "style-src 'none'"
	installed := &dom.PolicyContainer{ referrer_policy: .same_origin }
	settings.set_policy_container(installed)
	assert voidptr(scope.policy_container()) == voidptr(installed)
	assert voidptr(settings.policy_container()) == voidptr(installed)
}

fn test_standalone_settings_without_window_or_worker_keep_explicit_value_adapter() {
	mut realm := &ScriptingRealm{}
	url := dom.URL{value: 'https://standalone-settings-policy.test/'}
	environment := Environment.create('standalone-policy', url, url, url.origin(), none)
	mut settings := create_environment_settings(realm, environment, .window, main_thread_event_loop())
	assert settings.window_ == none && settings.worker_ == none
	mut input := &dom.PolicyContainer{ referrer_policy: .origin }
	input.csp_list << dom.SerializedCSPPolicy{ self_origin: url.origin(), pre_parsed_policy_string: 'standalone' }
	settings.set_policy_container(input)
	input.csp_list << dom.SerializedCSPPolicy{ self_origin: url.origin(), pre_parsed_policy_string: 'later' }
	assert settings.policy_container().referrer_policy == .origin
	assert settings.policy_container().csp_list.len == 1
	assert settings.serialize().policy_container.csp_list.len == 1
}
