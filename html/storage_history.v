// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Storage.{h,cpp} and History.{h,cpp}. Storage-area persistence
// and traversal scheduling remain owned by host-facing containers, while the
// Web Storage and same-document history algorithms execute here.
module html

import dom
import platform
import webidl

pub enum StorageType {
	local
	session
}

pub struct StorageEventRecord {
pub:
	key          ?string
	old_value    ?string
	new_value    ?string
	url          string
	storage_area &Storage
}

@[heap]
pub struct StorageBottle {
pub mut:
	entries map[string]string
	keys    []string
	quota   ?uint
}

pub fn StorageBottle.create(quota ?uint) &StorageBottle {
	return &StorageBottle{
		quota: quota
	}
}

fn (bottle &StorageBottle) prospective_size(key string, value string) uint {
	mut size := uint(0)
	for existing_key in bottle.keys {
		size += uint(existing_key.len)
		if existing_key == key {
			size += uint(value.len)
		} else {
			size += uint(bottle.entries[existing_key].len)
		}
	}
	if key !in bottle.entries {
		size += uint(key.len + value.len)
	}
	return size
}

@[heap]
pub struct StorageHub {
mut:
	storages_ []&Storage
}

pub fn StorageHub.create() &StorageHub {
	return &StorageHub{}
}

@[heap]
pub struct Storage {
pub:
	type_          StorageType
	storage_bottle &StorageBottle
mut:
	hub_            &StorageHub = unsafe { nil }
	origin_         dom.Origin
	traversable_id_ string
	document_url_   dom.URL
	events_         []StorageEventRecord
}

pub fn Storage.create(type_ StorageType, bottle &StorageBottle, mut hub StorageHub, origin dom.Origin, traversable_id string, document_url dom.URL) &Storage {
	storage := &Storage{
		type_:           type_
		storage_bottle:  bottle
		hub_:            hub
		origin_:         origin
		traversable_id_: traversable_id
		document_url_:   document_url
	}
	// The hub is process-wide; its list must not grow in a document arena.
	persistent := platform.enter_persistent()
	hub.storages_ << storage
	platform.leave_persistent(persistent)
	return storage
}

// A retiring document's Storage objects leave the hub before its arena is
// released, so later broadcasts cannot reach them.
pub fn (mut hub StorageHub) remove_storage(storage &Storage) {
	for index, candidate in hub.storages_ {
		if voidptr(candidate) == voidptr(storage) {
			hub.storages_.delete(index)
			return
		}
	}
}

pub fn (storage &Storage) type_() StorageType {
	return storage.type_
}

pub fn (storage &Storage) length() uint {
	return uint(storage.storage_bottle.keys.len)
}

pub fn (storage &Storage) key(index uint) ?string {
	if index >= uint(storage.storage_bottle.keys.len) {
		return none
	}
	return storage.storage_bottle.keys[index]
}

pub fn (storage &Storage) get_item(key string) ?string {
	return storage.storage_bottle.entries[key]
}

pub fn (mut storage Storage) set_item(key string, value string) ! {
	mut bottle := storage.storage_bottle
	mut old_value := ?string(none)
	if old := bottle.entries[key] {
		if old == value {
			return
		}
		old_value = old
	}
	if quota := bottle.quota {
		if bottle.prospective_size(key, value) > quota {
			return error('QuotaExceededError: storage quota exceeded')
		}
	}
	// Bottles outlive the documents that write them: keep their keys,
	// values and buckets in persistent storage.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if key !in bottle.entries {
		bottle.keys << key.clone()
	}
	bottle.entries[key] = value.clone()
	storage.broadcast(key, old_value, value)
}

