@[has_globals]
module indexeddb

fn test_upstream_key_and_range_entry_points() {
	key := Key.create_string('alpha')
	assert key.key_type() == .string_
	assert key.value_as_string()! == 'alpha'
	assert key.less_than(Key.create_string('beta'))
	assert Key.create_number(2).greater_than_or_equal(Key.create_number(2))
	assert Key.create_invalid().is_invalid()

	range := IDBKeyRange.create(Key.create_number(1), Key.create_number(3), false, true)!
	assert range.is_in_range(Key.create_number(1))!
	assert !range.is_in_range(Key.create_number(3))!
	assert range.key_range_lower()?.number == 1
	assert range.key_range_upper_open()
}

fn test_internal_object_store_mutation_log_reverts_insert_and_replace() {
	mut store := ObjectStoreData.create('store', false, none)
	store.records << ObjectStoreRecord{
		key: number_key(1)
		value: string_value('before')
	}
	mut log := MutationLog.create()
	store.set_mutation_log(log)
	start := log.position()
	store.remove_records_in_range(IDBKeyRange.only(number_key(1))!)
	store.store_a_record(ObjectStoreRecord{
		key: number_key(1)
		value: string_value('after')
	})!
	store.store_a_record(ObjectStoreRecord{
		key: number_key(2)
		value: string_value('inserted')
	})!
	assert store.records.len == 2
	assert store.records[0].value.text == 'after'
	store.revert_mutations_from(start)
	assert store.records.len == 1
	assert store.records[0].key.number == 1
	assert store.records[0].value.text == 'before'
}

fn test_internal_index_order_uniqueness_and_referenced_values() {
	mut store := ObjectStoreData.create('store', false, none)
	store.records = [
		ObjectStoreRecord{ key: number_key(1), value: string_value('one') },
		ObjectStoreRecord{ key: number_key(2), value: string_value('two') },
	]
	mut index := IndexData.create('by_name', 'name', true, false)
	index.store_a_record(IndexRecord{ key: string_key('a'), primary_key: number_key(1) })!
	// The store-record algorithm enforces uniqueness before calling the
	// internal Index::store_a_record primitive, exactly as in C++.
	index.store_a_record(IndexRecord{ key: string_key('b'), primary_key: number_key(2) })!
	assert index.has_record_with_key(string_key('a'))
	record := index.first_in_range(IDBKeyRange.only(string_key('a'))!)?
	assert index.referenced_value(record, store)?.text == 'one'
}

fn test_database_registry_connections_and_transaction_handle_identity() {
	DatabaseData.delete_for_key_and_name('storage', 'db')
	mut data := DatabaseData.create_for_key_and_name('storage', 'db')
	data.add_object_store(ObjectStoreData.create('items', false, none))
	assert DatabaseData.for_key_and_name('storage', 'db')? == data
	assert data.object_store_with_name('items')?.name == 'items'
	mut connection := IDBDatabase.create(data)
	assert data.associated_connections_as_heap_vector().len == 1
	mut transaction := IDBTransaction.create(connection, .readwrite, .default_, [
		'items',
	])
	first := transaction.get_or_create_object_store_handle('items')!
	second := transaction.get_or_create_object_store_handle('items')!
	assert first.name() == second.name()
	cached := transaction.object_store_handle_for('items')?
	assert cached.name() == 'items'
	connection.close()
	assert data.wait_for_connections_to_close()
	DatabaseData.delete_for_key_and_name('storage', 'db')
}

fn test_database_registry_inventory_and_dissociation() {
	DatabaseData.delete_for_key_and_name('registry-storage', 'registry-db')
	mut data := DatabaseData.create_for_key_and_name('registry-storage', 'registry-db')
	registry := idb_databases()
	key := database_registry_key('registry-storage', 'registry-db')
	assert key in registry
	registered := registry[key] or { panic('database missing from registry') }
	assert registered == data

	mut connection := IDBDatabase.create(data)
	assert data.connections == 1
	data.dissociate(connection)
	assert data.associated_connections.len == 0
	assert data.connections == 0
	connection.close()
	DatabaseData.delete_for_key_and_name('registry-storage', 'registry-db')
}

fn test_request_events_algorithms_and_multi_entry_conversion() {
	mut request := IDBRequest.create('store')
	fire_a_success_event(mut request, .count)
	assert request.done()
	assert request.result()! == .count

	mut failed := IDBRequest.create('store')
	fire_an_error_event(mut failed, 'ConstraintError')
	assert failed.has_error()
	assert failed.error()! == 'ConstraintError'

	key := convert_a_value_to_a_multi_entry_key(array_value([
		number_value(1),
		number_value(1),
		undefined_value(),
		string_value('x'),
	]))
	assert key.kind == .array
	assert key.subkeys().len == 2
	assert create_a_sorted_name_list(['z', 'a', 'm']) == ['a', 'm', 'z']
}
