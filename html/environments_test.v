module html

import dom

fn environment_test_document(url string) &dom.Document {
	parsed := dom.URL{url}
	return &dom.Document{
		url:              parsed
		origin_:          parsed.origin()
		load_timing_info: dom.DocumentLoadTimingInfo{
			navigation_start_time: 123.4
		}
	}
}

fn test_window_environment_settings_setup_urls_security_and_serialization() {
	document := environment_test_document('https://example.test/app/index.html')
	window := WindowModel.create_top_level(document, none, 'main')!
	mut realm := &ScriptingRealm{}
	settings_object := WindowEnvironmentSettingsObject.setup(window, dom.URL{'https://example.test/app/index.html'}, mut
		realm, none, dom.URL{'https://example.test/'}, dom.Origin{'https://example.test'})
	settings := settings_object.settings
	assert settings.responsible_document() or { panic('missing document') } == document
	assert settings.api_base_url().serialize() == document.base_url().serialize()
	assert settings.parse_url('../asset.js') or { panic('parse failed') }.serialize() == 'https://example.test/asset.js'
	assert settings.is_secure_context()
	assert settings.time_origin() == 123.4
	assert settings_object.has_cross_site_ancestor() == false
	assert settings_object.cross_origin_isolated_capability() == .no
	serialized := settings.serialize()
	assert serialized.id != ''
	assert serialized.api_base_url.serialize() == document.base_url().serialize()
	assert serialized.global is SerializedWindow
	assert can_run_script(realm) == .run

	mut context := unsafe { &BrowsingContextModel(window.browsing_context()) }
	context.set_fully_active_override(false)
	assert can_run_script(realm) == .do_not_run
}

fn test_reserved_window_environment_transfers_id_and_target() {
	document := environment_test_document('https://example.test/')
	window := WindowModel.create_top_level(document, none, 'main')!
	mut reserved := Environment.create('reserved-id', document.url, none, none,
		window.browsing_context())
	mut realm := &ScriptingRealm{}
	object := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, reserved,
		document.url, document.origin())
	assert object.settings.environment().id == 'reserved-id'
	assert reserved.id == ''
	assert object.settings.environment().target_browsing_context or { panic('missing target') } == window.browsing_context()
}

fn test_worker_environment_uses_outside_origin_except_for_data_urls() {
	document := environment_test_document('https://example.test/')
	window := WindowModel.create_top_level(document, none, 'main')!
	mut outside_realm := &ScriptingRealm{}
	outside := WindowEnvironmentSettingsObject.setup(window, document.url, mut outside_realm, none,
		document.url, document.origin()).settings.serialize()

	mut worker_realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{'https://example.test/worker.js'}, .classic, '',
		worker_realm)
	worker := WorkerEnvironmentSettingsObject.setup(scope, mut worker_realm, outside, 44.456)
	assert worker.origin().serialize() == 'https://example.test'
	assert worker.api_base_url().serialize() == 'https://example.test/worker.js'
	assert worker.time_origin() == 44.4
	assert worker.settings.is_secure_context()

	mut data_realm := &ScriptingRealm{}
	data_scope := WorkerGlobalScope.create(dom.URL{'data:text/javascript,close()'}, .classic, '',
		data_realm)
	data_worker := WorkerEnvironmentSettingsObject.setup(data_scope, mut data_realm, outside, 1.0)
	assert data_worker.origin().serialize() == 'opaque'
	assert data_worker.has_cross_site_ancestor()
}

fn test_environment_module_set_discard_and_service_worker_identity() {
	document := environment_test_document('https://example.test/')
	window := WindowModel.create_top_level(document, none, 'main')!
	mut realm := &ScriptingRealm{}
	mut settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	assert module_type_allowed('javascript')
	assert module_type_allowed('css')
	assert !module_type_allowed('wasm')
	settings.add_module_to_resolved_module_set(document.url.serialize(), 'pkg', none)
	assert settings.resolved_module_set().len == 1

	record := &ServiceWorkerRecordModel{
		id:    'worker-1'
		state: 'activated'
	}
	registration := &ServiceWorkerRegistrationRecordModel{
		storage_key: 'partition'
		scope_url:   dom.URL{'https://example.test/app/'}
		active:      record
	}
	first := settings.get_service_worker_registration_object(registration)
	second := settings.get_service_worker_registration_object(registration)
	assert first == second
	assert first.active or { panic('missing active worker') }.state == 'activated'
	settings.discard_environment()
	assert settings.discarded()
}
