module serviceworker

fn test_job_equivalence_coalesces_and_settles_all_promises() {
	mut agent := ServiceWorkerAgent.create()
	mut registration := agent.store.set('key', 'https://example.test/app/', .imports)
	worker := &ServiceWorkerRecord{
		script_url:  'https://example.test/sw.js'
		worker_type: .classic
		script_body: 'same'.bytes()
	}
	registration.set_active_worker(worker)
	agent.set_fetch_result(worker.script_url, ScriptFetchResult{ success: true, body: 'same'.bytes() })

	first := Job.create(.update, 'key', registration.scope_url(), worker.script_url,
		'https://example.test/page')
	second := Job.create(.update, 'key', registration.scope_url(), worker.script_url,
		'https://example.test/page')
	agent.schedule_job(first)
	agent.schedule_job(second)
	assert agent.queue_length(registration.scope_url()) == 1
	agent.process_all()
	assert first.promise.state == .fulfilled
	assert second.promise.state == .fulfilled
	assert voidptr(first.promise.registration or { panic('missing') }) == voidptr(registration)
}

fn test_register_security_fetch_validation_and_current_install_frontier() {
	mut agent := ServiceWorkerAgent.create()
	untrusted := Job.create(.register, 'key', 'http://evil.test/', 'http://evil.test/sw.js',
		'http://evil.test/page')
	agent.schedule_job(untrusted)
	agent.process_all()
	assert untrusted.promise.state == .rejected
	assert untrusted.promise.error.contains('untrustworthy')

	bad_mime := Job.create(.register, 'key', 'https://example.test/', 'https://example.test/sw.js',
		'https://example.test/page')
	agent.set_fetch_result(bad_mime.script_url, ScriptFetchResult{
		success:   true
		mime_type: 'text/html'
		body:      'x'.bytes()
	})
	agent.schedule_job(bad_mime)
	agent.process_all()
	assert bad_mime.promise.error.contains('JavaScript MIME')
	assert agent.store.get('key', 'https://example.test/') == none

	mut fresh_agent := ServiceWorkerAgent.create()
	updated := Job.create(.register, 'key', 'https://example.test/', 'https://example.test/sw.js',
		'https://example.test/page')
	fresh_agent.set_fetch_result(updated.script_url, ScriptFetchResult{
		success: true
		body:    'new'.bytes()
	})
	fresh_agent.schedule_job(updated)
	fresh_agent.process_all()
	assert updated.promise.state == .rejected
	assert updated.promise.error == 'NotImplemented: Run Service Worker'
}

fn test_update_mismatch_and_unregister_preserve_upstream_failures() {
	mut agent := ServiceWorkerAgent.create()
	mut registration := agent.store.set('key', 'https://example.test/', .imports)
	registration.set_active_worker(&ServiceWorkerRecord{ script_url: 'https://example.test/old.js' })
	update := Job.create(.update, 'key', registration.scope_url(), 'https://example.test/new.js',
		'https://example.test/page')
	unregister := Job.create(.unregister, 'key', registration.scope_url(), '',
		'https://example.test/page')
	agent.schedule_job(update)
	agent.schedule_job(unregister)
	agent.process_all()
	assert update.promise.error.contains('mismatch')
	assert unregister.promise.error == 'NotImplemented: Service Worker unregistration'
}

fn test_update_enforces_maximum_scope_and_preserves_unimplemented_body_comparison() {
	mut agent := ServiceWorkerAgent.create()
	too_wide := Job.create(.register, 'key', 'https://example.test/',
		'https://example.test/app/sw.js', 'https://example.test/page')
	agent.set_fetch_result(too_wide.script_url, ScriptFetchResult{
		success: true
		body:    'worker'.bytes()
	})
	agent.schedule_job(too_wide)
	agent.process_all()
	assert too_wide.promise.state == .rejected
	assert too_wide.promise.error.contains('Service-Worker-Allowed')
	assert agent.store.get('key', too_wide.scope_url) == none

	allowed := Job.create(.register, 'key', 'https://example.test/',
		'https://example.test/app/sw.js', 'https://example.test/page')
	agent.set_fetch_result(allowed.script_url, ScriptFetchResult{
		success:                true
		body:                   'worker'.bytes()
		service_worker_allowed: '/'
	})
	agent.schedule_job(allowed)
	agent.process_all()
	assert allowed.promise.error == 'NotImplemented: Run Service Worker'

	mut registration := agent.store.set('other', 'https://example.test/app/', .imports)
	registration.set_active_worker(&ServiceWorkerRecord{
		script_url:  'https://example.test/app/sw.js'
		worker_type: .classic
		script_body: 'old bytes'.bytes()
	})
	mut update := Job.create(.update, 'other', registration.scope_url(),
		'https://example.test/app/sw.js', 'https://example.test/app/page')
	update.update_via_cache = .none
	agent.set_fetch_result(update.script_url, ScriptFetchResult{
		success: true
		body:    'different bytes'.bytes()
	})
	agent.schedule_job(update)
	agent.process_all()
	assert update.promise.state == .fulfilled
	assert registration.update_via_cache() == .none
}
