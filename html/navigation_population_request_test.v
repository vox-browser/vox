module html

import contentsecuritypolicy
import dom

fn navigation_population_test_start(url string, resource DocumentResource) NavigationStartRequest {
	return NavigationStartRequest{
		navigable_id: 17
		url: dom.URL{ value: url }
		document_resource: resource
		request_referrer: dom.URL{ value: 'https://referrer.test/' }
		request_referrer_policy: .origin
		initiator_origin: dom.Origin{ value: 'https://initiator.test' }
		initiator_base_url: dom.URL{ value: 'https://initiator.test/base/' }
		navigable_target_name: 'target'
		source_snapshot_params: NavigationSourceSnapshot{
			has_transient_activation: true
			allows_downloading: false
		}
		target_snapshot_params: TargetSnapshotParams{
			iframe_element_referrer_policy: .no_referrer
		}
		csp_navigation_type: contentsecuritypolicy.NavigationType.form_submission
		history_handling: .replace
		user_involvement: .activation
		navigation_id: 'navigation-1'
		classic_history_api_state: SerializationRecord{ data: [u8(1), 2] }
		navigation_api_state: SerializationRecord{ data: [u8(3), 4] }
		navigation_api_key: 'key'
		navigation_api_id: 'id'
	}
}

fn test_create_navigation_population_request_preserves_detached_navigation_state() {
	request := create_navigation_population_request(navigation_population_test_start('https://example.test/page',
		DocumentResource('body')), 91)
	assert request.navigable_id == 17
	assert request.navigation_id == 'navigation-1'
	assert request.csp_navigation_type == .form_submission
	assert request.history_handling == .replace
	assert request.user_involvement == .activation
	assert request.target_snapshot_params.iframe_element_referrer_policy == .no_referrer
	assert request.history_entry.url.value == 'https://example.test/page'
	assert request.history_entry.classic_history_api_state.data == [u8(1), 2]
	assert request.history_entry.navigation_api_state.data == [u8(3), 4]
	assert request.history_entry.navigation_api_key == 'key'
	state := request.history_entry.document_state
	assert state.id == 91
	assert state.origin == none
	assert state.about_base_url == none
	assert state.navigable_target_name == 'target'
	assert state.resource is string
	assert state.resource as string == 'body'
}

fn test_create_navigation_population_request_applies_about_url_rules() {
	blank := create_navigation_population_request(navigation_population_test_start('about:blank',
		EmptyDocumentResource{}), 1)
	blank_state := blank.history_entry.document_state
	assert blank_state.origin or { panic('missing inherited origin') } == dom.Origin{
		value: 'https://initiator.test'
	}
	assert blank_state.about_base_url or { panic('missing inherited base URL') } == dom.URL{
		value: 'https://initiator.test/base/'
	}
	assert blank_state.resource is EmptyDocumentResource

	srcdoc := create_navigation_population_request(navigation_population_test_start('about:srcdoc',
		EmptyDocumentResource{}), 2)
	srcdoc_state := srcdoc.history_entry.document_state
	assert srcdoc_state.resource is string
	assert srcdoc_state.resource as string == ''
}

fn test_apply_navigation_population_result_updates_pending_entry() {
	mut request := create_navigation_population_request(navigation_population_test_start('https://example.test/start',
		DocumentResource('body')), 3)
	replacement := SessionHistoryDocumentStateDescriptor{
		id: 4
		resource: DocumentResource('replacement')
	}
	apply_navigation_population_result(mut request, NavigationPopulationResult{
		redirected_url: dom.URL{ value: 'https://example.test/final' }
		classic_history_api_state: SerializationRecord{ data: [u8(9)] }
		replacement_document_state: replacement
		resource_cleared: true
	})
	assert request.history_entry.url.value == 'https://example.test/final'
	assert request.history_entry.classic_history_api_state.data == [u8(9)]
	assert request.history_entry.document_state.id == 4
	assert request.history_entry.document_state.resource is EmptyDocumentResource
}

fn test_create_navigation_source_snapshot_detaches_policy_state() {
	snapshot := create_navigation_source_snapshot(SourceSnapshotParams{
		has_transient_activation: true
		sandboxing_flags: SandboxingFlagSet{ bits: 7 }
		allows_downloading: false
		source_policy_container: PolicyContainer{
			referrer_policy: .same_origin
		}
	})
	assert snapshot.has_transient_activation
	assert snapshot.sandboxing_flags.bits == 7
	assert !snapshot.allows_downloading
	assert snapshot.fetch_client == none
	assert snapshot.source_policy_container.referrer_policy == .same_origin
}
