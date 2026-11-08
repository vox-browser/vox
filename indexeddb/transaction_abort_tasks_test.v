module indexeddb

@[heap]
struct AbortTaskLog {
mut:
	events []string
}

fn test_abort_rolls_back_immediately_and_delivers_request_errors_before_abort() {
	mut factory := IDBFactory.create('https://abort-tasks.test')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	mut tx := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut store := tx.object_store('items')!
	mut request := store.get_async(IDBKeyRange.unbounded())!
	mut log := &AbortTaskLog{}
	request.onerror_ = fn [mut log, request] () {
		assert request.ready_state == .done && request.error_message.starts_with('AbortError:')
		log.events << 'request error'
	}
	tx.onabort_ = fn [mut log] () { log.events << 'abort' }
	tx.abort('')!
	assert tx.state == .aborted && request.aborted && request.processed
	assert request.ready_state == .pending && log.events == []string{}
	run_database_tasks()
	assert log.events == ['request error', 'abort']
	assert tx.request_list_.is_empty()
	connection.close()
}
