module browserjs

import dom
import fetch
import net
import time

fn source_fetch_runtime(document &dom.Document, mut host FetchHost) &Runtime {
	mut runtime := Runtime.create()
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut params := URLSearchParamsHost.create(document) or { panic(err) }
	params.install(mut runtime) or { panic(err) }
	mut abort := AbortSignalHost.create(document) or { panic(err) }
	abort.install(mut runtime) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime
}

fn source_fetch_until(host &FetchHost, runtime &Runtime, expression string) {
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [runtime, expression, deadline] () bool {
		return runtime.evaluate_host(expression) or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host(expression) or { 'false' } == 'true', expression
}

fn source_fetch_serve(mut listener net.TcpListener) {
	mut socket := listener.accept() or { panic(err) }
	defer { socket.close() or {} }
	mut input := []u8{len: 4096}
	_ := socket.read(mut input) or { panic(err) }
	socket.write_string('HTTP/1.1 404 Font reason\r\nContent-Type: application/octet-stream\r\nContent-Length: 4\r\nX-Font: yes\r\nSet-Cookie: secret=1\r\nConnection: close\r\n\r\n') or { return }
	time.sleep(250 * time.millisecond)
	socket.write([u8(0), 128, 255, 65]) or {}
}

fn test_native_fetch_resolves_headers_before_binary_body_and_clones_live_streams() {
	$if !darwin && !linux {
		return
	}
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	defer { listener.close() or {} }
	server := spawn source_fetch_serve(mut listener)
	mut document := dom.Document.create(dom.URL{ value: 'http://${listener.addr()!}/owner' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create_native(document)!
	mut runtime := source_fetch_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.gotHeaders=false;globalThis.gotBytes=false;globalThis.failure=null;
 fetch("/font.woff2",{credentials:"same-origin",headers:{"X-Client":"Vox"}}).then(response=>{
  globalThis.fontResponse=response;gotHeaders=true;
  globalThis.early=!gotBytes&&!response.bodyUsed&&response.body instanceof ReadableStream;
  globalThis.clone=response.clone();
  globalThis.reads=Promise.all([response.arrayBuffer(),clone.bytes()]).then(values=>{
   globalThis.buffer=values[0];globalThis.bytes=values[1];gotBytes=true;
  },reason=>failure=reason);
 },reason=>failure=reason);
 ')!
	assert runtime.evaluate_host('!gotHeaders&&!gotBytes&&failure===null')! == 'true'
	source_fetch_until(host, runtime, 'gotHeaders||failure!==null')
	assert runtime.evaluate_host('gotHeaders&&early&&!gotBytes&&failure===null')! == 'true'
	response := runtime.native_fetch_response(runtime.evaluate_host_value('fontResponse')!)!
	assert response.status() == 404
	assert runtime.evaluate_host('fontResponse instanceof Response&&fontResponse.type==="basic"&&!fontResponse.ok&&fontResponse.statusText==="Font reason"&&fontResponse.url.endsWith("/font.woff2")&&fontResponse.headers===fontResponse.headers&&fontResponse.headers.get("x-font")==="yes"&&fontResponse.headers.get("set-cookie")===null&&fontResponse.headers instanceof Headers')! == 'true'
	assert runtime.evaluate_host('let immutable=false;try{fontResponse.headers.set("x-font","changed")}catch(e){immutable=e instanceof TypeError}immutable')! == 'true'
	source_fetch_until(host, runtime, 'gotBytes||failure!==null')
	assert runtime.evaluate_host('gotBytes&&failure===null&&buffer instanceof ArrayBuffer&&bytes instanceof Uint8Array&&[...new Uint8Array(buffer)].join(",")==="0,128,255,65"&&[...bytes].join(",")==="0,128,255,65"&&fontResponse.bodyUsed&&clone.bodyUsed')! == 'true'
	runtime.evaluate_host('globalThis.reused=false;fontResponse.text().catch(e=>reused=e instanceof TypeError)')!
	source_fetch_until(host, runtime, 'reused')
	assert host.operations.len == 0
	assert runtime.take_document_state_dirty()
	server.wait()
}

fn test_native_fetch_constructors_headers_conversion_body_usage_and_brands() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://fetch-records.example.test/base/' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create(document, &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			panic('constructor tests must not perform a network request')
		}
	})!
	mut runtime := source_fetch_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 const headers=new Headers([["X-A"," one "],["x-a","two"],["z","last"]]);
 if(headers.get("X-A")!=="one, two"||[...headers.keys()].join(",")!=="x-a,z")throw "headers";
 const it=headers.entries();if(it.next().value.join(":")!=="x-a:one, two")throw "iterator";
 headers.append("y","middle");if(it.next().value[0]!=="y")throw "live iterator";
 let brands=0;const poison={toString(){throw "conversion before brand"}};
 for(const invoke of [()=>Headers.prototype.get.call({},poison),()=>Request.prototype.clone.call({}),()=>Response.prototype.clone.call({})]){try{invoke()}catch(e){if(e instanceof TypeError)brands++}}
 if(brands!==3)throw "brands";
 const latin=new Headers({"X-Latin":"\u0080\u00ff"});
 if(latin.get("x-latin")!=="\u0080\u00ff"||[...latin.values()][0]!=="\u0080\u00ff")throw "ByteString round trip";
 if(new Response(null,{statusText:"\u00ff"}).statusText!=="\u00ff")throw "status ByteString";
 for(const text of ["\u007f","\r","\n","\u0100"]){let rejected=false;try{new Response(null,{statusText:text})}catch(error){rejected=error instanceof TypeError}if(!rejected)throw "invalid status ByteString"}
 const request=new Request("../upload",{method:"post",headers,body:new URLSearchParams({q:"a b"}),credentials:"include",cache:"no-cache",redirect:"manual"});
 if(request.url!=="https://fetch-records.example.test/upload"||request.method!=="POST"||request.credentials!=="include"||request.cache!=="no-cache"||request.redirect!=="manual"||request.headers.get("content-type")!=="application/x-www-form-urlencoded;charset=UTF-8"||!(request.signal instanceof AbortSignal)||request.signal.aborted)throw "request";
 const requestCopy=request.clone();
 const response=new Response(new Uint8Array([88,0,89]),{status:201,statusText:"Created",headers:{"Content-Type":"application/custom"}});
 if(response.status!==201||!response.ok||response.type!=="default"||response.bodyUsed||response.url!=="")throw "response";
 const empty=new Response();if(empty.body!==null||empty.bodyUsed)throw "empty";
 globalThis.recordsDone=false;globalThis.recordsFailure=null;
 Promise.all([request.text(),requestCopy.text(),response.blob(),empty.text(),Response.json({ok:true}).json()]).then(values=>{
  recordsDone=values[0]==="q=a+b"&&values[1]==="q=a+b"&&values[2] instanceof Blob&&values[2].size===3&&values[2].type==="application/custom"&&values[3]===""&&values[4].ok&&request.bodyUsed&&response.bodyUsed&&!empty.bodyUsed;
 },reason=>recordsFailure=reason);
 const redirected=Response.redirect("../next",307);if(redirected.status!==307||redirected.headers.get("location")!=="https://fetch-records.example.test/next"||Response.error().type!=="error")throw "static";
 class Derived extends Response{};if(!(new Derived("ok") instanceof Derived))throw "subclass";
 ')!
	source_fetch_until(host, runtime, 'recordsDone||recordsFailure!==null')
	assert runtime.evaluate_host('recordsDone&&recordsFailure===null')! == 'true'
	runtime.evaluate_host(r'
 globalThis.rejects=0;const marker={identity:true};
 fetch("/",{get method(){throw marker}}).catch(reason=>{if(reason===marker)rejects++});
 fetch("http://[invalid",{get method(){throw marker}}).catch(reason=>{if(reason===marker)rejects++});
 fetch().catch(reason=>{if(reason instanceof TypeError)rejects++});
 fetch("https://user:pass@example.test/").catch(reason=>{if(reason instanceof TypeError)rejects++});
 fetch("/",{method:"GET",body:"invalid"}).catch(reason=>{if(reason instanceof TypeError)rejects++});
 new Response("bad json").json().catch(reason=>{if(reason instanceof SyntaxError)rejects++});
 Response.prototype.text.call({}).catch(reason=>{if(reason instanceof TypeError)rejects++});
 ')!
	source_fetch_until(host, runtime, 'rejects===7')
}

