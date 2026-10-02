@[has_globals]
module html

import dom

fn test_snapshot_source_snapshot_params_copies_live_document_state() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/source' })
	document.set_origin(document.url.origin())
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms) |
		u32(SandboxingFlag.sandboxed_downloads))
	window := WindowModel.create_top_level(document, none, 'source-snapshot')!
	mut mutable_window := unsafe { &WindowModel(window) }
	mutable_window.set_last_activation_timestamp(window_current_time_ms())

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
