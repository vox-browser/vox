module page

fn navigation_boundary_start_request() NavigationStartRequest {
	return NavigationStartRequest{
		navigable_id: 41
		url: 'https://example.test/start'
		document_resource: 'body'
		navigation_id: 'navigation-1'
		classic_history_api_state: 'classic'
		navigation_api_state: 'navigation'
		navigation_api_key: 'key'
		navigation_api_id: 'id'
	}
}

fn test_navigation_start_skips_javascript_and_resumes_cancelled_unload() {
	mut client := PageClient.create()
	mut endpoint := &NavigationEndpoint{
		id: 41
		unload_check_results: {
			'navigation-1': false
		}
	}
	client.request_navigation_start(mut endpoint, .top_level, 'javascript:alert(1)', 'javascript',
		none)
	assert endpoint.resumes.len == 0
	client.request_navigation_start(mut endpoint, .top_level, 'https://example.test/start',
		'navigation-1', navigation_boundary_start_request())
	assert endpoint.resumes.len == 1
	assert endpoint.resumes[0].navigation_id == 'navigation-1'
	assert endpoint.resumes[0].request == none
}

fn test_navigation_population_round_trip_applies_ui_result() {
	mut client := PageClient.create()
	mut endpoint := &NavigationEndpoint{ id: 41 }
	client.request_navigation_start(mut endpoint, .iframe, 'https://example.test/start',
		'navigation-1', navigation_boundary_start_request())
	assert endpoint.resumes.len == 1
	request := endpoint.resumes[0].request or { panic('missing population request') }
	assert request.history_entry.document_state.id == 1
	assert request.history_entry.url == 'https://example.test/start'
	assert request.history_entry.navigation_api_state == 'navigation'

	client.navigation_params_creation_finished(mut endpoint, request, NavigationPopulationResult{
		redirected_url: 'https://example.test/final'
		classic_history_api_state: 'redirected-state'
		replacement_document_state: NavigationDocumentState{
			id: 9
			resource: 'replacement'
		}
		resource_cleared: true
		navigation_params: 'fetch'
	})
	assert endpoint.continuations.len == 1
	continuation := endpoint.continuations[0]
	assert continuation.request.history_entry.url == 'https://example.test/final'
	assert continuation.request.history_entry.classic_history_api_state == 'redirected-state'
	assert continuation.request.history_entry.document_state.id == 9
	assert continuation.request.history_entry.document_state.resource_is_empty
	assert continuation.result.navigation_params == 'fetch'
}

fn test_history_navigation_population_resumes_only_registered_navigable() {
	mut model := Page.create(1)!
	mut executor := model.history_executor()
	executor.register_pending_population(7, 41)
	population := HistoryNavigationPopulation{
		request: NavigationPopulationRequest{
			navigable_id: 41
			navigation_id: 'history-navigation'
		}
	}
	mut client := model.client()
	client.history_navigation_params_creation_finished(8, population)
	assert executor.resumed_populations().len == 0
	client.history_navigation_params_creation_finished(7, population)
	assert executor.resumed_populations().len == 1
	client.history_navigation_params_creation_finished(7, population)
	assert executor.resumed_populations().len == 1
}
