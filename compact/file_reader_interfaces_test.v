module main

import browserjs
import dom
import fetch
import html
import http

fn file_reader_agent(source string, module_ bool, shared bool) !&browserjs.WorkerAgentRuntime {
	url := dom.URL{ value: 'https://file-readers.test/entry.js' }
	transport := &fetch.FetchHost{
		perform: fn [source] (_ &fetch.Request) !&fetch.Response {
			mut response := fetch.Response.create()
			response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/javascript' })
			response.set_body_bytes(source.bytes())
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
	if shared {
		return browserjs.WorkerAgentRuntime.create_shared(url, options, outside, 1, transport)
	}
	return browserjs.WorkerAgentRuntime.create(url, options, outside, 1, transport)
}

fn test_file_reader_sync_uses_native_bytes_decoding_and_worker_interface_metadata() {
	for module_ in [false, true] {
		mut agent := file_reader_agent(r'
const check=(value,message)=>{if(!value)throw Error(message)};
class Derived extends FileReaderSync{};const reader=new Derived();
check(reader instanceof Derived&&reader instanceof FileReaderSync&&!(reader instanceof EventTarget),"inheritance");
check(FileReaderSync.length===0&&FileReaderSync.name==="FileReaderSync"&&Object.prototype.toString.call(reader)==="[object FileReaderSync]","interface");
const blob=new Blob([new Uint8Array([0,128,255])]);Object.defineProperty(blob,"type",{get(){throw Error("author type getter")}});
const first=reader.readAsArrayBuffer(blob),second=reader.readAsArrayBuffer(blob);
check(first!==second&&Array.from(new Uint8Array(first)).join()==="0,128,255","fresh native ArrayBuffers");
first.transfer();check(Array.from(new Uint8Array(second)).join()==="0,128,255","independent bytes");
check(reader.readAsBinaryString(blob)==="\x00\x80\xff","binary string");
check(reader.readAsText(new Blob([new Uint8Array([255,254,65,0])]),"UTF-8")==="A","BOM wins");
check(reader.readAsText(new Blob([new Uint8Array([128])],{type:"text/plain;charset=windows-1252"}))==="€","MIME charset");
check(reader.readAsDataURL(new Blob())==="data:application/octet-stream;base64,","empty data URL");
check(reader.readAsDataURL(new File(["a"],"a.txt",{type:"text/plain"}))==="data:text/plain;base64,YQ==","File bytes");
let errors=0;for(const call of [()=>FileReaderSync(),()=>new reader.readAsText(blob),()=>reader.readAsText(),()=>reader.readAsText({}),()=>reader.readAsText(new Proxy(blob,{})),()=>FileReaderSync.prototype.readAsText.call({},blob),()=>reader.readAsText(blob,Symbol())])try{call()}catch(e){if(e instanceof TypeError)errors++;}
const marker={};let preserved=false;try{reader.readAsText(blob,{toString(){throw marker}})}catch(e){preserved=e===marker}
check(errors===7&&preserved&&reader.readAsText.length===1&&!("prototype" in reader.readAsText),"IDL conversion");
postMessage("passed");
', module_, false)!
		defer { agent.close() }
		agent.load_entry()!
		agent.process()
		frames := agent.take_outgoing()
		assert frames.len == 1, 'module=${module_}'
		mut receiver := browserjs.Runtime.create()
		defer { receiver.close() }
		bridge := browserjs.ArrayBufferTransferBridge.create(receiver)!
		actual := bridge.deserialize(browserjs.decode_worker_message(frames[0])!)!
		assert receiver.native_utf16_string(actual)!.str() == 'passed'
	}
}

fn test_file_reader_sync_is_available_to_shared_workers_and_rejected_for_window_installation() {
	mut window := browserjs.Runtime.create()
	defer { window.close() }
	if _ := window.install_file_reader_sync_binding() {
		assert false
	}
	assert window.evaluate_host('typeof FileReaderSync')! == 'undefined'
	mut agent := file_reader_agent(r'
const reader=new FileReaderSync();if(reader.readAsText(new Blob(["shared"]))!=="shared")throw Error("shared reader");
', false, true)!
	defer { agent.close() }
	agent.load_entry()!
	assert agent.environment.settings.realm().reported_exceptions.len == 0
}
