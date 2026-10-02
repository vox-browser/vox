module html

import libjs

fn test_microtask_checkpoint_finishes_the_bound_vm_generation_once_after_jobs() {
	mut event_loop := EventLoop.create(.window)
	mut vm := libjs.VM.create()
	event_loop.bind_vm(vm)
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [event_loop, vm] () {
		assert vm.execution_generation() == 0
		mut same_loop := unsafe { &EventLoop(event_loop) }
		same_loop.perform_a_microtask_checkpoint()
		assert vm.execution_generation() == 0
	}))
	event_loop.perform_a_microtask_checkpoint()
	assert vm.execution_generation() == 1
	event_loop.perform_a_microtask_checkpoint()
	assert vm.execution_generation() == 2
	event_loop.execution_paused = true
	event_loop.perform_a_microtask_checkpoint()
	assert vm.execution_generation() == 2
	event_loop.execution_paused = false
	event_loop.bind_vm(none)
	event_loop.perform_a_microtask_checkpoint()
	assert vm.execution_generation() == 2
}

fn test_worker_checkpoint_finishes_its_own_vm_generation() {
	mut window_loop := EventLoop.create(.window)
	mut worker_loop := EventLoop.create(.worker)
	window_vm := libjs.VM.create()
	worker_vm := libjs.VM.create()
	window_loop.bind_vm(window_vm)
	worker_loop.bind_vm(worker_vm)
	worker_loop.perform_a_microtask_checkpoint()
	assert worker_vm.execution_generation() == 1
	assert window_vm.execution_generation() == 0
	window_loop.perform_a_microtask_checkpoint()
	assert window_vm.execution_generation() == 1
	assert worker_vm.execution_generation() == 1
}
