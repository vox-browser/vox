module indexeddb

@[heap]
struct TransactionCompletionLog {
mut:
	entries []string
}

fn completion_test_connection(key string) &IDBDatabase {
	mut factory := IDBFactory.create('completion-${key}') or { panic(err) }
	mut open := factory.open('db', u64(1)) or { panic(err) }
	run_database_tasks()
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{}) or { panic(err) }
	open.finish_upgrade() or { panic(err) }
	run_database_tasks()
	return connection
}

fn test_transaction_commit_waits_for_requests_and_finishes_on_a_database_task() {
	mut connection := completion_test_connection('pending-request')
	mut transaction := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut pending := IDBRequest.create_for_global_scope(connection.global_scope, 'items')
	pending.transaction_ = transaction
	mut list := transaction.request_list()
	list.append(pending)
	mut log := &TransactionCompletionLog{}
	pending.onsucceed_ = fn [transaction, mut log] () {
		assert transaction.state == .committing
		log.entries << 'request'
	}
	transaction.oncomplete_ = fn [mut log] () { log.entries << 'complete' }
	transaction.commit()!
	assert transaction.state == .committing
	assert transaction.cleanup_event_loop() == unsafe { nil }
	assert !run_next_database_task()
	pending.succeed(.undefined)
	assert log.entries == ['request']
	assert transaction.state == .committing
	assert list.is_empty()
	assert run_next_database_task()
	assert transaction.state == .finished
	assert log.entries == ['request', 'complete']
	assert !run_next_database_task()
	connection.close()
}

fn test_upgrade_complete_event_tasks_precede_open_success() {
	mut factory := IDBFactory.create('upgrade-complete-order')!
	mut open := factory.open('db', u64(1))!
	run_database_tasks()
	mut log := &TransactionCompletionLog{}
	mut upgrade := open.upgrade_transaction
	upgrade.oncomplete_ = fn [mut log] () {
		log.entries << 'complete'
		queue_a_database_task(fn [mut log] () { log.entries << 'task-from-complete' })
	}
	open.request.onsucceed_ = fn [mut log] () { log.entries << 'success' }
	open.finish_upgrade()!
	assert log.entries.len == 0
	assert upgrade.state == .committing
	assert open.connection.upgrade_active
	assert run_next_database_task()
	assert upgrade.state == .finished
	assert !open.connection.upgrade_active
	assert open.request.transaction_ == none
	assert log.entries == ['complete']
	assert run_next_database_task()
	assert log.entries == ['complete', 'task-from-complete']
	assert open.request.ready_state == .pending
	assert run_next_database_task()
	assert log.entries == ['complete', 'task-from-complete', 'success']
	open.connection.close()
}
