// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebXR/XRSession, XRSessionEvent and XRSystem. Device discovery,
// permission prompting and native tracking/rendering remain platform boundaries,
// matching the corresponding upstream FIXMEs.
module webxr

pub enum XRSessionMode {
	inline
	immersive_vr
	immersive_ar
}

pub struct XRSessionInit {
pub:
	required_features ?[]string
	optional_features ?[]string
}

pub enum XRException {
	invalid_state
	not_supported
	security
}

pub struct BoolPromiseResult {
pub:
	value ?bool
	error ?XRException
}

pub struct SessionPromiseResult {
pub:
	session ?&XRSession
	error   ?XRException
}

pub struct EndPromiseResult {
pub:
	resolved bool
	error    ?XRException
}

pub enum XRPromiseState {
	pending
	resolved
	rejected
}

@[heap]
pub struct XRPromise {
mut:
	state_ XRPromiseState
	error_ ?XRException
}

pub fn (promise &XRPromise) state() XRPromiseState {
	return promise.state_
}

pub fn (promise &XRPromise) error() ?XRException {
	return promise.error_
}

pub type EndEventHandler = fn (&XRSessionEvent)

@[heap]
pub struct XRSession {
pub:
	mode XRSessionMode
mut:
	owner             &XRSystem = unsafe { nil }
	promise_resolved_ bool
	ended_            bool
	outstanding       int
	outstanding_promises_ []&XRPromise
	onend_            ?EndEventHandler
}

pub fn XRSession.create(xr_system &XRSystem) &XRSession {
	return XRSession.create_with_mode(xr_system, .inline)
}

pub fn XRSession.create_with_mode(xr_system &XRSystem, mode XRSessionMode) &XRSession {
	return &XRSession{
		mode:  mode
		owner: xr_system
	}
}

pub fn (mut session XRSession) create_promise() &XRPromise {
	promise := &XRPromise{}
	session.outstanding_promises_ << promise
	return promise
}

pub fn (mut session XRSession) resolve_promise(promise &XRPromise) {
	mut mutable_promise := unsafe { &XRPromise(promise) }
	mutable_promise.state_ = .resolved
	mutable_promise.error_ = none
	session.remove_outstanding_promise(promise)
}

pub fn (mut session XRSession) reject_promise(promise &XRPromise, reason XRException) {
	mut mutable_promise := unsafe { &XRPromise(promise) }
	mutable_promise.state_ = .rejected
	mutable_promise.error_ = reason
	session.remove_outstanding_promise(promise)
}

fn (mut session XRSession) remove_outstanding_promise(promise &XRPromise) {
	for index, entry in session.outstanding_promises_ {
		if voidptr(entry) == voidptr(promise) {
			session.outstanding_promises_.delete(index)
			return
		}
	}
}

pub fn (session &XRSession) promise_resolved() bool {
	return session.promise_resolved_
}

pub fn (session &XRSession) ended() bool {
	return session.ended_
}

pub fn (session &XRSession) outstanding_operation_count() int {
	return session.outstanding + session.outstanding_promises_.len
}

pub fn (mut session XRSession) set_promise_resolved(promise_resolved bool) {
	session.promise_resolved_ = promise_resolved
}

pub fn (mut session XRSession) set_onend(handler ?EndEventHandler) {
	session.onend_ = handler
}

pub fn (mut session XRSession) begin_operation() ! {
	if session.ended_ {
		return error('InvalidStateError: Session ended')
	}
	session.outstanding++
}

pub fn (mut session XRSession) settle_operation() {
	if session.outstanding > 0 {
		session.outstanding--
	}
}

pub fn (mut session XRSession) end() EndPromiseResult {
	if session.ended_ {
		return EndPromiseResult{
			error: XRException.invalid_state
		}
	}
	session.shut_down()
	return EndPromiseResult{
		resolved: true
	}
}

