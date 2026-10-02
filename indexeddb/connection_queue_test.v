module indexeddb

fn test_upgrade_waits_for_versionchange_and_closure_without_mutating_old_connection() {
	mut factory := IDBFactory.create('queue-upgrade')!
	mut first := factory.open('db', u64(1))!
	assert first.request.events.len == 0
	run_database_tasks()
	assert first.request.events == ['upgradeneeded']
	first.finish_upgrade()!
	run_database_tasks()
	mut old := first.connection
	mut second := factory.open('db', u64(2))!
	mut third := factory.open('db', none)!
	assert old.events.len == 0
	assert isnil(second.connection)
	run_database_tasks()
	assert old.events == ['versionchange']
	assert old.version_change_events[0].old_version == 1
	assert old.version_change_events[0].new_version? == 2
	assert second.request.events == ['blocked']
	assert second.request.ready_state == .pending
	assert isnil(second.upgrade_transaction)
	assert old.data.version == 1
	assert old.version() == 1
	assert second.connection.version() == 2
	assert isnil(third.connection)
	old.close()
	assert second.request.events == ['blocked']
	run_database_tasks()
	assert second.request.events == ['blocked', 'upgradeneeded']
	assert old.data.version == 2
	assert old.version() == 1
	assert isnil(third.connection)
	second.finish_upgrade()!
	assert third.request.events.len == 0
	run_database_tasks()
	assert second.request.events == ['blocked', 'upgradeneeded', 'success']
	assert third.request.events == ['success']
	assert third.connection.version() == 2
}

fn test_delete_notifies_connections_and_resumes_automatically_before_queued_open() {
	mut first_factory := IDBFactory.create('queue-delete')!
	mut second_factory := IDBFactory.create('queue-delete')!
	mut initial := first_factory.open('db', u64(4))!
	run_database_tasks()
	initial.finish_upgrade()!
	run_database_tasks()
	mut old := initial.connection
	deleted := second_factory.delete_database('db')
	mut reopened := first_factory.open('db', none)!
	run_database_tasks()
	assert old.events == ['versionchange']
	assert old.version_change_events[0].old_version == 4
	assert old.version_change_events[0].new_version == none
	assert deleted.request.events == ['blocked']
	assert isnil(reopened.connection)
	old.close()
	run_database_tasks()
	assert deleted.request.events == ['blocked', 'success']
	assert deleted.old_version == 4
	assert reopened.old_version == 0
	assert reopened.new_version? == 1
	assert reopened.request.events == ['upgradeneeded']
	reopened.finish_upgrade()!
	run_database_tasks()
}

fn test_versionchange_listener_closes_before_blocked_check() {
	mut factory := IDBFactory.create('queue-close-listener')!
	mut initial := factory.open('db', u64(1))!
	run_database_tasks()
	initial.finish_upgrade()!
	run_database_tasks()
	mut old := initial.connection
	old_ptr := voidptr(old)
	old.set_onversionchange(fn [old_ptr] () {
		mut connection := unsafe { &IDBDatabase(old_ptr) }
		connection.close()
	})
	mut upgrade := factory.open('db', u64(2))!
	run_database_tasks()
	assert old.events == ['versionchange']
	assert old.state == .closed
	assert upgrade.request.events == ['upgradeneeded']
	upgrade.finish_upgrade()!
	run_database_tasks()
}

fn test_close_waits_for_active_transactions_before_unblocking_upgrade() {
	mut factory := IDBFactory.create('queue-transaction-close')!
	mut initial := factory.open('db', u64(1))!
	run_database_tasks()
	mut old := initial.connection
	mut schema := initial.upgrade_transaction
	old.create_object_store(mut schema, 'store', IDBObjectStoreParameters{})!
	initial.finish_upgrade()!
	run_database_tasks()
	mut transaction := old.transaction(['store'], .readonly, IDBTransactionOptions{})!
	mut upgrade := factory.open('db', u64(2))!
	run_database_tasks()
	old.close()
	run_database_tasks()
	assert old.state == .closing
	assert upgrade.request.events == ['blocked']
	transaction.commit()!
	assert old.state == .closed
	run_database_tasks()
	assert upgrade.request.events == ['blocked', 'upgradeneeded']
	upgrade.abort_upgrade('AbortError: test')!
	run_database_tasks()
}
