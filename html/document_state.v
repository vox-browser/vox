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

pub type HistoryPolicyContainer = DocumentStateClient | dom.PolicyContainer

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
	document_id_             ?dom.UniqueNodeID
	history_policy_container HistoryPolicyContainer = DocumentStateClient.client
	request_referrer         RequestReferrer = RequestReferrerClient.client
	request_referrer_policy  ReferrerPolicy = .strict_origin_when_cross_origin
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
			id: history.id
			entries: history.entries.clone()
		}
	}
	return &DocumentState{
		document: state.document
		document_id_: state.document_id()
		history_policy_container: state.history_policy_container
		request_referrer: state.request_referrer
		request_referrer_policy: state.request_referrer_policy
		initiator_origin: state.initiator_origin
		origin: state.origin
		about_base_url: state.about_base_url
		nested_histories: nested_histories
		resource: state.resource
		reload_pending: state.reload_pending
		ever_populated: state.ever_populated
		navigable_target_name: state.navigable_target_name
	}
}

pub fn (state &DocumentState) document() ?&dom.Document {
	return state.document
}

pub fn (mut state DocumentState) set_document(document ?&dom.Document) {
	state.document = document
	state.document_id_ = if value := document { value.unique_id() } else { none }
}

// Document state is decoupled from a live document's lifetime. The stable node
// identity is used for history comparisons; `document` is only the V host's
// non-owning process-local pointer for an entry that is currently populated.
pub fn (state &DocumentState) document_id() ?dom.UniqueNodeID {
	if id := state.document_id_ {
		return id
	}
	if document := state.document {
		return document.unique_id()
	}
	return none
}

pub fn (mut state DocumentState) set_document_id(document_id ?dom.UniqueNodeID) {
	state.document_id_ = document_id
}

pub fn (state &DocumentState) history_policy_container() HistoryPolicyContainer {
	return state.history_policy_container
}

pub fn (mut state DocumentState) set_history_policy_container(value HistoryPolicyContainer) {
	state.history_policy_container = value
}

pub fn (state &DocumentState) request_referrer() RequestReferrer {
	return state.request_referrer
}

pub fn (mut state DocumentState) set_request_referrer(value RequestReferrer) {
	state.request_referrer = value
}

pub fn (state &DocumentState) request_referrer_policy() ReferrerPolicy {
	return state.request_referrer_policy
}

pub fn (mut state DocumentState) set_request_referrer_policy(value ReferrerPolicy) {
	state.request_referrer_policy = value
}

pub fn (state &DocumentState) initiator_origin() ?dom.Origin {
	return state.initiator_origin
}

pub fn (mut state DocumentState) set_initiator_origin(value ?dom.Origin) {
	state.initiator_origin = value
}

pub fn (state &DocumentState) origin() ?dom.Origin {
	return state.origin
}

pub fn (mut state DocumentState) set_origin(value ?dom.Origin) {
	state.origin = value
}

pub fn (state &DocumentState) about_base_url() ?dom.URL {
	return state.about_base_url
}

pub fn (mut state DocumentState) set_about_base_url(value ?dom.URL) {
	state.about_base_url = value
}

pub fn (state &DocumentState) nested_histories() []NestedHistory {
	return state.nested_histories.clone()
}

pub fn (mut state DocumentState) set_nested_histories(value []NestedHistory) {
	state.nested_histories = value.clone()
}

pub fn (state &DocumentState) resource() DocumentResource {
	return state.resource
}

pub fn (mut state DocumentState) set_resource(value DocumentResource) {
	state.resource = value
}

pub fn (state &DocumentState) reload_pending() bool {
	return state.reload_pending
}

pub fn (mut state DocumentState) set_reload_pending(value bool) {
	state.reload_pending = value
}

pub fn (state &DocumentState) ever_populated() bool {
	return state.ever_populated
}

pub fn (mut state DocumentState) set_ever_populated(value bool) {
	state.ever_populated = value
}

