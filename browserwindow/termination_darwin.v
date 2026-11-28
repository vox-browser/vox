module browserwindow

import macos

type ApplicationTerminateFn = fn (app macos.Id, selector macos.Sel, sender macos.Id)

struct ApplicationTermination {
mut:
	original       voidptr
	work_depth     int
	pending_app    macos.Id
	pending_sender macos.Id
	queued         bool
}

// AppKit termination and cooperative browser work both run on the main thread.
const application_termination = &ApplicationTermination{}

fn request_application_termination(app macos.Id, selector macos.Sel, sender macos.Id) {
	mut state := unsafe { application_termination }
	if !is_nil(state.pending_app) {
		return
	}
	if state.work_depth > 0 {
		state.pending_app = app
		state.pending_sender = macos.retain(sender)
		return
	}
	original := unsafe { ApplicationTerminateFn(state.original) }
	original(app, selector, sender)
}

fn deliver_application_termination(_context voidptr) {
	mut state := unsafe { application_termination }
	state.queued = false
	if state.work_depth > 0 || is_nil(state.pending_app) {
		return
	}
	app := state.pending_app
	sender := state.pending_sender
	state.pending_app = nil_id()
	state.pending_sender = nil_id()
	defer { macos.release(sender) }
	original := unsafe { ApplicationTerminateFn(state.original) }
	original(app, macos.sel('terminate:'), sender)
}

fn install_termination_hook(app macos.Id) {
	mut state := unsafe { application_termination }
	if is_nil(app) || !is_nil(state.original) {
		return
	}
	cls := macos.msg_id(app, 'class')
	selector := macos.sel('terminate:')
	method := class_instance_method(cls, selector)
	if is_nil(method) {
		return
	}
	state.original = method_implementation(method)
	class_replace_method(cls, selector, voidptr(request_application_termination), method_type_encoding(method))
}

// Defer entering AppKit's termination protocol while a nested event pump
// can still have browser render resources on the stack.
pub fn install_cooperative_termination() {
	install_termination_hook(ns_app())
}

pub fn begin_cooperative_application_work() {
	mut state := unsafe { application_termination }
	state.work_depth++
}

pub fn end_cooperative_application_work() {
	mut state := unsafe { application_termination }
	state.work_depth--
	if state.work_depth == 0 && !is_nil(state.pending_app) && !state.queued {
		state.queued = true
		dispatch_to_main_queue(deliver_application_termination)
	}
}
