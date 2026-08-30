// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/Tracing.{h,cpp}.
module webidl

pub struct TraceState {
pub mut:
	enabled bool
	lines   []string
}

pub fn (mut state TraceState) set_enable_idl_tracing(enabled bool) {
	state.enabled = enabled
}

pub fn (mut state TraceState) log_trace(function string, arguments []Value) {
	if !state.enabled {
		return
	}
	mut formatted := []string{cap: arguments.len}
	for argument in arguments {
		mut text := trace_value(argument)
		if argument.kind == .string_ {
			text = '"${text}"'
		}
		formatted << escape_control_characters(text)
	}
	state.lines << '${function}(${formatted.join(', ')})'
}

fn trace_value(value Value) string {
	return to_string(value) or {
		return match value.kind {
			.object { '[object Object]' }
			.sequence { '[object Array]' }
			.buffer_source { '[object BufferSource]' }
			.callback { '[object Function]' }
			.platform_object { '[object PlatformObject]' }
			else { '' }
		}
	}
}

pub fn (mut state TraceState) log_trace_impl(function string, arguments []Value) {
	state.log_trace(function, arguments)
}

fn escape_control_characters(value string) string {
	mut output := ''
	for character in value.runes() {
		if character < 0x20 {
			output += '\\u${u32(character):04x}'
		} else {
			output += character.str()
		}
	}
	return output
}
