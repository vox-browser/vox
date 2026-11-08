module indexeddb

fn test_closed_connection_keeps_its_own_schema_names_after_a_later_upgrade() {
	mut factory := IDBFactory.create('https://closed-schema.test')!
	mut opening := factory.open('items', u64(1))!
	run_database_tasks()
	mut original := opening.connection
	mut tx := opening.upgrade_transaction
	original.create_object_store(mut tx, 'first', IDBObjectStoreParameters{})!
	opening.finish_upgrade()!
	run_database_tasks()
	original.close()
	mut next := factory.open('items', u64(2))!
	run_database_tasks()
	mut current := next.connection
	mut upgrade := next.upgrade_transaction
	current.create_object_store(mut upgrade, 'second', IDBObjectStoreParameters{})!
	assert current.object_store_names() == ['first', 'second']
	assert original.object_store_names() == ['first']
	next.finish_upgrade()!
	run_database_tasks()
	current.close()
}
