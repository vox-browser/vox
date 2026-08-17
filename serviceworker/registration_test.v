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
	assert object.scope() == 'https://example.test/'
	assert object.update_via_cache() == .none
	assert (object.active() or { panic('missing') }).script_url() == record.script_url
}
