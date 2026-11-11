// XMLHttpRequest.cpp: send's Document serialization and content-type steps.
module xhr

import dom
import infra

pub fn (mut request XMLHttpRequest) send_document(document &dom.Document) ! {
	if request.state != .opened || request.send_flag {
		return error('InvalidStateError: XHR readyState is not OPENED or send flag is already set')
	}
	if request.request_method in ['GET', 'HEAD'] { request.send()!; return }
	serialized := document.as_node().serialize_fragment(.no, .inner)!
	content_type := if document.is_html_document() { 'text/html;charset=UTF-8' } else { 'application/xml;charset=UTF-8' }
	request.send_bytes(infra.convert_to_scalar_value_string(serialized).bytes(), content_type, true, true)!
}
