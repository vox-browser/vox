// SPDX-License-Identifier: BSD-2-Clause
module html

@[heap]
struct OwnedTaskObservation {
mut:
	calls int
	task ?&Task
	was_pending bool
}

fn test_owned_microtask_discard_releases_steps_and_keeps_other_tasks_in_order() {
	mut loop := EventLoop.create(.worker)
	mut seen := &OwnedTaskObservation{}
	first := Task.create_owned(.microtask, none, fn [mut seen] () { seen.calls += 1 })
	second := Task.create_owned(.microtask, none, fn [mut seen] () { seen.calls += 10 })
	loop.enqueue_microtask(first); loop.enqueue_microtask(second)
	assert loop.discard_microtask(first) && !first.owns_steps
	assert !loop.discard_microtask(first)
	first.execute()
	assert seen.calls == 0
	assert voidptr(loop.dequeue_microtask()?) == voidptr(second)
	second.execute()
	assert seen.calls == 10 && !second.owns_steps && loop.microtask_queue_empty()
}

fn test_running_owned_task_keeps_its_trampoline_until_steps_return() {
	mut loop := EventLoop.create(.worker)
	mut seen := &OwnedTaskObservation{}
	task := Task.create_owned(.microtask, none, fn [loop, mut seen] () {
		mut owner := unsafe { &EventLoop(loop) }
		task := seen.task or { panic('Missing owned task') }
		seen.was_pending = owner.discard_microtask(task)
		assert task.owns_steps
		seen.calls++
	})
	seen.task = task
	loop.enqueue_microtask(task)
	loop.dequeue_microtask()?.execute()
	assert !seen.was_pending && seen.calls == 1 && !task.owns_steps
}
