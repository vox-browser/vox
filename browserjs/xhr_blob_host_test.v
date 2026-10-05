module browserjs

import dom
import fetch
import html
import net
import time

fn source_xhr_blob_runtime(document &dom.Document, mut host XMLHttpRequestHost) &Runtime {
	mut runtime := Runtime.create()
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	runtime.evaluate_host(xhr_bootstrap()) or { panic(err) }
	return runtime
}

fn source_xhr_blob_serve(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut request := []u8{len: 4096}
	_ := socket.read(mut request) or { panic(err) }
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: application/x-source; charset=UTF-8\r\nContent-Length: 2\r\nConnection: close\r\n\r\nAB') or { panic(err) }
}

fn test_source_xhr_blob_response_wraps_cached_native_record_and_uses_owning_read_tasks() {
	$if !darwin {
		return
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn source_xhr_blob_serve(mut listener)
	mut document := dom.Document.create(dom.URL{value: 'http://${listener.addr()!}/source-blob-owner'})
	document.set_origin(document.url.origin())
	mut host := XMLHttpRequestHost.create_native(document)!
	mut runtime := source_xhr_blob_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('const sourceBlobXHR=new XMLHttpRequest();sourceBlobXHR.open("GET","/source-blob");sourceBlobXHR.responseType="blob";sourceBlobXHR.send();')!
	assert runtime.evaluate_host('sourceBlobXHR.response===null')! == 'true'
	request := (host.requests[1] or { panic('missing actual XHR') }).request
	deadline := time.sys_mono_now() + 3 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [request, deadline] () bool {
		return request.state == .done || time.sys_mono_now() >= deadline
	})
	assert request.state == .done
	server.wait()
	actual := runtime.evaluate_host_value('globalThis.sourceXHRBlob=sourceBlobXHR.response;sourceXHRBlob')!
	blob := runtime.native_blob(actual)!
	assert voidptr(blob) == voidptr(request.response_blob()?)
	assert blob.raw_bytes() == [u8(65), 66]
	assert runtime.evaluate_host('sourceXHRBlob instanceof Blob&&Object.getPrototypeOf(sourceXHRBlob)===Blob.prototype&&sourceXHRBlob===sourceBlobXHR.response&&sourceXHRBlob.size===2&&!Object.hasOwn(sourceXHRBlob,"__xhrBlobKey")&&!Object.isFrozen(sourceXHRBlob)&&typeof sourceXHRBlob.bytes==="function"&&typeof sourceXHRBlob.stream==="function"')! == 'true'
	assert runtime.evaluate_host('sourceXHRBlob.type')! == blob.type_()
	runtime.evaluate_host('globalThis.sourceXHRReadsDone=false;globalThis.sourceXHRReadFailure=null;const text=sourceXHRBlob.text(),bytes=sourceXHRBlob.bytes(),buffer=sourceXHRBlob.arrayBuffer();globalThis.sourceXHRPending=text instanceof Promise&&bytes instanceof Promise&&buffer instanceof Promise&&text!==bytes&&bytes!==buffer;Promise.all([text,bytes,buffer]).then(values=>{sourceXHRReadsDone=values[0]==="AB"&&values[1] instanceof Uint8Array&&values[2] instanceof ArrayBuffer&&values[1][1]===66&&new Uint8Array(values[2])[0]===65&&values[1].buffer!==values[2]},reason=>sourceXHRReadFailure=reason);')!
	assert runtime.evaluate_host('sourceXHRPending&&!sourceXHRReadsDone&&sourceXHRReadFailure===null')! == 'true'
	mut queue := host.settings.responsible_event_loop().task_queue()
	mut tasks := 0
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		assert task.document() == host.settings.responsible_document()
		task.execute()
		tasks++
	}
	assert tasks == 3
	assert runtime.evaluate_host('sourceXHRReadsDone&&sourceXHRReadFailure===null')! == 'true'
	// Source wraps cached records even when author-visible metadata is poisoned.
	runtime.evaluate_host('globalThis.sourceXHRBlobGetterCalls=0;for(const name of ["size","type","__xhrBlobKey","__xhrDocumentKey"])Object.defineProperty(sourceXHRBlob,name,{enumerable:true,get(){++sourceXHRBlobGetterCalls;throw "author Blob getter"}});globalThis.Blob=function ForgedBlob(){};')!
	bridge := StructuredCloneBridge.create(runtime)!
	cloned := bridge.clone(actual)!
	assert runtime.native_blob(cloned)!.raw_bytes() == blob.raw_bytes()
	assert voidptr(runtime.native_blob(cloned)!) != voidptr(blob)
	assert runtime.evaluate_host('sourceBlobXHR.response===sourceXHRBlob&&sourceXHRBlobGetterCalls===0')! == 'true'
	runtime.evaluate_host('sourceBlobXHR.open("POST","/source-blob-copy");sourceBlobXHR.send(sourceXHRBlob);')!
	assert request.request_body == blob.raw_bytes()
	assert request.author_request_headers[0].value == blob.type_()
	assert runtime.evaluate_host('sourceBlobXHR.response===null&&sourceXHRBlobGetterCalls===0')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_xhr_blob_body_uses_actual_record_and_rejects_visible_blob_keys() {
	$if !darwin {
		return
	}
	mut document := dom.Document.create(dom.URL{value: 'https://source-xhr-blob-send.example.test/'})
	document.set_origin(document.url.origin())
	transport := &fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('blocking XHR transport was used')
		}
		perform_async: fn (request &fetch.Request) &fetch.PendingResponse {
			mut actual := unsafe { &fetch.Request(request) }
			return fetch.PendingResponse.create(mut actual, none)
		}
	}
	mut host := XMLHttpRequestHost.create(document, transport)!
	mut runtime := source_xhr_blob_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
