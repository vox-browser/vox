module indexeddb

fn index_async_connection(name string) !&IDBDatabase {
	mut factory := IDBFactory.create('https://index-async.test/' + name)!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	store.create_index('lookup', '', IDBIndexParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	return connection
}

fn test_index_async_get_waits_for_writes_and_preserves_the_returned_request() {
	mut connection := index_async_connection('ordered')!
	defer { connection.close() }
	mut tx := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := tx.object_store('items')!
	store.put_async(string_value('value'), number_key(7), false)!
	mut index := store.index('lookup')!
	request := index.get_async(IDBKeyRange.only(string_key('value'))!, false)!
	key_request := index.get_async(IDBKeyRange.only(string_key('value'))!, true)!
	assert request.ready_state == .pending && key_request.ready_state == .pending
	tx.deactivate()
	run_database_tasks()
	assert request.ready_state == .done && request.value.text == 'value'
	assert request.events == ['success'] && request.transaction_ != none
	assert (key_request.key or { panic('missing key') }).number == 7
	assert tx.state == .finished && tx.request_list_.is_empty()
}

fn test_index_async_get_survives_explicit_commit_and_checks_deleted_source_first() {
	mut connection := index_async_connection('commit')!
	defer { connection.close() }
	mut tx := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut store := tx.object_store('items')!
	mut index := store.index('lookup')!
	request := index.get_async(IDBKeyRange.only(string_key('absent'))!, false)!
	tx.commit()!
	run_database_tasks()
	assert request.ready_state == .done && request.error_message == ''
	assert request.result_kind == .undefined
	mut data := index.index_ or { panic('missing index') }
	data.deleted = true
	if _ := index.get_async(IDBKeyRange.unbounded(), false) { assert false }
	else { assert err.msg().starts_with('InvalidStateError:') }
}
