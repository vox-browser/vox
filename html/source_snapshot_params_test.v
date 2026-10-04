@[has_globals]
module html

import dom
import highresolutiontime
import page

fn test_snapshot_source_snapshot_params_copies_live_document_state() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/source' })
	document.set_origin(document.url.origin())
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms) |
		u32(SandboxingFlag.sandboxed_downloads))
	window := WindowModel.create_top_level(document, none, 'source-snapshot')!
	mut mutable_window := unsafe { &WindowModel(window) }
	mutable_window.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}))

	settings_pointer := document.relevant_settings_object()
	assert settings_pointer != unsafe { nil }
	mut settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	settings.set_policy_container(&PolicyContainer{
		referrer_policy: .no_referrer
	})

	snapshot := snapshot_source_snapshot_params(document)
	assert snapshot.has_transient_activation
	assert snapshot.sandboxing_flags.contains(.sandboxed_forms)
	assert snapshot.sandboxing_flags.contains(.sandboxed_downloads)
	assert !snapshot.allows_downloading
	assert snapshot.fetch_client? == settings
	assert snapshot.source_policy_container.referrer_policy == .no_referrer

	// The source policy container is cloned, not aliased.
	settings.set_policy_container(&PolicyContainer{
		referrer_policy: .origin
	})
	assert snapshot.source_policy_container.referrer_policy == .no_referrer
	document.finalize()
}

fn test_browser_ui_navigation_has_no_source_document_or_policy_restrictions() {
	snapshot := snapshot_source_snapshot_params(unsafe { nil })
	assert snapshot.has_transient_activation
	assert snapshot.allows_downloading
	assert snapshot.sandboxing_flags.bits == 0
	assert snapshot.fetch_client == none
	assert snapshot.source_policy_container.referrer_policy == .strict_origin_when_cross_origin
}

fn retained_source_policy_snapshot(document &dom.Document) &SourceSnapshotParams {
	// The Source GC::Cell survives this constructor's local scope and is
	// retained by navigation's actual pointer consumers.
	snapshot := snapshot_source_snapshot_params(document)
	return &snapshot
}

fn test_actual_source_policy_snapshot_pointer_retains_records_after_constructor_scope() {
	owner := page.Page.create(1)!
	url := dom.URL{'https://snapshot-policy-owner.test/page'}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	defer { document.finalize() }
	window := document.get_window()?
	mut settings := unsafe { &WindowModel(window) }.environment_settings_.settings
	opaque := dom.origin_create_opaque()
	settings.set_policy_container(&PolicyContainer{
		csp_list:        [SerializedCSPPolicy{
			directives:               [SerializedCSPDirective{'img-src', ["'self'"]}]
			self_origin:              opaque
			pre_parsed_policy_string: "img-src 'self'"
		}]
		referrer_policy: .no_referrer
	})
	snapshot := retained_source_policy_snapshot(document)
	settings.set_policy_container(&PolicyContainer{ referrer_policy: .origin })
	assert snapshot.fetch_client? == settings
	assert snapshot.source_policy_container.referrer_policy == .no_referrer
	assert snapshot.source_policy_container.csp_list[0].self_origin.serialize_for_ipc() == opaque.serialize_for_ipc()
	assert snapshot.source_policy_container.csp_list[0].pre_parsed_policy_string == "img-src 'self'"
	assert snapshot.source_policy_container.csp_list[0].directives[0].value == ["'self'"]
}