globalThis.__ladybirdXHRBlob=function(){throw "author transport replacement"};
const body=new Blob([new Uint8Array([0,128,255])],{type:"application/custom;charset=windows-1252"});
globalThis.sourceSendBlobGetters=0;
for(const name of ["size","type","__xhrBlobKey","__xhrDocumentKey","toString"])Object.defineProperty(body,name,{get(){++sourceSendBlobGetters;throw "author Blob getter"}});
const sentBlob=new XMLHttpRequest();sentBlob.open("POST","/native-blob");sentBlob.send(body);
const overriddenBlob=new XMLHttpRequest();overriddenBlob.open("POST","/override");overriddenBlob.setRequestHeader("Content-Type","application/author;charset=windows-1252");overriddenBlob.send(body);
const fake={get __xhrBlobKey(){throw "visible Blob key"},toString(){return "ordinary string"}};
const sentFake=new XMLHttpRequest();sentFake.open("POST","/ordinary");sentFake.send(fake);
const emptyType=new XMLHttpRequest();emptyType.open("POST","/empty-type");emptyType.send(new Blob(["X"]));
const ignored=new XMLHttpRequest();ignored.open("GET","/ignored");ignored.send(body);
globalThis.sourceInvalidBlobSend=false;try{new XMLHttpRequest().send(body)}catch(error){sourceInvalidBlobSend=error.name==="InvalidStateError"}
')!
	actual := (host.requests[1] or { panic('missing Blob sender') }).request
	assert actual.request_body == [u8(0), 128, 255]
	assert actual.fetch_request_?.body.body_object?.bytes() == actual.request_body
	assert actual.author_request_headers[0].value == 'application/custom;charset=windows-1252'
	overridden := (host.requests[2] or { panic('missing overridden sender') }).request
	assert overridden.author_request_headers[0].value == 'application/author;charset=windows-1252'
	fake := (host.requests[3] or { panic('missing ordinary sender') }).request
	assert fake.request_body == 'ordinary string'.bytes()
	assert fake.author_request_headers[0].value == 'text/plain;charset=UTF-8'
	empty_type := (host.requests[4] or { panic('missing empty type sender') }).request
	assert empty_type.request_body == [u8(88)]
	assert empty_type.author_request_headers.len == 0
	ignored := (host.requests[5] or { panic('missing GET sender') }).request
	assert ignored.request_body.len == 0
	assert !ignored.request_body_present
	assert runtime.evaluate_host('sourceSendBlobGetters===0&&sourceInvalidBlobSend')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}