pub fn (mut storage Storage) remove_item(key string) {
	mut bottle := storage.storage_bottle
	old_value := bottle.entries[key] or { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	bottle.entries.delete(key)
	bottle.keys = bottle.keys.filter(it != key)
	storage.broadcast(key, old_value, none)
}

pub fn (mut storage Storage) clear() {
	mut bottle := storage.storage_bottle
	if bottle.keys.len == 0 {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	bottle.entries.clear()
	bottle.keys.clear()
	storage.broadcast(none, none, none)
}

// Records go to other documents' Storage objects, which can outlive this
// caller's arena; callers enter persistent storage and the strings are copied.
fn (mut storage Storage) broadcast(key ?string, old_value ?string, new_value ?string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for remote in storage.hub_.storages_ {
		if remote == &storage || remote.type_ != storage.type_
			|| !remote.origin_.is_same_origin(storage.origin_) {
			continue
		}
		if storage.type_ == .session && remote.traversable_id_ != storage.traversable_id_ {
			continue
		}
		mut mutable_remote := unsafe { &Storage(remote) }
		mutable_remote.events_ << StorageEventRecord{
			key:          if text := key { ?string(text.clone()) } else { none }
			old_value:    if text := old_value { ?string(text.clone()) } else { none }
			new_value:    if text := new_value { ?string(text.clone()) } else { none }
			url:          storage.document_url_.serialize()
			storage_area: remote
		}
	}
}

pub fn (storage &Storage) supported_property_names() []string {
	return storage.storage_bottle.keys.clone()
}

pub fn (storage &Storage) named_item_value(name string) dom.JSValue {
	return if value := storage.get_item(name) { dom.js_string(value) } else { dom.js_undefined() }
}

pub fn (mut storage Storage) reorder() {
	// The specification deliberately leaves the resulting order
	// implementation-defined, so retaining insertion order is conforming.
}

pub fn (storage &Storage) dump() {
	eprintln('Storage (${storage.storage_bottle.keys.len} key(s))')
	for index, key in storage.storage_bottle.keys {
		value := storage.storage_bottle.entries[key]
		eprintln('[${index}] "${key}": "${value}"')
	}
}

pub fn (mut storage Storage) set_value_of_named_property(key string, value dom.JSValue) ! {
	converted := match value.kind {
		.string { value.string_data }
		.number { value.number_data.str() }
		.boolean { value.boolean_data.str() }
		.null_ { 'null' }
		.undefined { 'undefined' }
		.object { return error('TypeError: object-to-string conversion requires a host runtime') }
		.runtime_value { webidl.to_string(value.as_webidl_value()!)! }
	}
	storage.set_item(key, converted)!
}

pub fn (mut storage Storage) delete_value(name string) {
	storage.remove_item(name)
}

pub fn (storage &Storage) events() []StorageEventRecord {
	return storage.events_.clone()
}

pub fn (mut storage Storage) clear_events() {
	storage.events_.clear()
}

pub enum HistoryTraversalAction {
	none
	reload
	traverse
}

pub struct HistoryTraversalRecord {
pub:
	action HistoryTraversalAction
	delta  int
}

@[heap]
pub struct History {
mut:
	entries_        []&SessionHistoryEntry
	index_          int
	fully_active_   bool = true
	document_url_   dom.URL
	state_          dom.JSValue
	last_traversal_ HistoryTraversalRecord
	navigation_     ?&Navigation
	document_       ?&dom.Document
	state_revision_ u64
	deserialization_context_ StructuredDeserializationContext
}

pub fn History.create(initial_url dom.URL, initial_state dom.JSValue) !&History {
	serialized := structured_serialize_for_storage(initial_state)!
	entry := &SessionHistoryEntry{
		step:                      0
		url:                       initial_url
		classic_history_api_state: serialized
	}
	return &History{
		entries_:      [entry]
		document_url_: initial_url
		state_:        initial_state
	}
}

pub fn (mut history History) set_fully_active(value bool) {
	history.fully_active_ = value
}

pub fn (mut history History) set_navigation(navigation ?&Navigation) {
	history.navigation_ = navigation
}

pub fn (mut history History) set_associated_document(document &dom.Document) {
	history.document_ = document
	mut owner := unsafe { &dom.Document(document) }
	mut state := owner.history()
	if state.length == 0 {
		state.length = history.entries_.len
		state.index = history.index_
	}
}

// Actual engine wrappers cache the deserialized state object until it changes.
pub fn (history &History) state_revision() u64 {
	return history.state_revision_
}

pub fn (mut history History) set_deserialization_context(context StructuredDeserializationContext) {
	history.deserialization_context_ = context
}

pub fn (history &History) deserialize_state(record SerializationRecord) !dom.JSValue {
	return structured_deserialize_with_context(record, history.deserialization_context_)
}

fn (history &History) require_fully_active(operation string) ! {
	if document := history.document_ {
		if !document.is_fully_active() {
			return error("SecurityError: cannot perform ${operation} on a document that isn't fully active")
		}
	}
	if !history.fully_active_ {
		return error("SecurityError: cannot perform ${operation} on a document that isn't fully active")
	}
}

pub fn (history &History) length() !u64 {
	history.require_fully_active('length')!
	if document := history.document_ { return u64(document.history().length) }
	return u64(history.entries_.len)
}

pub fn (history &History) state() !dom.JSValue {
	history.require_fully_active('state')!
	if document := history.document_ { return document.history().state }
	return history.state_
}

pub fn (history &History) unsafe_state() dom.JSValue {
	return history.state_
}

fn history_optional_string_equal(a ?string, b ?string) bool {
	left := a or {
		if _ := b {
			return false
		}
		return true
	}

	right := b or { return false }
	return left == right
}

fn history_optional_u16_equal(a ?u16, b ?u16) bool {
	left := a or {
		if _ := b {
			return false
		}
		return true
	}

	right := b or { return false }
	return left == right
}

pub fn can_have_its_url_rewritten(document_url dom.URL, target_url dom.URL) bool {
	if target_url.scheme() != document_url.scheme()
		|| target_url.username() != document_url.username()
		|| target_url.password() != document_url.password()
		|| !history_optional_string_equal(target_url.host(), document_url.host())
		|| !history_optional_u16_equal(target_url.port(), document_url.port()) {
		return false
	}
	if target_url.scheme() in ['http', 'https'] {
		return true
	}
	if target_url.scheme() == 'file' {
		return target_url.serialize_path() == document_url.serialize_path()
	}
	return target_url.serialize_path() == document_url.serialize_path()
		&& history_optional_string_equal(target_url.query(), document_url.query())
}

fn (mut history History) shared_history_push_replace_state(data dom.JSValue, url ?string, behavior_ HistoryHandlingBehavior) ! {
	behavior := if document := history.document_ {
		if document.get_is_initial_about_blank() {
			HistoryHandlingBehavior.replace
		} else {
			behavior_
		}
	} else {
		behavior_
	}
	history.require_fully_active(if behavior == .push { 'pushState' } else { 'replaceState' })!
	serialized := structured_serialize_for_storage(data) or {
		structured_serialize_for_storage(dom.js_null())!
	}
	mut new_url := history.current_url()
	base_url := if document := history.document_ { document.base_url() } else { new_url }
	if value := url {
		if value != '' {
			new_url = dom.dom_url_parse(value, base_url, 'UTF-8') or {
				return error('SecurityError: cannot push or replace state to incompatible URL')
			}
			if !can_have_its_url_rewritten(history.current_url(), new_url) {
				return error('SecurityError: cannot push or replace state to incompatible URL')
			}
		}
	}
	if mut navigation := history.navigation_ {
		type_ := if behavior_ == .push {
			dom.NavigationType.push
		} else {
			dom.NavigationType.replace
		}
		if !navigation.fire_a_push_replace_reload_navigate_event(type_, new_url, true, .none_,
			none, none, none, serialized) {
			return
		}
	}
	if document := history.document_ {
		perform_url_and_history_update_steps(document, new_url, serialized, behavior)!
	}
	entry := &SessionHistoryEntry{
		step:                      if behavior == .push {
			history.index_ + 1
		} else {
			history.index_
		}
		url:                       new_url
		classic_history_api_state: serialized
		scroll_restoration_mode:   history.entries_[history.index_].scroll_restoration_mode
	}
	if behavior == .push {
		if history.index_ + 1 < history.entries_.len {
			history.entries_ = history.entries_[..history.index_ + 1]
		}
		history.entries_ << entry
		history.index_++
	} else {
		history.entries_[history.index_] = entry
	}
	history.document_url_ = new_url
	history.state_ = data
	history.state_revision_++
}

pub fn (mut history History) push_state(data dom.JSValue, unused string, url ?string) ! {
	_ = unused
	history.shared_history_push_replace_state(data, url, .push)!
}

pub fn (mut history History) replace_state(data dom.JSValue, unused string, url ?string) ! {
	_ = unused
	history.shared_history_push_replace_state(data, url, .replace)!
}

pub fn (mut history History) delta_traverse(delta int) ! {
	history.require_fully_active('go')!
	if delta == 0 {
		history.last_traversal_ = HistoryTraversalRecord{
			action: .reload
		}
		return
	}
	target := history.index_ + delta
	if target < 0 || target >= history.entries_.len {
		history.last_traversal_ = HistoryTraversalRecord{}
		return
	}
	history.index_ = target
	entry := history.entries_[target]
	history.document_url_ = entry.url
	history.state_ = structured_deserialize(entry.classic_history_api_state) or { dom.js_null() }
	history.state_revision_++
	history.last_traversal_ = HistoryTraversalRecord{
		action: .traverse
		delta:  delta
	}
}

pub fn (mut history History) go(delta int) ! {
	history.delta_traverse(delta)!
}

pub fn (mut history History) back() ! {
	history.go(-1)!
}

pub fn (mut history History) forward() ! {
	history.go(1)!
}

pub fn (history &History) scroll_restoration() !ScrollRestorationMode {
	history.require_fully_active('scrollRestoration')!
	if entry := history.associated_history_entry() { return entry.scroll_restoration_mode }
	return history.entries_[history.index_].scroll_restoration_mode
}

pub fn (mut history History) set_scroll_restoration(value ScrollRestorationMode) ! {
	history.require_fully_active('scrollRestoration')!
	if mut entry := history.associated_history_entry() { entry.scroll_restoration_mode = value }
	history.entries_[history.index_].scroll_restoration_mode = value
}

fn (history &History) associated_history_entry() ?&SessionHistoryEntry {
	document := history.document_ or { return none }
	pointer := NavigableModel.navigable_with_active_document(document) or { return none }
	model := unsafe { &NavigableModel(pointer) }
	return model.active_session_history_entry()
}

pub fn (history &History) current_url() dom.URL {
	if document := history.document_ {
		return document.url
	}
	return history.document_url_
}

pub fn (history &History) last_traversal() HistoryTraversalRecord {
	return history.last_traversal_
}
