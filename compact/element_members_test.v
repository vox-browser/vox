module main

import browserjs
import html

fn test_namespace_and_adjacent_members_use_the_native_dom() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="box"><span id="s">s</span></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/page', [
		'const svgns="http://www.w3.org/2000/svg",xlink="http://www.w3.org/1999/xlink";box.setAttributeNS(xlink,"xl:href","#a");console.log(box.getAttributeNS(xlink,"href"),box.hasAttributeNS(xlink,"href"),box.getAttribute("xl:href"),String(box.getAttributeNS(null,"href")));box.removeAttributeNS(xlink,"href");console.log(box.hasAttribute("xl:href"));try{box.setAttributeNS(null,"a:b","x")}catch(e){console.log(e.name)}',
		'console.log(String(box.nodeValue),box.baseURI,box.lookupNamespaceURI(null),String(box.lookupPrefix("http://www.w3.org/1999/xhtml")),box.isDefaultNamespace("http://www.w3.org/1999/xhtml"),box.isSameNode(box),box.isSameNode(s),box.isSameNode(null));',
		'const b=document.createElement("b");console.log(box.insertAdjacentElement("afterbegin",b)===b,box.firstElementChild===b);box.insertAdjacentText("beforeend","t");console.log(box.innerHTML);const svg=document.createElementNS(svgns,"svg");box.appendChild(svg);svg.appendChild(document.createElementNS(svgns,"circle"));console.log(box.getElementsByTagNameNS(svgns,"*").length,document.getElementsByTagNameNS(svgns,"circle").length,document.getElementsByTagNameNS("*","span")[0]===s);',
	], runtime, mut messages)
	assert messages == ['#a true #a null', 'false', 'NamespaceError',
		'null about:blank http://www.w3.org/1999/xhtml null true true false false',
		'true true', '<b></b><span id="s">s</span>t', '2 1 true']
}
