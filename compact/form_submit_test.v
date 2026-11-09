module main

import browserjs
import dom
import fetch
import html
import http
import page
import platform
import time

@[heap]
struct SubmittedFormObservation {
mut:
	submissions []html.FormSubmission
	methods []string
	bodies [][]u8
	content_types []string
}

fn form_submit_document(markup string) !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{value: 'https://form-submit.test/page'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn test_legacy_form_submit_uses_live_properties_and_files_without_validation_or_submit_events() {
	mut document := form_submit_document('<!doctype html><form id="form"><input id="required" required name="required"><input id="file" name="upload" type="file"></form>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	element := document.get_element_by_id('form') or { panic('form') }
	mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
	observed := &SubmittedFormObservation{}
	model.set_submission_hook(fn [observed] (submission html.FormSubmission) ! {
		mut output := unsafe { &SubmittedFormObservation(observed) }
		output.submissions << submission
	})
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const descriptor=Object.getOwnPropertyDescriptor(HTMLFormElement.prototype,"submit"),method=descriptor.value;
if(method.name!=="submit"||method.length!==0||"prototype" in method||!descriptor.enumerable||!descriptor.writable||!descriptor.configurable)throw new Error("submit metadata");
let events=0;form.onsubmit=()=>events++;required.oninvalid=()=>events++;
Object.assign(form,{action:"/echo",method:"POST",enctype:"multipart/form-data",target:"upload",acceptCharset:"UTF-8"});
const files=new DataTransfer();files.items.add(new File([new Uint8Array([0,255,128,65])],"binary.bin",{type:"application/octet-stream"}));file.files=files.files;
if(form.method!=="post"||form.enctype!=="multipart/form-data"||form.encoding!==form.enctype||form.action!=="https://form-submit.test/echo")throw new Error("live form attributes");
if(form.submit()!==undefined||events!==0)throw new Error("legacy submission semantics");
for(const receiver of [null,undefined,{},document.createElement("div"),new Proxy(form,{})]){let rejected=false;try{method.call(receiver)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("submit receiver");}
'], runtime, mut messages)
	assert messages == []string{}
	assert observed.submissions.len == 1
	submission := observed.submissions[0]
	assert submission.method == .post && submission.encoding == .multipart
	assert submission.url.serialize() == 'https://form-submit.test/echo'
	assert submission.body.bytestr().contains('name="upload"; filename="binary.bin"\r\nContent-Type: application/octet-stream\r\n\r\n'+[u8(0),255,128,65].bytestr())
	assert model.has_submission_hook()
}

fn test_form_post_navigates_the_named_child_with_its_entity_body_and_boundary() {
	mut document := form_submit_document('<!doctype html><iframe id="frame" name="upload"></iframe><form id="form" target="upload"><input name="field" value="sent"></form>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	mut manager := browser_child_document_host(document, .javascriptcore)
	iframe := document.get_element_by_id('frame') or { panic('frame') }
	mut child := manager.ensure_child(iframe)!
	observed := &SubmittedFormObservation{}
	hook := fn [observed] (request &fetch.Request) !&fetch.Response {
		mut output := unsafe { &SubmittedFormObservation(observed) }
		output.methods << request.method
		output.bodies << request.body.bytes.clone()
		output.content_types << (request.header_list.get('Content-Type') or { '' })
		mut response := fetch.Response.create()
		response.url_list = [request.current_url()]
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/plain; charset=UTF-8'})
		response.set_body_bytes('posted &#63472; <b>literal</b>\r\nnext'.bytes())
		return response
	}
	child.set_navigation_fetch_hook(hook)
	runtime.evaluate_host('globalThis.uploadDone=false;globalThis.uploadText="";frame.onload=()=>{uploadText=frame.contentDocument.body.textContent;uploadDone=true};form.action="/echo";form.method="post";form.enctype="multipart/form-data";form.submit();')!
	deadline := time.now().add(5 * time.second)
	for {
		manager.poll(mut messages)
		html.main_thread_event_loop().process()
		platform.pump_native_events(0.001)
		if runtime.evaluate_host('uploadDone')! == 'true' { break }
		assert time.now() < deadline, messages.join('\n')
	}
	loaded_document := child.active_document() or { panic('loaded child document') }
	assert loaded_document.get_content_type() == 'text/plain'
	assert loaded_document.get_elements_by_tag_name('b').length() == 0
	assert observed.methods == ['POST']
	assert observed.bodies.len == 1 && observed.bodies[0].bytestr().contains('name="field"\r\n\r\nsent\r\n')
	boundary := observed.content_types[0].all_after('boundary=')
	assert boundary != '' && observed.bodies[0].bytestr().starts_with('--'+boundary+'\r\n')
	assert runtime.evaluate_host('uploadText')! == 'posted &#63472; <b>literal</b>\nnext'

	// The cleanup and replacement happen within one task, before host.poll().
	// A name lookup must not select the removed frame's retained context.
	runtime.evaluate_host('frame.remove();globalThis.replacement=Object.assign(document.createElement("iframe"),{id:"replacement",name:"upload"});document.body.append(replacement);form.querySelector("input").value="again";')!
	next_frame := document.get_element_by_id('replacement') or { panic('replacement frame') }
	mut next_child := manager.ensure_child(next_frame)!
	next_child.set_navigation_fetch_hook(hook)
	runtime.evaluate_host('uploadDone=false;uploadText="";replacement.onload=()=>{uploadText=replacement.contentDocument.body.textContent;uploadDone=true};form.submit();')!
	next_deadline := time.now().add(5 * time.second)
	for {
		manager.poll(mut messages)
		html.main_thread_event_loop().process()
		platform.pump_native_events(0.001)
		if runtime.evaluate_host('uploadDone')! == 'true' { break }
		assert time.now() < next_deadline, messages.join('\n')
	}
	assert observed.methods == ['POST','POST']
	assert observed.bodies[1].bytestr().contains('name="field"\r\n\r\nagain\r\n')
	assert runtime.evaluate_host('uploadText')! == 'posted &#63472; <b>literal</b>\nnext'
	model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(document.get_element_by_id('form') or { panic('form') }) })
	assert !model.has_submission_hook()
}
