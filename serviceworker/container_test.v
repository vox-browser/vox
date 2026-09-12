module serviceworker

fn client() &ServiceWorkerClient {
	return &ServiceWorkerClient{
		base_url:     'https://example.test/app/page.html'
		creation_url: 'https://example.test/app/page.html'
		origin:       'https://example.test'
		storage_key:  'example-key'
	}
}

fn test_container_register_url_validation_default_scope_and_matching() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	bad_scheme := container.register_('data:text/javascript,x', RegistrationOptions{})
	assert bad_scheme.state == .rejected
	encoded_slash := container.register_('/sw%2Fbad.js', RegistrationOptions{})
	assert encoded_slash.state == .rejected

	promise := container.register_('sw.js#version', RegistrationOptions{ update_via_cache: .none })
	assert promise.state == .pending
	assert agent.queue_length('https://example.test/app/') == 1
	registration := agent.store.set('example-key', 'https://example.test/app/', .imports)
	lookup := container.get_registration('./child')
	assert lookup.state == .fulfilled
	assert voidptr(lookup.registration or { panic('missing') }) == voidptr(registration)
	assert container.get_registration('https://other.test/').state == .rejected
}

fn test_ready_is_same_pending_promise_until_active_worker_exists() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	first := container.ready()
	second := container.ready()
	assert voidptr(first) == voidptr(second)
	assert first.state == .pending
	mut registration := agent.store.set('example-key', 'https://example.test/app/', .imports)
	container.poll_ready()
	assert first.state == .pending
	registration.set_active_worker(&ServiceWorkerRecord{
		script_url: 'https://example.test/sw.js'
		state:      .activated
	})
	container.poll_ready()
	assert first.state == .fulfilled
	assert voidptr(first.registration or { panic('missing') }) == voidptr(registration)
}

fn test_event_attributes_global_cookie_store_and_cache_storage() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	container.set_event_handler('message', true)
	assert container.has_event_handler('message')
	assert container.controller() == none

	mut scope := ServiceWorkerGlobalScope.create(42)
	scope.set_oninstall(true)
	scope.set_onactivate(true)
	scope.set_onfetch(true)
	scope.set_onmessage(true)
	scope.set_onmessageerror(true)
	assert scope.oninstall() && scope.onactivate() && scope.onfetch()
	assert scope.onmessage() && scope.onmessageerror()
	first := scope.cookie_store()
	second := scope.cookie_store()
	assert voidptr(first) == voidptr(second)
	assert first.page_client_id == 42

	mut storage := CacheStorage{}
	assert storage.open('v1').state == .fulfilled
	has := storage.has('v1')
	assert has.state == .fulfilled
	assert has.value or { false }
}

fn test_container_exact_start_register_entry_point() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	promise := container.start_register('sw.js', RegistrationOptions{})
	assert promise.state == .pending
	assert agent.queue_length('https://example.test/app/') == 1
}
