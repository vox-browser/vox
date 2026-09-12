module serviceworker

fn test_registration_map_fragment_exclusion_longest_scope_and_replacement() {
	mut store := RegistrationStore.create()
	first := store.set('key', 'https://example.test/app/#one', .imports)
	assert store.get('key', 'https://example.test/app/#two') or { panic('missing') } == first
	assert first.scope_url() == 'https://example.test/app/#one'
	store.set('key', 'https://example.test/app/admin/', .none)
	assert store.match_client('key', 'https://example.test/app/admin/panel') or { panic('missing') }.scope_url() == 'https://example.test/app/admin/'
	assert store.match_client('other', 'https://example.test/app/') == none
	replacement := store.set('key', 'https://example.test/app/', .all)
	assert store.is_unregistered(first)
	assert !store.is_unregistered(replacement)
}

fn test_newest_worker_priority_and_staleness_are_exact() {
	mut store := RegistrationStore.create()
	mut registration := store.set('key', 'https://example.test/', .imports)
	active := &ServiceWorkerRecord{
		script_url: 'active.js'
		state:      .activated
	}
	waiting := &ServiceWorkerRecord{
		script_url: 'waiting.js'
		state:      .installed
	}
	installing := &ServiceWorkerRecord{
		script_url: 'installing.js'
		state:      .installing
	}
	registration.set_active_worker(active)
	registration.set_waiting_worker(waiting)
	registration.set_installing_worker(installing)
	assert registration.newest_worker() or { panic('missing') }.script_url == 'installing.js'
	registration.set_installing_worker(none)
	assert registration.newest_worker() or { panic('missing') }.script_url == 'waiting.js'
	registration.set_last_update_check_time(100)
	assert !registration.is_stale(86500)
	assert registration.is_stale(86500.01)
}

fn test_registration_exact_static_map_entry_points() {
	mut store := RegistrationStore.create()
	registration := Registration.set(mut store, 'key', 'https://example.test/app/#fragment',
		.imports)
	assert voidptr(Registration.get(store, 'key', 'https://example.test/app/#other') or {
		panic('missing exact registration')
	}) == voidptr(registration)
	assert voidptr(Registration.match_(store, 'key', 'https://example.test/app/page') or {
		panic('missing exact registration match')
	}) == voidptr(registration)
	assert !registration.is_unregistered(store)
	Registration.remove(mut store, 'key', 'https://example.test/app/')
	assert registration.is_unregistered(store)
}

fn test_registrations_for_storage_key_preserve_registry_order() {
	mut store := RegistrationStore.create()
	first := store.set('key', 'https://example.test/first/', .imports)
	store.set('other', 'https://example.test/foreign/', .imports)
	second := store.set('key', 'https://example.test/second/', .all)
	registrations := Registration.for_storage_key(store, 'key')
	assert registrations.len == 2
	assert voidptr(registrations[0]) == voidptr(first)
	assert voidptr(registrations[1]) == voidptr(second)

	// Replacing an ordered-map value retains its position but changes identity.
	replacement := store.set('key', 'https://example.test/first/#new', .none)
	replaced := store.for_storage_key('key')
	assert voidptr(replaced[0]) == voidptr(replacement)
	assert voidptr(replaced[1]) == voidptr(second)
	assert registration_map(store).len == 3

	store.remove('key', 'https://example.test/first/')
	assert store.for_storage_key('key').len == 1
}

fn test_platform_objects_snapshot_records_and_handler_identity() {
	mut record := &ServiceWorkerRecord{
		script_url: 'https://example.test/sw.js'
		state:      .installed
	}
	mut worker := ServiceWorker.create(record)
	assert worker.script_url() == record.script_url
	assert worker.service_worker_state() == .parsed
	worker.set_service_worker_state(.installed)
	worker.set_event_handler('statechange', true)
	assert worker.has_event_handler('statechange')

	mut store := RegistrationStore.create()
	mut registration := store.set('key', 'https://example.test/', .none)
	registration.set_active_worker(record)
	object := ServiceWorkerRegistration.create(registration)
	assert voidptr(object.registration()) == voidptr(registration)
	assert object.scope() == 'https://example.test/'
	assert object.update_via_cache() == .none
	assert (object.active() or { panic('missing') }).script_url() == record.script_url
	mut object_mut := object
	replacement := ServiceWorker.create(record)
	object_mut.set_installing(replacement)
	object_mut.set_waiting(replacement)
	object_mut.set_active(replacement)
	assert voidptr(object.installing() or { panic('missing') }) == voidptr(replacement)
	assert ServiceWorkerRegistration.installing_offset() < ServiceWorkerRegistration.waiting_offset()
	assert ServiceWorkerRegistration.waiting_offset() < ServiceWorkerRegistration.active_offset()
}
