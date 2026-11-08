module indexeddb

fn test_aborting_created_schema_marks_retained_store_and_index_handles_deleted() {
	mut factory := IDBFactory.create('https://schema-metadata.test/abort')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut tx := opening.upgrade_transaction
	mut store := connection.create_object_store(mut tx, 'new', IDBObjectStoreParameters{})!
	mut index := store.create_index('created', 'field', IDBIndexParameters{})!
	mut deleted := store.create_index('deleted', 'field', IDBIndexParameters{})!
	store.delete_index('deleted')!
	tx.abort('')!
	assert tx.object_store_names() == []string{}
	mut handles := [index, deleted]
	for mut handle in handles {
		if _ := handle.get_async(IDBKeyRange.unbounded(), false) { assert false }
		else { assert err.msg().starts_with('InvalidStateError:') }
	}
	assert store.index_names() == []string{}
	run_database_tasks()
}

fn test_finished_index_handle_does_not_reflect_later_transactions_rename() {
	mut factory := IDBFactory.create('https://schema-metadata.test/rename')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut tx := opening.upgrade_transaction
	mut store := connection.create_object_store(mut tx, 'items', IDBObjectStoreParameters{})!
	old_index := store.create_index('original', 'field', IDBIndexParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	connection.close()
	mut second := factory.open('items', u64(2))!
	run_database_tasks()
	mut upgrade := second.upgrade_transaction
	mut next_store := upgrade.object_store('items')!
	mut next_index := next_store.index('original')!
	next_index.rename('renamed')!
	assert old_index.name() == 'original'
	assert next_index.name() == 'renamed'
	second.finish_upgrade()!
	run_database_tasks()
	second.connection.close()
}
