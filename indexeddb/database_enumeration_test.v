module indexeddb

fn test_database_enumeration_uses_only_committed_versions_and_returns_snapshots() {
	mut factory := IDBFactory.create('database-enumeration-snapshot')!
	mut opening := factory.open('one', u64(1))!
	run_database_tasks()
	assert factory.database_infos().len == 0
	opening.finish_upgrade()!
	run_database_tasks()
	snapshot := factory.database_infos()
	assert snapshot.len == 1 && snapshot[0].name == 'one' && snapshot[0].version == 1
	mut connection := opening.connection
	connection.close()
	mut upgrade := factory.open('one', u64(2))!
	run_database_tasks()
	assert factory.database_infos()[0].version == 1
	upgrade.finish_upgrade()!
	run_database_tasks()
	assert factory.database_infos()[0].version == 2
	assert snapshot[0].version == 1
	mut upgraded := upgrade.connection
	upgraded.close()
	deleted := factory.delete_database('one')!
	run_database_tasks()
	assert deleted.request.ready_state == .done
	assert factory.database_infos().len == 0
	assert snapshot[0].name == 'one'
}