pub fn (mut session XRSession) shut_down() {
	if session.ended_ {
		return
	}
	session.ended_ = true
	session.outstanding = 0
	for promise in session.outstanding_promises_ {
		mut mutable_promise := unsafe { &XRPromise(promise) }
		mutable_promise.state_ = .rejected
		mutable_promise.error_ = .invalid_state
	}
	session.outstanding_promises_.clear()
	if !isnil(session.owner) {
		mut owner := unsafe { &XRSystem(session.owner) }
		if active := owner.active_immersive_session() {
			if voidptr(active) == voidptr(session) {
				owner.set_active_immersive_session(none)
			}
		}
		owner.remove_inline_session(session)
	}
	if handler := session.onend_ {
		event := XRSessionEvent{
			type_:    'end'
			session_: session
		}
		handler(&event)
	}
}

pub struct XRSessionEventInit {
pub:
	session &XRSession = unsafe { nil }
}

@[heap]
pub struct XRSessionEvent {
pub:
	type_ string
mut:
	session_ &XRSession = unsafe { nil }
}

pub fn XRSessionEvent.new(type_ string, init XRSessionEventInit) !XRSessionEvent {
	if isnil(init.session) {
		return error('XRSessionEventInit.session is required')
	}
	return XRSessionEvent{
		type_:   type_
		session_: init.session
	}
}

pub fn XRSessionEvent.create(type_ string, init XRSessionEventInit) !XRSessionEvent {
	return XRSessionEvent.new(type_, init)
}

pub fn XRSessionEvent.construct_impl(type_ string, init XRSessionEventInit) !XRSessionEvent {
	return XRSessionEvent.create(type_, init)
}

pub fn (event &XRSessionEvent) session() &XRSession {
	return event.session_
}

@[heap]
pub struct XRSystem {
mut:
	pending_immersive_session_ bool
	active_immersive_session_  ?&XRSession
	inline_sessions           []&XRSession
}

pub fn XRSystem.create() &XRSystem {
	return &XRSystem{}
}

pub fn (system &XRSystem) is_session_supported(mode XRSessionMode) BoolPromiseResult {
	return BoolPromiseResult{
		value: mode == .inline
	}
}

pub fn (mut system XRSystem) request_session(mode XRSessionMode, _ XRSessionInit) SessionPromiseResult {
	immersive := mode != .inline
	if immersive && (system.pending_immersive_session_ || system.active_immersive_session_ != none) {
		return SessionPromiseResult{
			error: XRException.invalid_state
		}
	}
	if immersive {
		system.set_pending_immersive_session(true)
		// Upstream's current device step has no devices and rejects immersive modes.
		system.set_pending_immersive_session(false)
		return SessionPromiseResult{
			error: XRException.not_supported
		}
	}
	mut session := XRSession.create_with_mode(system, mode)
	system.inline_sessions << session
	session.set_promise_resolved(true)
	return SessionPromiseResult{
		session: session
	}
}

pub fn (system &XRSystem) pending_immersive_session() bool {
	return system.pending_immersive_session_
}

pub fn (mut system XRSystem) set_pending_immersive_session(pending bool) {
	system.pending_immersive_session_ = pending
}

pub fn (system &XRSystem) active_immersive_session() ?&XRSession {
	return system.active_immersive_session_
}

pub fn (mut system XRSystem) set_active_immersive_session(session ?&XRSession) {
	system.active_immersive_session_ = session
}

pub fn (system &XRSystem) inline_session_count() int {
	return system.inline_sessions.len
}

pub fn (mut system XRSystem) remove_inline_session(session &XRSession) {
	for index, inline_session in system.inline_sessions {
		if voidptr(inline_session) == voidptr(session) {
			system.inline_sessions.delete(index)
			break
		}
	}
}

pub fn (mut system XRSystem) remove_session(session &XRSession) {
	if active := system.active_immersive_session_ {
		if voidptr(active) == voidptr(session) {
			system.active_immersive_session_ = none
		}
	}
	system.remove_inline_session(session)
}
