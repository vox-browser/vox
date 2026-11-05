module main

import browserjs
import dom
import html

fn test_compact_document_owner_reads_registered_nodes_without_mutating_identity_maps() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut foreign := dom.Document.create(dom.url_about_blank())
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); foreign.finalize(); document.finalize() }
	mut binding := &CompactElementQueryBinding{document:document, runtime:&runtime}
	mut element := document.create_element('div')!
	text := document.create_text_node('text')
	comment := document.create_comment('comment')
	fragment := document.create_document_fragment()
	binding.elements['element'] = element
	for key, node in {'text':text.as_node(), 'comment':comment.as_node(), 'fragment':fragment.as_node(), 'document':document.as_node()} {
		binding.nodes[key] = node
	}
	for key in ['element', 'text', 'comment', 'fragment'] { assert binding.has_root_document_owner(key) }
	for key in ['', 'unknown', 'document'] { assert !binding.has_root_document_owner(key) }
	for node in [element.as_node(), text.as_node(), comment.as_node(), fragment.as_node()] { foreign.adopt_node(node) }
	for key in ['element', 'text', 'comment', 'fragment'] { assert !binding.has_root_document_owner(key) }
	document.adopt_node(element.as_node())
	assert binding.has_root_document_owner('element')
	assert binding.nodes.len == 4 && binding.elements.len == 1 && binding.keys.len == 0
}

fn test_compact_document_owner_bootstrap_checks_pending_edits_and_captures_intrinsics() {
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	_ = runtime.evaluate_host(r'
const document={},foreign={},__state={operations:[]},__dirtyElementStates=new Set(),__elementApply=Reflect.apply;
let ownerIsRoot=true,reads=0,queries=0,keyReads=0;
function __compactNodeState(object){if(!object||!object.state)throw new TypeError("brand");return object.state;}
function __queryElements(key,action,value){if(action!=="ownerDocument"||value!=="")throw new Error("query");queries++;__state.operations=[];__dirtyElementStates.clear();return foreign;}
globalThis.__ladybirdRootDocumentOwner=key=>{reads++;return ownerIsRoot&&key==="known";};
')!
	_ = runtime.evaluate_host(compact_document_owner_bootstrap())!
	assert runtime.evaluate_host(r'
const node={state:{get bridgeKey(){keyReads++;return "known";}}};
__compactOwnerDocument(node)===document&&reads===1&&queries===0&&keyReads===1
')! == 'true'
	assert runtime.evaluate_host(r'
__state.operations.push({op:"append"});
const pending=__compactOwnerDocument(node)===foreign&&reads===1&&queries===1;
__dirtyElementStates.add({attributesDirty:true});
pending&&__compactOwnerDocument(node)===foreign&&reads===1&&queries===2
')! == 'true'
	assert runtime.evaluate_host(r'
ownerIsRoot=false;const adopted=__compactOwnerDocument(node)===foreign&&queries===3;
ownerIsRoot=true;const returned=__compactOwnerDocument(node)===document&&reads===3;
globalThis.__ladybirdRootDocumentOwner=()=>{throw new Error("replaced callback");};
Object.defineProperty(Set.prototype,"size",{get(){throw new Error("replaced size");},configurable:true});
adopted&&returned&&__compactOwnerDocument(node)===document&&reads===4&&__compactOwnerDocument({state:{bridgeKey:"unknown"}})===foreign&&queries===4
')! == 'true'
	assert runtime.evaluate_host(r'
const before=reads;
const unusual=__compactOwnerDocument({state:{bridgeKey:{toString(){throw new Error("coerced")}}}})===foreign&&reads===before;
let branded=false;try{__compactOwnerDocument({});}catch(error){branded=error instanceof TypeError;}
unusual&&branded
')! == 'true'
}

fn test_compact_document_owner_keeps_live_javascript_identity_and_flushes_unrelated_writes() {
	mut document := html.parse_document('<!doctype html><body><div id="target">text</div><aside id="dirty"></aside></body>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.ownerTarget=document.getElementById("target");
const other=document.implementation.createHTMLDocument("other");
for(const node of [ownerTarget,ownerTarget.firstChild,document.createElement("b"),document.createTextNode("x"),document.createComment("y"),document.createDocumentFragment()]){
 if(node.ownerDocument!==document||node.ownerDocument!==document)throw new Error("main owner");
 if(node.nodeType!==11){other.body.appendChild(node);if(node.ownerDocument!==other)throw new Error("foreign adoption");document.body.appendChild(node);if(node.ownerDocument!==document)throw new Error("return adoption");}
}
document.getElementById("dirty").className="pending";
if(ownerTarget.ownerDocument!==document||document.ownerDocument!==null||other.ownerDocument!==null)throw new Error("owner after pending edit");
globalThis.documentOwnerPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('documentOwnerPassed')! == 'true'
	assert document.get_element_by_id('dirty')?.get_attribute_value('class') == 'pending'
	mut foreign := dom.Document.create(dom.url_about_blank())
	defer { foreign.finalize() }
	target := document.get_element_by_id('target')?
	foreign.adopt_node(target.as_node())
	assert runtime.evaluate_host('ownerTarget.ownerDocument!==document&&ownerTarget.ownerDocument.nodeType===9')! == 'true'
	document.adopt_node(target.as_node())
	assert runtime.evaluate_host('ownerTarget.ownerDocument===document')! == 'true'
}

@[heap]
struct DocumentOwnerAdoptionProbe {
	destination &dom.Document
	node &dom.Node
mut:
	armed bool = true
	calls int
}

fn document_owner_adopt_on_mutation(opaque voidptr) {
	mut probe := unsafe { &DocumentOwnerAdoptionProbe(opaque) }
	if !probe.armed { return }
	probe.armed = false
	probe.calls++
	mut destination := unsafe { &dom.Document(probe.destination) }
	destination.adopt_node(probe.node)
}

fn test_compact_document_owner_replays_unrelated_edits_before_observing_reentrant_adoption() {
	mut document := html.parse_document('<!doctype html><body><div id="target"></div><aside id="dirty"></aside></body>')
	mut foreign := dom.Document.create(dom.url_about_blank())
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); foreign.finalize(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'globalThis.ownerTarget=document.getElementById("target");globalThis.ownerDirty=document.getElementById("dirty");if(ownerTarget.ownerDocument!==document)throw new Error("initial");'], runtime, mut messages)
	assert messages == []string{}
	target := document.get_element_by_id('target')?
	mut probe := &DocumentOwnerAdoptionProbe{destination:foreign, node:target.as_node()}
	document.set_editing_history_hook(dom.DocumentEditingHistoryHook{target:probe, notify_dom_mutation:document_owner_adopt_on_mutation})
	assert runtime.evaluate_host('ownerDirty.className="replay";ownerTarget.ownerDocument!==document')! == 'true'
	assert probe.calls == 1
	assert voidptr(target.document()) == voidptr(foreign)
}
