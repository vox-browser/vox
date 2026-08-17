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
	onend_            ?EndEventHandler
}

pub fn (session &XRSession) promise_resolved() bool {
	return session.promise_resolved_
}

pub fn (session &XRSession) ended() bool {
	return session.ended_
}

pub fn (session &XRSession) outstanding_operation_count() int {
	return session.outstanding
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
	if !isnil(session.owner) {
		mut owner := unsafe { &XRSystem(session.owner) }
		owner.remove_session(session)
	}
	if handler := session.onend_ {
		event := XRSessionEvent{
			type_:   'end'
			session: session
		}
		handler(&event)
	}
}

pub struct XRSessionEventInit {
pub:
	session &XRSession = unsafe { nil }
}

pub struct XRSessionEvent {
pub:
	type_   string
	session &XRSession = unsafe { nil }
}

pub fn XRSessionEvent.new(type_ string, init XRSessionEventInit) !XRSessionEvent {
	if isnil(init.session) {
		return error('XRSessionEventInit.session is required')
	}
	return XRSessionEvent{
		type_:   type_
		session: init.session
	}
}

@[heap]
pub struct XRSystem {
mut:
	pending_immersive_session bool
	active_immersive_session  ?&XRSession
	inline_sessions           []&XRSession
}

pub fn (system &XRSystem) is_session_supported(mode XRSessionMode) BoolPromiseResult {
	return BoolPromiseResult{
		value: mode == .inline
	}
}

pub fn (mut system XRSystem) request_session(mode XRSessionMode, _ XRSessionInit) SessionPromiseResult {
	immersive := mode != .inline
	if immersive && (system.pending_immersive_session || system.active_immersive_session != none) {
		return SessionPromiseResult{
			error: XRException.invalid_state
		}
	}
	if immersive {
		system.pending_immersive_session = true
		// Upstream's current device step has no devices and rejects immersive modes.
		system.pending_immersive_session = false
		return SessionPromiseResult{
			error: XRException.not_supported
		}
	}
	mut session := &XRSession{
		mode:  mode
		owner: system
	}
	system.inline_sessions << session
	session.promise_resolved_ = true
	return SessionPromiseResult{
		session: session
	}
}

pub fn (system &XRSystem) pending_immersive_session() bool {
	return system.pending_immersive_session
}

pub fn (system &XRSystem) inline_session_count() int {
	return system.inline_sessions.len
}

pub fn (mut system XRSystem) remove_session(session &XRSession) {
	if active := system.active_immersive_session {
		if active == session {
			system.active_immersive_session = none
		}
	}
	for index, inline_session in system.inline_sessions {
		if inline_session == session {
			system.inline_sessions.delete(index)
			break
		}
	}
}
