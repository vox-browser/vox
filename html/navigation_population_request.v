// Copyright (c) 2026-present, the Ladybird developers
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NavigationSourceSnapshot.{h,cpp} and
// NavigationPopulationRequest.{h,cpp}. The C++ records are IPC descriptors;
// this single-process V port keeps the same detached data while retaining its
// existing process-local navigation-params result type.
module html

import contentsecuritypolicy
import dom

pub struct NavigationSourceSnapshot {
pub:
	has_transient_activation bool
	sandboxing_flags         SandboxingFlagSet
	allows_downloading       bool = true
	fetch_client             ?SerializedEnvironmentSettingsObject
	source_policy_container  SerializedPolicyContainer
}

pub fn create_navigation_source_snapshot(snapshot SourceSnapshotParams) NavigationSourceSnapshot {
	return NavigationSourceSnapshot{
		has_transient_activation: snapshot.has_transient_activation
		sandboxing_flags: snapshot.sandboxing_flags
		allows_downloading: snapshot.allows_downloading
		fetch_client: if client := snapshot.fetch_client { client.serialize() } else { none }
		source_policy_container: snapshot.source_policy_container.serialize()
	}
}

pub struct NavigationStartRequest {
pub:
	navigable_id              u64
	url                       dom.URL
	document_resource         DocumentResource = EmptyDocumentResource{}
	request_referrer          RequestReferrer = RequestReferrerClient.client
	request_referrer_policy   ReferrerPolicy = .strict_origin_when_cross_origin
	initiator_origin          dom.Origin
	initiator_base_url        ?dom.URL
	navigable_target_name     string
	source_snapshot_params    NavigationSourceSnapshot
	target_snapshot_params    TargetSnapshotParams
	csp_navigation_type       contentsecuritypolicy.NavigationType = .other
	history_handling          NavigationHistoryBehavior = .auto
	user_involvement          dom.UserNavigationInvolvement = .none
	navigation_id             string
	classic_history_api_state SerializationRecord = serialized_null()
	navigation_api_state      SerializationRecord = serialized_undefined()
	navigation_api_key        string
	navigation_api_id         string
}

pub struct SessionHistoryDocumentStateDescriptor {
pub mut:
	id                       u64
	history_policy_container HistoryPolicyContainer = DocumentStateClient.client
	request_referrer         RequestReferrer = RequestReferrerClient.client
	request_referrer_policy  ReferrerPolicy = .strict_origin_when_cross_origin
	initiator_origin         ?dom.Origin
	origin                   ?dom.Origin
	about_base_url           ?dom.URL
	resource                 DocumentResource = EmptyDocumentResource{}
	reload_pending           bool
	ever_populated           bool
	user_agent_initiated     bool
	navigable_target_name    string
	nested_histories         []NestedHistory
}

pub struct PendingSessionHistoryEntryDescriptor {
pub mut:
	url                       dom.URL
	document_state            SessionHistoryDocumentStateDescriptor
	classic_history_api_state SerializationRecord = serialized_null()
	navigation_api_state      SerializationRecord = serialized_undefined()
	navigation_api_key        string
	navigation_api_id         string
	scroll_restoration_mode   ScrollRestorationMode = .auto
	scroll_position_data      SessionHistoryEntryScrollPositionData
}

pub struct NavigationPopulationRequest {
pub:
	navigable_id           u64
	source_snapshot_params NavigationSourceSnapshot
	target_snapshot_params TargetSnapshotParams
	csp_navigation_type    contentsecuritypolicy.NavigationType = .other
	history_handling       NavigationHistoryBehavior = .auto
	user_involvement       dom.UserNavigationInvolvement = .none
	navigation_id          string
pub mut:
	history_entry PendingSessionHistoryEntryDescriptor
}

pub struct NavigationPopulationResult {
pub:
	navigation_params         NavigableNavigationParamsResult
	redirected_url            ?dom.URL
	classic_history_api_state ?SerializationRecord
	replacement_document_state ?SessionHistoryDocumentStateDescriptor
	resource_cleared          bool
}

pub struct HistoryNavigationPopulation {
pub:
	request NavigationPopulationRequest
	result  NavigationPopulationResult
}

pub fn create_navigation_population_request(start_request NavigationStartRequest, document_state_id u64) NavigationPopulationRequest {
	mut resource := start_request.document_resource
	mut origin := ?dom.Origin(none)
	mut about_base_url := ?dom.URL(none)
	if url_matches_about_blank(start_request.url) || url_matches_about_srcdoc(start_request.url) {
		if url_matches_about_srcdoc(start_request.url) && resource is EmptyDocumentResource {
			resource = DocumentResource('')
		}
		origin = start_request.initiator_origin
		about_base_url = start_request.initiator_base_url
	}
	document_state := SessionHistoryDocumentStateDescriptor{
		id: document_state_id
		history_policy_container: DocumentStateClient.client
		request_referrer: start_request.request_referrer
		request_referrer_policy: start_request.request_referrer_policy
		initiator_origin: start_request.initiator_origin
		user_agent_initiated: start_request.user_involvement == .browser_ui
		origin: origin
		about_base_url: about_base_url
		resource: resource
		navigable_target_name: start_request.navigable_target_name
	}
	history_entry := PendingSessionHistoryEntryDescriptor{
		url: start_request.url
		document_state: document_state
		classic_history_api_state: SerializationRecord{
			type_:                start_request.classic_history_api_state.type_
			data:                 start_request.classic_history_api_state.data.clone()
			shared_array_buffers: start_request.classic_history_api_state.shared_array_buffers.clone()
		}
		navigation_api_state: SerializationRecord{
			type_:                start_request.navigation_api_state.type_
			data:                 start_request.navigation_api_state.data.clone()
			shared_array_buffers: start_request.navigation_api_state.shared_array_buffers.clone()
		}
		navigation_api_key: start_request.navigation_api_key
		navigation_api_id: start_request.navigation_api_id
		scroll_restoration_mode: .auto
	}
	return NavigationPopulationRequest{
		navigable_id: start_request.navigable_id
		history_entry: history_entry
		source_snapshot_params: start_request.source_snapshot_params
		target_snapshot_params: start_request.target_snapshot_params
		csp_navigation_type: start_request.csp_navigation_type
		history_handling: start_request.history_handling
		user_involvement: start_request.user_involvement
		navigation_id: start_request.navigation_id
	}
}

pub fn apply_navigation_population_result(mut request NavigationPopulationRequest, result NavigationPopulationResult) {
	if replacement := result.replacement_document_state {
		request.history_entry.document_state = replacement
	}
	if redirected_url := result.redirected_url {
		request.history_entry.url = redirected_url
	}
	if state := result.classic_history_api_state {
		request.history_entry.classic_history_api_state = SerializationRecord{
			type_:                state.type_
			data:                 state.data.clone()
			shared_array_buffers: state.shared_array_buffers.clone()
		}
	}
	if result.resource_cleared {
		request.history_entry.document_state.resource = EmptyDocumentResource{}
	}
}
