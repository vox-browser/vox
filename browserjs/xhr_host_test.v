module browserjs

import dom
import html
import net
import time

fn xhr_host_serve(mut listener net.TcpListener, body string, delay_ms int) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut bytes := []u8{len: 4096}
	_ := socket.read(mut bytes) or { panic(err) }
	time.sleep(delay_ms * time.millisecond)
	socket.write_string('HTTP/1.1 200 Host reason\r\nContent-Type: application/json; charset=UTF-8\r\nContent-Length: ${body.len}\r\nX-Native: yes\r\nSet-Cookie: hidden=1\r\nConnection: close\r\n\r\n${body[..5]}') or { return }
	time.sleep(20 * time.millisecond)
	socket.write_string(body[5..]) or {}
}

fn xhr_host_runtime(address string) (&Runtime, &XMLHttpRequestHost) {
	mut document := dom.Document.create(dom.URL{value: address})
	document.set_origin(document.url.origin())
	mut host := XMLHttpRequestHost.create_native(document) or { panic(err) }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	host.install(mut runtime) or { panic(err) }
	runtime.evaluate_host(xhr_bootstrap()) or { panic(err) }
	return runtime, host
}

fn xhr_host_pump(host &XMLHttpRequestHost) {
	request := (host.requests[1] or { panic('missing native XHR') }).request
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [request, deadline] () bool { return request.state == .done || time.sys_mono_now() >= deadline })
	assert request.state == .done
}

fn test_compact_xhr_factory_uses_real_transport_model_and_native_dom_listeners() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn xhr_host_serve(mut listener, '{"transport":"curl","marker":"✓"}', 0)
	mut runtime, host := xhr_host_runtime('http://${listener.addr()!}/owning-document')
	defer { runtime.close() }
	runtime.evaluate_host(r'
 const request=new XMLHttpRequest(),states=[],events=[],retained=[];
 request.onreadystatechange=function(){states.push(this.readyState);};
 function remember(event){events.push(event.type);retained.push(event);}
 request.addEventListener("load",remember,{once:true});
 request.onload=function(event){retained.push(event);};
 request.addEventListener("progress",remember);
 request.open("GET","/native-data");request.responseType="json";request.send();
 ')!
	assert runtime.evaluate_host('request.readyState')! == '1'
	assert (host.requests[1] or { panic('missing owner') }).request.global_object_.associated_document? == host.document
	assert (host.requests[1] or { panic('missing owner') }).request.has_activity_root()
	xhr_host_pump(host)
	assert runtime.evaluate_host('request.status===200&&request.statusText==="Host reason"&&request.response.transport==="curl"&&request.response.marker==="✓"&&request.response===request.response')! == 'true'
	assert runtime.evaluate_host('request.responseURL.endsWith("/native-data")&&request.getResponseHeader("X-Native")==="yes"&&request.getResponseHeader("Set-Cookie")===null')! == 'true'
	assert runtime.evaluate_host('states[0]===XMLHttpRequest.OPENED&&states.includes(XMLHttpRequest.HEADERS_RECEIVED)&&states.includes(XMLHttpRequest.LOADING)&&states[states.length-1]===XMLHttpRequest.DONE')! == 'true'
	assert runtime.evaluate_host('events.filter(x=>x==="load").length===1&&retained[retained.length-1]===retained[retained.length-2]&&retained.every(e=>e.isTrusted&&e.target===request&&e.currentTarget===null)')! == 'true'
	assert runtime.evaluate_host('let invalid=false;try{request.responseText;}catch(e){invalid=e.name==="InvalidStateError";}invalid;')! == 'true'
	assert runtime.take_document_state_dirty()
	assert !runtime.take_document_state_dirty()
	assert !(host.requests[1] or { panic('missing owner') }).request.has_activity_root()
	server.wait()
}

fn test_compact_xhr_timeout_is_a_native_timer_and_event_target_transition() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn xhr_host_serve(mut listener, '{"delayed":true}', 100)
	mut runtime, host := xhr_host_runtime('http://${listener.addr()!}/owner')
	defer { runtime.close() }
	runtime.evaluate_host(r'
 const request=new XMLHttpRequest(),events=[];
 for(const type of ["load","timeout","loadend"])request.addEventListener(type,function(event){events.push(event.type);});
 request.open("GET","/late");request.timeout=15;request.send();
 ')!
	xhr_host_pump(host)
	assert runtime.evaluate_host('JSON.stringify(events)')! == '["timeout","loadend"]'
	assert runtime.evaluate_host('request.status===0&&request.readyState===XMLHttpRequest.DONE')! == 'true'
	assert (host.requests[1] or { panic('missing owner') }).request.timed_out
	server.wait()
}

fn test_compact_xhr_listener_removal_and_native_reentrant_abort_preserve_event_order() {
	$if !darwin { return }
	mut runtime, host := xhr_host_runtime('http://127.0.0.1:54321/owner')
	defer { runtime.close() }
	runtime.evaluate_host(r'
 const request=new XMLHttpRequest(),events=[];
 function removed(event){events.push("removed");}
 request.addEventListener("loadstart",removed);request.removeEventListener("loadstart",removed);
 request.onloadstart=function(event){events.push("loadstart");this.abort();};
 request.onabort=function(event){events.push("abort");};
 request.onloadend=function(event){events.push("loadend");};
 request.open("GET","/cancel");request.send();
 ')!
	assert runtime.evaluate_host('JSON.stringify(events)')! == '["loadstart","abort","loadend"]'
	assert runtime.evaluate_host('request.readyState===XMLHttpRequest.UNSENT')! == 'true'
	if connection := host.connection { assert connection.active_request_count() == 0 }
	assert !(host.requests[1] or { panic('missing owner') }).request.send_flag
}

fn test_compact_xhr_header_errors_are_dom_exceptions_and_byte_string_type_errors() {
	$if !darwin { return }
	mut runtime, _ := xhr_host_runtime('http://127.0.0.1:9/owning-document')
	defer { runtime.close() }
	runtime.evaluate_host(r'
 globalThis.DOMException=function DOMException(message,name){this.message=message;this.name=name;};
 const request=new XMLHttpRequest();request.open("GET","/headers");
 globalThis.headerError=null;try{request.setRequestHeader("(","x");}catch(error){headerError=error;}
 globalThis.byteError=null;try{request.setRequestHeader("X-ﾃ","x");}catch(error){byteError=error;}
 ')!
	assert runtime.evaluate_host('headerError instanceof DOMException&&headerError.name==="SyntaxError"&&headerError.message==="Header contains invalid characters"')! == 'true'
	assert runtime.evaluate_host('byteError instanceof TypeError')! == 'true'
}
