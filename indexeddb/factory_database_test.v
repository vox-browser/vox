module indexeddb

fn create_people_database() !(&IDBFactory, &IDBDatabase) {
	mut factory := IDBFactory.create('https://example.test')!
	mut open := factory.open('people-db', u64(1))!
	assert open.request.events == ['upgradeneeded']
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	mut people := connection.create_object_store(mut upgrade, 'people', IDBObjectStoreParameters{
		key_path:       'id'
		auto_increment: true
	})!
	people.create_index('by_name', 'name', IDBIndexParameters{ unique: true })!
	if _ := connection.transaction(['people'], .readonly, IDBTransactionOptions{}) {
		assert false
	} else {
		assert err.msg().contains('InvalidStateError')
	}
	open.finish_upgrade()!
	assert open.request.ready_state == .done
	return factory, connection
}

fn test_factory_open_upgrade_reopen_and_database_listing() {
	mut factory, mut connection := create_people_database()!
	assert connection.name() == 'people-db'
	assert connection.version() == 1
	assert connection.object_store_names() == ['people']
	infos := factory.database_infos()
	assert infos.len == 1
	assert infos[0].name == 'people-db'
	assert infos[0].version == 1

	mut reopened := factory.open('people-db', none)!
	assert reopened.request.ready_state == .done
	assert reopened.request.events == ['success']
	assert factory.cmp(number_key(1), string_key('1'))! == -1
	if _ := connection.transaction(['people'], .versionchange, IDBTransactionOptions{}) {
		assert false
	} else {
		assert err.msg().contains('TypeError')
	}
	mut second := reopened.connection
	second.close()
	connection.close()
	assert connection.state == .closed

	deleted := factory.delete_database('people-db')
	assert deleted.request.ready_state == .done
	assert factory.database_infos().len == 0
}

fn test_version_errors_blocked_delete_and_upgrade_abort_restore_schema() {
	mut factory, mut first := create_people_database()!
	blocked := factory.delete_database('people-db')
	assert blocked.request.ready_state == .pending
	assert blocked.request.events == ['blocked']

	mut upgrade_request := factory.open('people-db', u64(2))!
	mut connection := upgrade_request.connection
	mut transaction := upgrade_request.upgrade_transaction
	connection.create_object_store(mut transaction, 'temporary', IDBObjectStoreParameters{})!
	upgrade_request.abort_upgrade('AbortError: test')!
	assert 'temporary' !in first.data.stores
	assert first.data.version == 1
	first.close()

	mut low_version := factory.open('people-db', u64(0)) or {
		assert err.msg().contains('TypeError')
		return
	}
	assert low_version.request.ready_state == .pending
}

fn test_aborting_initial_upgrade_removes_database_and_scope_names_are_deduplicated() {
	mut factory := IDBFactory.create('initial-abort')!
	mut first_open := factory.open('discarded', u64(1))!
	mut connection := first_open.connection
	mut upgrade := first_open.upgrade_transaction
	connection.create_object_store(mut upgrade, 'temporary', IDBObjectStoreParameters{})!
	first_open.abort_upgrade('AbortError: initial upgrade failed')!
	assert 'discarded' !in factory.databases

	mut reopened := factory.open('discarded', none)!
	assert reopened.old_version == 0
	assert reopened.request.events == ['upgradeneeded']
	mut reopened_connection := reopened.connection
	mut reopened_upgrade := reopened.upgrade_transaction
	reopened_connection.create_object_store(mut reopened_upgrade, 'items', IDBObjectStoreParameters{})!
	reopened.finish_upgrade()!
	mut transaction :=
		reopened_connection.transaction(['items', 'items', 'items'], .readonly, IDBTransactionOptions{})!
	assert transaction.object_store_names() == ['items']
	transaction.commit()!
}

fn test_schema_name_lists_use_utf16_code_unit_order() {
	mut factory := IDBFactory.create('name-order')!
	mut open := factory.open('names', u64(1))!
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	supplementary := rune(0x10000).str()
	bmp_after_surrogates := rune(0xe000).str()
	connection.create_object_store(mut upgrade, bmp_after_surrogates, IDBObjectStoreParameters{})!
	mut store :=
		connection.create_object_store(mut upgrade, supplementary, IDBObjectStoreParameters{})!
	store.create_index(bmp_after_surrogates, 'a', IDBIndexParameters{})!
	store.create_index(supplementary, 'b', IDBIndexParameters{})!
	assert connection.object_store_names() == [supplementary, bmp_after_surrogates]
	assert upgrade.object_store_names() == [supplementary, bmp_after_surrogates]
	assert store.index_names() == [supplementary, bmp_after_surrogates]
}
