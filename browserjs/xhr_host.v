// XMLHttpRequest.idl native binding. The owning XHR/Fetch/DOM records perform
// validation, state transitions, transport, timers and event dispatch.
module browserjs

import css
import dom
import fetch
import html
import requestserver
import xhr
import x.json2

@[heap]
struct XHRHostRecord {
mut:
	request &xhr.XMLHttpRequest
	listeners map[int]&dom.IDLEventListener
}

@[heap]
pub struct XMLHttpRequestHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
	fetch_host &fetch.FetchHost
mut:
	requests map[int]&XHRHostRecord
	events map[string]&dom.Event
	documents map[string]&dom.Document
	elements map[string]&dom.Element
	connection ?&requestserver.CurlConnection
	next_id int
	closed bool
}

pub fn XMLHttpRequestHost.create(document &dom.Document, fetch_host &fetch.FetchHost) !&XMLHttpRequestHost {
	mut settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings_pointer = document.relevant_settings_object()
	}
	return &XMLHttpRequestHost{
		document: document
		settings: unsafe { &html.EnvironmentSettingsObject(settings_pointer) }
		fetch_host: fetch_host
	}
}

pub fn XMLHttpRequestHost.create_native(document &dom.Document) !&XMLHttpRequestHost {
	mut connection := requestserver.CurlConnection.create()!
	mut host := XMLHttpRequestHost.create(document, connection.fetch_host()) or { connection.close(); return err }
	host.connection = connection
	return host
}

pub fn (mut host XMLHttpRequestHost) install(mut runtime Runtime) ! {
	runtime.define_host_function('__ladybirdXHR', fn [mut host, mut runtime] (input string) !string {
		return host.call(input, runtime)
	})!
	$if darwin || linux { host.install_native_blob_transport(mut runtime)! }
	runtime.add_close_handler(fn [mut host] () { host.close() })
}

pub fn (mut host XMLHttpRequestHost) close() {
	if host.closed { return }
	host.closed = true
	for _, mut record in host.requests {
		record.request.stop_timeout_timer()
		record.request.fetch_controller_.stop_fetch()
		xhr.XMLHttpRequest.release_activity_roots_for_relevant_global_object(record.request.relevant_global_object())
	}
	if mut connection := host.connection { connection.close() }
	host.requests = {}
	host.events = {}
	host.documents = {}
	host.elements = {}
}

fn xhr_host_optional_string(value json2.Any) ?string {
	if value is string { return value }
	return none
}

fn (mut host XMLHttpRequestHost) native_callback(runtime &Runtime, key int, upload bool, token int) &dom.CallbackType {
	return &dom.CallbackType{ handle_event: fn [mut host, runtime, key, upload, token] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
		if host.closed { return dom.js_undefined() }
		event_key := '${usize(voidptr(event))}'
		host.events[event_key] = event
		mut payload := {
			'key': json2.Any(event_key)
			'type': json2.Any(event.type_)
			'isTrusted': json2.Any(event.is_trusted())
			'timeStamp': json2.Any(event.time_stamp())
			'bubbles': json2.Any(event.bubbles())
			'cancelable': json2.Any(event.cancelable())
			'composed': json2.Any(event.composed())
		}
		if event.interface_ == .progress_event {
			progress := unsafe { &xhr.ProgressEvent(event) }
			payload['lengthComputable'] = json2.Any(progress.length_computable())
			payload['loaded'] = json2.Any(progress.loaded())
			payload['total'] = json2.Any(progress.total())
		}
		result := runtime.evaluate_host('__ladybirdXHRInvoke(${key}, ${upload}, ${token}, ${json2.encode(payload)})') or {
			host.settings.report_an_exception(dom.js_string(err.msg()), false)
			'false'
		}
		mut mutable_runtime := unsafe { &Runtime(runtime) }
		mutable_runtime.mark_document_state_dirty()
		return if result == 'false' { dom.js_bool(false) } else { dom.js_undefined() }
	} }
}

