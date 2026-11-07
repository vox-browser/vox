module main

import browserjs
import html

fn test_compact_query_selector_all_returns_static_branded_node_lists() {
	mut document := html.parse_document('<!doctype html><main id="host"><i id="first"></i><i id="last"></i></main>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const saved=document.querySelectorAll("main i"),local=host.querySelectorAll("i"),live=host.childNodes;
for(const list of [saved,local]){
 if(!(list instanceof NodeList)||Array.isArray(list)||Object.prototype.toString.call(list)!=="[object NodeList]")throw new Error("query NodeList interface");
 if(list.length!==2||list[0]!==first||list.item(1)!==last||list.item(2)!==null||list.item(-1)!==null||list[2]!==undefined)throw new Error("query NodeList indices");
 if([...list.keys()].join()!=="0,1"||[...list.values()][1]!==last||[...list.entries()][1][0]!==1)throw new Error("query NodeList iteration");
 const owner={},seen=[];list.forEach(function(node,index,collection){if(this!==owner||collection!==list)throw new Error("forEach arguments");seen.push(node.id+index);},owner);
 if(seen.join()!=="first0,last1"||Object.keys(list).join()!=="0,1")throw new Error("query NodeList enumeration");
 let missing=false;try{list.item()}catch(error){missing=error instanceof TypeError;}if(!missing)throw new Error("NodeList missing index");
}
first.remove();const added=document.createElement("i");added.id="added";host.appendChild(added);
if(saved.length!==2||saved.item(0)!==first||local.item(0)!==first)throw new Error("query list must be static");
if(live.length!==2||live.item(0)!==last||live.item(1)!==added)throw new Error("child list must stay live");
const current=host.querySelectorAll("i");if(current===local||current.item(0)!==last||current.item(1)!==added)throw new Error("fresh query");
const fragment=document.createDocumentFragment();fragment.appendChild(document.createElement("em"));
if(!(fragment.querySelectorAll("em") instanceof NodeList)||fragment.querySelectorAll("em").item(0)!==fragment.firstChild)throw new Error("fragment query");
const detached=document.implementation.createHTMLDocument("other");detached.body.appendChild(detached.createElement("b"));
if(!(detached.querySelectorAll("b") instanceof NodeList)||detached.querySelectorAll("b").item(0)!==detached.body.firstChild)throw new Error("detached document query");
if(document.querySelectorAll(".absent").item(-1)!==null)throw new Error("empty query list");
'], runtime, mut messages)
	assert messages == []string{}
}
