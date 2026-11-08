module indexeddb

fn test_unique_index_population_runs_after_prior_requests_and_aborts_later_requests() {
	mut factory := IDBFactory.create('https://index-population.test/failure')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	opening.prepare_upgrade_completion()!
	mut tx := opening.upgrade_transaction
	mut store := opening.connection.create_object_store(mut tx, 'items', IDBObjectStoreParameters{})!
	first := store.put_async(string_value('same'), number_key(1), false)!
	second := store.put_async(string_value('same'), number_key(2), false)!
	store.create_index_async('unique', '', IDBIndexParameters{unique: true})!
	later := store.put_async(string_value('later'), number_key(3), false)!
	tx.deactivate()
	run_database_tasks()
	assert first.events == ['success'] && second.events == ['success']
	assert later.events == ['error'] && later.error_message.starts_with('AbortError:')
	assert tx.state == .aborted && tx.error_message.starts_with('ConstraintError:')
	assert opening.request.error_message.starts_with('AbortError:')
}

fn test_requests_keep_indexes_that_are_deleted_after_the_request_was_made() {
	mut factory := IDBFactory.create('https://index-population.test/deletion')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	opening.prepare_upgrade_completion()!
	mut tx := opening.upgrade_transaction
	mut store := opening.connection.create_object_store(mut tx, 'items', IDBObjectStoreParameters{})!
	store.create_index_async('unique', '', IDBIndexParameters{unique: true})!
	first := store.put_async(string_value('same'), number_key(1), false)!
	mut duplicate := store.put_async(string_value('same'), number_key(2), false)!
	duplicate.onerror_ = fn [mut duplicate] () { duplicate.error_event_canceled_ = true }
	store.delete_index('unique')!
	later := store.put_async(string_value('same'), number_key(3), false)!
	tx.deactivate()
	run_database_tasks()
	assert first.events == ['success'] && later.events == ['success']
	assert duplicate.error_message.starts_with('ConstraintError:')
	assert tx.state == .finished && store.index_names() == []string{}
	assert opening.connection.data.stores['items'].records.len == 2
	opening.connection.close()
}
