module html

import dom

fn test_referrer_and_policy_container_algorithms() {
	assert referrer_policy_from_string('STRICT-ORIGIN')? == .strict_origin
	assert ReferrerPolicy.strict_origin_when_cross_origin.to_string() == 'strict-origin-when-cross-origin'
	assert referrer_policy_from_string('bogus') == none
	assert url_requires_storing_the_policy_container_in_history(dom.URL{ value: 'about:blank' })
	assert url_requires_storing_the_policy_container_in_history(dom.URL{ value: 'data:text/plain,x' })
	assert !url_requires_storing_the_policy_container_in_history(dom.URL{
		value: 'blob:https://example.com/id'
	})
	assert !url_requires_storing_the_policy_container_in_history(dom.URL{
		value: 'https://example.com/'
	})

	container := PolicyContainer{
		csp_list:                     [
			SerializedCSPPolicy{
				directives: [
					SerializedCSPDirective{
						name:  'default-src'
						value: ["'self'"]
					},
				]
			},
		]
		embedder_policy:              EmbedderPolicy{
			value: .require_corp
		}
		integrity_policy:             IntegrityPolicy{
			blocked_destinations: [.script]
		}
		report_only_integrity_policy: IntegrityPolicy{
			blocked_destinations: [.style]
		}
	}
	cloned := container.clone()
	assert cloned.csp_list[0].directives[0].value[0] == "'self'"
	assert cloned.embedder_policy.value == .require_corp
	assert cloned.integrity_policy.blocked_destinations == [.script]
	// PolicyContainer::clone does not copy the report-only integrity policy.
	assert cloned.report_only_integrity_policy.is_empty()
	serialized := container.serialize()
	restored := create_a_policy_container_from_serialized_policy_container(serialized)
	assert restored.referrer_policy == .strict_origin_when_cross_origin
	assert restored.csp_list.len == 1
}

fn test_document_state_and_session_history_entry_clone() {
	document := dom.Document.create(dom.URL{ value: 'https://example.com/' })
	mut state := &DocumentState{
		document:              document
		initiator_origin:      dom.Origin{
			value: 'https://example.com'
		}
		navigable_target_name: 'frame'
		reload_pending:        true
	}
	entry := &SessionHistoryEntry{
		url:            dom.URL{
			value: 'https://example.com/page'
		}
		document_state: state
		step:           3
	}
	state.nested_histories << NestedHistory{
		id:      'child'
		entries: [entry]
	}
	cloned := entry.clone()
	assert cloned != entry
	cloned_state := cloned.document_state or { panic('missing cloned state') }
	assert voidptr(cloned_state) != voidptr(state)
	assert cloned.document()? == document
	assert cloned.navigation_api_key == entry.navigation_api_key
	assert cloned.navigation_api_id == entry.navigation_api_id
	assert cloned.navigation_api_key.len == 36
	assert cloned.classic_history_api_state.data == [
		u8(StructuredSerializeValueTag.null_primitive),
	]
	assert cloned.navigation_api_state.data == [
		u8(StructuredSerializeValueTag.undefined_primitive),
	]
}
