module main

import browserjs
import html

fn test_compact_tree_walker_traverses_live_native_nodes_and_rejected_subtrees() {
	mut document := html.parse_document('<!doctype html><div id="root"><section id="skip"><b id="one">text</b><!--anchor--><i id="two"></i></section><svg id="reject"><g id="hidden"/></svg><p id="three"></p></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://walker.test/', [r'
const root=document.getElementById("root"),one=document.getElementById("one"),two=document.getElementById("two"),three=document.getElementById("three"),skip=document.getElementById("skip");
const visited=[],filter={acceptNode(node){if(this!==filter)throw new Error("filter receiver");visited.push(node.id);return node.id==="reject"?2:node.id==="skip"?3:1;}};
const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT,filter);
if(!(walker instanceof TreeWalker)||walker.root!==root||walker.currentNode!==root||walker.whatToShow!==1||walker.filter!==filter||Object.prototype.toString.call(walker)!=="[object TreeWalker]")throw new Error("walker identity");
const ids=[];for(let node;node=walker.nextNode();)ids.push(node.id);
if(ids.join()!=="one,two,three"||visited.includes("hidden")||walker.currentNode!==three)throw new Error("filtered preorder "+ids);
if(walker.previousNode()!==two||walker.previousSibling()!==one||walker.nextSibling()!==two||walker.parentNode()!==root||walker.parentNode()!==null)throw new Error("relative traversal");
if(walker.firstChild()!==one||walker.nextSibling()!==two||walker.nextSibling()!==three||walker.previousSibling()!==two)throw new Error("skipped parent siblings");
walker.currentNode=root;if(walker.lastChild()!==three||walker.previousNode()!==two||walker.previousNode()!==one||walker.previousNode()!==root)throw new Error("reverse traversal");
walker.currentNode=skip;if(walker.firstChild()!==one)throw new Error("first child");walker.currentNode=skip;if(walker.lastChild()!==two)throw new Error("last child");
walker.currentNode=one;const added=document.createElement("em");added.id="added";one.after(added);if(walker.nextNode()!==added)throw new Error("live insertion");added.remove();if(walker.nextNode()!==null||walker.currentNode!==added)throw new Error("detached current");
const fragment=document.createDocumentFragment();fragment.appendChild(document.createComment("comment"));fragment.appendChild(document.createTextNode("text"));
const mixed=document.createTreeWalker(fragment,NodeFilter.SHOW_COMMENT|NodeFilter.SHOW_TEXT);
if(mixed.nextNode()!==fragment.firstChild||mixed.nextNode()!==fragment.lastChild||mixed.nextNode()!==null)throw new Error("non-element traversal");
const detached=document.implementation.createHTMLDocument("");if(detached.createTreeWalker(fragment).root!==fragment)throw new Error("detached document factory");
// Pikabu uses this traversal to choose a cookie overlay z-index.
one.style.zIndex="17";three.style.zIndex="6";document.getElementById("hidden").style.zIndex="999";
const z=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT,node=>node.nodeName.toUpperCase()==="SVG"?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT);let max=0;for(let node;node=z.nextNode();)max=Math.max(max,Number(getComputedStyle(node).zIndex)||0);if(max!==17)throw new Error("overlay z-index "+max);
globalThis.treeWalkerTraversalPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('treeWalkerTraversalPassed')! == 'true'
}

fn test_compact_tree_walker_filter_exceptions_reentry_and_webidl_conversion() {
	mut document := html.parse_document('<!doctype html><div id="root"><b id="one">text</b><i id="two"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://walker.test/', [r'
const root=document.getElementById("root"),one=document.getElementById("one"),two=document.getElementById("two"),original={sentinel:true};
let calls=0,fail=true;const callback=function(node){"use strict";if(this!==undefined)throw new Error("callable filter receiver");calls++;if(fail)throw original;return 65537;};
const walker=document.createTreeWalker(root,1,callback);try{walker.nextNode();throw new Error("missing exception");}catch(error){if(error!==original)throw error;}
if(calls!==1||walker.currentNode!==root)throw new Error("exception changed current");fail=false;if(walker.nextNode()!==one)throw new Error("filter stayed active");
let reentered=false;const recursive=document.createTreeWalker(root,1,node=>{try{recursive.nextNode();}catch(error){reentered=error instanceof DOMException&&error.name==="InvalidStateError";}return 1;});if(recursive.nextNode()!==one||!reentered)throw new Error("filter reentry");
let converted=0;const numeric=document.createTreeWalker(root,{valueOf(){converted++;return 4294967297;}},null);if(converted!==1||numeric.whatToShow!==1||numeric.filter!==null)throw new Error("whatToShow conversion");
let maskedCalls=0;const masked=document.createTreeWalker(root,NodeFilter.SHOW_COMMENT,()=>{maskedCalls++;return 1;});if(masked.nextNode()!==null||maskedCalls!==0)throw new Error("masked callback");
const throwing=document.createTreeWalker(root,1,()=>({valueOf(){throw original;}}));try{throwing.nextNode();throw new Error("missing conversion error");}catch(error){if(error!==original)throw error;}if(throwing.currentNode!==root)throw new Error("conversion changed current");
const mutable={acceptNode(){return 3;}};const live=document.createTreeWalker(root,1,mutable);mutable.acceptNode=()=>1;if(live.nextNode()!==one)throw new Error("live callback lookup");
const all=document.createTreeWalker(root);if(all.whatToShow!==4294967295||all.filter!==null||all.nextNode()!==one||all.nextNode()!==one.firstChild)throw new Error("default mask");
all.currentNode=document.body;if(all.currentNode!==document.body||all.root!==root)throw new Error("outside root assignment");
let invalid=0;for(const call of [()=>document.createTreeWalker(),()=>document.createTreeWalker(null),()=>document.createTreeWalker({nodeType:1}),()=>document.createTreeWalker(root,1,5),()=>document.createTreeWalker(root,1n),()=>document.createTreeWalker.call({},root),()=>TreeWalker(),()=>new TreeWalker(),()=>NodeFilter(),()=>new NodeFilter(),()=>TreeWalker.prototype.nextNode.call({}),()=>{all.currentNode=null;}])try{call();}catch(error){if(error instanceof TypeError)invalid++;else throw error;}
if(invalid!==12||document.createTreeWalker.length!==1||typeof NodeFilter!=="function"||NodeFilter.prototype!==undefined)throw new Error("IDL validation "+invalid);
for(const name of ["root","filter","whatToShow"])if(Object.getOwnPropertyDescriptor(TreeWalker.prototype,name).set!==undefined)throw new Error("readonly "+name);
globalThis.treeWalkerFilterPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('treeWalkerFilterPassed')! == 'true'
}
