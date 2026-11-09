module html

import libjs
import platform

fn test_embedding_vm_registration_outlives_the_callers_arena() {
	mut event_loop := EventLoop.create(.window)
	first := libjs.VM.create()
	mut second := libjs.VM.create()
	mut context := libjs.ExecutionContext.create(0, [], 0)
	mut arena := platform.new_arena('embedding registration caller')
	entry := arena.enter()
	event_loop.attach_embedding_vm(first)
	event_loop.attach_embedding_vm(second)
	event_loop.attach_embedding_vm(first)
	arena.leave(entry)
	transient_backing := arena.contains(event_loop.embedding_vms_.data)
	if !transient_backing {
		arena.reset()
		assert event_loop.embedding_vms_.len == 2
		assert voidptr(event_loop.embedding_vms_[0]) == voidptr(first)
		assert voidptr(event_loop.embedding_vms_[1]) == voidptr(second)
		assert !event_loop.has_running_execution_context()
		second.push_execution_context(mut context)
		assert event_loop.has_running_execution_context()
		second.pop_execution_context()
		assert !event_loop.has_running_execution_context()
	}
	event_loop.detach_embedding_vm(first)
	event_loop.detach_embedding_vm(second)
	arena.release()
	assert !transient_backing, 'event-loop VM registry used the registering document arena'
}

fn test_embedding_vm_removal_keeps_remaining_vms_outside_the_callers_arena() {
	mut event_loop := EventLoop.create(.window)
	first := libjs.VM.create()
	removed := libjs.VM.create()
	mut remaining := libjs.VM.create()
	mut context := libjs.ExecutionContext.create(0, [], 0)
	event_loop.attach_embedding_vm(first)
	event_loop.attach_embedding_vm(removed)
	event_loop.attach_embedding_vm(remaining)
	mut arena := platform.new_arena('embedding removal caller')
	entry := arena.enter()
	event_loop.detach_embedding_vm(removed)
	arena.leave(entry)
	transient_backing := arena.contains(event_loop.embedding_vms_.data)
	if !transient_backing {
		arena.reset()
		assert event_loop.embedding_vms_.len == 2
		assert voidptr(event_loop.embedding_vms_[0]) == voidptr(first)
		assert voidptr(event_loop.embedding_vms_[1]) == voidptr(remaining)
		remaining.push_execution_context(mut context)
		assert event_loop.has_running_execution_context()
		event_loop.detach_embedding_vm(remaining)
		assert !event_loop.has_running_execution_context()
		remaining.pop_execution_context()
	}
	event_loop.detach_embedding_vm(first)
	event_loop.detach_embedding_vm(remaining)
	arena.release()
	assert !transient_backing, 'event-loop VM removal allocated surviving entries in the closing document arena'
}
