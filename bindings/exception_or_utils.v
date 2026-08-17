// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/ExceptionOrUtils.h. V's result type already carries
// both WebIDL exceptions and host-language failures, so the C++ conversion
// templates reduce to a checked invocation boundary.
module bindings

pub fn exception_to_throw_completion(exception IError) IError {
	return exception
}

pub fn throw_dom_exception_if_needed[T](operation fn () !T) !T {
	return operation()
}
