module indexeddb

fn batch_async_connection(name string) !&IDBDatabase {
	mut factory := IDBFactory.create('https://batch-async.test/' + name)!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	store.create_index('lookup', 'field', IDBIndexParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	return connection
}

fn test_batch_queries_share_the_write_queue_and_survive_explicit_commit() {
	mut connection := batch_async_connection('ordered')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	mut index := store.index('lookup')!
	for key in 1 .. 4 {
		store.put_async(object_value({
			'field': string_value(if key < 3 { 'a' } else { 'b' })
		}), number_key(key), false)!
	}
	options := IDBGetAllOptions{ count: u32(2), direction: .prev }
	values := store.get_all_async(options, .values)!
	keys := store.get_all_async(options, .keys)!
	records := store.get_all_async(options, .records)!
	index_values := index.get_all_async(options, .values)!
	index_keys := index.get_all_async(options, .keys)!
	index_records := index.get_all_async(IDBGetAllOptions{ direction: .prevunique }, .records)!
	assert values.ready_state == .pending && index_records.ready_state == .pending
	assert connection.data.stores['items'].records.len == 0
	transaction.commit()!
	run_database_tasks()
	assert values.values.len == 2 && values.values[0].fields['field'].text == 'b'
	assert keys.keys.len == 2 && keys.keys[0].number == 3 && keys.keys[1].number == 2
	assert records.records.len == 2 && records.records[0].primary_key.number == 3
	assert index_values.values.len == 2 && index_values.values[1].fields['field'].text == 'a'
	assert index_keys.keys.len == 2 && index_keys.keys[0].number == 3
	assert index_records.records.len == 2 && index_records.records[0].key.text == 'b'
	assert index_records.records[1].primary_key.number == 1
	assert transaction.state == .finished && transaction.request_list_.is_empty()
}

fn test_batch_queries_validate_deleted_sources_and_abort_pending_requests() {
	mut connection := batch_async_connection('deleted')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	mut index := store.index('lookup')!
	request := store.get_all_async(IDBGetAllOptions{}, .records)!
	transaction.abort('AbortError: requested')!
	run_database_tasks()
	assert request.error_message.starts_with('AbortError:')
	mut data := index.index_ or { panic('missing index') }
	data.deleted = true
	if _ := index.get_all_async(IDBGetAllOptions{}, .values) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
	mut source := store.store_ or { panic('missing store') }
	source.deleted = true
	if _ := store.get_all_async(IDBGetAllOptions{}, .keys) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}
