// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/OverloadResolution.{h,cpp}.
module webidl

pub enum IDLTypeKind {
	any
	undefined
	boolean
	numeric
	bigint
	string_
	object
	interface_
	dictionary
	sequence
	callback
	array_buffer
	data_view
	typed_array
	buffer_source
}

pub struct IDLType {
pub:
	kind     IDLTypeKind
	name     string
	nullable bool
}

pub struct OverloadArgument {
pub:
	type_    IDLType
	optional bool
	variadic bool
}

pub struct EffectiveOverload {
pub:
	callable_id int
	arguments   []OverloadArgument
}

pub struct ResolvedOverload {
pub:
	callable_id int
	arguments   []?Value
}

pub fn resolve_overload(candidates []EffectiveOverload, arguments []Value) !ResolvedOverload {
	mut arity_matches := []EffectiveOverload{}
	for candidate in candidates {
		minimum := candidate.arguments.filter(!it.optional && !it.variadic).len
		has_variadic := candidate.arguments.any(it.variadic)
		if arguments.len < minimum {
			continue
		}
		if !has_variadic && arguments.len > candidate.arguments.len {
			continue
		}
		arity_matches << candidate
	}
	if arity_matches.len == 0 {
		return error('TypeError: no overload matches the supplied argument count')
	}
	mut type_matches := []EffectiveOverload{}
	mut best_score := 1_000_000
	for candidate in arity_matches {
		if score := overload_match_score(candidate, arguments) {
			if score < best_score {
				best_score = score
				type_matches = [candidate]
			} else if score == best_score {
				type_matches << candidate
			}
		}
	}
	if type_matches.len != 1 {
		return error('TypeError: ${if type_matches.len == 0 { 'no' } else { 'multiple' }} overloads match the supplied values')
	}
	chosen := type_matches[0]
	mut resolved := []?Value{}
	for index, argument in chosen.arguments {
		if index < arguments.len {
			resolved << arguments[index]
		} else if argument.variadic {
			break
		} else {
			resolved << none
		}
	}
	if chosen.arguments.len > 0 && chosen.arguments.last().variadic {
		for index in chosen.arguments.len .. arguments.len {
			resolved << arguments[index]
		}
	}
	return ResolvedOverload{
		callable_id: chosen.callable_id
		arguments:   resolved
	}
}

fn overload_match_score(candidate EffectiveOverload, values []Value) ?int {
	mut total := 0
	for index, value in values {
		argument := if index < candidate.arguments.len {
			candidate.arguments[index]
		} else if candidate.arguments.len > 0 && candidate.arguments.last().variadic {
			candidate.arguments.last()
		} else {
			return none
		}
		score := value_type_match_score(value, argument.type_) or { return none }
		total += score
	}
	return total
}

// Lower scores follow the distinguishing-argument precedence in
// WebIDL/OverloadResolution.cpp. Conversion fallbacks rank after exact matches.
fn value_type_match_score(value Value, type_ IDLType) ?int {
	if value.kind == .null_ && type_.nullable {
		return 0
	}
	if value.kind in [.null_, .undefined] && type_.kind == .dictionary {
		return 1
	}
	if value_matches_type(value, type_) {
		return match type_.kind {
			.any { 100 }
			.object { 20 }
			else { 0 }
		}
	}
	return match type_.kind {
		.string_ {
			60
		}
		.numeric {
			70
		}
		.boolean {
			80
		}
		.bigint {
			if value.kind == .bigint {
				0
			} else {
				90
			}
		}
		.any {
			100
		}
		else {
			none
		}
	}
}

pub fn value_matches_type(value Value, type_ IDLType) bool {
	if value.kind == .null_ && type_.nullable {
		return true
	}
	return match type_.kind {
		.any {
			true
		}
		.undefined {
			value.kind == .undefined
		}
		.boolean {
			value.kind == .boolean
		}
		.numeric {
			value.kind == .number
		}
		.bigint {
			value.kind == .bigint
		}
		.string_ {
			value.kind == .string_
		}
		.object {
			value.kind in [.object, .sequence, .buffer_source, .callback, .platform_object]
		}
		.interface_ {
			value.kind == .platform_object
		}
		.dictionary {
			value.kind in [.object, .undefined, .null_]
		}
		.sequence {
			value.kind == .sequence
		}
		.callback {
			value.kind == .callback
		}
		.array_buffer {
			value.kind == .buffer_source
				&& (value.buffer_value or { return false }).kind == .array_buffer
		}
		.data_view {
			value.kind == .buffer_source
				&& (value.buffer_value or { return false }).kind == .data_view
		}
		.typed_array {
			value.kind == .buffer_source
				&& (value.buffer_value or { return false }).is_typed_array()
		}
		.buffer_source {
			value.kind == .buffer_source
		}
	}
}
