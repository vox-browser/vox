module main

import browserjs
import html

fn test_compact_element_insert_before_preserves_text_comment_anchors_and_live_content() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://insertion.test/', [r'
const host=document.getElementById("host"),other=document.getElementById("other");
const start=document.createTextNode("["),end=document.createTextNode("]"),comment=document.createComment("anchor");
host.appendChild(start);host.appendChild(end);host.appendChild(comment);
const middle=document.createElement("b");middle.textContent="middle";
if(host.insertBefore(middle,end)!==middle)throw new Error("insertion return value");
if(Array.from(host.childNodes).map(n=>n.nodeName).join(",")!=="#text,B,#text,#comment"||host.textContent!=="[middle]")throw new Error("text anchor insertion");
const tail=document.createElement("i");tail.textContent="tail";
host.insertBefore(tail,comment);
if(host.textContent!=="[middle]tail"||comment.previousSibling!==tail||tail.parentNode!==host)throw new Error("comment anchor insertion");
other.insertBefore(middle,null);
if(host.textContent!=="[]tail"||other.textContent!=="middle"||other.firstChild!==middle)throw new Error("moving element content");
host.insertBefore(middle,start);
if(host.textContent!=="middle[]tail"||other.textContent!==""||host.firstChild!==middle)throw new Error("first text anchor insertion");
const fragment=document.createDocumentFragment(),leaf=document.createElement("em");leaf.textContent="fragment";fragment.appendChild(leaf);
host.insertBefore(fragment,end);
if(fragment.firstChild!==null||end.previousSibling!==leaf||host.textContent!=="middle[fragment]tail")throw new Error("fragment insertion");
let absent=false;try{host.insertBefore(document.createElement("u"),other);}catch(e){absent=e.name==="NotFoundError";}
let cycle=false;try{middle.insertBefore(host,null);}catch(e){cycle=e.name==="HierarchyRequestError";}
let invalid=false;try{host.insertBefore({},null);}catch(e){invalid=e instanceof TypeError;}
if(!absent||!cycle||!invalid)throw new Error("insertion validation");
globalThis.anchoredInsertionPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('anchoredInsertionPassed')! == 'true'
	host := document.get_element_by_id('host') or { panic('missing host') }
	assert host.as_node().text_content()? == 'middle[fragment]tail'
}

fn test_compact_child_nodes_remain_live_and_include_text_comments_and_fragment_children() {
 mut document := html.parse_document('<!doctype html><div id="host">a<b>bold</b><!--tail--></div>')
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,'about:blank',[r'
const nodes=host.childNodes;
if(nodes!==host.childNodes||!(nodes instanceof NodeList)||nodes.length!==3||nodes[0].nodeType!==3||nodes[2].nodeType!==8||nodes.item(99)!==null)throw new Error("child node list");
const fragment=document.createDocumentFragment(),saved=fragment.childNodes,text=document.createTextNode("Привет");
if(fragment.nodeType!==11||fragment.nodeName!=="#document-fragment"||fragment.ownerDocument!==document||text.nodeType!==3||text.nodeName!=="#text")throw new Error("native node kinds");
if(text.childNodes.length!==0||text.firstChild!==null||text.lastChild!==null)throw new Error("text children");
if(fragment.appendChild(text)!==text||saved.length!==1||saved[0]!==text||fragment.firstChild!==text||text.parentNode!==fragment)throw new Error("fragment identity");
host.insertBefore(fragment,nodes[0]);
if(saved.length!==0||nodes.length!==4||nodes[0]!==text||text.parentNode!==host||text.parentElement!==host)throw new Error("fragment transfer");
text.nodeValue="updated";
if(nodes[0].data!=="updated"||host.textContent!=="updatedabold")throw new Error("native text write");
if(host.removeChild(text)!==text||text.parentNode!==null||nodes.length!==3||Array.from(nodes).length!==3)throw new Error("live removal");
const item=NodeList.prototype.item;
for(const receiver of [null,{},document]){let rejected=false;try{item.call(receiver,0);}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("NodeList branding");}
globalThis.childNodesPassed=true;
'],runtime,mut messages)
 assert runtime.evaluate_host('childNodesPassed')! == 'true'
 assert messages == []string{}
}

fn test_compact_fragment_text_replacement_cloning_and_queries_use_the_native_tree() {
 mut document := html.parse_document('<!doctype html><div id="host"></div>')
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,'about:blank',[r'
const fragment=document.createDocumentFragment(),node=document.createElement("em"),list=fragment.childNodes;
node.setAttribute("class","child");fragment.appendChild(node);
if(node.parentNode!==fragment||node.parentElement!==null||fragment.querySelector(".child")!==node||fragment.querySelectorAll("em").length!==1)throw new Error("fragment parent and query");
fragment.textContent="two";
if(node.parentNode!==null||list.length!==1||list[0].nodeType!==3||fragment.textContent!=="two"||fragment.nodeValue!==null)throw new Error("fragment replace all");
const copy=fragment.cloneNode(true),copied=copy.firstChild;
if(copy===fragment||copied===fragment.firstChild||copied.textContent!=="two"||copy.lastChild!==copied||copied.parentNode!==copy)throw new Error("fragment deep clone");
host.appendChild(copy);
if(copy.childNodes.length!==0||host.firstChild!==copied||copied.parentNode!==host)throw new Error("cloned fragment transfer");
fragment.textContent=null;
if(list.length!==0||fragment.firstChild!==null||fragment.lastChild!==null)throw new Error("fragment empty");
globalThis.fragmentTreePassed=true;
'],runtime,mut messages)
 assert runtime.evaluate_host('fragmentTreePassed')! == 'true'
 assert messages == []string{}
}

fn test_jquery_comment_labels_and_text_fragment_insertion_finish_without_errors() {
 mut document := html.parse_document('<!doctype html><div id="thread" class="thing comment collapsed"><a id="expand" class="expand">[+]</a><div id="body"></div></div>')
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,'https://old.reddit.com/',[
  $embed_file('@VMODROOT/Tests/Browser/fixtures/jquery-2.1.1.min.js').to_string(),
  r'
jQuery.fn.thing=function(){return this.closest(".thing");};
function togglecomment(e){var t=$(e).thing(),n=t.find(".expand:first"),r=t.hasClass("collapsed");t.toggleClass("collapsed noncollapsed"),r?n.text("[–]"):n.text("[+]")}
$(body).empty().append(document.createTextNode("fragment text"));
if(body.textContent!=="fragment text")throw new Error("jQuery text fragment");
'
 ],runtime,mut messages)
 assert messages == []string{}
 for index in 0..4 {
  expected := if index%2==0 {'[–]'} else {'[+]'}
  assert runtime.evaluate_host('togglecomment(expand); expand.textContent')! == expected
  state := runtime.evaluate_host('__ladybirdFinalize()')!
  apply_javascript_state(document,state,runtime.canvas_elements_for_binding(),mut messages)
  runtime.evaluate_host('__ladybirdClearLogs()')!
  assert messages == []string{}
  anchor := document.get_element_by_id('expand') or { panic('missing control') }
  assert (anchor.as_node().text_content() or { '' }) == expected
 }
}
