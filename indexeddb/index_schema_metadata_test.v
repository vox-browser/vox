module indexeddb

fn test_index_schema_metadata_remains_readable_after_its_store_is_deleted() {
	mut factory := IDBFactory.create('retained-index-metadata')!
	mut opening := factory.open('retained-index-metadata', u64(1))!
	run_database_tasks()
	mut upgrade := opening.upgrade_transaction
	mut database := opening.connection
	mut store := database.create_object_store(mut upgrade, 'items', IDBObjectStoreParameters{})!
	mut index := store.create_index('kept', ['nested.key'], IDBIndexParameters{ unique: true })!
	mut tags := store.create_index('tags', 'tags', IDBIndexParameters{ multi_entry: true })!
	database.delete_object_store(mut upgrade, 'items')!
	assert index.name() == 'kept'
	assert index.unique()
	assert !index.multi_entry()
	assert tags.multi_entry()
	path := index.key_path()!
	assert path is []string
	if path is []string { assert path == ['nested.key'] }
	upgrade.abort('AbortError: test finished')!
	assert index.unique()
	assert tags.multi_entry()
	assert index.key_path_value()!.items[0].text == 'nested.key'
}