pub fn (state &DocumentState) navigable_target_name() string {
	return state.navigable_target_name
}

pub fn (mut state DocumentState) set_navigable_target_name(value string) {
	state.navigable_target_name = value
}

pub enum StructuredSerializeValueTag {
	empty
	undefined_primitive
	null_primitive
	boolean_primitive
	number_primitive
	string_primitive
	big_int_primitive
	boolean_object
	number_object
	string_object
	big_int_object
	date_object
	regexp_object
	map_object
	set_object
	array_object
	error_object
	object
	object_reference
	// StructuredSerializeTypes.h stable serialization values; never reorder.
	growable_shared_array_buffer = 19
	shared_array_buffer = 20
	resizable_array_buffer = 21
	array_buffer = 22
	array_buffer_view = 23
	serializable_object = 24
	int32_primitive = 25
	end_object = 0xff
}

// Source IPCSerializationRecord and StorageSerializationRecord share this DTO
// boundary, but retain their distinct source wire codecs.
pub enum SerializationType {
	ipc
	storage
}

pub struct SerializationRecord {
pub:
	data                 []u8
	shared_array_buffers []&StructuredObject
	type_                SerializationType
}

fn serialized_undefined() SerializationRecord {
	// SessionHistoryEntry.cpp constructs the owning StorageSerializationRecord.
	return structured_serialize_for_storage(dom.js_undefined()) or { panic(err.msg()) }
}

fn serialized_null() SerializationRecord {
	// SessionHistoryEntry.cpp constructs the owning StorageSerializationRecord.
	return structured_serialize_for_storage(dom.js_null()) or { panic(err.msg()) }
}

pub enum SessionHistoryEntryPending {
	pending
}

pub type SessionHistoryStep = SessionHistoryEntryPending | int

