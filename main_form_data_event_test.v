module main

import browserjs
import html

fn test_formdata_event_exposes_live_native_payload_and_changes_constructed_entries() {
	mut document := html.parse_document('<!doctype html><form id="form"><input name="prompt" value="old"><input name="duplicate" value="one"><input name="duplicate" value="two"></form>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://form-data-event.test/', [r'
globalThis.valid=false;globalThis.savedEvent=null;globalThis.savedData=null;
globalThis.file=new File([new Uint8Array([0,128,255])],"part.bin",{type:"application/custom",lastModified:42});
form.addEventListener("formdata",event=>{
 savedEvent=event;savedData=event.formData;
 valid=event instanceof FormDataEvent&&event instanceof Event&&event.isTrusted&&event.target===form&&event.currentTarget===form&&event.bubbles&&!event.cancelable&&event.formData===savedData&&savedData instanceof FormData;
 savedData.set("prompt","changed");savedData.delete("duplicate");savedData.append("metadata","ready");savedData.append("file",file);
},{once:true});
globalThis.result=new FormData(form);
if(!valid||result.get("prompt")!=="changed"||result.has("duplicate")||result.get("metadata")!=="ready"||result.get("file")!==file)throw new Error("native formdata payload");
'], runtime, mut messages)
	assert messages == []string{}
	native_event := runtime.native_event(runtime.evaluate_host_value('savedEvent')!)!
	mut payload := unsafe { &html.FormDataEvent(native_event) }.form_data() or { panic('payload') }
	payload.set(html.create_form_data_string_entry('metadata', 'native'))
	assert runtime.evaluate_host('savedData.get("metadata")==="native"&&savedData.get("file")===file&&result.get("metadata")==="ready"')! == 'true'
	mut data := runtime.native_form_data(runtime.evaluate_host_value('savedData')!)!
	data.set('metadata', 'direct')
	entries := payload.entries()
	value := entries.filter(it.name == 'metadata')[0].value
	assert value is string
	assert value as string == 'direct'
	runtime.evaluate_host('savedData.set("metadata","javascript");0')!
	updated := payload.entries().filter(it.name == 'metadata')[0].value
	assert updated is string
	assert updated as string == 'javascript'
}

fn test_form_data_event_constructor_preserves_payload_identity_flags_and_brands() {
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://form-data-event.test/', [r'
const data=new FormData();data.set("field","one");
const order=[],event=new FormDataEvent({toString(){order.push("type");return "custom"}},{get bubbles(){order.push("bubbles");return true},get cancelable(){order.push("cancelable");return true},get composed(){order.push("composed");return true},get formData(){order.push("formData");return data}});
if(order.join()!=="type,bubbles,cancelable,composed,formData"||event.type!=="custom"||!event.bubbles||!event.cancelable||!event.composed||event.isTrusted||event.formData!==data||Object.getPrototypeOf(event)!==FormDataEvent.prototype||Object.prototype.toString.call(event)!=="[object FormDataEvent]")throw new Error("constructor payload");
class Child extends FormDataEvent{}const child=new Child("child",{formData:data});if(!(child instanceof Child)||child.formData!==data)throw new Error("subclass");
const descriptor=Object.getOwnPropertyDescriptor(FormDataEvent.prototype,"formData"),getter=descriptor.get;
if(FormDataEvent.length!==2||FormDataEvent.prototype.constructor!==FormDataEvent||Object.getPrototypeOf(FormDataEvent.prototype)!==Event.prototype||!descriptor.enumerable||!descriptor.configurable||descriptor.set!==undefined)throw new Error("metadata");
let hooks=0;const fake={get formData(){hooks++;throw new Error("author hook")}},proxy=new Proxy(data,{get(){hooks++;throw new Error("proxy")},getPrototypeOf(){hooks++;throw new Error("prototype")}});
function rejects(callback){let rejected=false;try{callback()}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("expected TypeError");}
for(const value of [undefined,null,{},fake,proxy,Object.create(data)])rejects(()=>new FormDataEvent("bad",{formData:value}));
for(const value of [undefined,null,{},new Event("formdata"),data])rejects(()=>getter.call(value));
rejects(()=>new FormDataEvent("missing"));rejects(()=>new FormDataEvent("missing",{}));rejects(()=>FormDataEvent("call",{formData:data}));
const marker={};let caught;try{new FormDataEvent("abrupt",{get formData(){throw marker}})}catch(error){caught=error}if(caught!==marker||hooks)throw new Error("conversion hooks");
data.set("field","two");if(event.formData.get("field")!=="two"||child.formData!==event.formData)throw new Error("shared constructor payload");
'], runtime, mut messages)
	assert messages == []string{}
}
