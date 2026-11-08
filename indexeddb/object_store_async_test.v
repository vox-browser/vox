module indexeddb

fn async_store_connection(name string) !&IDBDatabase {
	mut factory := IDBFactory.create('https://async-store.test/${name}')!
	mut open := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	open.finish_upgrade()!
	run_database_tasks()
	return connection
}

fn test_async_store_clones_at_call_and_executes_requests_in_order_before_commit() {
	mut connection := async_store_connection('ordered')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	mut value := object_value({
		'name': string_value('before')
	})
	mut put := store.put_async(value, string_key('key'), false)!
	value.fields['name'] = string_value('after')
	mut get := store.get_async(IDBKeyRange.only(string_key('key'))!)!
	assert put.ready_state == .pending && get.ready_state == .pending
	assert connection.data.stores['items'].records.len == 0
	assert transaction.request_list_.length() == 2
	transaction.deactivate()
	assert run_next_database_task()
	assert put.ready_state == .done && get.ready_state == .pending
	assert put.key or { panic('missing key') }.text == 'key'
	assert run_next_database_task()
	assert get.value.fields['name'].text == 'before'
	assert transaction.state == .committing
	assert run_next_database_task()
	assert transaction.state == .finished
	assert transaction.request_list_.is_empty()
}

fn test_async_store_validation_is_synchronous_and_request_failure_aborts_mutations() {
	mut connection := async_store_connection('failure')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	if _ := store.put_async(string_value('invalid'), none, false) {
		assert false
	} else {
		assert err.msg().starts_with('DataError:')
		assert transaction.request_list_.is_empty()
	}
	first := store.put_async(string_value('first'), string_key('key'), true)!
	duplicate := store.put_async(string_value('second'), string_key('key'), true)!
	later := store.get_async(IDBKeyRange.only(string_key('key'))!)!
	run_database_tasks()
	assert first.ready_state == .done
	assert duplicate.error_message.starts_with('ConstraintError:')
	assert later.error_message.starts_with('AbortError:')
	assert transaction.state == .aborted
	assert connection.data.stores['items'].records.len == 0
}

fn test_async_store_explicit_commit_waits_for_queued_write() {
	mut connection := async_store_connection('explicit-commit')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	put := store.put_async(string_value('committed'), string_key('key'), false)!
	transaction.commit()!
	run_database_tasks()
	assert put.error_message == ''
	assert transaction.state == .finished
	assert connection.data.stores['items'].records.len == 1
}

fn test_upgrade_completion_waits_for_writes_added_by_request_handlers() {
	mut factory := IDBFactory.create('https://async-store.test/upgrade')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	opening.prepare_upgrade_completion()!
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	mut first := store.put_async(string_value('first'), string_key('first'), false)!
	first.onsucceed_ = fn [mut store] () {
		store.put_async(string_value('second'), string_key('second'), false) or { panic(err) }
	}
	upgrade.deactivate()
	run_database_tasks()
	assert upgrade.state == .finished
	assert connection.data.stores['items'].records.len == 2
	assert opening.request.events == ['upgradeneeded', 'success']
	assert opening.request.transaction_ == none
	connection.close()
}

fn test_request_failure_rolls_back_an_explicitly_committing_transaction() {
	mut connection := async_store_connection('commit-failure')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	store.put_async(string_value('first'), string_key('key'), true)!
	store.put_async(string_value('duplicate'), string_key('key'), true)!
	transaction.commit()!
	run_database_tasks()
	assert transaction.state == .aborted
	assert transaction.error_message.starts_with('ConstraintError:')
	assert transaction.events == ['abort']
	assert connection.data.stores['items'].records.len == 0
}

fn test_async_upgrade_failure_rolls_back_and_finishes_the_open_request() {
	mut factory := IDBFactory.create('https://async-store.test/upgrade-abort')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	opening.prepare_upgrade_completion()!
	mut connection := opening.connection
	mut upgrade := opening.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	store.put_async(string_value('first'), string_key('key'), true)!
	store.put_async(string_value('duplicate'), string_key('key'), true)!
	upgrade.deactivate()
	run_database_tasks()
	assert upgrade.state == .aborted
	assert opening.request.ready_state == .done
	assert opening.request.error_message.starts_with('AbortError:')
	assert opening.request.events == ['upgradeneeded', 'error']
	assert opening.request.transaction_ == none
	assert connection.state == .closed
	assert factory.database_infos().len == 0
}

fn test_async_counts_observe_prior_writes_and_finish_after_explicit_commit() {
	mut connection := async_store_connection('count')!
	defer { connection.close() }
	mut tx := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := tx.object_store('items')!
	store.put_async(string_value('one'), number_key(1), false)!
	store.put_async(string_value('two'), number_key(2), false)!
	all := store.count_async(none)!
	one := store.count_async(IDBKeyRange.only(number_key(1))!)!
	assert all.ready_state == .pending && one.ready_state == .pending
	tx.commit()!
	run_database_tasks()
	assert all.result_kind == .count && all.count == 2
	assert one.result_kind == .count && one.count == 1
	assert tx.state == .finished
}
