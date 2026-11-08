module main

import browserjs
import html

fn check_compact_child_node_script(script string) ! {
	mut document := html.parse_document('<!doctype html><div id="host"><b id="a">A</b><i id="b">B</i><em id="c">C</em></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://pikabu.ru/story/test', [script,
		'globalThis.childMutationPassed=true;'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('childMutationPassed')! == 'true'
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_child_node_mutations_preserve_native_order_identity_and_live_lists() {
	check_compact_child_node_script(r'
const list=host.childNodes;
if(b.after(a,b,"tail")!==undefined)throw new Error("after return");
if(host.innerHTML!=="<b id=\"a\">A</b><i id=\"b\">B</i>tail<em id=\"c\">C</em>"||list.length!==4||list[0]!==a||list[1]!==b)throw new Error("viable following sibling: "+host.innerHTML);
c.before(b,a,"head");
if(list[0].data!=="tail"||list[1]!==b||list[2]!==a||list[3].data!=="head"||list[4]!==c)throw new Error("viable preceding sibling");
b.replaceWith(b,c,"end");
if(list.length!==6||list[1]!==b||list[2]!==c||list[3].data!=="end"||list[4]!==a||c.parentNode!==host)throw new Error("self replacement");
const fragment=document.createDocumentFragment(),fresh=document.createElement("u");fresh.textContent="fresh";
fragment.appendChild(fresh);fragment.appendChild(document.createTextNode("fragment"));
a.replaceWith(fragment);
if(fragment.childNodes.length!==0||a.parentNode!==null||fresh.parentNode!==host||!host.textContent.includes("freshfragment"))throw new Error("fragment insertion");
fresh.replaceWith();
if(fresh.parentNode!==null||host.textContent.includes("fresh"))throw new Error("empty replacement");
')!
}

fn test_compact_child_node_character_data_doctype_and_cross_document_adoption() {
	check_compact_child_node_script(r'
host.innerHTML="text<!--comment-->";
const text=host.firstChild,comment=host.lastChild;
text.before("before");text.after("after");comment.replaceWith("replacement");
if(host.textContent!=="beforetextafterreplacement"||comment.parentNode!==null)throw new Error("CharacterData mutation");
const detached=document.implementation.createHTMLDocument("other"),foreign=detached.createElement("strong");foreign.textContent="foreign";
detached.body.appendChild(foreign);const saved=detached.body.childNodes;
text.after(foreign);
if(foreign.ownerDocument!==document||foreign.parentNode!==host||saved.length!==0||text.nextSibling!==foreign)throw new Error("cross-document adoption");
const doctype=document.doctype;doctype.before(comment);
if(document.firstChild.nodeType!==8||document.firstChild.nextSibling!==doctype)throw new Error("DocumentType before");
doctype.replaceWith();if(document.doctype!==null)throw new Error("DocumentType replaceWith");
')!
}

fn test_compact_child_node_conversion_branding_noop_and_hierarchy_errors() {
	check_compact_child_node_script(r'
const method=Element.prototype.after;
if(method.length!==0||method.name!=="after"||Element.prototype[Symbol.unscopables].after!==true||Element.prototype[Symbol.unscopables].before!==true||Element.prototype[Symbol.unscopables].replaceWith!==true)throw new Error("ChildNode metadata");
let conversions=0;const detached=document.createElement("span"),value={toString(){conversions++;return "converted";}};
detached.after(value,a);
if(conversions!==1||a.parentNode!==host||detached.parentNode!==null)throw new Error("detached no-op conversion");
for(const receiver of [null,undefined,{},document,document.createDocumentFragment()]){let rejected=false;try{method.call(receiver,"bad");}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("ChildNode branding");}
let symbolRejected=false;try{b.before(Symbol());}catch(error){symbolRejected=error instanceof TypeError;}if(!symbolRejected)throw new Error("symbol conversion");
let hierarchy=false;try{b.after(host);}catch(error){hierarchy=error instanceof DOMException&&error.name==="HierarchyRequestError";}if(!hierarchy||b.parentNode!==host)throw new Error("ancestor hierarchy error");
hierarchy=false;try{b.after(document);}catch(error){hierarchy=error instanceof DOMException&&error.name==="HierarchyRequestError";}if(!hierarchy)throw new Error("document hierarchy error");
b.after(null,undefined,7,true,value);
if(!host.textContent.includes("nullundefined7trueconverted")||conversions!==2)throw new Error("DOMString conversion");
')!
}

fn test_compact_element_remove_prototype_uses_the_receiver_and_native_tree() {
	check_compact_child_node_script(r'
const remove=Element.prototype.remove,descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"remove");
if(remove.name!=="remove"||remove.length!==0||Object.hasOwn(remove,"prototype")||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable||Element.prototype[Symbol.unscopables].remove!==true)throw new Error("remove metadata");
const saved=host.childNodes,observer=new MutationObserver(()=>{});observer.observe(host,{childList:true});
b.remove=function(){throw new Error("author override must not run")};
const ignored={toString(){throw new Error("remove ignores arguments")}};
if(remove.call(b,ignored,Symbol())!==undefined||b.parentNode!==null||b.isConnected||document.getElementById("b")!==null||saved.length!==2)throw new Error("native prototype removal");
let changes=observer.takeRecords();if(changes.length!==1||changes[0].removedNodes[0]!==b||changes[0].previousSibling!==a||changes[0].nextSibling!==c)throw new Error("removal record");
remove.call(b);if(observer.takeRecords().length!==0)throw new Error("detached remove no-op");
c.before(b);observer.takeRecords();remove.call(b);if(saved.length!==2||b.parentNode!==null||observer.takeRecords().length!==1)throw new Error("remove after reinsertion");
const created=document.createElement("span");host.appendChild(created);remove.call(created);if(created.parentNode!==null||host.childNodes.length!==2)throw new Error("created removal");
for(const receiver of [null,undefined,{},Object.create(Element.prototype),document,document.doctype,document.createTextNode("text"),document.createComment("comment"),document.createDocumentFragment()]){
 let rejected=false;try{remove.call(receiver)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("remove receiver");
}
')!
}
