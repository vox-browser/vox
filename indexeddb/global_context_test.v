module indexeddb

fn test_relevant_global_context_propagates_through_indexeddb_handles() {
	global_scope := IndexedDBGlobalScope.create('global-storage')
	mut factory := IDBFactory.create_for_global_scope(global_scope)!
	assert factory.relevant_global_scope() == global_scope
	assert factory.relevant_global_object() == global_scope
	assert factory.relevant_settings_object() == global_scope

	mut open := factory.open('global-database', u64(1))!
	run_database_tasks()
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut store := connection.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{
		key_path: 'id'
	})!
	mut index := store.create_index('by-name', 'name', IDBIndexParameters{})!
	assert connection.relevant_global_object() == global_scope
	assert connection.relevant_global_scope() == global_scope
	assert upgrade.relevant_global_object() == global_scope
	assert upgrade.relevant_global_scope() == global_scope
	assert store.relevant_global_object() == global_scope
	assert index.relevant_global_object() == global_scope
	assert index.object_store().name() == 'items'
	assert index.key_path_value()!.text == 'name'
	assert store.key_path_value().text == 'id'
	open.finish_upgrade()!
	run_database_tasks()

	mut transaction := connection.transaction(['items'], .readwrite, IDBTransactionOptions{})!
	mut transaction_store := transaction.object_store('items')!
	request := transaction_store.put(object_value({
		'id':   number_value(1)
		'name': string_value('first')
	}), none)!
	assert request.relevant_global_object() == global_scope
	assert request.relevant_global_scope() == global_scope
	assert request.request_transaction()? == transaction

	mut cursor_request := transaction_store.open_cursor(none, .next, false)!
	mut cursor := cursor_request.cursor
	assert cursor.relevant_global_object() == global_scope
	assert cursor.current_key()?.number == 1
	assert cursor.current_value()?.fields['name'].text == 'first'
	value_cursor := IDBCursorWithValue.from_cursor(cursor)!
	assert value_cursor.current_value()?.fields['name'].text == 'first'
	transaction.commit()!
	run_database_tasks()
	connection.close()
}

fn test_internal_database_adapter_dissociates_connections() {
	mut data := DatabaseData.create('adapter-database')
	mut connection := new_connection(data)
	mut database := Database.from_data(data)
	database.dissociate(connection)
	assert data.associated_connections.len == 0
	connection.close()
}

fn test_binding_offsets_address_the_translated_handle_fields() {
	assert IDBCursor.request_offset() == uint(__offsetof(IDBCursor, request))
	assert IDBIndex.object_store_handle_offset() == uint(__offsetof(IDBIndex, object_store_handle_))
	assert IDBRequest.transaction_offset() == uint(__offsetof(IDBRequest, transaction_))
	assert IDBTransaction.connection_offset() == uint(__offsetof(IDBTransaction, database))
	assert IDBTransaction.error_offset() == uint(__offsetof(IDBTransaction, error_message))
}

fn test_object_store_without_key_path_exposes_null_binding_value() {
	mut data := DatabaseData.create('out-of-line')
	mut store_data := ObjectStoreData.create('store', false, none)
	data.stores['store'] = store_data
	mut connection := new_connection(data)
	mut transaction := IDBTransaction.create(connection, .readonly, .default_, ['store'])
	store := transaction.object_store('store')!
	assert store.key_path_value().kind == .null_
	transaction.commit()!
	run_database_tasks()
	connection.close()
}
