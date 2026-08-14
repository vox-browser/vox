// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2023, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DocumentState.cpp, SessionHistoryEntry.cpp, and POSTResource.h.
module html

import dom
import rand

pub enum POSTResourceRequestContentType {
	application_x_www_form_urlencoded
	multipart_form_data
	text_plain
}

pub struct POSTResourceDirective {
pub:
	type_ string
	value string
}

pub struct POSTResource {
pub:
	request_body                    ?[]u8
	request_content_type            POSTResourceRequestContentType
	request_content_type_directives []POSTResourceDirective
}

pub struct EmptyDocumentResource {}

pub type DocumentResource = EmptyDocumentResource | POSTResource | string

pub enum DocumentStateClient {
	client
}

pub type HistoryPolicyContainer = DocumentStateClient | PolicyContainer

pub enum RequestReferrerClient {
	client
	no_referrer
}

pub type RequestReferrer = RequestReferrerClient | dom.URL

pub struct NestedHistory {
pub:
	id      string
	entries []&SessionHistoryEntry
}

@[heap]
pub struct DocumentState {
pub mut:
	document                 ?&dom.Document
	history_policy_container HistoryPolicyContainer = DocumentStateClient.client
	request_referrer         RequestReferrer        = RequestReferrerClient.client
	request_referrer_policy  ReferrerPolicy         = .strict_origin_when_cross_origin
	initiator_origin         ?dom.Origin
	origin                   ?dom.Origin
	about_base_url           ?dom.URL
	nested_histories         []NestedHistory
	resource                 DocumentResource = EmptyDocumentResource{}
	reload_pending           bool
	ever_populated           bool
	navigable_target_name    string
}

pub fn (state &DocumentState) clone() &DocumentState {
	mut nested_histories := []NestedHistory{cap: state.nested_histories.len}
	for history in state.nested_histories {
		nested_histories << NestedHistory{
			id:      history.id
			entries: history.entries.clone()
		}
	}
	return &DocumentState{
		document:                 state.document
		history_policy_container: state.history_policy_container
		request_referrer:         state.request_referrer
		request_referrer_policy:  state.request_referrer_policy
		initiator_origin:         state.initiator_origin
		origin:                   state.origin
		about_base_url:           state.about_base_url
		nested_histories:         nested_histories
		resource:                 state.resource
		reload_pending:           state.reload_pending
		ever_populated:           state.ever_populated
		navigable_target_name:    state.navigable_target_name
	}
}

pub enum StructuredSerializeValueTag {
	empty
	undefined_primitive
	null_primitive
}

pub struct SerializationRecord {
pub:
	data []u8
}

fn serialized_undefined() SerializationRecord {
	return SerializationRecord{
		data: [u8(StructuredSerializeValueTag.undefined_primitive)]
	}
}

fn serialized_null() SerializationRecord {
	return SerializationRecord{
		data: [u8(StructuredSerializeValueTag.null_primitive)]
	}
}

pub enum SessionHistoryEntryPending {
	pending
}

pub type SessionHistoryStep = SessionHistoryEntryPending | int

pub enum ScrollRestorationMode {
	auto
	manual
}

@[heap]
pub struct SessionHistoryEntry {
pub mut:
	step                             SessionHistoryStep = SessionHistoryEntryPending.pending
	url                              dom.URL
	document_state                   ?&DocumentState
	classic_history_api_state        SerializationRecord   = serialized_null()
	navigation_api_state             SerializationRecord   = serialized_undefined()
	navigation_api_key               string                = rand.uuid_v4()
	navigation_api_id                string                = rand.uuid_v4()
	scroll_restoration_mode          ScrollRestorationMode = .auto
	policy_container                 ?&PolicyContainer
	browsing_context_name            ?string
	original_source_browsing_context voidptr
}

pub fn (entry &SessionHistoryEntry) clone() &SessionHistoryEntry {
	document_state := entry.document_state or {
		panic('SessionHistoryEntry.clone requires a document state')
	}

	return &SessionHistoryEntry{
		step:                             entry.step
		url:                              entry.url
		document_state:                   document_state.clone()
		classic_history_api_state:        SerializationRecord{
			data: entry.classic_history_api_state.data.clone()
		}
		navigation_api_state:             SerializationRecord{
			data: entry.navigation_api_state.data.clone()
		}
		navigation_api_key:               entry.navigation_api_key
		navigation_api_id:                entry.navigation_api_id
		scroll_restoration_mode:          entry.scroll_restoration_mode
		policy_container:                 entry.policy_container
		browsing_context_name:            entry.browsing_context_name
		original_source_browsing_context: entry.original_source_browsing_context
	}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#she-document
pub fn (entry &SessionHistoryEntry) document() ?&dom.Document {
	state := entry.document_state or { return none }
	return state.document
}