fn (mut host XMLHttpRequestHost) bind_listener(record &XHRHostRecord, runtime &Runtime, key int, upload bool, object map[string]json2.Any) ! {
	token := int(canvas_host_number(object['token'] or { json2.Any(0) }))
	name := canvas_host_string(object['name'] or { json2.Any('') })
	action := canvas_host_string(object['action'] or { json2.Any('') })
	target := if upload { record.request.upload().as_event_target() } else { record.request.as_event_target() }
	mut mutable_record := unsafe { &XHRHostRecord(record) }
	if action == 'handler' {
		mut callback := ?&dom.CallbackType(none)
		if token != 0 { callback = host.native_callback(runtime, key, upload, token) }
		target.set_event_handler_attribute(name, callback)
		return
	}
	listener := mutable_record.listeners[token] or {
		created := dom.IDLEventListener.create(host.native_callback(runtime, key, upload, token))
		mutable_record.listeners[token] = created
		created
	}
	capture := canvas_host_bool(object['capture'] or { json2.Any(false) })
	if action == 'remove' {
		target.remove_event_listener(name, listener, dom.EventListenerOptions{ capture: capture })
	} else {
		target.add_event_listener(name, listener, dom.AddEventListenerOptions{
			capture: capture
			once: canvas_host_bool(object['once'] or { json2.Any(false) })
			passive: if value := object['passive'] { if value is bool { ?bool(value) } else { none } } else { none }
		})
	}
}

fn (mut host XMLHttpRequestHost) document_value(document ?&dom.Document) json2.Any {
	value := document or { return json2.Null{} }
	key := '${value.unique_id()}'
	host.documents[key] = value
	return json2.Any({ 'kind': json2.Any('document'), 'key': json2.Any(key) })
}

fn (mut host XMLHttpRequestHost) element_value(element ?&dom.Element) json2.Any {
	value := element or { return json2.Null{} }
	key := '${value.unique_id()}'
	host.elements[key] = value
	return json2.Any({ 'kind': json2.Any('element'), 'key': json2.Any(key) })
}

fn (mut host XMLHttpRequestHost) response_value(mut request xhr.XMLHttpRequest) json2.Any {
	response := request.response()
	match response.type_ {
		.empty, .text { return json2.Any(response.text) }
		.json { return if value := response.json_text { json2.decode[json2.Any](value) or { json2.Null{} } } else { json2.Null{} } }
		.arraybuffer { return if request.state == .done { json2.Any({ 'kind': json2.Any('arraybuffer'), 'bytes': json2.Any(response.bytes.map(json2.Any(int(it)))) }) } else { json2.Null{} } }
		.blob {
			return if response.blob != none { json2.Any({ 'kind': json2.Any('blob') }) } else { json2.Null{} }
		}
		.document { return host.document_value(response.document) }
	}
}

