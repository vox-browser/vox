module main

import browserjs
import dom
import fetch
import http

fn test_xhr_text_reply_retires_after_javascript_copies_it() {
	$if !darwin { return }
	mut document := dom.Document.create(dom.URL{value: 'https://xhr-reply.test/'})
	document.set_origin(document.url.origin())
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer {
		runtime.close()
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	body := 'abcdλ😀'.repeat(16_384)
	mut host := browserjs.XMLHttpRequestHost.create(document, &fetch.FetchHost{
		perform: fn [body] (request &fetch.Request) !&fetch.Response {
			mut response := fetch.Response.create()
			response.status = 200
			response.url_list = request.url_list.clone()
			response.header_list.append(http.Header{name: 'Content-Type', value: 'text/plain;charset=UTF-8'})
			response.body = fetch.Body.from_bytes(body.bytes(), .bytes)
			return response
		}
	})!
	host.install(mut runtime)!
	runtime.evaluate_host(browserjs.xhr_bootstrap())!
	runtime.evaluate_host(r'
const request=new XMLHttpRequest();
request.open("GET","/text",false);
request.send();
const first=request.responseText;
')!
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	assert runtime.evaluate_host(r'
let matched=request.readyState===4&&first.length===114688&&first.endsWith("abcdλ😀");
for(let i=0;i<5;i++)matched=matched&&(i%2?request.response:request.responseText)===first;
matched;
')! == 'true'
	$if prealloc {
		assert storage.arena.usage().used - before < body.len
	}
}
