module browserjs

import dom
import fetch
import html

fn native_form_data_runtime(document &dom.Document) (&Runtime, &FormDataHost) {
	mut runtime := Runtime.create()
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	files.install_constructor() or { panic(err) }
	mut data := FormDataHost.create(document) or { panic(err) }
	data.install(mut runtime) or { panic(err) }
	return runtime, data
}

fn test_native_form_data_entries_preserve_scalar_strings_native_files_and_overloads() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://form-data.test/' })
	mut runtime, _ := native_form_data_runtime(document)
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{
 const data=new FormData(),file=new File([new Uint8Array([0,128,255])],"original.bin",{type:"application/custom",lastModified:42});
 data.append("a",1);data.append("a",2);data.append("bad\ud800","x\udc00");data.append("file",file);
 if(data.get("file")!==file||data.get("missing")!==null||data.getAll("missing").length||data.getAll("a").join()!=="1,2"||data.get("bad�")!=="x�")return false;
 data.set("a",3);data.append("renamed",file,"renamed.bin");data.append("blob",new Blob(["abc"]));
 const renamed=data.get("renamed"),blob=data.get("blob");
 if(renamed===file||renamed.name!=="renamed.bin"||renamed.lastModified!==42||renamed.type!=="application/custom"||blob.name!=="blob"||blob.size!==3||!(blob instanceof File))return false;
 data.set("blob",new Blob(["Z"]),"z");data.delete("bad�");
 globalThis.nativeData=data;globalThis.nativeFile=file;
 return data.getAll("a").join()==="3"&&!data.has("bad�")&&data.get("blob").name==="z"&&[...data.keys()].join()==="a,file,renamed,blob";
 })()')! == 'true'
	data := runtime.native_form_data(runtime.evaluate_host_value('nativeData')!)!
	assert data.entries.len == 4
	assert runtime.javascript_form_data(data)! == runtime.evaluate_host_value('nativeData')!
	file := runtime.native_file(runtime.evaluate_host_value('nativeData.get("renamed")')!)!
	assert file.raw_bytes() == [u8(0), 128, 255]
	assert runtime.evaluate_host(r'(()=>{let calls=0;const marker={},value={toString(){calls++;throw marker}},data=new FormData();let brand,missing,conversion;try{data.append.call({},value,value)}catch(e){brand=e}try{data.append(value)}catch(e){missing=e}try{data.append("x",value)}catch(e){conversion=e}return brand instanceof TypeError&&missing instanceof TypeError&&conversion===marker&&calls===1&&[()=>data.append("x","s","name"),()=>data.set("x","s",undefined),()=>data.get(Symbol()),()=>new FormData(null),()=>new FormData({})].every(run=>{try{run();return false}catch(e){return e instanceof TypeError}})})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const data=new FormData(),order=[],name={toString(){order.push("name");return "field"}},value={toString(){order.push("value");return "text"}},filename={toString(){order.push("filename");return "name"}};let rejected=false;try{data.append(name,value,filename)}catch(e){rejected=e instanceof TypeError}if(!rejected||order.length)return false;data.append(name,value);data.set(name,new Blob(["x"]),filename);return order.join()==="name,value,name,filename"&&data.get("field").name==="name"})()')! == 'true'
}

fn test_native_form_data_iterators_and_callbacks_observe_live_entries_and_original_errors() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://form-data.test/' })
	mut runtime, _ := native_form_data_runtime(document)
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'(()=>{const data=new FormData();data.append("a","1");data.append("b","2");const it=data.entries();if(it.next().value.join()!=="a,1")return false;data.delete("b");data.append("c","3");if(it.next().value.join()!=="c,3"||!it.next().done)return false;data.append("d","4");if(it.next().value.join()!=="d,4")return false;const seen=[],receiver={};data.forEach(function(value,key,owner){if(this!==receiver||owner!==data)throw 1;seen.push(key+value);if(key==="a"){data.delete("c");data.append("e","5")}},receiver);return seen.join()==="a1,d4,e5"&&it[Symbol.iterator]()===it&&data[Symbol.iterator]===data.entries&&Object.prototype.toString.call(it)==="[object FormData Iterator]"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const data=new FormData(),marker={};data.append("a",1);data.append("b",2);let calls=0,failure;try{data.forEach(()=>{calls++;throw marker})}catch(e){failure=e}let brand;try{data.entries().next.call({})}catch(e){brand=e}return calls===1&&failure===marker&&brand instanceof TypeError})()')! == 'true'
}

