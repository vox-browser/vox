module webxr

fn test_support_and_request_match_current_platform_boundary() {
	mut xr_system := &XRSystem{}
	assert xr_system.is_session_supported(.inline).value? == true
	assert xr_system.is_session_supported(.immersive_vr).value? == false
	assert xr_system.request_session(.immersive_vr, XRSessionInit{}).error? == .not_supported
	assert !xr_system.pending_immersive_session()
	result := xr_system.request_session(.inline, XRSessionInit{})
	mut session := result.session?
	assert session.promise_resolved()
	assert xr_system.inline_session_count() == 1
	assert session.end().resolved
	assert xr_system.inline_session_count() == 0
	assert session.end().error? == .invalid_state
}

fn test_session_event_requires_session() {
	XRSessionEvent.new('end', XRSessionEventInit{}) or {
		assert err.msg().contains('required')
		return
	}
	assert false
}

fn test_shutdown_rejects_outstanding_work_and_event_keeps_session_identity() {
	mut xr_system := &XRSystem{}
	result := xr_system.request_session(.inline, XRSessionInit{})
	mut session := result.session?
	session.begin_operation()!
	session.begin_operation()!
	assert session.outstanding_operation_count() == 2
	event := XRSessionEvent.new('custom', XRSessionEventInit{
		session: session
	})!
	assert event.type_ == 'custom'
	assert event.session() == session
	session.shut_down()
	assert session.ended()
	assert session.outstanding_operation_count() == 0
}

fn test_exact_session_promise_and_creation_entry_points() {
	mut xr_system := XRSystem.create()
	mut session := XRSession.create(xr_system)
	assert session.mode == .inline
	session.set_promise_resolved(true)
	assert session.promise_resolved()

	resolved := session.create_promise()
	assert resolved.state() == .pending
	assert session.outstanding_operation_count() == 1
	session.resolve_promise(resolved)
	assert resolved.state() == .resolved
	assert session.outstanding_operation_count() == 0

	rejected := session.create_promise()
	session.reject_promise(rejected, .not_supported)
	assert rejected.state() == .rejected
	assert rejected.error()? == .not_supported

	ended := session.create_promise()
	session.shut_down()
	assert ended.state() == .rejected
	assert ended.error()? == .invalid_state
}

fn test_exact_session_event_and_system_entry_points() {
	mut xr_system := XRSystem.create()
	session := XRSession.create(xr_system)
	event := XRSessionEvent.create('end', XRSessionEventInit{
		session: session
	})!
	constructed := XRSessionEvent.construct_impl('end', XRSessionEventInit{
		session: session
	})!
	assert event.session() == session
	assert constructed.session() == session

	xr_system.set_pending_immersive_session(true)
	assert xr_system.pending_immersive_session()
	xr_system.set_active_immersive_session(session)
	assert xr_system.active_immersive_session()? == session
	xr_system.set_active_immersive_session(none)
	assert xr_system.active_immersive_session() == none
}
