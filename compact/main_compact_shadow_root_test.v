module main

import browserjs
import html

fn test_compact_shadow_roots_keep_native_identity_closed_access_and_tree_scopes() {
	mut document := html.parse_document('<!doctype html><div id="host"><span id="light">light</span></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://shadow.test/', [r'
const bare=document.createElement("div");if(bare.shadowRoot!==null)throw new Error("new host");
const detached=document.createElement("section");if(detached.getRootNode()!==detached)throw new Error("new detached root");
const root=host.attachShadow({mode:"open",delegatesFocus:true,clonable:true,serializable:true,slotAssignment:"manual"});
if(!(root instanceof ShadowRoot)||!(root instanceof DocumentFragment)||!(root instanceof Node)||root instanceof Element)throw new Error("shadow hierarchy");
if(Object.getPrototypeOf(ShadowRoot)!==DocumentFragment||Object.getPrototypeOf(ShadowRoot.prototype)!==DocumentFragment.prototype||Object.prototype.toString.call(root)!=="[object ShadowRoot]")throw new Error("shadow prototype");
if(root!==host.shadowRoot||root.host!==host||root.mode!=="open"||!root.delegatesFocus||!root.clonable||!root.serializable||root.slotAssignment!=="manual")throw new Error("shadow metadata");
root.innerHTML="<span id=inside>shadow</span>";
const child=root.firstChild;
if(root.parentNode!==null||child.parentNode!==root||root.children[0]!==child||root.getElementById("inside")!==child||root.getElementById("")!==null)throw new Error("shadow tree");
if(child.getRootNode()!==root||root.getRootNode()!==root||child.getRootNode({composed:true})!==document||!root.isConnected)throw new Error("root lookup");
if(document.getElementById("inside")!==null||host.querySelector("#inside")!==null||root.querySelector("#light")!==null)throw new Error("tree isolation");
const closed=other.attachShadow({mode:"closed"});closed.append(document.createElement("b"));
if(other.shadowRoot!==null||closed.host!==other||closed.firstChild.getRootNode()!==closed||closed.mode!=="closed")throw new Error("closed access");
host.remove();if(root.isConnected||child.isConnected||child.getRootNode({composed:true})!==host)throw new Error("disconnected root");
document.body.append(host);if(!root.isConnected||host.shadowRoot!==root||root.firstChild!==child)throw new Error("reattached root");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_shadow_root_markup_and_unsafe_element_markup_use_native_parsing() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://shadow.test/', [r'
const detached=document.createElement("section");detached.setHTMLUnsafe("<i>detached</i>");
if(detached.firstChild.textContent!=="detached")throw new Error("new host markup");
const root=host.attachShadow({mode:"open"}),saved=root.childNodes;
root.innerHTML="<b id=first>one</b>";const removed=root.firstChild;
if(root.innerHTML!=="<b id=\"first\">one</b>"||saved.length!==1)throw new Error("serialize shadow markup");
root.setHTMLUnsafe("<p id=second>two</p>");
if(saved.length!==1||saved[0]===removed||removed.parentNode!==null||root.querySelector("#second").textContent!=="two")throw new Error("replace shadow markup");
host.setHTMLUnsafe("<em id=light>outside</em>");
if(root!==host.shadowRoot||host.firstChild.id!=="light"||root.firstChild.id!=="second")throw new Error("light and shadow markup");
root.innerHTML=null;if(saved.length!==0||root.innerHTML!=="")throw new Error("nullable shadow markup");
const adopted=document.implementation.createHTMLDocument("other");adopted.body.append(host);
root.innerHTML="<i>adopted</i>";
if(root.ownerDocument!==adopted||root.firstChild.ownerDocument!==adopted||root.host!==host)throw new Error("adopted shadow owner");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_shadow_root_brands_options_and_native_errors() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><button id="button"></button>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
function typeError(call){let caught=false;try{call()}catch(error){caught=error instanceof TypeError}if(!caught)throw new Error("expected TypeError");}
typeError(()=>new ShadowRoot());
for(const init of [undefined,null,1,{}, {mode:"OPEN"},{mode:"open",slotAssignment:"bad"},{mode:Symbol()}])typeError(()=>host.attachShadow(init));
for(const name of ["host","mode","delegatesFocus","innerHTML"]){const getter=Object.getOwnPropertyDescriptor(ShadowRoot.prototype,name).get;for(const receiver of [null,host,document.createDocumentFragment()])typeError(()=>getter.call(receiver));}
let unsupported=0;try{button.attachShadow({mode:"open"})}catch(error){if(error instanceof DOMException&&error.name==="NotSupportedError")unsupported++}
host.attachShadow({mode:"open"});try{host.attachShadow({mode:"open"})}catch(error){if(error instanceof DOMException&&error.name==="NotSupportedError")unsupported++}
if(unsupported!==2)throw new Error("native shadow errors");
typeError(()=>Element.prototype.attachShadow.call({}, {mode:"open"}));
typeError(()=>ShadowRoot.prototype.setHTMLUnsafe.call(document.createDocumentFragment(),""));
'], runtime, mut messages)
	assert messages == []string{}
}

// GitHub's invoker-commands polyfill adds a capture listener to every attached
// shadow root; fragments and character data are EventTargets too.
fn test_compact_shadow_roots_fragments_and_text_share_native_event_listeners() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://shadow.test/', [r'
const root=host.attachShadow({mode:"open"});root.innerHTML="<button id=inner>x</button>";
const inner=root.getElementById("inner"),seen=[];
function onRoot(event){seen.push(["root",this===root,event.currentTarget===root,event.target===inner,event.eventPhase]);}
root.addEventListener("click",onRoot,true);
host.addEventListener("click",event=>seen.push(["host",event.target===host,event.currentTarget===host]));
inner.dispatchEvent(new MouseEvent("click",{bubbles:true,composed:true}));
root.removeEventListener("click",onRoot,true);inner.dispatchEvent(new MouseEvent("click",{bubbles:true,composed:true}));
root.addEventListener("custom",event=>seen.push(["custom",event.target===root]));
if(!root.dispatchEvent(new Event("custom")))throw new Error("custom dispatch");
const fragment=document.createDocumentFragment();fragment.addEventListener("x",event=>seen.push(["fragment",event.target===fragment]));fragment.dispatchEvent(new Event("x"));
const text=document.createTextNode("t");text.addEventListener("y",event=>seen.push(["text",event.target===text]));text.dispatchEvent(new Event("y"));
const expected=[["root",true,true,true,1],["host",true,true],["host",true,true],["custom",true],["fragment",true],["text",true]];
if(JSON.stringify(seen)!==JSON.stringify(expected))throw new Error("listeners "+JSON.stringify(seen));
'], runtime, mut messages)
	assert messages == []string{}
}
