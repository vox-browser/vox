// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebDriver/Error.{h,cpp}, Response.{h,cpp}, and Properties.h.
module webdriver

import x.json2

pub fn json_value_from_text(input string) json2.Any {
	return json2.decode[json2.Any](input) or { panic(err) }
}

pub enum ErrorCode {
	element_click_intercepted
	element_not_interactable
	insecure_certificate
	invalid_argument
	invalid_cookie_domain
	invalid_element_state
	invalid_selector
	invalid_session_id
	javascript_error
	move_target_out_of_bounds
	no_such_alert
	no_such_cookie
	no_such_element
	no_such_frame
	no_such_window
	no_such_shadow_root
	script_timeout
	session_not_created
	stale_element_reference
	detached_shadow_root
	timeout
	unable_to_set_cookie
	unable_to_capture_screen
	unexpected_alert_open
	unknown_command
	unknown_error
	unknown_method
	unsupported_operation
	out_of_memory
}

pub struct ErrorCodeData {
pub:
	error_code      ErrorCode
	http_status     u32
	json_error_code string
}

// https://w3c.github.io/webdriver/#dfn-error-code
pub fn error_code_data() []ErrorCodeData {
	statuses := [u32(400), 400, 400, 400, 400, 400, 400, 404, 500, 500, 404, 404, 404, 404, 404,
		404, 500, 500, 404, 404, 500, 500, 500, 500, 404, 500, 405, 500, 500]
	names := ['element click intercepted', 'element not interactable', 'insecure certificate',
		'invalid argument', 'invalid cookie domain', 'invalid element state', 'invalid selector',
		'invalid session id', 'javascript error', 'move target out of bounds', 'no such alert',
		'no such cookie', 'no such element', 'no such frame', 'no such window', 'no such shadow root',
		'script timeout', 'session not created', 'stale element reference', 'detached shadow root',
		'timeout', 'unable to set cookie', 'unable to capture screen', 'unexpected alert open',
		'unknown command', 'unknown error', 'unknown method', 'unsupported operation',
		'out of memory']
	mut data := []ErrorCodeData{cap: names.len}
	for index, name in names {
		data << ErrorCodeData{
			error_code:      unsafe { ErrorCode(index) }
			http_status:     statuses[index]
			json_error_code: name
		}
	}
	return data
}

pub struct WebDriverError {
pub:
	http_status u32
	code        string
	message     string
	data        ?json2.Any
}

pub fn WebDriverError.from_code(code ErrorCode, message string) WebDriverError {
	return WebDriverError.from_code_with_data(code, message, none)
}

pub fn WebDriverError.from_code_with_data(code ErrorCode, message string, data ?json2.Any) WebDriverError {
	code_data := error_code_data()[int(code)]
	return WebDriverError{
		http_status: code_data.http_status
		code:        code_data.json_error_code
		message:     message
		data:        data
	}
}

pub fn (e WebDriverError) msg() string {
	return '${e.code}: ${e.message}'
}

pub struct Response {
pub:
	value ?json2.Any
	err   ?WebDriverError
}

pub fn success(value json2.Any) Response {
	return Response{
		value: value
	}
}

pub fn failure(code ErrorCode, message string) Response {
	return Response{
		err: WebDriverError.from_code(code, message)
	}
}

pub fn (response Response) is_error() bool {
	return response.err != none
}

pub fn require_object(value json2.Any, property string) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property '${property}' must be an object").msg())
	}
	return value as map[string]json2.Any
}

pub fn string_property(object map[string]json2.Any, key string) !string {
	value := object[key] or {
		return error(WebDriverError.from_code(.invalid_argument, "Missing property '${key}'").msg())
	}
	if value !is string {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property '${key}' must be a string").msg())
	}
	return value as string
}

pub fn optional_string_property(object map[string]json2.Any, key string) ?string {
	value := object[key] or { return none }
	if value is json2.Null {
		return none
	}
	if value !is string {
		return none
	}
	return value as string
}

pub fn integer_property_in_range(object map[string]json2.Any, key string, min i64, max i64) !i64 {
	value := object[key] or {
		return error(WebDriverError.from_code(.invalid_argument, "Missing property '${key}'").msg())
	}
	mut number := i64(0)
	if value is i64 {
		number = value
	} else if value is f64 && (value as f64) == f64(i64(value as f64)) {
		number = i64(value as f64)
	} else {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property '${key}' must be an integer").msg())
	}
	if number < min || number > max {
		return error(WebDriverError.from_code(.invalid_argument,
			"Property '${key}' is outside the allowed range").msg())
	}
	return number
}
