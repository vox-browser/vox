module browserwindow

import macos

struct TerminationRequests {
mut:
	count  int
	sender macos.Id
}

const termination_requests = &TerminationRequests{}

fn record_termination_request(_app macos.Id, _selector macos.Sel, sender macos.Id) {
	mut requests := unsafe { termination_requests }
	requests.count++
	requests.sender = sender
	if !is_nil(sender) {
		assert macos.msg_id(sender, 'class') == macos.get_class('NSObject')
	}
}

fn run_termination_delivery() {
	for _ in 0 .. 10 {
		if !application_termination.queued {
			return
		}
		C.CFRunLoopRunInMode(pump_run_loop_mode(), 0.01, false)
	}
	assert !application_termination.queued
}

fn test_application_termination_waits_for_cooperative_work_and_preserves_sender() {
	pool := macos.autorelease_pool_new()
	defer { macos.release(pool) }
	cls := runtime_class('VoxCooperativeTerminationTestApp', [
		RuntimeMethod{
			selector:       'terminate:'
			implementation: voidptr(record_termination_request)
			types:          'v@:@'
		},
	])
	app := macos.msg_id(cls, 'new')
	defer {
		method_set_implementation(class_instance_method(cls, macos.sel('terminate:')),
			voidptr(record_termination_request))
		mut state := unsafe { application_termination }
		state.original = unsafe { nil }
		macos.release(app)
	}
	install_termination_hook(app)
	install_termination_hook(app)
	macos.msg_void1(app, 'terminate:', nil_id())
	assert termination_requests.count == 1
	assert is_nil(termination_requests.sender)

	begin_cooperative_application_work()
	begin_cooperative_application_work()
	sender := macos.msg_id(macos.get_class('NSObject'), 'new')
	macos.msg_void1(app, 'terminate:', sender)
	macos.release(sender)
	macos.msg_void1(app, 'terminate:', nil_id())
	end_cooperative_application_work()
	assert !application_termination.queued
	assert termination_requests.count == 1
	end_cooperative_application_work()
	assert application_termination.queued
	assert termination_requests.count == 1

	// A later frame can service AppKit before it unwinds as well.
	begin_cooperative_application_work()
	run_termination_delivery()
	assert termination_requests.count == 1
	end_cooperative_application_work()
	macos.msg_void1(app, 'terminate:', nil_id())
	run_termination_delivery()
	assert termination_requests.count == 2
	assert termination_requests.sender == sender
	assert is_nil(application_termination.pending_app)
	assert is_nil(application_termination.pending_sender)
}
