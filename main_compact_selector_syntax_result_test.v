module main

import browserjs
import html

fn test_compact_selector_syntax_results_keep_fresh_errors_replay_and_original_host_failures() {
	$if !darwin { return }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	source := r'(()=>{
 class DOMException extends Error{constructor(message,name){super(message);this.name=name;}}
 const __elementApply=Reflect.apply,__state={operations:[]};let pending={},calls=0,applied=0;
 const hostError=new Error("host failure"),replayError=new Error("replay failure");let failReplay=false;
 function __pendingElementStates(){return pending;}
 function __queryElement(value){return value;}
 function __nativeElementQuery(source){
  calls++;const request=JSON.parse(source);
  if(request.snapshot){applied++;if(failReplay)throw replayError;}
  if(request.selector==="host-error")throw hostError;
  if(request.selector==="valid")return request.action==="matches"?"true":"[]";
  return JSON.stringify({__voxSelectorSyntaxError:"SyntaxError: invalid fixture"});
 }
 ' + compact_element_query_bootstrap() + r'
 function invalid(){try{__queryElements("root","querySelectorAll",":first");}catch(error){if(error.name!=="SyntaxError"||error.message!=="invalid fixture")throw error;return error;}throw new Error("missing failure");}
 const first=invalid(),second=invalid();
 if(first===second||calls!==2)throw new Error("syntax request was skipped or exception identity reused");
 __state.operations.push({kind:"change"});invalid();
 if(calls!==3||applied!==1||__state.operations.length!==0)throw new Error("operation replay did not precede failure");
 pending={owner:{attributesDirty:true}};invalid();
 if(calls!==4||applied!==2||pending.owner.attributesDirty!==false)throw new Error("attribute replay did not precede failure");
 failReplay=true;
 try{invalid();throw new Error("missing replay error");}catch(error){if(error!==replayError)throw error;}
 pending={};failReplay=false;
 try{__queryElements("root","querySelectorAll","host-error");throw new Error("missing host error");}catch(error){if(error!==hostError)throw error;}
 Object.prototype.__voxSelectorSyntaxError="spoof";
 try{
  if(__queryElements("root","querySelectorAll","valid").length!==0||__queryElements("root","matches","valid")!==true)throw new Error("inherited property became a syntax failure");
 }finally{delete Object.prototype.__voxSelectorSyntaxError;}
 return true;
 })()'
	assert runtime.evaluate_host(source)! == 'true'
}

fn test_compact_native_selector_syntax_transport_covers_first_failure_and_preserves_live_queries() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><section id="scope"><span class="expand">label</span></section>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	owner := document.get_element_by_id('scope')?
	runtime.define_host_function('__selectorNativeClass', fn [owner] (_ string) !string {
		return owner.get_attribute_value('class')
	})!
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const owner=document.getElementById("scope");
const request={key:owner.__state.bridgeKey,action:"querySelectorAll",selector:".expand:first"};
const result=JSON.parse(__ladybirdElementQuery(JSON.stringify(request)));
if(result.__voxSelectorSyntaxError!=="SyntaxError: Failed to parse selector")throw new Error("native parse failure crossed as an exception");
function invalid(){try{owner.querySelectorAll(".expand:first");}catch(error){if(error.name!=="SyntaxError")throw error;return error;}throw new Error("missing syntax error");}
const first=invalid(),second=invalid();if(first===second)throw new Error("exception identity was reused");
owner.className="changed";invalid();
if(__selectorNativeClass("")!=="changed")throw new Error("native mutation did not precede syntax failure");
if(owner.querySelectorAll(".expand").length!==1||owner.querySelector(".expand").textContent!=="label")throw new Error("valid neighboring query changed");
for(let i=0;i<3;i++)invalid();
console.log("selector syntax results passed");
'], runtime, mut messages)
	assert messages == ['selector syntax results passed']
}
