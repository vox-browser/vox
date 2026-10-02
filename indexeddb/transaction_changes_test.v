module indexeddb

fn test_transaction_changes_are_coalesced_by_key_and_schema_operation() {
	mut log := MutationLog.create()
	log.note_object_store_created()
	log.note_object_store_renamed('old-store')
	log.note_records_deleted([
		ObjectStoreRecord{ key: number_key(1), value: string_value('before') },
		ObjectStoreRecord{ key: number_key(3), value: string_value('deleted') },
	])
	log.note_record_stored(number_key(1))
	log.note_record_stored(number_key(2))
	log.note_record_stored(number_key(4))
	log.note_records_deleted([
		ObjectStoreRecord{ key: number_key(4), value: string_value('cancelled') },
	])

	mut changes := TransactionChanges{}
	log.append_changes('database', 'new-store', mut changes)

	assert !changes.is_empty()
	assert changes.added.len == 3
	assert changes.added[0].object_store_name == 'new-store'
	assert changes.added[1].object_store_name == 'new-store'
	assert changes.added[2].key?.number == 2
	assert changes.changed.len == 1
	assert changes.changed[0].key?.number == 1
	assert changes.deleted.len == 2
	assert changes.deleted[0].object_store_name == 'old-store'
	assert changes.deleted[1].key?.number == 3
}

fn test_commit_reports_changes_before_discarding_mutation_logs() {
	mut data := DatabaseData.create('devtools-database')
	mut store := ObjectStoreData.create('items', false, none)
	data.stores['items'] = store
	mut connection := new_connection(data)
	connection.set_devtools_inspection_context('https://example.test/', true)
	mut transaction := IDBTransaction.create(connection, .readwrite, .default_, [
		'items',
	])
	mut handle := transaction.object_store('items')!
	handle.put(string_value('value'), number_key(7))!

	transaction.commit()!
	run_database_tasks()

	assert connection.devtools_notifications.len == 1
	assert connection.devtools_notifications[0].document_url == 'https://example.test/'
	changes := connection.devtools_notifications[0].changes
	assert changes.added.len == 1
	assert changes.added[0].database_name == 'devtools-database'
	assert changes.added[0].object_store_name == 'items'
	assert changes.added[0].key?.number == 7
	assert transaction.store_mutation_logs.len == 0
	connection.close()
}

fn test_commit_skips_empty_or_inactive_devtools_notifications() {
	mut data := DatabaseData.create('quiet-database')
	mut store := ObjectStoreData.create('items', false, none)
	data.stores['items'] = store
	mut connection := new_connection(data)
	connection.set_devtools_inspection_context('https://example.test/', true)
	mut empty_transaction := IDBTransaction.create(connection, .readwrite, .default_, [
		'items',
	])
	empty_transaction.commit()!
	run_database_tasks()
	assert connection.devtools_notifications.len == 0

	connection.set_devtools_inspection_context('https://example.test/', false)
	mut transaction := IDBTransaction.create(connection, .readwrite, .default_, [
		'items',
	])
	mut handle := transaction.object_store('items')!
	handle.put(string_value('hidden'), number_key(1))!
	transaction.commit()!
	run_database_tasks()
	assert connection.devtools_notifications.len == 0
	connection.close()
}
