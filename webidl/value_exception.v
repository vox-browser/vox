// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// The thrown JS::Value carried by WebIDL's JS::Completion boundary. This is
// a completion carrier, not a JavaScript Error object or a string conversion.
module webidl

pub struct ValueException {
pub:
	value Value
}

pub fn (exception ValueException) msg() string {
	if native := exception.value.simple_exception_ { return native.name() + ': ' + native.message }
	return 'WebIDL callback threw a value'
}
pub fn (exception ValueException) code() int { return 0 }

pub fn throw_value(value Value) IError { return ValueException{value} }

pub fn exception_value(exception IError) Value {
	if exception is ValueException { return exception.value }
	return string_value(exception.msg())
}
