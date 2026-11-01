module main

import browserjs
import dom
import html
import page
import time

fn check_compact_request_submit(source string) ! {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><form id="form"><input id="field" name="prompt" required><button id="send">Send</button><button id="ordinary" type="button">Other</button></form><form id="other"><button id="outsider">Other form</button></form><div id="host"></div>',
		dom.URL{value: 'https://request-submit.test/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://request-submit.test/', [source], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('globalThis.requestSubmitPassed===true')! == 'true'
}

fn test_request_submit_validates_live_values_and_delivers_cancellable_native_events() {
	check_compact_request_submit(r'
let submissions=0,invalid=0,clicks=0;
form.addEventListener("submit",event=>{if(!event.isTrusted||event.target!==form||!event.cancelable||!event.bubbles)throw new Error("native submit event");submissions++;event.preventDefault()});
field.addEventListener("invalid",event=>{if(!event.isTrusted||event.target!==field)throw new Error("native invalid event");invalid++;event.preventDefault()});
send.addEventListener("click",()=>clicks++);
if(form.requestSubmit()!==undefined||submissions!==0||invalid!==1)throw new Error("constraint validation");
field.value="Reply with exactly: Vox ready.";
form.requestSubmit();form.requestSubmit(null);form.requestSubmit(undefined);form.requestSubmit(send);
if(submissions!==4||invalid!==1||clicks!==0||field.value!=="Reply with exactly: Vox ready.")throw new Error("live valid submissions "+submissions);
field.value="";send.setAttribute("formnovalidate","");form.requestSubmit(send);
if(submissions!==5||invalid!==1)throw new Error("submitter validation override");
globalThis.requestSubmitPassed=true;
')!
}

fn test_request_submit_checks_receiver_and_submitter_without_author_hooks() {
	check_compact_request_submit(r'
const method=HTMLFormElement.prototype.requestSubmit,d=Object.getOwnPropertyDescriptor(HTMLFormElement.prototype,"requestSubmit");
if(method.name!=="requestSubmit"||method.length!==0||"prototype" in method||!d.writable||!d.enumerable||!d.configurable)throw new Error("metadata");
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")},toString(){hooks++;throw new Error("conversion")}},proxy=new Proxy(send,{get(){hooks++;throw new Error("get")},getPrototypeOf(){hooks++;throw new Error("prototype")}});
function rejects(callback,name){let actual;try{callback()}catch(error){actual=error}if(!actual||actual.name!==name||(name==="TypeError"?!(actual instanceof TypeError):!(actual instanceof DOMException)))throw new Error("expected "+name);}
for(const receiver of [null,undefined,{},host,Object.create(form),new Proxy(form,{})])rejects(()=>method.call(receiver,fake),"TypeError");
for(const submitter of [{},fake,proxy,Object.create(send),1,"send",Symbol(),host,field,ordinary,document,document.createElementNS("http://www.w3.org/2000/svg","svg")])rejects(()=>method.call(form,submitter),"TypeError");
rejects(()=>new method(),"TypeError");rejects(()=>form.requestSubmit(outsider),"NotFoundError");
if(hooks)throw new Error("author hooks invoked");
globalThis.requestSubmitPassed=true;
')!
}

fn test_request_submit_tracks_reassociation_and_script_created_submitters() {
	check_compact_request_submit(r'
let submissions=0;form.addEventListener("submit",event=>{submissions++;event.preventDefault()});field.value="ready";
function submit(label,button){try{form.requestSubmit(button)}catch(error){throw new Error(label+": "+error.name+": "+error.message)}}
const button=document.createElement("button");form.appendChild(button);submit("created button",button);
button.setAttribute("form","other");let rejected=false;try{form.requestSubmit(button)}catch(error){rejected=error instanceof DOMException&&error.name==="NotFoundError"}if(!rejected)throw new Error("reassociated submitter");
button.removeAttribute("form");submit("reassociated button",button);
const image=document.createElement("input");image.setAttribute("type","image");form.appendChild(image);submit("image input",image);
if(submissions!==3)throw new Error("created submitters "+submissions);
globalThis.requestSubmitPassed=true;
')!
}
