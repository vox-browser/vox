module main

import browserjs
import html

fn test_compact_create_comment_preserves_native_anchors_data_and_identity() {
	mut document := html.parse_document('<!doctype html><main id="host"><span id="tail"></span></main>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://comment.test/', [r'
const fragment=document.createDocumentFragment(),start=document.createComment("start"),end=document.createComment("end");
for(const node of [start,end])if(node.nodeType!==8||node.nodeName!=="#comment"||node.ownerDocument!==document||node.isConnected||node.childNodes.length!==0)throw new Error("detached comment");
fragment.appendChild(start);fragment.appendChild(end);
host.insertBefore(fragment,tail);
if(host.firstChild!==start||start.nextSibling!==end||end.previousSibling!==start||end.nextSibling!==tail||host.children.length!==1||!start.isConnected)throw new Error("comment anchors");
const content=document.createTextNode("content");host.insertBefore(content,end);
start.data="Привет 💬";end.nodeValue=null;
if(start.data!=="Привет 💬"||start.nodeValue!==start.data||start.textContent!==start.data||start.length!==9||end.data!==""||host.textContent!=="content")throw new Error("comment data");
const copy=start.cloneNode(true);
if(copy===start||copy.nodeType!==8||copy.data!==start.data||copy.parentNode!==null)throw new Error("comment clone");
const detached=document.implementation.createHTMLDocument(""),foreign=detached.createComment("foreign");
if(foreign.ownerDocument!==detached||foreign.isConnected||foreign.data!=="foreign")throw new Error("comment document owner");
host.appendChild(foreign);
if(foreign.ownerDocument!==document||!foreign.isConnected||host.lastChild!==foreign)throw new Error("comment adoption");
host.removeChild(foreign);
end.replaceWith(copy);
if(copy.previousSibling!==content||copy.nextSibling!==tail||end.parentNode!==null||end.isConnected)throw new Error("comment replacement");
host.removeChild(start);
if(start.parentNode!==null||start.isConnected||host.firstChild!==content)throw new Error("comment removal");
// DOMString conversion permits markup and comment terminators without parsing.
for(const [value,expected] of [[null,"null"],[undefined,"undefined"],[17,"17"],["--><b>x</b><!--","--><b>x</b><!--"]]){
 const node=document.createComment(value);if(node.data!==expected||node.childNodes.length)throw new Error("comment string conversion");
}
let calls=0;const converted=document.createComment({toString(){calls++;return "converted";}});
if(calls!==1||converted.data!=="converted")throw new Error("comment conversion count");
for(const callback of [()=>document.createComment(),()=>document.createComment(Symbol()),()=>document.createComment.call({},"x"),()=>document.createComment.call(null,"x"),()=>new document.createComment("x")]){
 let rejected=false;try{callback();}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("comment argument validation");
}
globalThis.commentPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('commentPassed')! == 'true'
	assert document.get_element_by_id('host')?.as_node().text_content()? == 'content'
}