fn test_native_form_data_constructs_successful_controls_and_validates_actual_submitter() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document('<form id="form"><input name="text" value="initial"><input disabled name="skip" value="skip"><input type="checkbox" name="on" checked><button id="submit" name="send" value="yes">Send</button></form><form id="other"><button id="wrong">Wrong</button></form><div id="div"></div>')
	mut runtime, _ := native_form_data_runtime(document)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_event_target_binding()!
	for id in ['form', 'submit', 'wrong', 'div'] {
		object := runtime.evaluate_host_value('globalThis.${id}={}')!
		element := document.get_element_by_id(id)?
		runtime.bind_event_target(object, unsafe { &dom.EventTarget(element) })!
	}
	assert runtime.evaluate_host(r'(()=>{const plain=new FormData(form),sent=new FormData(form,submit);return [...plain.keys()].join()==="text,on"&&plain.get("text")==="initial"&&!plain.has("skip")&&plain.get("on")==="on"&&sent.get("send")==="yes"&&[()=>new FormData(form,div),()=>new FormData(div)].every(run=>{try{run();return false}catch(e){return e instanceof TypeError}})&&(()=>{try{new FormData(form,wrong);return false}catch(e){return e.name==="NotFoundError"}})()})()')! == 'true'
}

fn test_native_form_data_fetch_and_xhr_serialize_binary_multipart_without_author_getters() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://form-data.test/' })
	document.set_origin(document.url.origin())
	mut runtime, _ := native_form_data_runtime(document)
	defer {
		runtime.close()
		document.finalize()
	}
	transport := &fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('unexpected blocking transport')
		}
		perform_async: fn (request &fetch.Request) &fetch.PendingResponse {
			mut actual := unsafe { &fetch.Request(request) }
			return fetch.PendingResponse.create(mut actual, none)
		}
	}
	mut queries := URLSearchParamsHost.create(document)!
	queries.install(mut runtime)!
	mut abort := AbortSignalHost.create(document)!
	abort.install(mut runtime)!
	mut fetch_host := FetchHost.create(document, transport)!
	fetch_host.install(mut runtime)!
	mut xhr_host := XMLHttpRequestHost.create(document, transport)!
	xhr_host.install(mut runtime)!
	runtime.evaluate_host(xhr_bootstrap())!
	runtime.evaluate_host(r'
 globalThis.body=new FormData();body.append("line\n\"","a\nb");body.append("file",new File([new Uint8Array([0,128,255])],"a\".bin",{type:"application/custom"}));
 for(const name of ["entries","toString",Symbol.iterator])Object.defineProperty(body,name,{get(){throw "author data getter"}});
 globalThis.request=new Request("/upload",{method:"POST",body});
 const sent=new XMLHttpRequest();sent.open("POST","/upload");sent.send(body);
 const overridden=new XMLHttpRequest();overridden.open("POST","/override");overridden.setRequestHeader("Content-Type","application/author;charset=windows-1252");overridden.send(body);
 body.delete("file");
 ')!
	record := fetch_host.record(runtime.evaluate_host_value('request')!, .request)!
	request := unsafe { &fetch.RequestObject(record.native) }
	body := request.internal_request().body.body_object?.bytes()
	assert body.bytestr().contains('name="line%0D%0A%22"\r\n\r\na\r\nb\r\n')
	assert body.bytestr().contains('filename="a%22.bin"\r\nContent-Type: application/custom\r\n\r\n')
	assert body.bytestr().contains([u8(0), 128, 255].bytestr())
	assert runtime.evaluate_host('request.headers.get("content-type").startsWith("multipart/form-data; boundary=")')! == 'true'
	sent := xhr_host.requests[1] or { panic('missing sender') }
	assert sent.request.request_body.bytestr().contains([u8(0), 128, 255].bytestr())
	assert sent.request.author_request_headers[0].value.starts_with('multipart/form-data; boundary=')
	overridden := xhr_host.requests[2] or { panic('missing overridden sender') }
	assert overridden.request.author_request_headers[0].value == 'application/author;charset=windows-1252'
}

fn test_native_form_data_metadata_subclasses_private_slots_and_close() {
	$if !darwin && !linux {
		return
	}
	mut document := dom.Document.create(dom.URL{ value: 'https://form-data.test/' })
	mut runtime, host := native_form_data_runtime(document)
	defer { document.finalize() }
	assert runtime.evaluate_host(r'(()=>{class Data extends FormData{}const d=new Data(),get=Object.getOwnPropertyDescriptor;return d instanceof Data&&d instanceof FormData&&FormData.length===0&&FormData.prototype.append.length===2&&FormData.prototype.get.length===1&&FormData.prototype.forEach.length===1&&get(FormData.prototype,"append").enumerable&&Function.prototype.toString.call(FormData.prototype.append).includes("[native code]")&&Object.prototype.toString.call(d)==="[object FormData]"&&Reflect.ownKeys(d).length===0&&(()=>{try{FormData();return false}catch(e){return e instanceof TypeError}})()})()')! == 'true'
	actual := runtime.evaluate_host_value('new FormData()')!
	mut data := runtime.native_form_data(actual)!
	data.append('native', 'retained')
	assert runtime.javascript_form_data(data)! == actual
	runtime.close()
	assert host.closed
	assert host.by_wrapper.len == 0 && host.iterators.len == 0
	assert data.has('native')
	if _ := runtime.native_form_data(actual) {
		assert false, 'closed runtime retained FormData table'
	}
}
