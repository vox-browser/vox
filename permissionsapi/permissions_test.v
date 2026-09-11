module permissionsapi

import dom

fn permission_test_origin(value string) dom.Origin {
	return dom.Origin{ value: value }
}

fn permission_test_environment(secure bool) PermissionEnvironment {
	origin := permission_test_origin('https://example.com')
	return PermissionEnvironment{
		secure_context: secure
		top_level_origin: origin
		origin: origin
	}
}

fn test_permission_store_replaces_and_removes_same_origin_entries() {
	mut store := &PermissionStore{}
	descriptor := PermissionDescriptor{ name: 'geolocation' }
	key := permission_test_origin('https://example.com')
	store.set_permission_store_entry(descriptor, key, .prompt)
	store.set_permission_store_entry(descriptor, key, .granted)
	assert store.entries.len == 1
	assert store.get_permission_store_entry(descriptor, key)?.state == .granted
	store.remove_permission_store_entry(descriptor, key)
	assert store.get_permission_store_entry(descriptor, key) == none
}

fn test_permission_state_denies_insecure_context_and_persists_requests() {
	mut store := PermissionStore.the()
	store.clear()
	descriptor := PermissionDescriptor{ name: 'geolocation' }
	assert permission_state(descriptor, permission_test_environment(false)) == .denied
	environment := permission_test_environment(true)
	assert permission_state(descriptor, environment) == .prompt
	assert request_permission(descriptor, environment) == .granted
	assert permission_state(descriptor, environment) == .granted
}

fn test_permissions_query_validates_context_and_supported_names() {
	permissions := Permissions.create()
	mut inactive := permission_test_environment(true)
	inactive = PermissionEnvironment{
		...inactive
		fully_active: false
	}
	if _ := permissions.query(PermissionDescriptor{ name: 'geolocation' }, inactive) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	if _ := permissions.query(PermissionDescriptor{ name: 'camera' }, permission_test_environment(true)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_permission_status_requeries_and_queues_change_event() {
	mut store := PermissionStore.the()
	store.clear()
	environment := permission_test_environment(true)
	descriptor := PermissionDescriptor{ name: 'geolocation' }
	mut status := PermissionStatus.create(environment, descriptor)
	assert status.relevant_global_object() == environment
	permission_query_algorithm(descriptor, mut status)
	assert status.state() == .prompt
	store.set_permission_store_entry(descriptor, environment.top_level_origin, .granted)
	status.update_steps()
	assert status.state() == .granted
	assert status.run_next_task()
	assert !status.run_next_task()
}
