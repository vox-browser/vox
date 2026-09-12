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
	assert voidptr(first.registration_object or { panic('missing wrapper') }.registration()) == voidptr(registration)
}

fn test_ready_cache_is_per_wrapper_world_and_prunes_dead_containers() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	first_world := container.ready_for_world(1)
	first_world_again := container.ready_for_world(1)
	second_world := container.ready_for_world(2)
	assert voidptr(first_world) == voidptr(first_world_again)
	assert voidptr(first_world) != voidptr(second_world)
	assert service_worker_container_ready_promise_caches().len > 0
	container.mark_destroyed()
	for entry in service_worker_container_ready_promise_caches() {
		assert entry.container_pointer != voidptr(container)
	}
}

fn test_get_registrations_filters_storage_key_and_reuses_wrappers() {
	mut agent := ServiceWorkerAgent.create()
	mut container := ServiceWorkerContainer.create(client(), agent)
	first := agent.store.set('example-key', 'https://example.test/a/', .imports)
	second := agent.store.set('example-key', 'https://example.test/b/', .all)
	agent.store.set('foreign', 'https://example.test/c/', .none)
	promise := container.get_registrations()
	assert promise.state == .fulfilled
	assert promise.registrations.len == 2
	assert voidptr(promise.registrations[0]) == voidptr(first)
	assert voidptr(promise.registrations[1]) == voidptr(second)
	assert promise.registration_objects.len == 2

	lookup := container.get_registration('https://example.test/a/page')
	assert voidptr(lookup.registration_object or { panic('missing wrapper') }) == voidptr(promise.registration_objects[0])
	assert voidptr(container.service_worker_client()) == voidptr(container.client_)
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
