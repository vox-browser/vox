module mixedcontent

import dom
import fetch

fn request_for(url string, destination fetch.Destination) &fetch.Request {
	mut request := fetch.Request.create()
	request.url_list = [dom.URL{value: url}]
	request.destination = destination
	return request
}

fn restrictive_settings() EnvironmentSettings {
	return EnvironmentSettings{
		origin_potentially_trustworthy: true
		global_kind:                    .window
	}
}

fn test_settings_prohibition_uses_own_and_window_ancestor_origins() {
	assert does_settings_prohibit_mixed_security_contexts(&EnvironmentSettings{
		origin_potentially_trustworthy: true
	}) == .prohibits_mixed_security_contexts
	assert does_settings_prohibit_mixed_security_contexts(&EnvironmentSettings{
		global_kind:                              .window
		ancestor_origins_potentially_trustworthy: [false, true]
	}) == .prohibits_mixed_security_contexts
	assert does_settings_prohibit_mixed_security_contexts(&EnvironmentSettings{
		global_kind:                              .worker
		ancestor_origins_potentially_trustworthy: [true]
	}) == .does_not_restrict_mixed_security_contexts
}

fn test_upgrade_only_rewrites_eligible_passive_mixed_content() {
	settings := restrictive_settings()
	mut image := request_for('http://example.test/image.png', .image)
	upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut image,
		&settings)
	assert image.url().scheme() == 'https'

	mut audio := request_for('http://example.test/sound.ogg', .audio)
	upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut audio,
		&settings)
	assert audio.url().scheme() == 'https'

	mut script := request_for('http://example.test/app.js', .script)
	upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut script,
		&settings)
	assert script.url().scheme() == 'http'

	mut image_set := request_for('http://example.test/2x.png', .image)
	image_set.initiator = .image_set
	upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut image_set,
		&settings)
	assert image_set.url().scheme() == 'http'
}

fn test_upgrade_exemptions_cover_trustworthy_ip_and_nonrestrictive_settings() {
	settings := restrictive_settings()
	for value in ['https://example.test/image.png', 'http://127.0.0.2/image.png',
		'http://[2001:db8::1]/image.png'] {
		mut request := request_for(value, .image)
		upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut request,
			&settings)
		assert request.url().serialize() == value
	}
	open_settings := EnvironmentSettings{}
	mut request := request_for('http://example.test/image.png', .image)
	upgrade_a_mixed_content_request_to_a_potentially_trustworthy_url_if_appropriate(mut request,
		&open_settings)
	assert request.url().scheme() == 'http'
}

fn test_request_blocking_allowed_branches_and_default_block() {
	restrictive := restrictive_settings()
	open := EnvironmentSettings{}
	assert should_fetching_request_be_blocked_as_mixed_content(request_for('http://example.test/a.js',
		.script), &restrictive) == .blocked
	assert should_fetching_request_be_blocked_as_mixed_content(request_for('https://example.test/a.js',
		.script), &restrictive) == .allowed
	assert should_fetching_request_be_blocked_as_mixed_content(request_for('http://example.test/a.js',
		.script), &open) == .allowed
	top_level := EnvironmentSettings{
		origin_potentially_trustworthy:       true
		target_browsing_context_is_top_level: true
	}
	assert should_fetching_request_be_blocked_as_mixed_content(request_for('http://example.test/',
		.document), &top_level) == .allowed
}

fn test_response_blocking_uses_response_url_and_top_level_exception() {
	restrictive := restrictive_settings()
	request := request_for('http://example.test/a.js', .script)
	mut secure_response := fetch.Response.create()
	secure_response.url_list = [dom.URL{value: 'https://cdn.example.test/a.js'}]
	assert should_response_to_request_be_blocked_as_mixed_content(request, secure_response,
		&restrictive) == .allowed
	mut insecure_response := fetch.Response.create()
	insecure_response.url_list = [dom.URL{value: 'http://cdn.example.test/a.js'}]
	assert should_response_to_request_be_blocked_as_mixed_content(request, insecure_response,
		&restrictive) == .blocked
	no_url_response := fetch.Response.create()
	assert should_response_to_request_be_blocked_as_mixed_content(request, no_url_response,
		&restrictive) == .blocked
}
