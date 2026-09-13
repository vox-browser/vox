// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioParamMap.{h,cpp,idl} and its read-only maplike glue.
module webaudio

pub struct AudioParamMapEntry {
pub:
	key   string
	value &AudioParam
}

@[heap]
pub struct AudioParamMap {
mut:
	keys_    []string
	entries_ map[string]&AudioParam
}

pub fn AudioParamMap.create() &AudioParamMap {
	return &AudioParamMap{}
}

pub fn (parameter_map &AudioParamMap) entries() []AudioParamMapEntry {
	mut result := []AudioParamMapEntry{cap: parameter_map.keys_.len}
	for key in parameter_map.keys_ {
		value := parameter_map.entries_[key] or { continue }
		result << AudioParamMapEntry{
			key: key
			value: value
		}
	}
	return result
}

pub fn (mut parameter_map AudioParamMap) set_entry(key string, value &AudioParam) {
	if key !in parameter_map.entries_ {
		parameter_map.keys_ << key
	}
	parameter_map.entries_[key] = value
}

pub fn (parameter_map &AudioParamMap) size() int {
	return parameter_map.keys_.len
}

pub fn (parameter_map &AudioParamMap) get(key string) ?&AudioParam {
	return parameter_map.entries_[key] or { return none }
}

pub fn (parameter_map &AudioParamMap) has(key string) bool {
	return key in parameter_map.entries_
}

pub fn (parameter_map &AudioParamMap) keys() []string {
	return parameter_map.keys_.clone()
}

pub fn (parameter_map &AudioParamMap) values() []&AudioParam {
	mut result := []&AudioParam{cap: parameter_map.keys_.len}
	for key in parameter_map.keys_ {
		result << parameter_map.entries_[key] or { continue }
	}
	return result
}

// These helpers mirror the generated read-only maplike binding hooks while
// retaining V-native values rather than manufacturing JavaScript wrappers.
pub fn map_entries(parameter_map &AudioParamMap) []AudioParamMapEntry {
	return parameter_map.entries()
}

pub fn map_get(parameter_map &AudioParamMap, key string) ?&AudioParam {
	return parameter_map.get(key)
}

pub fn map_has(parameter_map &AudioParamMap, key string) bool {
	return parameter_map.has(key)
}