fn (mut host XMLHttpRequestHost) call(input string, runtime &Runtime) !string {
	if host.closed { return error('InvalidStateError: XMLHttpRequest global has closed') }
	object := canvas_host_object(json2.decode[json2.Any](input)!)!
	method := canvas_host_string(object['method'] or { json2.Any('') })
	args := canvas_host_args(object)
	if method == 'create' {
		host.next_id++
		host.requests[host.next_id] = &XHRHostRecord{ request: xhr.XMLHttpRequest.construct_in_settings(host.settings, host.fetch_host) }
		return json2.encode(host.next_id)
	}
	if method == 'event' {
		event := host.events[canvas_host_string(object['event'] or { json2.Any('') })] or { return error('InvalidStateError: unknown native event') }
		mut mutable_event := unsafe { &dom.Event(event) }
		match canvas_host_string(object['action'] or { json2.Any('') }) {
			'preventDefault' { mutable_event.prevent_default() }
			'stopPropagation' { mutable_event.stop_propagation() }
			'stopImmediatePropagation' { mutable_event.stop_immediate_propagation() }
			else { return json2.encode(event.default_prevented()) }
		}
		return 'null'
	}
	if method == 'document' || method == 'element' {
		key := canvas_host_string(object['key'] or { json2.Any('') })
		action := canvas_host_string(object['action'] or { json2.Any('') })
		mut result := json2.Any(json2.Null{})
		mut node := unsafe { &dom.Node(nil) }
		if method == 'document' {
			document := host.documents[key] or { return error('InvalidStateError: unknown response document') }
			node = unsafe { &dom.Node(document) }
			match action {
				'URL' { result = json2.Any(document.url.serialize()) }
				'title' { result = json2.Any(document.title()) }
				'contentType' { result = json2.Any(document.get_content_type()) }
				'documentElement' { result = host.element_value(document.document_element()) }
				'getElementById' { result = host.element_value(document.get_element_by_id(canvas_host_string(args[0]))) }
				else {}
			}
		} else {
			element := host.elements[key] or { return error('InvalidStateError: unknown response element') }
			node = unsafe { &dom.Node(element) }
			if action == 'tagName' { result = json2.Any(element.tag_name()) }
			if action == 'getAttribute' { result = if value := element.get_attribute(canvas_host_string(args[0])) { json2.Any(value) } else { json2.Null{} } }
		}
		if action == 'textContent' { result = if value := node.text_content() { json2.Any(value) } else { json2.Null{} } }
		if action == 'querySelector' { result = host.element_value(css.query_selector(node, canvas_host_string(args[0]))) }
		if action == 'querySelectorAll' { result = json2.Any(css.query_selector_all(node, canvas_host_string(args[0])).map(host.element_value(it))) }
		return json2.encode(result)
	}
	key := int(canvas_host_number(object['key'] or { json2.Any(0) }))
	record := host.requests[key] or { return error('InvalidStateError: unknown XMLHttpRequest') }
	mut request := record.request
	upload := canvas_host_bool(object['upload'] or { json2.Any(false) })
	mut result := json2.Any(json2.Null{})
	match method {
		'listen' { host.bind_listener(record, runtime, key, upload, object)! }
		'open' { request.open(canvas_host_string(args[0]), canvas_host_string(args[1]), canvas_host_bool(args[2]), xhr_host_optional_string(args[3]), xhr_host_optional_string(args[4]))! }
		'setRequestHeader' { request.set_request_header(canvas_host_string(args[0]), canvas_host_string(args[1]))! }
		'send' {
			if document_input := object['document'] {
				document_key := canvas_host_string(document_input)
				document := if document_key == 'owner' { host.document } else { host.documents[document_key] or { return error('InvalidStateError: unknown request Document') } }
				request.send_document(document)!
			} else if args.len == 0 || args[0] is json2.Null { request.send()! }
			else if args[0] is string { request.send_text(canvas_host_string(args[0]))! }
			else { request.send_raw(canvas_host_bytes(args[0]))! }
		}
		'abort' { request.abort() }
		'overrideMimeType' { request.override_mime_type(canvas_host_string(args[0]))! }
		'getResponseHeader' { result = if value := request.get_response_header(canvas_host_string(args[0])) { json2.Any(value) } else { json2.Null{} } }
		'getAllResponseHeaders' { result = json2.Any(request.get_all_response_headers()) }
		'get' {
			match canvas_host_string(object['property'] or { json2.Any('') }) {
				'readyState' { result = json2.Any(int(request.ready_state())) }
				'timeout' { result = json2.Any(int(request.timeout())) }
				'withCredentials' { result = json2.Any(request.with_credentials()) }
				'responseType' { result = json2.Any(if request.response_type() == .empty { '' } else { request.response_type().str() }) }
				'responseURL' { result = json2.Any(request.response_url()) }
				'status' { result = json2.Any(int(request.status())) }
				'statusText' { result = json2.Any(request.status_text()) }
				'responseText' { result = json2.Any(request.response_text()!) }
				'responseXML' { value := request.response_xml()!; result = host.document_value(value.document) }
				'response' { result = host.response_value(mut request) }
				else { return error('TypeError: unknown XMLHttpRequest attribute') }
			}
		}
		'set' {
			match canvas_host_string(object['property'] or { json2.Any('') }) {
				'timeout' { request.set_timeout(u32(canvas_host_number(args[0])))! }
				'withCredentials' { request.set_with_credentials(canvas_host_bool(args[0]))! }
				'responseType' {
					value := canvas_host_string(args[0])
					type_ := match value { '' { xhr.ResponseType.empty } 'text' { .text } 'json' { .json } 'blob' { .blob } 'document' { .document } 'arraybuffer' { .arraybuffer } else { return 'null' } }
					request.set_response_type(type_)!
				}
				else { return error('TypeError: unknown XMLHttpRequest attribute') }
			}
		}
		else { return error('TypeError: unknown XMLHttpRequest operation ${method}') }
	}
	return json2.encode(result)
}
