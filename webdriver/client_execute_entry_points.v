// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// HTTP client and script-completion entry points. Socket I/O and JavaScript
// evaluation remain injected host boundaries; parsing, routing, response
// framing, completion state, and timeout behavior are concrete here.
module webdriver

import x.json2

pub struct ClientResponse {
pub:
	status u32
	body   json2.Any
	raw    string
}

@[heap]
pub struct Client {
pub mut:
	alive             bool = true
	remaining_request string
	responses         []ClientResponse
	response_log      []string
}

pub fn Client.new() &Client {
	return &Client{}
}

pub fn (mut client Client) die() {
	client.alive = false
}

fn http_method_from_string(value string) ?HttpMethod {
	return match value.to_upper() {
		'GET' { .get }
		'POST' { .post }
		'DELETE' { .delete }
		else { none }
	}
}

pub fn (client &Client) read_body_as_json(body string) !json2.Any {
	if body == '' {
		return json2.null
	}
	return json2.decode[json2.Any](body)
}

pub fn (mut client Client) on_ready_to_read(data string) ! {
	if !client.alive {
		return error('WebDriver client is closed')
	}
	client.remaining_request += data
	header_end := client.remaining_request.index('\r\n\r\n') or { return }
	header_text := client.remaining_request[..header_end]
	lines := header_text.split('\r\n')
	if lines.len == 0 {
		return error('HTTP request is empty')
	}
	request_parts := lines[0].split(' ')
	if request_parts.len < 2 {
		return error('HTTP request line is invalid')
	}
	mut content_length := 0
	for line in lines[1..] {
		separator := line.index(':') or { continue }
		if line[..separator].trim_space().to_lower() == 'content-length' {
			content_length = line[separator + 1..].trim_space().int()
		}
	}
	body_start := header_end + 4
	if client.remaining_request.len < body_start + content_length {
		return
	}
	body_text := client.remaining_request[body_start..body_start + content_length]
	client.remaining_request = client.remaining_request[body_start + content_length..].clone()
	method := http_method_from_string(request_parts[0]) or {
		error_ := WebDriverError.from_code(.unknown_method, 'The HTTP method is unsupported')
		client.handle_error(request_parts[0], request_parts[1], error_)
		return
	}
	body := client.read_body_as_json(body_text) or {
		error_ := WebDriverError.from_code(.invalid_argument, err.msg())
		client.handle_error(request_parts[0], request_parts[1], error_)
		return
	}
	client.handle_request(method, request_parts[1], body) or {
		error_ := WebDriverError.from_code(.unknown_error, err.msg())
		client.handle_error(request_parts[0], request_parts[1], error_)
		return
	}
}

pub fn (mut client Client) handle_request(method HttpMethod, path string, body json2.Any) ! {
	route := match_route(method, path)!
	mut default_result := map[string]json2.Any{}
	default_result['command'] = route.command
	mut parameters := []json2.Any{}
	for parameter in route.parameters {
		parameters << parameter
	}
	default_result['parameters'] = parameters
	client.finish_request(method, path, success(json2.Any(default_result)))
}

// handle_request_with is the host-command boundary corresponding to the
// browser-process IPC callback used by Ladybird's Client::handle_request.
pub fn (mut client Client) handle_request_with(method HttpMethod, path string, body json2.Any,
	handler fn (route MatchedRoute, body json2.Any) Response) ! {
	route := match_route(method, path)!
	client.finish_request(method, path, handler(route, body))
}

fn (mut client Client) finish_request(method HttpMethod, path string, response Response) {
	if error_ := response.err {
		client.send_error_response(method, path, error_)
		return
	}
	client.send_success_response(method, path, response.value or { json2.null })
}

pub fn (mut client Client) handle_error(method string, path string, error_ WebDriverError) {
	parsed_method := http_method_from_string(method) or { HttpMethod.post }
	client.send_error_response(parsed_method, path, error_)
	client.die()
}

fn http_response_text(status u32, body json2.Any) string {
	content := body.json_str()
	reason := match status {
		200 { 'OK' }
		400 { 'Bad Request' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		else { 'Internal Server Error' }
	}
	return 'HTTP/1.1 ${status} ${reason}\r\nCache-Control: no-cache\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: ${content.len}\r\n\r\n${content}'
}

pub fn (mut client Client) send_success_response(method HttpMethod, path string, result json2.Any) {
	body := json2.Any(make_success_response(result))
	client.responses << ClientResponse{
		status: 200
		body:   body
		raw:    http_response_text(200, body)
	}
	client.log_response(method, path, 200)
}

pub fn (mut client Client) send_error_response(method HttpMethod, path string, error_ WebDriverError) {
	mut detail := map[string]json2.Any{}
	detail['error'] = error_.code
	detail['message'] = error_.message
	detail['stacktrace'] = ''
	if data := error_.data {
		detail['data'] = data
	}
	body := json2.Any({
		'value': json2.Any(detail)
	})
	client.responses << ClientResponse{
		status: error_.http_status
		body:   body
		raw:    http_response_text(error_.http_status, body)
	}
	client.log_response(method, path, error_.http_status)
}

pub fn (mut client Client) log_response(method HttpMethod, path string, code u32) {
	client.response_log << '${code:03} :: ${method.str().to_upper()} ${path}'
}

pub fn promise_call(result ExecutionResult) ExecutionResult {
	return result
}

pub fn execute_a_function_body(body string, arguments []json2.Any, executor ScriptExecutor) ExecutionResult {
	return execute_script(body, arguments, executor)
}

pub fn fire_completion_when_resolved(result ExecutionResult, mut timer HeapTimer) ExecutionResult {
	if timer.is_timed_out() {
		return ExecutionResult{state: .pending}
	}
	timer.stop()
	return result
}
