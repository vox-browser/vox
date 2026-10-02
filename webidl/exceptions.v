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

@[heap]
pub struct DOMException {
mut:
	name_    string = 'Error'
	message_ string
}

pub fn DOMException.create(name string, message string) DOMException {
	return DOMException{
		name_:    name
		message_: message
	}
}

pub fn DOMException.create_record(name string, message string) &DOMException {
	return &DOMException{ name_: name, message_: message }
}

// The JS constructor intentionally takes message before name.
pub fn DOMException.construct(message string, name string) DOMException {
	return DOMException{
		name_:    name
		message_: message
	}
}

pub fn DOMException.construct_impl(message string, name string) DOMException {
	return DOMException.construct(message, name)
}

pub fn DOMException.create_for_constructor(message string, name string) DOMException {
	return DOMException.create(name, message)
}

pub fn (exception DOMException) name() string {
	return exception.name_
}

pub fn (exception DOMException) message() string {
	return exception.message_
}

pub fn (exception DOMException) code() u16 {
	return get_legacy_code_for_name(exception.name_)
}

pub fn (exception DOMException) serialize() []string {
	return exception.serialization_steps()
}

pub fn (exception DOMException) serialization_steps() []string {
	return [exception.name_, exception.message_]
}

pub fn DOMException.deserialize(fields []string) !DOMException {
	if fields.len != 2 {
		return error('DataCloneError: invalid DOMException serialization')
	}
	mut exception := DOMException{}
	exception.deserialization_steps(fields)!
	return exception
}

pub fn (mut exception DOMException) deserialization_steps(fields []string) ! {
	if fields.len != 2 {
		return error('DataCloneError: invalid DOMException serialization')
	}
	exception.name_ = fields[0]
	exception.message_ = fields[1]
}

pub fn (exception DOMException) str() string {
	return '[${exception.name_}]: ${exception.message_}'
}

// A DOMException is a Web IDL platform object when used as a JavaScript value.
// Keep its observable properties on the typed value so promise rejection
// reasons retain the exception instead of degrading to a message string.
pub fn dom_exception_value(exception DOMException) Value {
	native := &DOMException{ name_: exception.name(), message_: exception.message() }
	return dom_exception_value_for_record(native)
}

pub fn dom_exception_value_for_record(exception &DOMException) Value {
	return Value{
		kind: .platform_object
		dom_exception_: exception
		opaque_id: u64(voidptr(exception))
		platform_interfaces: ['DOMException']
		object_value: {
			'name':    string_value(exception.name())
			'message': string_value(exception.message())
			'code':    number_value(exception.code())
		}
	}
}

pub struct DOMExceptionReportDetails {
pub:
	name    string
	message string
}

pub fn dom_exception_from_object(object Value) ?DOMException {
	if native := object.dom_exception_ { return *native }
	if object.kind != .platform_object || 'DOMException' !in object.platform_interfaces {
		return none
	}
	name := object.object_value['name'] or { return none }
	message := object.object_value['message'] or { return none }
	if name.kind != .string_ || message.kind != .string_ {
		return none
	}
	return DOMException.create(name.string_value, message.string_value)
}

pub fn dom_exception_report_details(object Value) ?DOMExceptionReportDetails {
	exception := dom_exception_from_object(object) or { return none }
	return DOMExceptionReportDetails{
		name: exception.name()
		message: exception.message()
	}
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

pub fn get_legacy_code_for_name(name string) u16 {
	return legacy_code_for_name(name)
}

pub fn throw_completion(exception DOMException) ! {
	return error(exception.str())
}

pub struct QuotaExceededErrorOptions {
pub:
	quota     ?f64
	requested ?f64
}

pub struct QuotaExceededError {
pub mut:
	base DOMException
mut:
	quota_     ?f64
	requested_ ?f64
}

pub fn QuotaExceededError.create(message string) QuotaExceededError {
	return QuotaExceededError{
		base: DOMException.create('QuotaExceededError', message)
	}
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
		quota_:     options.quota
		requested_: options.requested
	}
}

pub fn QuotaExceededError.construct_impl(message string, options QuotaExceededErrorOptions) !QuotaExceededError {
	return QuotaExceededError.construct(message, options)
}

pub fn (exception QuotaExceededError) quota() ?f64 {
	return exception.quota_
}

pub fn (exception QuotaExceededError) requested() ?f64 {
	return exception.requested_
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
		name:      exception.base.name()
		message:   exception.base.message()
		quota:     exception.quota_
		requested: exception.requested_
	}
}

pub fn (exception QuotaExceededError) serialization_steps() SerializedQuotaExceededError {
	return exception.serialize()
}

pub fn QuotaExceededError.deserialize(value SerializedQuotaExceededError) QuotaExceededError {
	return QuotaExceededError{
		base:      DOMException.create(value.name, value.message)
		quota_:     value.quota
		requested_: value.requested
	}
}

pub fn (mut exception QuotaExceededError) deserialization_steps(value SerializedQuotaExceededError) {
	exception.base = DOMException.create(value.name, value.message)
	exception.quota_ = value.quota
	exception.requested_ = value.requested
}
