// Copyright (c) 2022-2023, networkException <networkexception@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/ModuleMap.{h,cpp}.
module html

import dom

pub enum ModuleMapEntryType {
	fetching
	failed
	module_script
}

pub struct ModuleMapEntry {
pub:
	type_         ModuleMapEntryType
	module_script ?&ModuleScript
}

pub type ModuleMapChangeCallback = fn (ModuleMapEntry)

@[heap]
pub struct ModuleMap {
mut:
	values_          map[string]ModuleMapEntry
	callbacks_       map[string][]ModuleMapChangeCallback
	firing_callbacks bool
}

pub fn ModuleMap.create() &ModuleMap {
	return &ModuleMap{
		values_:    map[string]ModuleMapEntry{}
		callbacks_: map[string][]ModuleMapChangeCallback{}
	}
}

fn module_map_key(url dom.URL, type_ string) string {
	return '${url.serialize()}\x00${type_}'
}

pub fn (module_map &ModuleMap) is_fetching(url dom.URL, type_ string) bool {
	return module_map.is_(url, type_, .fetching)
}

pub fn (module_map &ModuleMap) is_failed(url dom.URL, type_ string) bool {
	return module_map.is_(url, type_, .failed)
}

pub fn (module_map &ModuleMap) is_(url dom.URL, type_ string, entry_type ModuleMapEntryType) bool {
	entry := module_map.values_[module_map_key(url, type_)] or { return false }
	return entry.type_ == entry_type
}

pub fn (module_map &ModuleMap) get(url dom.URL, type_ string) ?ModuleMapEntry {
	return module_map.values_[module_map_key(url, type_)] or { return none }
}

pub fn (mut module_map ModuleMap) set(url dom.URL, type_ string, entry ModuleMapEntry) !bool {
	if module_map.firing_callbacks {
		return error('ModuleMap.set cannot be re-entered while firing callbacks')
	}
	key := module_map_key(url, type_)
	was_new := key !in module_map.values_
	module_map.values_[key] = entry
	callbacks := module_map.callbacks_[key].clone()
	if callbacks.len > 0 {
		module_map.firing_callbacks = true
		for callback in callbacks {
			callback(entry)
		}
		module_map.firing_callbacks = false
	}
	return was_new
}

pub fn (mut module_map ModuleMap) wait_for_change(url dom.URL, type_ string, callback ModuleMapChangeCallback) {
	key := module_map_key(url, type_)
	module_map.callbacks_[key] << callback
}
