module main

import browserjs
import dom
import html
import x.json2

fn test_compact_create_html_document_runs_the_pikabu_two_form_probe_in_a_separate_native_tree() {
	mut document := html.parse_document('<!doctype html><title>Displayed</title><div id="host">original</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://pikabu.ru/story/test', [r'
if(document.location!==window.location||document.defaultView!==window)throw new Error("displayed document window");
const implementation=document.implementation;
if(implementation!==document.implementation||!(implementation instanceof DOMImplementation))throw new Error("implementation identity");
const probe=implementation.createHTMLDocument("");
if(!(probe instanceof HTMLDocument)||!(probe instanceof Document)||probe===document||probe.implementation===implementation)throw new Error("document identity");
if(probe.nodeType!==9||probe.nodeName!=="#document"||probe.ownerDocument!==null||probe.defaultView!==null||probe.location!==null)throw new Error("detached document");
if(probe.URL!=="about:blank"||probe.contentType!=="text/html"||probe.compatMode!=="CSS1Compat"||probe.doctype.nodeName!=="html")throw new Error("native document metadata");
if(probe.childNodes.length!==2||probe.firstChild!==probe.doctype||probe.lastChild!==probe.documentElement||probe.documentElement.parentNode!==probe)throw new Error("document children");
const body=probe.body;
let wheelEvents=0;body.onwheel=function(event){if(this!==body||event.target!==body)throw new Error("detached event owner");wheelEvents++;};
body.dispatchEvent(new Event("wheel"));if(wheelEvents!==1)throw new Error("detached event binding");
body.innerHTML="<form></form><form></form>";
const children=body.children;
const counts=[body.childNodes.length,children.length,probe.querySelectorAll("form").length];
if(counts.some(count=>count!==2))throw new Error("Pikabu jQuery probe: "+counts.join(",")+"; "+body.innerHTML);
if(body!==probe.body||body.ownerDocument!==probe||body.firstChild.ownerDocument!==probe||probe.head.ownerDocument!==probe)throw new Error("native ownership");
body.innerHTML="<b id=foreign>detached</b>";
if(body.children!==children||children.length!==1||children[0]!==body.firstChild)throw new Error("saved children after markup replacement");
if(probe.getElementById("foreign")!==body.firstChild||document.getElementById("foreign")!==null||host.textContent!=="original")throw new Error("tree isolation");
if(document.title!=="Displayed")throw new Error("displayed title changed");
globalThis.detachedProbePassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('detachedProbePassed')! == 'true'
	assert document.get_element_by_id('foreign') == none
}

fn test_compact_detached_factories_keep_owner_document_live_lists_base_url_and_adoption() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://pikabu.ru/story/test', [r'
const detached=document.implementation.createHTMLDocument("Detached title"),body=detached.body;
if(detached.title!=="Detached title"||detached.head.querySelector("title").firstChild.ownerDocument!==detached)throw new Error("title node");
const list=body.childNodes,tags=detached.getElementsByTagName("span"),fragment=detached.createDocumentFragment(),text=detached.createTextNode("native text"),node=detached.createElement("SPAN");
if(fragment.ownerDocument!==detached||text.ownerDocument!==detached||node.ownerDocument!==detached||node.localName!=="span")throw new Error("factory owner");
fragment.appendChild(text);fragment.appendChild(node);body.appendChild(fragment);
if(list.length!==2||list[0]!==text||list[1]!==node||tags.length!==1||fragment.childNodes.length!==0)throw new Error("live detached collections");
const fromMain=document.createElement("em");body.appendChild(fromMain);
if(fromMain.ownerDocument!==detached||list.length!==3||fromMain.parentNode!==body)throw new Error("adopt into detached document");
const base=detached.createElement("base");base.href="https://pikabu.ru/detached/";detached.head.appendChild(base);
const link=detached.createElement("a");link.href="relative";
if(detached.baseURI!=="https://pikabu.ru/detached/"||link.href!=="https://pikabu.ru/detached/relative")throw new Error("detached base URL");
const subtree=document.createElement("section"),adoptedLink=document.createElement("a");adoptedLink.href="nested";
if(adoptedLink.ownerDocument!==document)throw new Error("uninserted owner");
subtree.appendChild(adoptedLink);body.appendChild(subtree);
if(subtree.ownerDocument!==detached||adoptedLink.ownerDocument!==detached||adoptedLink.href!=="https://pikabu.ru/detached/nested")throw new Error("adopted subtree URL");
adoptedLink.remove();
if(adoptedLink.ownerDocument!==detached||adoptedLink.href!=="https://pikabu.ru/detached/nested")throw new Error("removed adopted owner");
host.appendChild(adoptedLink);
if(adoptedLink.ownerDocument!==document||adoptedLink.href!=="https://pikabu.ru/story/nested")throw new Error("readopted URL");
const svg=detached.createElementNS("http://www.w3.org/2000/svg","linearGradient");
if(svg.localName!=="linearGradient"||svg.ownerDocument!==detached)throw new Error("namespaced factory");
host.appendChild(node);void host.childNodes;
if(node.ownerDocument!==document||tags.length!==0||list.length!==3||node.parentNode!==host)throw new Error("adopt into displayed document");
detached.title="changed";if(detached.title!=="changed")throw new Error("native title setter");
globalThis.detachedFactoriesPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('detachedFactoriesPassed')! == 'true'
}

fn test_compact_html_document_optional_title_conversion_and_receiver_checks() {
	mut document := html.parse_document('<!doctype html><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const implementation=document.implementation,create=DOMImplementation.prototype.createHTMLDocument;
if(create.length!==0||create.name!=="createHTMLDocument")throw new Error("method metadata");
if(create.call(implementation).head.querySelector("title")!==null||create.call(implementation,undefined).head.querySelector("title")!==null)throw new Error("omitted title");
if(create.call(implementation,"").head.querySelector("title")===null||create.call(implementation,null).title!=="null")throw new Error("present title");
let conversions=0;const titled=create.call(implementation,{toString(){conversions++;return "converted";}});
if(conversions!==1||titled.title!=="converted")throw new Error("DOMString conversion");
for(const receiver of [null,{},document,DOMImplementation.prototype]){let rejected=false;try{create.call(receiver,"x");}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("implementation receiver");}
for(const operation of [()=>new DOMImplementation(),()=>create.call(implementation,Symbol()),()=>Document.prototype.createElement.call({},"div"),()=>titled.createElement(),()=>titled.createElementNS("x")]){let rejected=false;try{operation();}catch(error){rejected=error instanceof TypeError;}if(!rejected)throw new Error("constructor or argument validation");}
globalThis.detachedConversionsPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('detachedConversionsPassed')! == 'true'
}

fn test_compact_tag_collection_does_not_reuse_another_documents_matching_version_after_adoption() {
	mut document := html.parse_document('<!doctype html><body></body>')
	mut other := document.implementation().create_html_document(none)!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		other.finalize()
		document.finalize()
	}
	mut binding := &CompactElementQueryBinding{ document: document, runtime: &runtime }
	root := document.create_element('div')!
	mut node := root.as_node()
	first := document.create_element('span')!
	node.append_child(first.as_node())!
	snapshot := json2.decode[map[string]json2.Any](binding.tag_collection_query(node, '{"name":"span"}')!)!
	mut body := other.body()?.as_node()
	body.append_child(node)!
	second := other.create_element('span')!
	node.append_child(second.as_node())!
	// Different documents can naturally reach the same counter. Adoption must
	// invalidate by document identity even when that number happens to match.
	other.dom_tree_version = document.dom_tree_version()
	request := json2.encode({
		'name':    json2.Any('span')
		'version': snapshot['version'] or { json2.Any('') }
		'owner':   snapshot['owner'] or { json2.Any('') }
	})
	updated := json2.decode[map[string]json2.Any](binding.tag_collection_query(node, request)!)!
	elements := updated['elements'] or { panic('Missing collection') }
	assert elements is []json2.Any
	assert (elements as []json2.Any).len == 2
	assert (updated['owner'] or { json2.Any('') }) != (snapshot['owner'] or { json2.Any('') })
}

fn test_compact_document_collection_clock_includes_detached_mutations_and_rejects_rounded_versions() {
	for engine in [browserjs.Engine.javascriptcore, .libjs] {
		mut document := dom.Document.create(dom.url_about_blank())
		mut runtime := browserjs.Runtime.create_with_engine(engine)
		defer {
			runtime.close()
			document.finalize()
		}
		mut binding := &CompactElementQueryBinding{ document: document, runtime: &runtime }
		install_compact_document_binding(binding, mut runtime)!
		mut detached := document.implementation().create_html_document(none)!
		binding.documents['detached'] = detached
		version := document.dom_tree_version() + detached.dom_tree_version()
		assert runtime.evaluate('__ladybirdDOMTreeVersion() === ${version}')! == 'true'
		detached.bump_dom_tree_version()
		assert runtime.evaluate('__ladybirdDOMTreeVersion() === ${version + 1}')! == 'true'
		document.dom_tree_version = u64(9007199254740991) - detached.dom_tree_version()
		assert runtime.evaluate('__ladybirdDOMTreeVersion() === 9007199254740991')! == 'true'
		detached.bump_dom_tree_version()
		assert runtime.evaluate('__ladybirdDOMTreeVersion() === -1')! == 'true'
		document.dom_tree_version = u64(18446744073709551615)
		assert runtime.evaluate('__ladybirdDOMTreeVersion() === -1')! == 'true'
	}
}
