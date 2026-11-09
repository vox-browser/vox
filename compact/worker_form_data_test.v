module main

import browserjs
import dom
import fetch
import html
import http
import time

fn worker_form_data_agent(source string, module_ bool, is_shared bool) !&browserjs.WorkerAgentRuntime {
	url := dom.URL{ value: 'https://worker-form-data.test/entry.js' }
	transport := &fetch.FetchHost{
		perform: fn [source] (request &fetch.Request) !&fetch.Response {
			mut response := fetch.Response.create()
			if request.current_url().serialize().ends_with('/entry.js') {
				response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
				response.set_body_bytes(source.bytes())
			} else {
				assert request.current_url().serialize().ends_with('/echo')
				response.header_list.append(http.Header{ name: 'Content-Type', value: request.header_list.get('Content-Type') or { '' } })
				body := request.body.body_object or { return error('Missing upload body') }
				response.set_body_bytes(body.bytes())
			}
			return response
		}
	}
	outside := html.SerializedEnvironmentSettingsObject{
		creation_url: url
		api_base_url: url
		origin:       url.origin()
		global:       html.SerializedWindow{ associated_document: html.SerializedDocument{ url: url, relevant_settings_object_is_secure_context: true } }
	}
	options := html.WorkerOptions{ type_: if module_ { .module_ } else { .classic } }
	if is_shared {
		return browserjs.WorkerAgentRuntime.create_shared(url, options, outside, 1, transport)
	}
	return browserjs.WorkerAgentRuntime.create(url, options, outside, 1, transport)
}

fn worker_form_data_message(mut agent browserjs.WorkerAgentRuntime) !string {
	deadline := time.sys_mono_now() + 5 * time.second
	mut frames := [][]u8{}
	for frames.len == 0 && time.sys_mono_now() < deadline {
		agent.process()
		frames << agent.take_outgoing()
	}
	assert frames.len == 1
	mut receiver := browserjs.Runtime.create()
	defer { receiver.close() }
	bridge := browserjs.ArrayBufferTransferBridge.create(receiver)!
	return receiver.native_utf16_string(bridge.deserialize(browserjs.decode_worker_message(frames[0])!)!)!.str()
}

fn test_worker_form_data_uses_native_files_strings_overloads_and_live_iterators() {
	for module_ in [false, true] {
		mut agent := worker_form_data_agent(r'
const check=(ok,message)=>{if(!ok)throw Error(message)};
class Data extends FormData{};const data=new Data(),file=new File([new Uint8Array([0,128,255])],"file.bin",{type:"application/custom",lastModified:42});
check(data instanceof Data&&data instanceof FormData&&FormData.length===0&&FormData.prototype.append.length===2&&Object.prototype.toString.call(data)==="[object FormData]","interface");
check(typeof document==="undefined"&&typeof FormDataEvent==="undefined","worker globals");
data.append("a",1);data.append("a",2);data.append("bad\ud800","x\udc00");data.append("file",file);
check(data.getAll("a").join()==="1,2"&&data.get("bad�")==="x�"&&data.get("file")===file,"native entries");
data.append("renamed",file,"other.bin");data.append("blob",new Blob(["b"]));
check(data.get("renamed")!==file&&data.get("renamed").lastModified===42&&data.get("renamed").name==="other.bin"&&data.get("blob") instanceof File&&data.get("blob").name==="blob","file conversion");
data.set("a",3);data.delete("bad�");const iterator=data.keys();check(iterator.next().value==="a","iterator starts");data.delete("file");check(iterator.next().value==="renamed"&&iterator[Symbol.iterator]()===iterator,"live iterator");
let rejected=0;for(const call of [()=>FormData(),()=>new FormData(null),()=>new FormData({}),()=>data.append("a","b","c"),()=>data.get(Symbol()),()=>data.get.call({},"a"),()=>new data.append("a","b")])try{call()}catch(error){if(error instanceof TypeError)rejected++}
const marker={};let original=false;try{data.append("a",{toString(){throw marker}})}catch(error){original=error===marker}check(rejected===7&&original,"IDL conversions");
postMessage("passed");
', module_, false)!
		defer { agent.close() }
		agent.load_entry()!
		assert worker_form_data_message(mut agent)! == 'passed'
		assert agent.environment.settings.realm().reported_exceptions.len == 0
	}
}

fn test_worker_form_data_fetch_body_round_trip_keeps_binary_files_and_ignores_author_getters() {
	for module_ in [false, true] {
		mut agent := worker_form_data_agent(r'
const check=(ok,message)=>{if(!ok)throw Error(message)};
const data=new FormData();data.append("field","line\n星");data.append("file",new File([new Uint8Array([0,128,255])],"name.bin",{type:"application/custom",lastModified:7}));
for(const key of ["entries","toString",Symbol.iterator])Object.defineProperty(data,key,{get(){throw Error("author FormData getter")}});
const request=new Request("/echo",{method:"POST",body:data});data.delete("file");
fetch(request).then(response=>{check(response.headers.get("content-type").startsWith("multipart/form-data; boundary="),"multipart MIME");return response.formData()}).then(async received=>{
 const file=received.get("file");check(received instanceof FormData&&received.get("field")==="line\r\n星"&&file instanceof File&&file.name==="name.bin"&&file.type==="application/custom","round trip");
 check(Array.from(new Uint8Array(await file.arrayBuffer())).join()==="0,128,255","binary bytes");postMessage("passed");
}).catch(error=>postMessage("failed: "+error));
', module_, false)!
		defer { agent.close() }
		agent.load_entry()!
		assert worker_form_data_message(mut agent)! == 'passed'
		assert agent.environment.settings.realm().reported_exceptions.len == 0
	}
}

fn test_shared_worker_form_data_is_exposed_on_classic_and_module_globals() {
	for module_ in [false, true] {
		mut agent := worker_form_data_agent(r'
const data=new FormData(),file=new File(["shared"],"shared.txt");data.append("file",file);data.append("field","shared");
if(data.get("file")!==file||data.get("field")!=="shared"||typeof document!=="undefined"||typeof FormDataEvent!=="undefined")throw Error("shared FormData");
', module_, true)!
		defer { agent.close() }
		agent.load_entry()!
		for _ in 0 .. 10 { agent.process() }
		assert agent.environment.settings.realm().reported_exceptions.len == 0
	}
}
