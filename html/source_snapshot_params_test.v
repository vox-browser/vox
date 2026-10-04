@[has_globals]
module html

import dom
import fetch
import highresolutiontime
import http
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

fn source_snapshot_owned_document(address string, header string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	mut response := fetch.Response.create()
	response.url_list = [url]
	response.header_list.append(http.Header{'Content-Security-Policy', header})
	document.set_policy_container(create_a_policy_container_from_fetch_response(response))
	native := document.get_window() or { return error('missing actual source Window') }
	return document, unsafe { &WindowModel(native) }
}

fn source_snapshot_insert_meta(document &dom.Document, header string) ! {
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'content-security-policy')
	meta.set_attribute_value('content', header)
	head := document.head() or { return error('missing actual source Head') }
	mut head_node := head.as_node()
	head_node.append_child(meta.as_node())!
}

fn test_source_snapshot_clones_own_document_policy_during_window_reassociation() {
	mut original, mut window := source_snapshot_owned_document('https://own-snapshot-policy.test:8443/page', "img-src 'self'; sandbox; trusted-types original-name")!
	mut replacement, _ := source_snapshot_owned_document('https://current-snapshot-policy.test/page', "script-src 'none'")!
	defer {
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	header := original.policy_container()
	old_container := &dom.PolicyContainer{
		csp_list:                     header.csp_list
		referrer_policy:              .no_referrer
		embedder_policy:              dom.EmbedderPolicy{ value: .require_corp, reporting_endpoint: 'source-endpoint' }
		integrity_policy:             dom.IntegrityPolicy{ blocked_destinations: [.style] }
		report_only_integrity_policy: dom.IntegrityPolicy{ blocked_destinations: [.script] }
	}
	original.set_policy_container(old_container)
	opaque := dom.origin_create_opaque()
	original.set_origin(opaque)
	source_snapshot_insert_meta(original, "style-src 'none'; trusted-types meta-name")!
	source_snapshot_insert_meta(replacement, "base-uri 'none'")!
	original.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms) |
		u32(SandboxingFlag.sandboxed_downloads))
	window.set_last_activation_timestamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: replacement.load_timing_info.navigation_start_time
	}))
	settings := window.environment_settings_.settings
	window.set_associated_document(replacement)
	assert voidptr(settings.policy_container()) == voidptr(replacement.policy_container())
	snapshot := retained_source_policy_snapshot(original)
	assert snapshot.fetch_client? == settings
	assert snapshot.has_transient_activation == window.has_transient_activation()
	assert snapshot.sandboxing_flags.contains(.sandboxed_forms)
	assert snapshot.sandboxing_flags.contains(.sandboxed_downloads)
	assert !snapshot.allows_downloading
	cloned := snapshot.source_policy_container
	assert cloned.referrer_policy == .no_referrer
	assert cloned.embedder_policy.value == .require_corp
	assert cloned.embedder_policy.reporting_endpoint == 'source-endpoint'
	assert cloned.integrity_policy.blocked_destinations == [.style]
	// Pinned PolicyContainer::clone copies enforced integrity only.
	assert cloned.report_only_integrity_policy.is_empty()
	assert cloned.csp_list.len == 2
	assert cloned.csp_list.map(it.source) == [.header, .meta]
	assert cloned.csp_list[0].pre_parsed_policy_string == "img-src 'self'; sandbox; trusted-types original-name"
	assert cloned.csp_list[0].directives.map(it.name) == ['img-src', 'sandbox', 'trusted-types']
	assert cloned.csp_list[0].self_origin.serialize_for_ipc() == header.csp_list[0].self_origin.serialize_for_ipc()
	assert cloned.csp_list[0].self_origin.serialize() == 'https://own-snapshot-policy.test:8443'
	assert cloned.csp_list[1].pre_parsed_policy_string == "style-src 'none'; trusted-types meta-name"
	assert cloned.csp_list[1].self_origin.serialize_for_ipc() == opaque.serialize_for_ipc()
	assert cloned.csp_list[1].self_origin.is_opaque()
	window.set_associated_document(original)
	source_snapshot_insert_meta(original, "img-src 'none'")!
	assert old_container.csp_list.len == 3
	assert snapshot.source_policy_container.csp_list.len == 2
	mut actual_container := original.policy_container()
	actual_container.referrer_policy = .unsafe_url
	assert snapshot.source_policy_container.referrer_policy == .no_referrer
	original.set_policy_container(&dom.PolicyContainer{ referrer_policy: .origin })
	assert snapshot.source_policy_container.csp_list.len == 2
	assert snapshot.source_policy_container.referrer_policy == .no_referrer
}
