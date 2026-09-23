// Copyright (c) 2022-2023, networkException <networkexception@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/ModuleMap.{h,cpp}.
module html

import dom

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
pub struct ModuleMap {
mut:
	values_ map[string]ModuleMapEntry
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
	for callback in callbacks {
		if script := module_script {
			callback(&script.Script)
		} else {
			callback(none)
		}
	}
}

pub fn (mut module_map ModuleMap) remove(url dom.URL, type_ string) {
	module_map.values_.delete(module_map_key(url, type_))
}
