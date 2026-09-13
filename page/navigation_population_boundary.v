// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// PageClient's side of the UI-owned navigation-population transaction in
// Page.cpp. HTML owns the full serializable descriptors; these records retain
// the fields PageClient mutates or routes across its process boundary.
module page

pub enum NavigationTarget {
	top_level
	iframe
}

pub struct NavigationDocumentState {
pub mut:
	id                u64
	resource          string
	resource_is_empty bool
}

pub struct NavigationHistoryEntry {
pub mut:
	url                       string
	document_state            NavigationDocumentState
	classic_history_api_state string
	navigation_api_state      string
	navigation_api_key        string
	navigation_api_id         string
}

pub struct NavigationStartRequest {
pub:
	navigable_id              u64
	url                       string
	document_resource         string
	document_resource_is_empty bool
	navigation_id             string
	classic_history_api_state string
	navigation_api_state      string
	navigation_api_key        string
	navigation_api_id         string
}

pub struct NavigationPopulationRequest {
pub:
	navigable_id  u64
	navigation_id string
pub mut:
	history_entry NavigationHistoryEntry
}

pub struct NavigationPopulationResult {
pub:
	redirected_url            ?string
	classic_history_api_state ?string
	replacement_document_state ?NavigationDocumentState
	resource_cleared          bool
	navigation_params         string
}

pub struct HistoryNavigationPopulation {
pub:
	request NavigationPopulationRequest
	result  NavigationPopulationResult
}

pub struct NavigationResume {
pub:
	navigation_id string
	request       ?NavigationPopulationRequest
}

pub struct NavigationContinuation {
pub:
	request NavigationPopulationRequest
	result  NavigationPopulationResult
}

@[heap]
pub struct NavigationEndpoint {
pub:
	id u64
pub mut:
	unload_check_results map[string]bool
	resumes              []NavigationResume
	continuations        []NavigationContinuation
}

pub fn (endpoint &NavigationEndpoint) run_navigation_unload_check(navigation_id string) bool {
	return endpoint.unload_check_results[navigation_id] or { true }
}

pub fn (mut endpoint NavigationEndpoint) resume_navigation_params_creation(navigation_id string, request ?NavigationPopulationRequest) {
	endpoint.resumes << NavigationResume{
		navigation_id: navigation_id
		request: request
	}
}

pub fn (mut endpoint NavigationEndpoint) continue_navigation_at_population(request NavigationPopulationRequest, result NavigationPopulationResult) {
	endpoint.continuations << NavigationContinuation{
		request: request
		result: result
	}
}

@[heap]
pub struct HistoryExecutor {
mut:
	pending_populations_ map[string]bool
	resumed_populations_ []HistoryNavigationPopulation
}

fn history_population_key(operation_id u64, navigable_id u64) string {
	return '${operation_id}:${navigable_id}'
}

pub fn (mut executor HistoryExecutor) register_pending_population(operation_id u64, navigable_id u64) {
	executor.pending_populations_[history_population_key(operation_id, navigable_id)] = true
}

pub fn (mut executor HistoryExecutor) resume_history_navigation_population(operation_id u64, population HistoryNavigationPopulation) bool {
	key := history_population_key(operation_id, population.request.navigable_id)
	if key !in executor.pending_populations_ {
		return false
	}
	executor.pending_populations_.delete(key)
	executor.resumed_populations_ << population
	return true
}

pub fn (executor &HistoryExecutor) resumed_populations() []HistoryNavigationPopulation {
	return executor.resumed_populations_.clone()
}

fn create_client_navigation_population_request(start_request NavigationStartRequest, document_state_id u64) NavigationPopulationRequest {
	return NavigationPopulationRequest{
		navigable_id: start_request.navigable_id
		navigation_id: start_request.navigation_id
		history_entry: NavigationHistoryEntry{
			url: start_request.url
			document_state: NavigationDocumentState{
				id: document_state_id
				resource: start_request.document_resource
				resource_is_empty: start_request.document_resource_is_empty
			}
			classic_history_api_state: start_request.classic_history_api_state
			navigation_api_state: start_request.navigation_api_state
			navigation_api_key: start_request.navigation_api_key
			navigation_api_id: start_request.navigation_api_id
		}
	}
}

fn apply_client_navigation_population_result(mut request NavigationPopulationRequest, result NavigationPopulationResult) {
	if replacement := result.replacement_document_state {
		request.history_entry.document_state = replacement
	}
	if url := result.redirected_url {
		request.history_entry.url = url
	}
	if state := result.classic_history_api_state {
		request.history_entry.classic_history_api_state = state
	}
	if result.resource_cleared {
		request.history_entry.document_state.resource = ''
		request.history_entry.document_state.resource_is_empty = true
	}
}

pub fn (mut client PageClient) history_navigation_params_creation_finished(operation_id u64, population HistoryNavigationPopulation) {
	client.history_executor_.resume_history_navigation_population(operation_id, population)
}

pub fn (mut client PageClient) request_navigation_start(mut navigable NavigationEndpoint, target NavigationTarget, _ string, navigation_id string, start_request ?NavigationStartRequest) {
	request := start_request or {
		// javascript: navigations run synchronously and never populate an entry.
		return
	}
	if !navigable.run_navigation_unload_check(navigation_id) {
		navigable.resume_navigation_params_creation(navigation_id, none)
		return
	}
	population_request := create_client_navigation_population_request(request,
		client.allocate_cross_process_id())
	client.request_navigation_population(mut navigable, target, population_request)
}

pub fn (mut client PageClient) request_navigation_population(mut navigable NavigationEndpoint, _ NavigationTarget, request NavigationPopulationRequest) {
	navigable.resume_navigation_params_creation(request.navigation_id, request)
}

pub fn (mut client PageClient) navigation_params_creation_finished(mut navigable NavigationEndpoint, request NavigationPopulationRequest, result NavigationPopulationResult) {
	mut populated_request := request
	apply_client_navigation_population_result(mut populated_request, result)
	navigable.continue_navigation_at_population(populated_request, result)
}
