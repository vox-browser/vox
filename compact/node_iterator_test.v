module main

import browserjs
import html

fn test_compact_node_iterator_traverses_filters_and_follows_removals() {
	mut document := html.parse_document('<!doctype html><div id="root"><p id="a">one</p><p id="b"><span id="c"></span></p><p id="d"></p></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const root=document.getElementById("root"),ids=[];
const iterator=document.createNodeIterator(root,NodeFilter.SHOW_ELEMENT);
if(!(iterator instanceof NodeIterator)||iterator.root!==root||iterator.referenceNode!==root||!iterator.pointerBeforeReferenceNode||iterator.whatToShow!==1)fail("initial state");
for(let node=iterator.nextNode();node;node=iterator.nextNode())ids.push(node.id);
if(ids.join()!=="root,a,b,c,d")fail("forward "+ids.join());
if(iterator.referenceNode.id!=="d"||iterator.pointerBeforeReferenceNode)fail("end state");
if(iterator.previousNode().id!=="d"||iterator.previousNode().id!=="c")fail("backward");
const texts=document.createNodeIterator(root,NodeFilter.SHOW_TEXT);
if(texts.nextNode().data!=="one"||texts.nextNode()!==null)fail("text filter");
const filtered=document.createNodeIterator(root,NodeFilter.SHOW_ELEMENT,{acceptNode(node){return node.id==="b"?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT;}});
const seen=[];for(let node=filtered.nextNode();node;node=filtered.nextNode())seen.push(node.id);
if(seen.join()!=="root,a,c,d")fail("reject does not skip children "+seen.join());
const removal=document.createNodeIterator(root,NodeFilter.SHOW_ELEMENT);
removal.nextNode();removal.nextNode();removal.nextNode();
if(removal.referenceNode.id!=="b")fail("before removal "+removal.referenceNode.id);
document.getElementById("b").remove();
if(removal.referenceNode.nodeType!==3||removal.referenceNode.data!=="one"||removal.pointerBeforeReferenceNode)fail("after removal "+removal.referenceNode.nodeName);
if(removal.nextNode().id!=="d")fail("continue after removal");
console.log("node iterator passed");
'], runtime, mut messages)
	assert messages == ['node iterator passed']
}