pub enum ScrollRestorationMode {
	auto
	manual
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#she-scroll-position
pub struct SessionHistoryEntryScrollPositionData {
pub mut:
	// FIXME: Track all restorable scrollable regions. Currently only the viewport is persisted.
	viewport_scroll_position ?dom.CSSPixelPoint_
}

@[heap]
pub struct SessionHistoryEntry {
pub mut:
	step                             SessionHistoryStep = SessionHistoryEntryPending.pending
	url                              dom.URL
	document_state                   ?&DocumentState
	classic_history_api_state        SerializationRecord = serialized_null()
	navigation_api_state             SerializationRecord = serialized_undefined()
	navigation_api_key               string = rand.uuid_v4()
	navigation_api_id                string = rand.uuid_v4()
	scroll_restoration_mode          ScrollRestorationMode = .auto
	scroll_position_data             SessionHistoryEntryScrollPositionData
	policy_container                 ?&PolicyContainer
	browsing_context_name            ?string
	original_source_browsing_context voidptr
}

// Copies for entries that join a navigable's session history while a
// document arena is entered. Callers enter persistent storage first. The URL
// record is re-derived from its serialization on demand.
fn persistent_session_history_url(url dom.URL) dom.URL {
	return dom.URL{
		value: url.value.clone()
	}
}

fn persistent_serialization_record(record SerializationRecord) SerializationRecord {
	return SerializationRecord{
		type_:                record.type_
		data:                 record.data.clone()
		shared_array_buffers: record.shared_array_buffers.clone()
	}
}

pub fn (entry &SessionHistoryEntry) clone() &SessionHistoryEntry {
	document_state := entry.document_state or {
		panic('SessionHistoryEntry.clone requires a document state')
	}

	return &SessionHistoryEntry{
		step: entry.step
		url: entry.url
		document_state: document_state.clone()
		classic_history_api_state: SerializationRecord{
			type_:                entry.classic_history_api_state.type_
			data:                 entry.classic_history_api_state.data.clone()
			shared_array_buffers: entry.classic_history_api_state.shared_array_buffers.clone()
		}
		navigation_api_state: SerializationRecord{
			type_:                entry.navigation_api_state.type_
			data:                 entry.navigation_api_state.data.clone()
			shared_array_buffers: entry.navigation_api_state.shared_array_buffers.clone()
		}
		navigation_api_key: entry.navigation_api_key
		navigation_api_id: entry.navigation_api_id
		scroll_restoration_mode: entry.scroll_restoration_mode
		scroll_position_data: SessionHistoryEntryScrollPositionData{
			viewport_scroll_position: entry.scroll_position_data.viewport_scroll_position
		}
		policy_container: entry.policy_container
		browsing_context_name: entry.browsing_context_name
		original_source_browsing_context: entry.original_source_browsing_context
	}
}

pub fn (entry &SessionHistoryEntry) step() SessionHistoryStep {
	return entry.step
}

pub fn (mut entry SessionHistoryEntry) set_step(value SessionHistoryStep) {
	entry.step = value
}

pub fn (entry &SessionHistoryEntry) url() dom.URL {
	return entry.url
}

pub fn (mut entry SessionHistoryEntry) set_url(value dom.URL) {
	entry.url = value
}

pub fn (entry &SessionHistoryEntry) document_state() ?&DocumentState {
	return entry.document_state
}

pub fn (mut entry SessionHistoryEntry) set_document_state(value ?&DocumentState) {
	entry.document_state = value
}

pub fn (entry &SessionHistoryEntry) classic_history_api_state() SerializationRecord {
	return entry.classic_history_api_state
}

pub fn (mut entry SessionHistoryEntry) set_classic_history_api_state(value SerializationRecord) {
	entry.classic_history_api_state = value
}

pub fn (entry &SessionHistoryEntry) navigation_api_state() SerializationRecord {
	return entry.navigation_api_state
}

pub fn (mut entry SessionHistoryEntry) set_navigation_api_state(value SerializationRecord) {
	entry.navigation_api_state = value
}

pub fn (entry &SessionHistoryEntry) navigation_api_key() string {
	return entry.navigation_api_key
}

pub fn (mut entry SessionHistoryEntry) set_navigation_api_key(value string) {
	entry.navigation_api_key = value
}

pub fn (entry &SessionHistoryEntry) navigation_api_id() string {
	return entry.navigation_api_id
}

pub fn (mut entry SessionHistoryEntry) set_navigation_api_id(value string) {
	entry.navigation_api_id = value
}

pub fn (entry &SessionHistoryEntry) scroll_restoration_mode() ScrollRestorationMode {
	return entry.scroll_restoration_mode
}

pub fn (mut entry SessionHistoryEntry) set_scroll_restoration_mode(value ScrollRestorationMode) {
	entry.scroll_restoration_mode = value
}

pub fn (entry &SessionHistoryEntry) scroll_position_data() SessionHistoryEntryScrollPositionData {
	return entry.scroll_position_data
}

pub fn (mut entry SessionHistoryEntry) set_scroll_position_data(value SessionHistoryEntryScrollPositionData) {
	entry.scroll_position_data = value
}

pub fn (entry &SessionHistoryEntry) policy_container() ?&PolicyContainer {
	return entry.policy_container
}

pub fn (mut entry SessionHistoryEntry) set_policy_container(value ?&dom.PolicyContainer) {
	entry.policy_container = value
}

pub fn (entry &SessionHistoryEntry) browsing_context_name() ?string {
	return entry.browsing_context_name
}

pub fn (mut entry SessionHistoryEntry) set_browsing_context_name(value ?string) {
	entry.browsing_context_name = value
}

pub fn (entry &SessionHistoryEntry) original_source_browsing_context() voidptr {
	return entry.original_source_browsing_context
}

pub fn (mut entry SessionHistoryEntry) set_original_source_browsing_context(value voidptr) {
	entry.original_source_browsing_context = value
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#she-document
pub fn (entry &SessionHistoryEntry) document() ?&dom.Document {
	state := entry.document_state or { return none }
	return state.document
}
