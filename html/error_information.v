// Copyright (c) 2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/ErrorInformation.{h,cpp}.
module html

import dom
import webidl

// https://html.spec.whatwg.org/multipage/webappapis.html#extract-error
pub struct ErrorInformation {
pub:
	message  string
	filename string
	error    dom.JSValue
	lineno   uint
	colno    uint
}

// The translated DOM currently represents JavaScript values without a VM or
// executable stack. This record carries precisely the VM-derived information
// consumed by extract_error_information, keeping the extraction algorithm
// independent from the eventual JavaScript runtime implementation.
pub struct ErrorSourceLocation {
pub:
	filename string
	line     uint
	column   uint
}

pub struct ErrorExtractionContext {
pub:
	// The exception object's own `message` property, when it can be read without
	// side effects. `none` follows the C++ fallback formatting path.
	own_message ?string
	// JS::Error uses its traceback; other exceptions use the most recent
	// executable execution context.
	exception_is_error bool
	traceback          []ErrorSourceLocation
	execution_stack    []ErrorSourceLocation
}

fn first_nonempty_error_location(locations []ErrorSourceLocation) ?ErrorSourceLocation {
	for location in locations {
		if location.line != 0 || location.column != 0 {
			return location
		}
	}
	return none
}

fn error_message_prefixed_with_name(name string, message string) string {
	if message == '' { return name }
	if name == '' { return message }
	return '${name}: ${message}'
}

fn exception_report_message(exception dom.JSValue, context ErrorExtractionContext) string {
	// A DOMException's name and message are prototype accessors, so an own
	// message lookup misses them. Read the retained native exception instead.
	if native := exception.native_value_ {
		if details := webidl.dom_exception_report_details(native) {
			return error_message_prefixed_with_name(details.name, details.message)
		}
	}
	return context.own_message or { 'Uncaught exception: ${exception.to_string_value()}' }
}

// https://html.spec.whatwg.org/multipage/webappapis.html#extract-error
pub fn extract_error_information(exception dom.JSValue, context ErrorExtractionContext) ErrorInformation {
	message := exception_report_message(exception, context)
	mut filename := ''
	mut lineno := uint(0)
	mut colno := uint(0)

	if context.exception_is_error {
		if location := first_nonempty_error_location(context.traceback) {
			filename = location.filename
			lineno = location.line
			colno = location.column
		}
	} else {
		// The VM execution-context stack is ordered oldest-to-newest. Search it
		// backwards, matching ErrorInformation.cpp.
		for index := context.execution_stack.len - 1; index >= 0; index-- {
			location := context.execution_stack[index]
			if location.line != 0 || location.column != 0 {
				filename = location.filename
				lineno = location.line
				colno = location.column
				break
			}
		}
	}

	return ErrorInformation{
		message:  message
		filename: filename
		error:    exception
		lineno:   lineno
		colno:    colno
	}
}
