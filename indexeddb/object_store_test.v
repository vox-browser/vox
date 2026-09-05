module indexeddb

fn person(name string, age f64) Value {
	return object_value({
		'name': string_value(name)
		'age':  number_value(age)
	})
}

fn object_store_test_database() !(&IDBFactory, &IDBDatabase) {
	storage_key := 'https://object-store.test'
	DatabaseData.delete_for_key_and_name(storage_key, 'people-db')
	mut factory := IDBFactory.create(storage_key)!
	mut open := factory.open('people-db', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut people := connection.create_object_store(mut upgrade, 'people', IDBObjectStoreParameters{
		key_path: 'id'
		auto_increment: true
	})!
	people.create_index('by_name', 'name', IDBIndexParameters{ unique: true })!
	open.finish_upgrade()!
	return factory, connection
}

fn test_object_store_add_put_get_delete_and_key_generator() {
	_, mut connection := object_store_test_database()!
	mut transaction := connection.transaction(['people'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('people')!
	first := store.add(person('Ada', 36), none)!
	assert first.result()! == .key
	assert first.key or { panic('no generated key') }.number == 1
	second := store.add(person('Grace', 40), none)!
	assert second.key or { panic('no generated key') }.number == 2
	duplicate_name := store.add(person('Ada', 50), none)!
	assert duplicate_name.error()!.contains('ConstraintError')
	assert store.count(none)!.count == 2
	// The failed request rolls its key-generator and index mutations back from
	// the request's mutation-log position; it must not consume key 3.
	third := store.add(person('Katherine', 32), none)!
	assert third.key or { panic('no generated key') }.number == 3
	assert store.count(none)!.count == 3

	range := IDBKeyRange.only(number_key(1))!
	got := store.get(range)!
	assert got.value.fields['name'].text == 'Ada'
	updated := object_value({
		'id':   number_value(1)
		'name': string_value('Ada Lovelace')
		'age':  number_value(37)
	})
	store.put(updated, none)!
	assert store.get(range)!.value.fields['age'].number == 37
	store.delete(IDBKeyRange.only(number_key(2))!)!
	assert store.count(none)!.count == 2
	transaction.commit()!
}

fn test_out_of_line_keys_ranges_order_and_structured_clone() {
	mut factory := IDBFactory.create('partition')!
	mut open := factory.open('db', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	open.finish_upgrade()!
	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut store := transaction.object_store('items')!
	mut original := object_value({
		'payload': binary_value([u8(1), 2])
	})
	store.add(original, number_key(3))!
	original.fields['payload'] = binary_value([u8(9)])
	store.add(string_value('one'), number_key(1))!
	store.add(string_value('two'), number_key(2))!
	between := IDBKeyRange.bound(number_key(1), number_key(3), true, false)!
	all := store.get_all(IDBGetAllOptions{ range: between })!
	assert all.values.len == 2
	assert all.values[0].text == 'two'
	assert all.values[1].fields['payload'].bytes == [u8(1), 2]
	reverse := store.get_all_keys(IDBGetAllOptions{ direction: .prev, count: u32(2) })!
	assert reverse.keys.map(it.number) == [3.0, 2.0]
	transaction.abort('')!
	mut read := connection.transaction(['items'], .readonly, IDBTransactionOptions{})!
	mut read_store := read.object_store('items')!
	assert read_store.count(none)!.count == 0
}

fn test_transaction_state_and_schema_constraints() {
	_, mut connection := object_store_test_database()!
	mut readonly := connection.transaction(['people'], .readonly, IDBTransactionOptions{})!
	mut store := readonly.object_store('people')!
	if _ := store.add(person('Ada', 1), none) {
		assert false
	} else {
		assert err.msg().contains('ReadOnlyError')
	}
	readonly.deactivate()
	if _ := store.count(none) {
		assert false
	} else {
		assert err.msg().contains('TransactionInactiveError')
	}
	readonly.activate()
	readonly.commit()!
	if _ := readonly.commit() {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}
}
