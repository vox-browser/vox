module indexeddb

fn test_key_path_grammar_accepts_unicode_identifiers_and_valid_sequences() {
	for path in ['', 'id', '$._', 'return.function', 'a0.b1', '水.é', '℘.á', 'a\u200c.b\u200d'] {
		assert is_valid_key_path(KeyPath(path)), path
		assert is_valid_key_path(KeyPath([path])), path
	}
}

fn test_key_path_grammar_rejects_empty_components_and_invalid_identifier_characters() {
	for path in ['j a', '.yo', 'yo,lo', '3m', 'my.1337', '..yo', 'y..o', 'y.o.', 'm.*', '"m"', 'm%', 'm/', 'm/a', 'm&', 'm!', '*', '^m', '/m/', '😀', '\u200c', 'a.́b'] {
		assert !is_valid_key_path(KeyPath(path)), path
		assert !is_valid_key_path(KeyPath(['valid', path])), path
	}
	assert !is_valid_key_path(KeyPath([]string{}))
}

fn test_active_upgrade_keeps_schema_access_after_close_is_requested() {
	mut factory := IDBFactory.create('https://key-path-grammar.test')!
	mut opening := factory.open('grammar', u64(1))!
	run_database_tasks()
	mut connection := opening.connection
	mut transaction := opening.upgrade_transaction
	connection.close()
	assert connection.state == .closing
	if _ := connection.create_object_store(mut transaction, 'invalid', IDBObjectStoreParameters{key_path: KeyPath('bad path')}) { assert false }
	else { assert err.msg().starts_with('SyntaxError:') }
	store := connection.create_object_store(mut transaction, 'valid', IDBObjectStoreParameters{key_path: KeyPath('valid.path')})!
	assert store.name() == 'valid'
	transaction.abort('')!
	run_database_tasks()
}
