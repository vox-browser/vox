// Copyright (c) 2022-2023, networkException <networkexception@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/ModuleMap.{h,cpp}.
module html

import dom
import platform

pub enum ModuleMapEntryType {
	fetching
	module_script
}

pub struct ModuleLocationTuple {
pub:
	url_  dom.URL
	type_ string
}

pub fn ModuleLocationTuple.create(url dom.URL, type_ string) ModuleLocationTuple {
	return ModuleLocationTuple{url_: url, type_: type_}
}

pub fn (tuple &ModuleLocationTuple) url() dom.URL {
	return tuple.url_
}

pub fn (tuple &ModuleLocationTuple) type_() string {
	return tuple.type_
}

pub struct ModuleMapEntry {
pub:
	type_         ModuleMapEntryType
	module_script ?&ModuleScript
	callbacks     []OnFetchScriptComplete
}

@[heap]
struct OwnedModuleFetchCallback {
	callback OnFetchScriptComplete
	captured_closures []voidptr
	document_identity u64
mut:
	canceled bool
	invoked bool
}

@[heap]
pub struct ModuleMap {
mut:
	values_ map[string]ModuleMapEntry
	owned_fetch_callbacks_ map[u64]&OwnedModuleFetchCallback
	callback_dispatch_depth_ int
	owned_callback_cleanup_documents_ map[u64]bool
}

// Modulepreload creates one-shot adapters, whereas the public fetch APIs can
// borrow caller-owned callbacks. Track only the explicitly transferred ones.
fn (mut module_map ModuleMap) own_fetch_callback(callback OnFetchScriptComplete, captured_closures []voidptr, document_identity u64) &OwnedModuleFetchCallback {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owned := &OwnedModuleFetchCallback{
		callback: callback
		captured_closures: captured_closures.clone()
		document_identity: document_identity
	}
	module_map.owned_fetch_callbacks_[u64(voidptr(callback))] = owned
	return owned
}

fn (mut module_map ModuleMap) ensure_owned_callback_cleanup(document &dom.Document) {
	if document.native_storage() == unsafe { nil } { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	document_identity := u64(voidptr(document))
	if document_identity in module_map.owned_callback_cleanup_documents_ { return }
	module_map.owned_callback_cleanup_documents_[document_identity] = true
	owner := voidptr(&module_map)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.add_native_storage_cleanup(fn [owner, document_identity] () {
		mut owned_map := unsafe { &ModuleMap(owner) }
		owned_map.cancel_owned_fetch_callbacks(document_identity)
	})
}

fn (mut module_map ModuleMap) discard_owned_fetch_callback(callback OnFetchScriptComplete) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := u64(voidptr(callback))
	mut owned := module_map.owned_fetch_callbacks_[key] or { return }
	owned.canceled = true
	// A borrowed callback can retire the document while a completion batch
	// still holds a snapshot. Leave a canceled marker until that batch ends.
	if module_map.callback_dispatch_depth_ > 0 { return }
	module_map.owned_fetch_callbacks_.delete(key)
	for captured in owned.captured_closures {
		platform.release_closure(captured)
	}
	platform.release_closure(voidptr(owned.callback))
}

fn (mut module_map ModuleMap) cancel_owned_fetch_callbacks(document_identity u64) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	module_map.owned_callback_cleanup_documents_.delete(document_identity)
	for key, entry in module_map.values_ {
		mut callbacks := []OnFetchScriptComplete{}
		for callback in entry.callbacks {
			owned := module_map.owned_fetch_callbacks_[u64(voidptr(callback))] or {
				callbacks << callback
				continue
			}
			if owned.document_identity != document_identity { callbacks << callback }
		}
		module_map.values_[key] = ModuleMapEntry{ ...entry, callbacks: callbacks }
	}
	for key in module_map.owned_fetch_callbacks_.keys() {
		owned := module_map.owned_fetch_callbacks_[key] or { continue }
		if owned.document_identity == document_identity {
			module_map.discard_owned_fetch_callback(owned.callback)
		}
	}
}

