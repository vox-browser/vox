// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/ExceptionOrUtils.h. V's result type already carries
// both WebIDL exceptions and host-language failures, so the C++ conversion
// templates reduce to a checked invocation boundary.
module bindings

// V strings retain Unicode scalar values directly, so both of upstream's
// UTF-8/UTF-16 attribute conversion overloads reduce to this identity copy.
pub fn attribute_value_to_utf16(value string) string {
	return value
}

pub fn exception_to_throw_completion(exception IError) IError {
	return exception
}

pub fn throw_dom_exception_if_needed[T](operation fn () !T) !T {
	return operation()
}
