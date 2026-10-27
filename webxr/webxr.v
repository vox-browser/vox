// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebXR/XRLayer, XRRenderState, XRSession, XRSessionEvent,
// XRSystem, and XRWebGLLayer. Device discovery, permission prompting and native
// tracking/rendering remain platform boundaries, matching upstream FIXMEs.
module webxr

import dom
import webgl

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

pub struct XRRenderStateInit {
pub:
	depth_near                    f64
	depth_far                     f64
	passthrough_fully_obscured    ?bool
	inline_vertical_field_of_view ?f64
}

@[heap]
pub struct XRRenderState {}

@[heap]
pub struct XRLayer {
	dom.EventTarget
}

pub struct XRWebGLLayerInit {
pub:
	antialias                bool = true
	depth                    bool = true
	stencil                  bool
	alpha                    bool = true
	ignore_depth_values      bool
	framebuffer_scale_factor f64 = 1.0
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
	owner                 &XRSystem = unsafe { nil }
	promise_resolved_     bool
	ended_                bool
	outstanding           int
	outstanding_promises_ []&XRPromise
	onend_                ?EndEventHandler
}

pub fn XRSession.create(xr_system &XRSystem) &XRSession {
	return XRSession.create_with_mode(xr_system, .inline)
}

pub fn XRSession.create_with_mode(xr_system &XRSystem, mode XRSessionMode) &XRSession {
	return &XRSession{
		mode: mode
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

pub fn (session &XRSession) is_immersive() bool {
	return session.mode != .inline
}

// Current upstream exposes updateRenderState but still leaves its algorithm as
// an explicit stub.
pub fn (_ &XRSession) update_render_state(_ XRRenderStateInit) {}

pub fn (session &XRSession) outstanding_operation_count() int {
	return session.outstanding + session.outstanding_promises_.len
}

pub fn (mut session XRSession) set_promise_resolved(promise_resolved bool) {
	session.promise_resolved_ = promise_resolved
}

pub fn (mut session XRSession) set_onend(handler ?EndEventHandler) {
	session.onend_ = handler
}

pub fn (session &XRSession) onend() ?EndEventHandler {
	return session.onend_
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
			type_: 'end'
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
	type_      string
	time_stamp f64
mut:
	session_ &XRSession = unsafe { nil }
}

pub fn XRSessionEvent.new(type_ string, init XRSessionEventInit) !XRSessionEvent {
	if isnil(init.session) {
		return error('XRSessionEventInit.session is required')
	}
	return XRSessionEvent{
		type_: type_
		time_stamp: dom.current_event_timestamp()
		session_: init.session
	}
}

pub fn XRSessionEvent.create_with_timestamp(type_ string, init XRSessionEventInit, time_stamp f64) !XRSessionEvent {
	if isnil(init.session) {
		return error('XRSessionEventInit.session is required')
	}
	return XRSessionEvent{
		type_: type_
		time_stamp: time_stamp
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

pub fn XRSessionEvent.session_offset() uint {
	return uint(__offsetof(XRSessionEvent, session_))
}

@[heap]
pub struct XRSystem {
mut:
	relevant_global_object_    voidptr
	pending_immersive_session_ bool
	active_immersive_session_  ?&XRSession
	inline_sessions            []&XRSession
}

pub fn XRSystem.create() &XRSystem {
	return &XRSystem{}
}

pub fn XRSystem.create_with_global_object(global_object voidptr) &XRSystem {
	return &XRSystem{
		relevant_global_object_: global_object
	}
}

pub fn (system &XRSystem) relevant_global_object() voidptr {
	return system.relevant_global_object_
}

pub fn (_ &XRSystem) is_session_mode_supported(mode XRSessionMode) bool {
	return mode == .inline
}

pub fn (system &XRSystem) is_session_supported(mode XRSessionMode) BoolPromiseResult {
	return BoolPromiseResult{
		value: system.is_session_mode_supported(mode)
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

@[heap]
pub struct XRWebGLLayer {
	XRLayer
pub:
	session &XRSession
	context &webgl.WebGLRenderingContext
	init    XRWebGLLayerInit
}

// https://immersive-web.github.io/webxr/#dom-xrwebgllayer-xrwebgllayer
pub fn XRWebGLLayer.create(session &XRSession, context &webgl.WebGLRenderingContext, init XRWebGLLayerInit) !&XRWebGLLayer {
	if session.ended() {
		return error('InvalidStateError: The XRSession has ended.')
	}
	if context.is_context_lost() {
		return error('InvalidStateError: The context has been lost.')
	}
	if session.is_immersive() && !context.xr_compatible() {
		return error('InvalidStateError: The XRSession is immersive but the context is not XR-compatible.')
	}
	return &XRWebGLLayer{
		XRLayer: XRLayer{
			EventTarget: dom.EventTarget{}
		}
		session: session
		context: context
		init: init
	}
}