fn test_native_fetch_aborts_pending_transport_with_original_reason() {
	$if !darwin && !linux {
		return
	}
	transport := &fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response { panic('blocking transport used') }
		perform_async: fn (request &fetch.Request) &fetch.PendingResponse {
			mut actual := unsafe { &fetch.Request(request) }
			return fetch.PendingResponse.create(mut actual, none)
		}
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://fetch-abort.example.test/' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create(document, transport)!
	mut runtime := source_fetch_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 const controller=new AbortController(),reason={cancelled:true};globalThis.aborted=0;
 fetch("/pending",{signal:controller.signal}).catch(error=>{if(error===reason)aborted++});
 controller.abort(reason);
 fetch("/already-aborted",{signal:controller.signal}).catch(error=>{if(error===reason)aborted++});
 ')!
	source_fetch_until(host, runtime, 'aborted===2')
	assert host.operations.len == 0
}

fn test_native_fetch_aborts_streaming_response_after_headers_and_rejects_network_errors() {
	$if !darwin && !linux {
		return
	}
	body := fetch.Body.streaming()
	transport := &fetch.FetchHost{
		perform: fn [body] (request &fetch.Request) !&fetch.Response {
			if request.url().serialize().ends_with('/failure') {
				return fetch.Response.network_error('connection failed')
			}
			mut response := fetch.Response.create()
			response.url_list = request.url_list.clone()
			response.body = body
			return response
		}
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://fetch-stream.example.test/' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create(document, transport)!
	mut runtime := source_fetch_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 const controller=new AbortController(),reason={bodyCancelled:true};globalThis.ready=false;globalThis.failed=0;
 fetch("/stream",{signal:controller.signal}).then(response=>{
  globalThis.streamingResponse=response;
  response.text().catch(error=>{if(error===reason)failed++});ready=true;
 });
 fetch("/failure").catch(error=>{if(error instanceof TypeError)failed++});
 ')!
	source_fetch_until(host, runtime, 'ready&&failed===1')
	assert host.operations.len == 1
	runtime.evaluate_host('controller.abort(reason)')!
	source_fetch_until(host, runtime, 'failed===2')
	assert runtime.evaluate_host('streamingResponse.bodyUsed')! == 'true'
	assert host.operations.len == 0
}
