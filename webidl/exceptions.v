// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebIDL/DOMException, ExceptionOr and QuotaExceededError.
module webidl

pub enum SimpleExceptionType {
	eval_error
	range_error
	reference_error
	type_error
	uri_error
}

pub struct SimpleException {
pub:
	type_   SimpleExceptionType
	message string
}

pub struct DOMException {
pub:
	name    string = 'Error'
	message string
}

pub fn DOMException.create(name string, message string) DOMException {
	return DOMException{
		name:    name
		message: message
	}
}

// The JS constructor intentionally takes message before name.
pub fn DOMException.construct(message string, name string) DOMException {
	return DOMException{
		name:    name
		message: message
	}
}

pub fn (exception DOMException) code() u16 {
	return legacy_code_for_name(exception.name)
}

pub fn (exception DOMException) serialize() []string {
	return [exception.name, exception.message]
}

pub fn DOMException.deserialize(fields []string) !DOMException {
	if fields.len != 2 {
		return error('DataCloneError: invalid DOMException serialization')
	}
	return DOMException{
		name:    fields[0]
		message: fields[1]
	}
}

pub fn (exception DOMException) str() string {
	return '[${exception.name}]: ${exception.message}'
}

pub fn legacy_code_for_name(name string) u16 {
	return match name {
		'IndexSizeError' { 1 }
		'HierarchyRequestError' { 3 }
		'WrongDocumentError' { 4 }
		'InvalidCharacterError' { 5 }
		'NoModificationAllowedError' { 7 }
		'NotFoundError' { 8 }
		'NotSupportedError' { 9 }
		'InUseAttributeError' { 10 }
		'InvalidStateError' { 11 }
		'SyntaxError' { 12 }
		'InvalidModificationError' { 13 }
		'NamespaceError' { 14 }
		'InvalidAccessError' { 15 }
		'TypeMismatchError' { 17 }
		'SecurityError' { 18 }
		'NetworkError' { 19 }
		'AbortError' { 20 }
		'URLMismatchError' { 21 }
		'QuotaExceededError' { 22 }
		'TimeoutError' { 23 }
		'InvalidNodeTypeError' { 24 }
		'DataCloneError' { 25 }
		else { 0 }
	}
}

pub struct QuotaExceededErrorOptions {
pub:
	quota     ?f64
	requested ?f64
}

pub struct QuotaExceededError {
pub:
	base      DOMException
	quota     ?f64
	requested ?f64
}

pub fn QuotaExceededError.construct(message string, options QuotaExceededErrorOptions) !QuotaExceededError {
	if quota := options.quota {
		if quota < 0 {
			return error('RangeError: Quota cannot be less than 0')
		}
	}
	if requested := options.requested {
		if requested < 0 {
			return error('RangeError: Requested cannot be less than 0')
		}
		if quota := options.quota {
			if requested < quota {
				return error('RangeError: Requested cannot be less than quota')
			}
		}
	}
	return QuotaExceededError{
		base:      DOMException.create('QuotaExceededError', message)
		quota:     options.quota
		requested: options.requested
	}
}

pub struct SerializedQuotaExceededError {
pub:
	name      string
	message   string
	quota     ?f64
	requested ?f64
}

pub fn (exception QuotaExceededError) serialize() SerializedQuotaExceededError {
	return SerializedQuotaExceededError{
		name:      exception.base.name
		message:   exception.base.message
		quota:     exception.quota
		requested: exception.requested
	}
}

pub fn QuotaExceededError.deserialize(value SerializedQuotaExceededError) QuotaExceededError {
	return QuotaExceededError{
		base:      DOMException.create(value.name, value.message)
		quota:     value.quota
		requested: value.requested
	}
}
