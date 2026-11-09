module indexeddb

fn test_key_lookup_and_index_count_wait_for_writes_and_explicit_commit() {
	mut factory := IDBFactory.create('https://key-count-async.test/ordered')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut schema := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	schema.create_index('lookup', '', IDBIndexParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	mut index := store.index('lookup')!
	store.put_async(string_value('value'), array_key([number_key(7)]), false)!
	key_request := store.get_key_async(IDBKeyRange.unbounded())!
	count_request := index.count_async(IDBKeyRange.only(string_key('value'))!)!
	assert key_request.ready_state == .pending && count_request.ready_state == .pending
	transaction.commit()!
	run_database_tasks()
	assert key_request.events == ['success']
	assert (key_request.key or { panic('missing key') }).items[0].number == 7
	assert count_request.events == ['success'] && count_request.count == 1
	assert transaction.state == .finished && transaction.request_list_.is_empty()
	connection.close()
}

fn test_key_lookup_and_index_count_check_deleted_sources_before_inactive_transactions() {
	mut factory := IDBFactory.create('https://key-count-async.test/deleted')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	mut index := store.create_index('lookup', '', IDBIndexParameters{})!
	store.delete_index('lookup')!
	connection.delete_object_store(mut upgrade, 'items')!
	opening.finish_upgrade()!
	run_database_tasks()
	if _ := store.get_key_async(IDBKeyRange.unbounded()) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	if _ := index.count_async(none) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	connection.close()
}
