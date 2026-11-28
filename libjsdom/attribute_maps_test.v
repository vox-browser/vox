// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn attribute_map_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'attribute-map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or {
		return error(exception_message(err))
	}
}

fn test_named_node_map_tracks_live_native_attributes() {
	document := html.parse_document('<body><div id="target" data-live="first"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert attribute_map_eval(mut vm, r'
		const element = document.getElementById("target");
		const map = element.attributes;
		const original = map["data-live"];
		let valid = map === element.attributes && map instanceof NamedNodeMap &&
			map.length === 2 && map.item(1) === original && map[1] === original &&
			Object.keys(map).join(",") === "0,1" && [...map].map(a => a.name).join(",") === "id,data-live";
		valid &&= original instanceof Attr && original instanceof Node && original.ownerElement === element &&
			original.nodeType === Node.ATTRIBUTE_NODE && original.nodeName === "data-live" &&
			original.localName === "data-live" && original.namespaceURI === null && original.specified;
		original.value = "second";
		valid &&= map.getNamedItem("DATA-LIVE") === original && element.getAttribute("data-live") === "second" &&
			original.nodeValue === "second" && original.textContent === "second" && original.ownerDocument === document;
		const replacement = document.createAttribute("DATA-LIVE");
		replacement.value = "third";
		valid &&= map.setNamedItem(replacement) === original && original.ownerElement === null &&
			map[1] === replacement && element.getAttribute("data-live") === "third";
		const svgAttribute = document.createAttributeNS("urn:test", "test:value");
		svgAttribute.value = "namespace";
		valid &&= map.setNamedItemNS(svgAttribute) === null && svgAttribute.prefix === "test" &&
			map.getNamedItemNS("urn:test", "value") === svgAttribute && svgAttribute.namespaceURI === "urn:test";
		valid &&= map.removeNamedItemNS("urn:test", "value") === svgAttribute && svgAttribute.ownerElement === null &&
			map.removeNamedItem("data-live") === replacement && map.item(1) === null && map[1] === undefined;
		let errors = 0;
		try { map.removeNamedItem("missing"); } catch (error) { if (error.name === "NotFoundError") errors++; }
		try { map.setNamedItem({}); } catch (error) { if (error instanceof TypeError) errors++; }
		try { new Attr(); } catch (error) { if (error instanceof TypeError) errors++; }
		valid && errors === 3 && map.length === 1;
	')!.as_bool()
}

fn test_history_back_can_restore_attributes_from_a_named_node_map() {
	address := dom.URL{value: 'https://attribute-history.test/start'}
	mut document := html.parse_navigation_document('<html data-route="repo"><body>Repository</body></html>',
		address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	attribute_map_eval(mut vm, r'
		const root = document.documentElement;
		const saved = [...root.attributes];
		addEventListener("popstate", () => {
			for (const attr of root.attributes) {
				if (!saved.some(previous => previous.nodeName === attr.nodeName)) root.removeAttribute(attr.nodeName);
			}
			for (const attr of saved) root.setAttribute(attr.nodeName, attr.value);
		});
		history.pushState(null, "", "/file");
		root.removeAttribute("data-route");
		root.setAttribute("data-file", "true");
		root.setAttribute("data-route", "readme");
	')!
	window := document.get_window() or { panic('No associated Window') }
	native := window.navigable() or { panic('No associated navigable') }
	mut navigable := html.navigable_model_for_host(native) or { panic('No navigable model') }
	assert navigable.traverse_same_document_history(mut document, -1)
	assert attribute_map_eval(mut vm, 'location.pathname === "/start" &&
		root.getAttribute("data-route") === "repo" && !root.hasAttribute("data-file")')!.as_bool()
}
