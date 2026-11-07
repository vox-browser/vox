module main

import browserjs
import html

fn check_compact_custom_events(source string) ! {
	mut document := html.parse_document('<!doctype html><div id="host"><textarea id="field"></textarea></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [source], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('globalThis.customEventsPassed===true')! == 'true'
}

fn test_custom_element_events_share_native_dispatch_propagation_and_cancellation() {
	check_compact_custom_events(r'
const order=[],event=new Event("refresh",{bubbles:true,cancelable:true});
function observe(label,target,phase){return function(actual){
 if(actual!==event||this!==target||actual.currentTarget!==target||actual.target!==field||actual.eventPhase!==phase||actual.isTrusted)throw new Error("native custom event "+label);
 order.push(label);
};}
document.addEventListener("refresh",observe("capture",document,Event.CAPTURING_PHASE),true);
EventTarget.prototype.addEventListener.call(field,"refresh",observe("direct",field,Event.AT_TARGET));
field.addEventListener("refresh",function(actual){observe("field",field,Event.AT_TARGET).call(this,actual);actual.preventDefault();host.dataset.refreshed="yes";},{once:true});
host.addEventListener("refresh",observe("parent",host,Event.BUBBLING_PHASE));
document.addEventListener("refresh",observe("document",document,Event.BUBBLING_PHASE));
if(field.dispatchEvent(event)!==false||!event.defaultPrevented||order.join(",")!=="capture,direct,field,parent,document")throw new Error("custom propagation "+order);
if(event.currentTarget!==null||event.eventPhase!==Event.NONE||host.dataset.refreshed!=="yes")throw new Error("custom dispatch cleanup");
globalThis.customEventsPassed=true;
')!
}

fn test_custom_element_listeners_keep_native_once_abort_removal_and_created_identity() {
	check_compact_custom_events(r'
const target=document.createElement("button");host.appendChild(target);
const controller=new AbortController(),calls=[];
const removed=()=>{throw new Error("removed callback")};target.addEventListener("Refresh",removed);target.removeEventListener("Refresh",removed);
target.addEventListener("Refresh",()=>{throw new Error("aborted callback")},{signal:controller.signal});controller.abort();
const listener={handleEvent(event){if(this!==listener||event.target!==target||event.currentTarget!==target)throw new Error("created custom target");calls.push(event.type);}};
target.addEventListener("Refresh",listener,{once:true});target.addEventListener("Refresh",listener,{once:true});
for(let i=0;i<2;i++)if(!target.dispatchEvent(new Event("Refresh")))throw new Error("custom return value");
target.addEventListener("refresh",()=>calls.push("lowercase"));target.dispatchEvent(new Event("refresh"));
if(calls.join(",")!=="Refresh,lowercase")throw new Error("custom listener lifecycle "+calls);
globalThis.customEventsPassed=true;
')!
}
