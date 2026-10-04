module html

import dom
import fetch
import http

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

fn test_create_policy_container_from_fetch_response() {
	mut realm := &ScriptingRealm{}
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	window := WindowModel.create_top_level(document, none, 'policy-test')!
	settings := WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	mut response := fetch.Response.create()
	response.url_list = [dom.URL{ value: 'https://example.test/resource' }]
	response.header_list.append(http.Header{'Content-Security-Policy', "default-src 'self'; sandbox"})
	response.header_list.append(http.Header{'Referrer-Policy', 'bogus, origin'})
	container := create_a_policy_container_from_a_fetch_response(response, settings)
	assert container.csp_list.len == 1
	assert container.csp_list[0].directives.len == 2
	assert container.csp_list[0].self_origin.serialize() == 'https://example.test'
	assert container.referrer_policy == .origin
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
		scroll_position_data: SessionHistoryEntryScrollPositionData{
			viewport_scroll_position: dom.CSSPixelPoint_{ x_: 7, y_: 11 }
		}
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
	assert cloned.scroll_position_data.viewport_scroll_position?.x() == 7
	assert cloned.scroll_position_data.viewport_scroll_position?.y() == 11
	assert cloned.navigation_api_key.len == 36
	// Source SessionHistoryEntry constructs StorageSerializationRecords,
	// whose envelope is distinct from a bare IPC primitive tag.
	assert cloned.classic_history_api_state.type_ == .storage
	assert cloned.classic_history_api_state.data == entry.classic_history_api_state.data
	assert structured_deserialize(cloned.classic_history_api_state)!.kind == .null_
	assert cloned.navigation_api_state.type_ == .storage
	assert cloned.navigation_api_state.data == entry.navigation_api_state.data
	assert structured_deserialize(cloned.navigation_api_state)!.kind == .undefined
}
