module indexeddb

fn async_cursor_connection(name string) !&IDBDatabase {
	mut factory := IDBFactory.create('https://async-cursor.test/${name}')!
	mut open := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	store.create_index('by_value', '', IDBIndexParameters{})!
	open.finish_upgrade()!
	run_database_tasks()
	return connection
}

fn test_async_cursor_reuses_its_request_in_order_and_reads_the_live_store() {
	mut connection := async_cursor_connection('ordered')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	store.put_async(string_value('one'), number_key(1), false)!
	store.put_async(string_value('three'), number_key(3), false)!
	mut request := store.open_cursor_async(none, .next, false)!
	mut log := &AsyncCursorLog{}
	request.onsucceed_ = fn [mut request, mut store, mut log] () {
		assert request.ready_state == .done
		if request.result_kind != .cursor {
			assert request.value.kind == .null_
			log.exhausted = true
			return
		}
		mut cursor := request.cursor
		log.keys << cursor.key()!.number
		if log.keys.len == 1 {
			store.put_async(string_value('two'), number_key(2), false) or { panic(err) }
		}
		cursor.continue_async(none) or { panic(err) }
		assert request.ready_state == .pending
		assert !cursor.got_value
		if _ := cursor.continue_async(none) { assert false }
	}
	assert request.ready_state == .pending
	transaction.deactivate()
	run_database_tasks()
	assert log.keys == [f64(1), 2, 3]
	assert log.exhausted
	assert request.events == ['success', 'success', 'success', 'success']
	assert transaction.state == .finished
	assert transaction.request_list_.is_empty()
}

@[heap]
struct AsyncCursorLog {
mut:
	keys []f64
	exhausted bool
}

fn test_async_index_cursor_direction_advance_and_explicit_commit() {
	mut connection := async_cursor_connection('index')!
	defer { connection.close() }
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	store.put_async(string_value('same'), number_key(1), false)!
	store.put_async(string_value('same'), number_key(2), false)!
	store.put_async(string_value('same'), number_key(3), false)!
	mut index := store.index('by_value')!
	mut request := index.open_cursor_async(none, .prev, true)!
	mut log := &AsyncCursorLog{}
	request.onsucceed_ = fn [mut request, mut log] () {
		mut cursor := request.cursor
		assert !cursor.with_value
		assert cursor.key()!.text == 'same'
		log.keys << cursor.primary_key()!.number
		if log.keys.len == 1 {
			cursor.advance_async(2) or { panic(err) }
		}
	}
	transaction.deactivate()
	run_database_tasks()
	assert log.keys == [f64(3), 1]
	assert transaction.state == .finished
	mut read := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut read_store := read.object_store('items')!
	result := read_store.open_cursor_async(none, .next, false)!
	read.commit()!
	run_database_tasks()
	assert result.result_kind == .cursor
	assert result.cursor.key()!.number == 1
	assert read.state == .finished
}
