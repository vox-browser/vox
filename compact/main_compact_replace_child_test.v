module main

import browserjs
import html

fn check_compact_replace_child(source string) ! {
	mut document := html.parse_document('<!doctype html><main id="host"><span id="old">old</span><b id="tail">tail</b></main><aside id="source"><em id="moved">moved</em></aside>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://replace-child.test/', [source], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('globalThis.replacementPassed===true')! == 'true'
}

fn test_replace_child_uses_native_order_fragment_splicing_and_live_collections() {
	check_compact_replace_child(r'
const nodes=host.childNodes,replace=Node.prototype.replaceChild;
const fresh=document.createElement("i");fresh.textContent="fresh";
if(host.replaceChild(fresh,old)!==old||old.parentNode!==null||old.isConnected||fresh.parentNode!==host||nodes.length!==2||nodes[0]!==fresh||host.textContent!=="freshtail")throw new Error("replacement identity");
const fragment=document.createDocumentFragment(),text=document.createTextNode("text"),comment=document.createComment("comment");fragment.append(text,comment);
if(replace.call(host,fragment,tail)!==tail||tail.parentNode!==null||fragment.childNodes.length!==0||nodes.length!==3||nodes[1]!==text||nodes[2]!==comment||text.parentNode!==host)throw new Error("fragment replacement");
if(host.replaceChild(fresh,fresh)!==fresh||nodes[0]!==fresh||nodes.length!==3)throw new Error("self replacement");
if(host.replaceChild(comment,fresh)!==fresh||nodes.length!==2||nodes[0]!==comment||nodes[1]!==text)throw new Error("moving a sibling");
if(source.textContent!=="moved")throw new Error("source cache setup");
host.replaceChild(moved,comment);
if(source.textContent!==""||source.childNodes.length!==0||moved.parentNode!==host||host.textContent!=="movedtext")throw new Error("moving from another parent");
const empty=document.createDocumentFragment();host.replaceChild(empty,text);
if(nodes.length!==1||nodes[0]!==moved||text.parentNode!==null)throw new Error("empty fragment");
globalThis.replacementPassed=true;
')!
}

fn test_replace_child_checks_brands_arguments_and_native_hierarchy_before_mutating() {
	check_compact_replace_child(r'
const method=Node.prototype.replaceChild,d=Object.getOwnPropertyDescriptor(Node.prototype,"replaceChild");
if(method.length!==2||method.name!=="replaceChild"||"prototype" in method||!d.writable||!d.enumerable||!d.configurable)throw new Error("metadata");
let hooks=0;const fake={get __state(){hooks++;throw new Error("state")},toString(){hooks++;throw new Error("conversion")}},proxy=new Proxy(old,{get(){hooks++;throw new Error("get")},getPrototypeOf(){hooks++;throw new Error("prototype")}});
function rejects(callback,name){let actual;try{callback()}catch(error){actual=error}if(!actual||(name==="TypeError"?!(actual instanceof TypeError):!(actual instanceof DOMException)&&actual.name===name)||actual.name!==name)throw new Error("expected "+name);}
for(const invalid of [null,undefined,{},fake,proxy,Object.create(old),1,"node",Symbol()]){
 rejects(()=>method.call(invalid,old,tail),"TypeError");rejects(()=>method.call(host,invalid,tail),"TypeError");rejects(()=>method.call(host,old,invalid),"TypeError");
}
rejects(()=>method.call(host),"TypeError");rejects(()=>method.call(host,old),"TypeError");rejects(()=>new method(old,tail),"TypeError");
rejects(()=>host.replaceChild(moved,moved),"NotFoundError");rejects(()=>host.replaceChild(host,old),"HierarchyRequestError");rejects(()=>host.replaceChild(document,old),"HierarchyRequestError");
if(hooks||host.firstChild!==old||source.firstChild!==moved||old.parentNode!==host)throw new Error("failed replacement changed the tree");
globalThis.replacementPassed=true;
')!
}

fn test_replace_child_supports_detached_parents_documents_and_adoption() {
	check_compact_replace_child(r'
const foreign=document.implementation.createHTMLDocument("foreign"),node=foreign.createElement("strong");node.textContent="foreign";foreign.body.append(node);
if(host.replaceChild(node,old)!==old||node.ownerDocument!==document||node.parentNode!==host||foreign.body.childNodes.length!==0)throw new Error("adoption");
const detached=document.createElement("section"),first=document.createTextNode("first"),last=document.createComment("last");detached.append(first);
if(detached.replaceChild(last,first)!==first||detached.firstChild!==last||last.parentNode!==detached||first.parentNode!==null||detached.isConnected)throw new Error("detached parent");
const replacement=foreign.createElement("body"),previous=foreign.body;
if(foreign.documentElement.replaceChild(replacement,previous)!==previous||foreign.body!==replacement||previous.parentNode!==null)throw new Error("document element child");
globalThis.replacementPassed=true;
')!
}
