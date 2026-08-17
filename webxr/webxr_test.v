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
	assert event.session == session
	session.shut_down()
	assert session.ended()
	assert session.outstanding_operation_count() == 0
}
