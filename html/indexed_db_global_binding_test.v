module html

import dom
import indexeddb

fn idb_binding_window(origin string) (&dom.Document, &WindowModel) {
	mut document := parse_document('<!doctype html><body></body>')
	document.set_origin(dom.URL{value: origin}.origin())
	window := WindowModel.create_top_level(document, none, 'idb-binding') or { panic(err) }
	return document, window
}

fn run_binding_database_task(mut loop EventLoop) {
	mut queue := loop.task_queue()
	task := queue.take_first_runnable_matching(fn (candidate &Task) bool {
		return candidate.source == .database_access
	}) or { panic('database task was not queued on the owning loop') }
	task.execute()
}

fn run_binding_tasks_until_upgrade(mut loop EventLoop, request &indexeddb.IDBOpenDBRequest) {
	mut turns := 0
	for request.upgrade_transaction == unsafe { nil } {
		assert turns < 8, 'connection work did not reach its upgrade task'
		run_binding_database_task(mut loop)
		turns++
	}
}

fn test_indexed_db_global_returns_real_factory_and_queues_connection_work() {
	mut document, window := idb_binding_window('https://idb-binding.example/')
	defer { document.finalize() }
	mut services := window.window_or_worker_global_scope()
	mut factory := services.indexed_db()
	assert services.indexed_db() == factory
	mut request := factory.open('source-owner-binding', u64(1))!
	assert request.request.ready_state == .pending
	assert request.connection == unsafe { nil }
	assert request.request.relevant_global_scope().event_loop_handle == voidptr(services.responsible_event_loop())
	mut loop := services.responsible_event_loop()
	run_binding_tasks_until_upgrade(mut loop, request)
	assert request.request.events == ['upgradeneeded']
	assert request.connection.name() == 'source-owner-binding'
	request.finish_upgrade()!
	assert request.request.ready_state == .pending
	run_binding_database_task(mut loop)
	assert request.request.ready_state == .done
	assert request.request.events == ['upgradeneeded', 'success']
	assert factory.database_infos().any(it.name == 'source-owner-binding')
	request.connection.close()
}

fn test_worker_database_tasks_use_worker_loop_and_do_not_enter_window_queue() {
	mut document, window := idb_binding_window('https://worker-idb-binding.example/')
	defer { document.finalize() }
	outside := window.environment_settings_.settings.serialize()
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{value: 'https://worker-idb-binding.example/worker.js'}, .classic, '', realm)
	_ = WorkerEnvironmentSettingsObject.setup(worker, mut realm, outside, 1)
	mut services := worker.window_or_worker_global_scope()
	mut factory := services.indexed_db()
	mut request := factory.open('worker-source-owner-binding', u64(1))!
	assert request.request.ready_state == .pending
	assert request.request.relevant_global_scope().event_loop_handle == voidptr(worker.event_loop)
	mut loop := worker.event_loop
	run_binding_tasks_until_upgrade(mut loop, request)
	assert request.request.events == ['upgradeneeded']
	request.finish_upgrade()!
	run_binding_database_task(mut loop)
	assert request.request.ready_state == .done
	assert request.connection.relevant_global_scope() == request.request.relevant_global_scope()
	request.connection.close()
}

fn test_opaque_origin_getter_preserves_identity_and_operations_reject_storage_access() {
	mut services := WindowOrWorkerGlobalScopeMixin.create(dom.origin_create_opaque(), false, false)
	mut factory := services.indexed_db()
	assert services.indexed_db() == factory
	assert factory.cmp(indexeddb.number_key(1), indexeddb.number_key(2))! == -1
	if _ := factory.open('opaque', u64(0)) {
		assert false
	} else {
		assert err.msg().contains('TypeError')
	}
	if _ := factory.open('opaque', u64(1)) {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	if _ := factory.delete_database('opaque') {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
}
