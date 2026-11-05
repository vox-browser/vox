module browserjs

import dom
import fetch
import time

fn cache_storage_runtime(document &dom.Document, mut host FetchHost) &Runtime {
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

fn cache_storage_until(host &FetchHost, runtime &Runtime, expression string) {
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [runtime, expression, deadline] () bool {
		return runtime.evaluate_host(expression) or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host(expression) or { 'false' } == 'true', expression
}

fn test_cache_storage_stores_matches_and_deletes_responses() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://cache-storage.example/app/' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create(document, &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			return error('cache tests do not use the network')
		}
	})!
	mut runtime := cache_storage_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_cache_storage_binding(true)!
	assert runtime.evaluate_host(r'
 let illegal=0;for(const Type of [Cache,CacheStorage]){try{new Type()}catch(error){if(error instanceof TypeError)illegal++}}
 illegal===2&&caches===caches&&caches instanceof CacheStorage&&Object.prototype.toString.call(caches)==="[object CacheStorage]";
 ')! == 'true'
	runtime.evaluate_host(r'globalThis.cacheLog=[];(async function(){
  const cache=await caches.open("experiments");
  cacheLog.push(cache===await caches.open("experiments"),cache instanceof Cache,await caches.has("experiments"),await caches.has("missing"));
  await cache.put("/data.json?v=1",new Response("first",{headers:{"Content-Type":"application/json"}}));
  await cache.put(new Request("https://cache-storage.example/data.json?v=1"),new Response("second"));
  const exact=await cache.match("https://cache-storage.example/data.json?v=1#ignored");
  cacheLog.push(await exact.text(),(await cache.match("/data.json?v=2"))===undefined,await (await cache.match("/data.json",{ignoreSearch:true})).text());
  cacheLog.push((await cache.keys()).map(request=>request.url).join(","),(await caches.match("/data.json?v=1")).status);
  let rejected=0;
  for(const put of [()=>cache.put(new Request("/post",{method:"POST"}),new Response("x")),()=>cache.put("/partial",new Response("x",{status:206})),()=>cache.put("/vary",new Response("x",{headers:{Vary:"*"}}))]){try{await put()}catch(error){if(error instanceof TypeError)rejected++}}
  cacheLog.push(rejected,await cache.delete("/data.json?v=1"),await cache.delete("/data.json?v=1"),(await cache.matchAll()).length);
  cacheLog.push(await caches.delete("experiments"),JSON.stringify(await caches.keys()));
  cacheLog.push("done");
 })().catch(error=>cacheLog.push("error "+error));')!
	cache_storage_until(host, runtime, 'cacheLog[cacheLog.length-1]==="done"||String(cacheLog[cacheLog.length-1]).startsWith("error")')
	log := runtime.evaluate_host('JSON.stringify(cacheLog)')!
	assert log == '[true,true,true,false,"second",true,"second","https://cache-storage.example/data.json?v=1",200,3,true,false,0,true,"[]","done"]', log
}

fn test_cache_storage_is_only_exposed_to_secure_contexts() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'http://insecure-cache.example/' })
	document.set_origin(document.url.origin())
	mut host := FetchHost.create(document, &fetch.FetchHost{
		perform: fn (_ &fetch.Request) !&fetch.Response {
			return error('cache tests do not use the network')
		}
	})!
	mut runtime := cache_storage_runtime(document, mut host)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_cache_storage_binding(false)!
	assert runtime.evaluate_host('typeof caches==="undefined"&&typeof CacheStorage==="undefined"')! == 'true'
}
