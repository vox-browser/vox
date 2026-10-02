module html

import dom
import indexeddb
import libjs

fn cleanup_test_connection(loop &EventLoop, hostname string) &indexeddb.IDBDatabase {
	mut services := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{value: 'https://${hostname}'}, true, false)
	services.responsible_event_loop_ = loop
	mut factory := services.indexed_db()
	mut open := factory.open('checkpoint-db', u64(1)) or { panic(err) }
	mut queue := loop.task_queue()
	mut turns := 0
	for open.upgrade_transaction == unsafe { nil } {
		assert turns < 8
		task := queue.take_first_runnable_matching(fn (task &Task) bool { return task.source == .database_access }) or { panic('missing upgrade task') }
		task.execute()
		turns++
	}
	mut connection := open.connection
	mut upgrade := open.upgrade_transaction
	connection.create_object_store(mut upgrade, 'items', indexeddb.IDBObjectStoreParameters{}) or { panic(err) }
	open.finish_upgrade() or { panic(err) }
	for open.request.ready_state == .pending {
		assert turns < 12
		task := queue.take_first_runnable_matching(fn (task &Task) bool { return task.source == .database_access }) or { panic('missing completion task') }
		task.execute()
		turns++
	}
	return connection
}

fn test_checkpoint_deactivates_and_commits_only_transactions_owned_by_that_loop() {
	mut first_loop := EventLoop.create(.window)
	mut second_loop := EventLoop.create(.worker)
	mut first_connection := cleanup_test_connection(first_loop, 'first-checkpoint.example')
	mut second_connection := cleanup_test_connection(second_loop, 'second-checkpoint.example')
	first := first_connection.transaction(['items'], .readonly, indexeddb.IDBTransactionOptions{})!
	second := second_connection.transaction(['items'], .readonly, indexeddb.IDBTransactionOptions{})!
	assert first.cleanup_event_loop() == voidptr(first_loop)
	assert second.cleanup_event_loop() == voidptr(second_loop)
	first_loop.enqueue_microtask(Task.create(.microtask, none, fn [first] () {
		assert first.state == .active
	}))
	first_loop.perform_a_microtask_checkpoint()
	assert first.state == .committing
	assert first.cleanup_event_loop() == unsafe { nil }
	assert second.state == .active
	assert second.cleanup_event_loop() == voidptr(second_loop)
	assert !indexeddb.cleanup_indexed_database_transactions(voidptr(first_loop))
	mut first_queue := first_loop.task_queue()
	first_queue.take_first_runnable() or { panic('missing commit task') }.execute()
	assert first.state == .finished
	second_loop.perform_a_microtask_checkpoint()
	assert second.state == .committing
	mut second_queue := second_loop.task_queue()
	second_queue.take_first_runnable() or { panic('missing worker commit task') }.execute()
	assert second.state == .finished
	first_connection.close()
	second_connection.close()
}

fn test_checkpoint_leaves_pending_and_blocked_transactions_inactive_and_clears_cleanup_owner() {
	mut loop := EventLoop.create(.window)
	mut connection := cleanup_test_connection(loop, 'blocked-checkpoint.example')
	mut blocked := connection.transaction(['items'], .readonly, indexeddb.IDBTransactionOptions{})!
	mut pending := connection.transaction(['items'], .readonly, indexeddb.IDBTransactionOptions{})!
	mut blocked_list := blocked.request_list()
	blocked_list.block_execution()
	mut pending_list := pending.request_list()
	request := indexeddb.IDBRequest.create_for_global_scope(connection.global_scope, 'items')
	pending_list.append(request)
	loop.perform_a_microtask_checkpoint()
	assert blocked.state == .inactive
	assert pending.state == .inactive
	assert blocked.cleanup_event_loop() == unsafe { nil }
	assert pending.cleanup_event_loop() == unsafe { nil }
	assert loop.task_queue().is_empty()
	assert !indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
	blocked.abort('cleanup test ended')!
	pending.abort('cleanup test ended')!
	connection.close()
}

fn test_checkpoint_queues_rejection_notification_before_commit_and_finishes_vm_generation_after_cleanup() {
	mut loop := EventLoop.create(.window)
	mut vm := libjs.VM.create()
	loop.bind_vm(vm)
	mut connection := cleanup_test_connection(loop, 'checkpoint-order.example')
	transaction := connection.transaction(['items'], .readonly, indexeddb.IDBTransactionOptions{})!
	realm := &ScriptingRealm{}
	environment := Environment.create('checkpoint-order', dom.url_about_blank(), none, none, none)
	mut settings := create_environment_settings(realm, environment, .snapshot, loop)
	mut scope := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, realm, none)
	settings.universal_global_scope_ = scope
	scope.push_onto_about_to_be_notified_rejected_promises_list(dom.Promise.rejected(dom.js_string('rejection')))
	loop.perform_a_microtask_checkpoint()
	assert vm.execution_generation() == 1
	assert transaction.state == .committing
	mut queue := loop.task_queue()
	notification := queue.take_first_runnable() or { panic('notification missing') }
	assert notification.source == .dom_manipulation
	notification.execute()
	assert realm.reported_exceptions.len == 1
	completion := queue.take_first_runnable() or { panic('commit missing') }
	assert completion.source == .database_access
	completion.execute()
	assert transaction.state == .finished
	connection.close()
}
