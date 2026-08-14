module html

struct EventLoopTestCalls {
mut:
	values []string
}

fn test_task_queue_runs_runnable_tasks_in_order() {
	mut event_loop := EventLoop.create(.window)
	mut calls := &EventLoopTestCalls{}
	first := Task.create(.dom_manipulation, none, fn [mut calls] () {
		calls.values << '1'
	})
	second := Task.create(.networking, none, fn [mut calls] () {
		calls.values << '2'
	})
	mut queue := event_loop.task_queue()
	queue.add(first)
	queue.add(second)
	assert queue.has_runnable_tasks()
	event_loop.process()
	assert calls.values == ['1']
	event_loop.process()
	assert calls.values == ['1', '2']
	assert queue.is_empty()
}

fn test_microtask_checkpoint_after_task() {
	mut event_loop := EventLoop.create(.window)
	mut calls := &EventLoopTestCalls{}
	microtask := Task.create(.microtask, none, fn [mut calls] () {
		calls.values << 'microtask'
	})
	task := Task.create(.dom_manipulation, none, fn [mut calls, mut event_loop, microtask] () {
		calls.values << 'task'
		event_loop.enqueue_microtask(microtask)
	})
	mut queue := event_loop.task_queue()
	queue.add(task)
	event_loop.process()
	assert calls.values == ['task', 'microtask']
}

fn test_remove_and_take_tasks_matching() {
	mut event_loop := EventLoop.create(.window)
	mut queue := event_loop.task_queue()
	queue.add(Task.create(.networking, none, fn () {}))
	queue.add(Task.create(.dom_manipulation, none, fn () {}))
	queue.add(Task.create(.networking, none, fn () {}))
	queue.remove_tasks_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	})
	matching := queue.take_tasks_matching(fn (task &Task) bool {
		return task.source == .networking
	})
	assert matching.len == 2
	assert queue.is_empty()
}

fn test_main_thread_event_loop_is_stable() {
	assert main_thread_event_loop() == main_thread_event_loop()
}
