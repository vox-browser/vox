module dom

fn test_document_policy_container_lazily_retains_one_actual_owner() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	first := document.policy_container()
	second := document.policy_container()
	assert voidptr(first) == voidptr(second)
	assert first.csp_list.len == 0
	assert first.referrer_policy == .strict_origin_when_cross_origin
	assert first.embedder_policy.value == .unsafe_none
	assert first.embedder_policy.report_only_value == .unsafe_none
	assert first.integrity_policy.is_empty()
	assert first.report_only_integrity_policy.is_empty()
}

fn test_document_policy_container_setter_and_navigation_keep_actual_owner_identity() {
	mut document := Document.create(URL{'https://policy-owner.test/page'})
	defer { document.finalize() }
	first := &PolicyContainer{}
	second := &PolicyContainer{}
	document.set_policy_container(first)
	assert voidptr(document.policy_container()) == voidptr(first)
	document.set_policy_container(second)
	assert voidptr(document.policy_container()) == voidptr(second)
	mut navigation := Document.create_and_initialize(.html, 'text/html', &NavigationParams{
		response_url:     URL{'https://policy-owner.test/navigation'}
		policy_container: first
	})!
	defer { navigation.finalize() }
	assert voidptr(navigation.policy_container()) == voidptr(first)
}

fn test_document_retains_complete_actual_policy_record_and_origin_identity() {
	mut document := Document.create(URL{'https://policy-owner.test/page'})
	defer { document.finalize() }
	opaque := origin_create_opaque()
	mut policy := &PolicyContainer{
		csp_list:                     [SerializedCSPPolicy{
			directives:               [SerializedCSPDirective{'script-src', ["'self'"]}]
			disposition:              .report
			source:                   .meta
			self_origin:              opaque
			pre_parsed_policy_string: "SCRIPT-SRC 'self'"
		}]
		referrer_policy:              .origin
		embedder_policy:              EmbedderPolicy{
			value:                          .require_corp
			report_only_value:              .credentialless
			reporting_endpoint:             'enforced'
			report_only_reporting_endpoint: 'reported'
		}
		integrity_policy:             IntegrityPolicy{
			sources:              ['inline']
			blocked_destinations: [.script]
			endpoints:            ['enforced']
		}
		report_only_integrity_policy: IntegrityPolicy{
			blocked_destinations: [.style]
			endpoints:            ['reported']
		}
	}
	document.set_policy_container(policy)
	retained := document.policy_container()
	assert voidptr(retained) == voidptr(policy)
	assert retained.csp_list[0].self_origin.serialize_for_ipc() == opaque.serialize_for_ipc()
	assert retained.csp_list[0].disposition == .report && retained.csp_list[0].source == .meta
	assert retained.csp_list[0].pre_parsed_policy_string == "SCRIPT-SRC 'self'"
	assert retained.referrer_policy == .origin
	assert retained.embedder_policy.report_only_value == .credentialless
	assert retained.embedder_policy.report_only_reporting_endpoint == 'reported'
	assert retained.integrity_policy.endpoints == ['enforced']
	assert retained.report_only_integrity_policy.endpoints == ['reported']
	policy.csp_list << SerializedCSPPolicy{ self_origin: URL{'https://policy-owner.test:444/next'}.origin() }
	assert document.policy_container().csp_list.len == 2
	assert document.policy_container().csp_list[1].self_origin.serialize() == 'https://policy-owner.test:444'
}
