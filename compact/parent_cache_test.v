module main

import browserjs
import html

fn test_native_parent_cache_uses_mutation_versions_and_replays_pending_writes() {
	$if !darwin { return }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	_ = runtime.evaluate_host(r'
const __state={operations:[]},__dirtyElementStates=new Set();
const __elementApply=Reflect.apply,__elementRecordGet=WeakMap.prototype.get,__elementRecordSet=WeakMap.prototype.set;
let version=1,queries=0,cacheable=true,parent={name:"first"};
globalThis.__ladybirdDOMTreeVersion=()=>version;
function __queryElements(key,action){
 if(key!=="target"||action!=="cachedParent")throw new Error("unexpected parent query");
 queries++;__state.operations=[];__dirtyElementStates.clear();
 return {parent,cacheable};
}
function __queryElement(value){return value;}
')!
	_ = runtime.evaluate_host(compact_native_parent_bootstrap())!
	assert runtime.evaluate_host(r'
const target={bridgeKey:"target"};
__compactNativeParent(target)===parent&&__compactNativeParent(target)===parent&&queries===1
')! == 'true'
	assert runtime.evaluate_host(r'
parent={name:"second"};version++;
__compactNativeParent(target)===parent&&queries===2
')! == 'true'
	assert runtime.evaluate_host(r'
parent={name:"pending"};__state.operations.push({op:"appendCreated"});
const afterOperation=__compactNativeParent(target)===parent&&queries===3;
parent={name:"dirty"};__dirtyElementStates.add(target);
afterOperation&&__compactNativeParent(target)===parent&&queries===4&&__compactNativeParent(target)===parent&&queries===4
')! == 'true'
	assert runtime.evaluate_host(r'
version=-1;parent={name:"unrepresentable"};
__compactNativeParent(target)===parent&&__compactNativeParent(target)===parent&&queries===6
')! == 'true'
	assert runtime.evaluate_host(r'
version=3;cacheable=false;parent=null;
__compactNativeParent(target)===null&&__compactNativeParent(target)===null&&queries===8
')! == 'true'
}

fn test_native_parent_cache_tracks_native_moves_pending_appends_text_and_disconnected_owners() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div id="first"><span id="target">text</span></div><div id="second"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.parentTarget=document.getElementById("target");
parentTarget.__state.nativeParent=true;
if(parentTarget.parentNode!==first||parentTarget.parentElement!==first)throw new Error("initial parent identity");
globalThis.parentText=parentTarget.firstChild;
if(parentText.parentNode!==parentTarget||parentText.parentNode!==parentTarget)throw new Error("text parent identity");
'], runtime, mut messages)
	assert messages == []string{}
	mut target := document.get_element_by_id('target')?
	mut second := document.get_element_by_id('second')?.as_node()
	second.append_child(target.as_node())!
	assert runtime.evaluate_host('parentTarget.parentNode===second&&parentTarget.parentElement===second')! == 'true'
	assert runtime.evaluate_host('first.appendChild(parentTarget);parentTarget.parentNode===first')! == 'true'
	assert voidptr(target.as_node().parent()?) == voidptr(document.get_element_by_id('first')?.as_node())
	_ = runtime.evaluate_host('parentTarget.className="pending-style";parentTarget.parentNode')!
	assert target.get_attribute_value('class') == 'pending-style'
	mut target_node := target.as_node()
	target_node.remove(false)
	assert runtime.evaluate_host('parentTarget.parentNode===null&&parentTarget.parentElement===null')! == 'true'
	// Disconnected owners cannot be cached against a document clock: adoption
	// and subsequent mutations can belong to a different document altogether.
	mut foreign := html.parse_document('<!doctype html><main id="foreign"><aside id="other"></aside></main>')
	defer { foreign.finalize() }
	adopted := foreign.adopt_node_binding(target.as_node())!
	mut foreign_parent := foreign.get_element_by_id('foreign')?.as_node()
	foreign_parent.append_child(adopted)!
	assert runtime.evaluate_host('(()=>{const value=JSON.parse(__ladybirdElementQuery(JSON.stringify({key:parentTarget.__state.bridgeKey,action:"cachedParent",selector:""})));return !value.cacheable&&value.parent.id==="foreign"})()')! == 'true'
	mut other := foreign.get_element_by_id('other')?.as_node()
	other.append_child(adopted)!
	assert runtime.evaluate_host('(()=>{const value=JSON.parse(__ladybirdElementQuery(JSON.stringify({key:parentTarget.__state.bridgeKey,action:"cachedParent",selector:""})));return !value.cacheable&&value.parent.id==="other"})()')! == 'true'
	// Foreign-document facade construction is gated by the existing native
	// event-owner binding. After adopting back, this realm’s facade works again.
	repatriated := document.adopt_node_binding(adopted)!
	second.append_child(repatriated)!
	assert runtime.evaluate_host('parentTarget.parentNode===second&&parentText.parentNode===parentTarget')! == 'true'
	assert messages == []string{}
}
