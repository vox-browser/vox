module indexeddb

fn cursor_test_database() !(&IDBFactory, &IDBDatabase) {
	mut factory := IDBFactory.create('https://cursor.test')!
	mut open := factory.open('people-db', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut people := connection.create_object_store(mut upgrade, 'people', IDBObjectStoreParameters{
		key_path:       'id'
		auto_increment: true
	})!
	people.create_index('by_name', 'name', IDBIndexParameters{ unique: true })!
	open.finish_upgrade()!
	return factory, connection
}

fn cursor_person(name string, age f64) Value {
	return object_value({
		'name': string_value(name)
		'age':  number_value(age)
	})
}

fn test_index_queries_unique_multi_entry_and_rename() {
	mut factory := IDBFactory.create('index-test')!
	mut open := factory.open('db', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	if _ := connection.create_object_store(mut upgrade, 'invalid', IDBObjectStoreParameters{
		key_path: []string{}
	})
	{
		assert false
	} else {
		assert err.msg().contains('SyntaxError')
	}
	mut books := connection.create_object_store(mut upgrade, 'books', IDBObjectStoreParameters{})!
	books.create_index('author', 'author', IDBIndexParameters{})!
	books.create_index('tags', 'tags', IDBIndexParameters{ multi_entry: true })!
	if _ := books.create_index('invalid', []string{}, IDBIndexParameters{}) {
		assert false
	} else {
		assert err.msg().contains('SyntaxError')
	}
	open.finish_upgrade()!

	mut write := connection.transaction(['books'], .readwrite, IDBTransactionOptions{})!
	mut store := write.object_store('books')!
	store.add(object_value({
		'author': string_value('Le Guin')
		'tags':   array_value([string_value('sf'), null_value(),
			string_value('classic'), string_value('sf')])
	}), number_key(1))!
	store.add(object_value({
		'author': string_value('Le Guin')
		'tags':   array_value([string_value('sf')])
	}), number_key(2))!
	store.add(object_value({
		'author': string_value('Butler')
		'tags':   array_value([string_value('sf')])
	}), number_key(3))!
	mut author := store.index('author')!
	authors := author.get_all(IDBGetAllOptions{ range: IDBKeyRange.only(string_key('Le Guin'))! })!
	assert authors.values.len == 2
	assert author.count(none)!.count == 3
	mut tags := store.index('tags')!
	assert tags.count(IDBKeyRange.only(string_key('sf'))!)!.count == 3
	assert tags.count(IDBKeyRange.only(string_key('classic'))!)!.count == 1
	write.commit()!
}

fn test_cursor_iteration_advance_update_delete_and_primary_key() {
	_, mut connection := cursor_test_database()!
	mut write := connection.transaction(['people'], .readwrite, IDBTransactionOptions{})!
	mut store := write.object_store('people')!
	store.add(cursor_person('Ada', 1), none)!
	store.add(cursor_person('Grace', 2), none)!
	store.add(cursor_person('Lin', 3), none)!
	request := store.open_cursor(none, .next, false)!
	mut cursor := request.cursor
	assert cursor.key()!.number == 1
	assert cursor.value()!.fields['name'].text == 'Ada'
	assert cursor.continue_to(number_key(3))!
	assert cursor.key()!.number == 3
	cursor.update(object_value({
		'id':   number_value(3)
		'name': string_value('Lin')
		'age':  number_value(30)
	}))!
	cursor.delete()!
	assert store.count(none)!.count == 2
	write.commit()!
}

fn test_cursor_validation_continue_primary_key_and_key_only_mutations() {
	_, mut connection := cursor_test_database()!
	mut write := connection.transaction(['people'], .readwrite, IDBTransactionOptions{})!
	mut store := write.object_store('people')!
	store.add(cursor_person('Ada', 1), none)!
	store.add(cursor_person('Grace', 2), none)!
	mut by_name := store.index('by_name')!
	request := by_name.open_cursor(none, .next, false)!
	mut cursor := request.cursor
	if _ := cursor.continue_primary_key(string_key('Ada'), number_key(1)) {
		assert false
	} else {
		assert err.msg().contains('DataError')
	}
	assert cursor.continue_primary_key(string_key('Ada'), number_key(2))!
	assert cursor.key()!.text == 'Grace'

	inactive_request := by_name.open_cursor(none, .next, false)!
	mut inactive_cursor := inactive_request.cursor
	write.deactivate()
	if _ := inactive_cursor.continue_primary_key(string_key('Grace'), number_key(2)) {
		assert false
	} else {
		assert err.msg().contains('TransactionInactiveError')
	}
	write.activate()
	assert !inactive_cursor.advance(2)!
	if _ := inactive_cursor.continue_primary_key(string_key('Grace'), number_key(2)) {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}

	key_request := by_name.open_cursor(none, .next, true)!
	mut key_cursor := key_request.cursor
	if _ := key_cursor.update(cursor_person('Changed', 3)) {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}
	if _ := key_cursor.delete() {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}
	write.commit()!
}

fn test_cursor_rejects_deleted_source() {
	mut factory := IDBFactory.create('deleted-cursor-source')!
	mut open := factory.open('db', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	store.add(object_value({
		'name': string_value('one')
	}), number_key(1))!
	store.create_index('by_name', 'name', IDBIndexParameters{})!
	mut index := store.index('by_name')!
	request := index.open_cursor(none, .next, false)!
	mut cursor := request.cursor
	store.delete_index('by_name')!
	if _ := cursor.advance(1) {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}
	open.finish_upgrade()!
}

fn test_request_list_and_version_change_event() {
	mut list := RequestList{}
	mut first := IDBRequest.create('store')
	mut second := IDBRequest.create('store')
	list.append(first)
	list.append(first)
	list.append(second)
	assert list.length() == 2
	assert !list.all_processed()
	first.succeed(.undefined)
	second.fail('UnknownError')
	assert list.all_processed()
	assert list.remove(first)
	assert !list.contains(first)
	event := new_version_change_event('upgradeneeded', 1, u64(2))
	assert event.old_version == 1
	assert event.new_version or { 0 } == 2
}

fn complete_queued_request(mut request IDBRequest) {
	request.succeed(.undefined)
}

fn observe_all_processed() {}

fn test_request_list_serializes_steps_and_honors_blocking_and_completion_callback() {
	mut list := RequestList{}
	mut first := IDBRequest.create('first')
	mut second := IDBRequest.create('second')
	list.block_execution()
	assert list.execution_is_blocked()
	list.enqueue(first, complete_queued_request)
	list.enqueue(second, complete_queued_request)
	assert first.ready_state == .pending
	assert second.ready_state == .pending
	list.unblock_execution()
	assert first.ready_state == .done
	assert second.ready_state == .pending
	list.on_request_processed()
	assert second.ready_state == .done
	assert list.requests() == [first, second]
	list.set_on_all_processed(observe_all_processed)
	assert list.all_processed_notifications == 1
	list.check_all_processed()
	assert list.all_processed_notifications == 1
}
