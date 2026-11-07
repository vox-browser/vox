module main

import browserjs
import dom
import html

fn test_native_document_blob_bindings_retain_pending_owner_reads_and_replay_real_results() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<div id="result">pending</div>', dom.URL{value: 'https://native-document-blob.example.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_script_sources(document, document.url.serialize(), [browserjs.ScriptSource{
		code: r'
globalThis.nativeDocumentBlob=new Blob(["A",new Uint8Array([66])],{type:"TEXT/PLAIN"});
globalThis.nativeBlobDone=false;globalThis.nativeBlobErrors=[];
const text=nativeDocumentBlob.text(),bytes=nativeDocumentBlob.bytes(),buffer=nativeDocumentBlob.arrayBuffer();
globalThis.nativeBlobPending=text instanceof Promise&&bytes instanceof Promise&&buffer instanceof Promise&&text!==bytes&&bytes!==buffer;
Promise.all([text,bytes,buffer]).then(values=>{
 globalThis.nativeBlobResults=values;
 document.getElementById("result").textContent=values[0]==="AB"&&values[1] instanceof Uint8Array&&values[2] instanceof ArrayBuffer&&values[1][1]===66&&new Uint8Array(values[2])[0]===65?"source Blob":"wrong Blob";
 nativeBlobDone=true;
},reason=>nativeBlobErrors.push(reason));
'
	}], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('nativeBlobPending&&!nativeBlobDone&&nativeDocumentBlob instanceof Blob&&nativeDocumentBlob.type==="text/plain"')! == 'true'
	assert document.get_element_by_id('result')?.text_content()? == 'pending'
	actual := runtime.native_blob(runtime.evaluate_host_value('nativeDocumentBlob')!)!
	assert actual.raw_bytes() == [u8(65), 66]
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	mut tasks := 0
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { break }
		assert task.document() == settings.responsible_document()
		task.execute()
		tasks++
	}
	assert tasks == 3
	assert runtime.evaluate_host('nativeBlobDone&&nativeBlobErrors.length===0&&nativeBlobResults[1].buffer!==nativeBlobResults[2]')! == 'true'
	mut app := BrowserApp{ document: document, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.poll_javascript_tasks()
	assert app.js_messages == []
	assert document.get_element_by_id('result')?.text_content()? == 'source Blob'
	assert !runtime.libjs_vm().has_running_execution_context()
}