fn (mut module_map ModuleMap) invoke_fetch_callbacks(callbacks []OnFetchScriptComplete, result ?&Script) {
	module_map.callback_dispatch_depth_++
	defer {
		module_map.callback_dispatch_depth_--
		if module_map.callback_dispatch_depth_ == 0 {
			for key in module_map.owned_fetch_callbacks_.keys() {
				owned := module_map.owned_fetch_callbacks_[key] or { continue }
				if owned.canceled { module_map.discard_owned_fetch_callback(owned.callback) }
			}
		}
	}
	for callback in callbacks {
		key := u64(voidptr(callback))
		is_owned := key in module_map.owned_fetch_callbacks_
		if mut owned := module_map.owned_fetch_callbacks_[key] {
			if owned.canceled { continue }
			// Invocation transfers any captured callback to its queued task.
			// The stable token also prevents a canceled adapter's caller from
			// mistaking a newly allocated closure at the same address for it.
			owned.invoked = true
			persistent := platform.enter_persistent()
			module_map.owned_fetch_callbacks_.delete(key)
			platform.leave_persistent(persistent)
		}
		callback(result)
		if is_owned { platform.release_closure(voidptr(callback)) }
	}
}

pub fn ModuleMap.create() &ModuleMap {
	return &ModuleMap{
		values_: map[string]ModuleMapEntry{}
	}
}

fn module_map_key(url dom.URL, type_ string) string {
	return '${url.serialize()}\x00${type_}'
}

pub fn (module_map &ModuleMap) is_fetching(url dom.URL, type_ string) bool {
	return module_map.is_(url, type_, .fetching)
}

pub fn (module_map &ModuleMap) is_(url dom.URL, type_ string, entry_type ModuleMapEntryType) bool {
	entry := module_map.values_[module_map_key(url, type_)] or { return false }
	return entry.type_ == entry_type
}

// `is` is a V keyword, so this is the literal class-qualified translation of
// ModuleMap::is.
pub fn module_map_is(module_map &ModuleMap, url dom.URL, type_ string, entry_type ModuleMapEntryType) bool {
	return module_map.is_(url, type_, entry_type)
}

pub fn (module_map &ModuleMap) get(url dom.URL, type_ string) ?ModuleMapEntry {
	return module_map.values_[module_map_key(url, type_)] or { return none }
}

pub fn (mut module_map ModuleMap) set(url dom.URL, type_ string, entry ModuleMapEntry) !bool {
	key := module_map_key(url, type_)
	was_new := key !in module_map.values_
	if previous := module_map.values_[key] {
		for callback in previous.callbacks {
			if !entry.callbacks.any(voidptr(it) == voidptr(callback)) {
				module_map.discard_owned_fetch_callback(callback)
			}
		}
	}
	module_map.values_[key] = entry
	return was_new
}

pub fn (mut module_map ModuleMap) begin_fetch(url dom.URL, type_ string, callbacks []OnFetchScriptComplete) ! {
	key := module_map_key(url, type_)
	if key in module_map.values_ {
		return error('ModuleMap already has an entry for ${url.serialize()} (${type_})')
	}
	module_map.values_[key] = ModuleMapEntry{
		type_: .fetching
		callbacks: callbacks.clone()
	}
}

pub fn (mut module_map ModuleMap) append_fetch_callback(url dom.URL, type_ string, callback OnFetchScriptComplete) ! {
	key := module_map_key(url, type_)
	mut entry := module_map.values_[key] or {
		return error('ModuleMap has no in-progress fetch for ${url.serialize()} (${type_})')
	}
	if entry.type_ != .fetching {
		return error('ModuleMap entry is not an in-progress fetch')
	}
	mut callbacks := entry.callbacks.clone()
	callbacks << callback
	module_map.values_[key] = ModuleMapEntry{
		type_: .fetching
		callbacks: callbacks
	}
}

pub fn (mut module_map ModuleMap) complete_fetch(url dom.URL, type_ string, module_script ?&ModuleScript) ! {
	key := module_map_key(url, type_)
	entry := module_map.values_[key] or {
		return error('ModuleMap has no in-progress fetch for ${url.serialize()} (${type_})')
	}
	if entry.type_ != .fetching {
		return error('ModuleMap entry is not an in-progress fetch')
	}
	callbacks := entry.callbacks.clone()
	module_map.values_.delete(key)
	if script := module_script {
		module_map.values_[key] = ModuleMapEntry{
			type_: .module_script
			module_script: script
		}
	}
	mut result := ?&Script(none)
	if script := module_script { result = &script.Script }
	module_map.invoke_fetch_callbacks(callbacks, result)
}

pub fn (mut module_map ModuleMap) remove(url dom.URL, type_ string) {
	key := module_map_key(url, type_)
	if entry := module_map.values_[key] {
		for callback in entry.callbacks { module_map.discard_owned_fetch_callback(callback) }
	}
	module_map.values_.delete(key)
}
