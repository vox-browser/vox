module main

import browserjs
import dom
import html
import platform

fn test_compact_document_named_node_lists_are_native_live_ordered_and_document_scoped() {
	address := dom.URL{value: 'https://named-list.test/'}
	mut document := html.parse_navigation_document('<!doctype html><meta name="target" id="metadata"><body><iframe name="target" id="frame"></iframe><span name="target" id="span"></span><input name="Target" id="capital"><div name="" id="empty"></div><div id="target"></div><svg><g name="target" id="svg-target"/></svg><div id="host"></div>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	mut scratch := platform.begin_thread_scratch('native named node list')
	assert runtime.evaluate_host(r'
 globalThis.namedList=document.getElementsByName("target");
 if(!(namedList instanceof NodeList)||namedList instanceof HTMLCollection||Array.isArray(namedList)||namedList.length!==3||namedList[0]!==metadata||namedList[1]!==frame||namedList[2]!==span||namedList.item(3)!==null)throw Error("native NodeList membership/order");
 if(document.getElementsByName("target")===namedList||document.getElementsByName("Target").item(0)!==capital||document.getElementsByName("").length!==1||document.getElementsByName("")[0]!==empty||namedList.namedItem!==undefined||namedList.metadata!==undefined)throw Error("name semantics or NodeList identity");
 if([...namedList.keys()].join()!=="0,1,2"||[...namedList.values()][1]!==frame||[...namedList.entries()][2][1]!==span||Object.keys(namedList).join()!=="0,1,2")throw Error("NodeList iteration/enumeration");
 const iterator=namedList.values();if(iterator.next().value!==metadata)throw Error("live iterator start");
 frame.name="other";if(namedList.length!==2||iterator.next().value!==span||namedList[1]!==span)throw Error("pending name write or live iterator");
 frame.name="target";document.body.insertBefore(span,frame);if(namedList[1]!==span||namedList[2]!==frame)throw Error("tree reordering");
 span.remove();if(namedList.length!==2||namedList.item(1)!==frame)throw Error("live removal");
 const shadow=host.attachShadow({mode:"open"});shadow.innerHTML="<input name=target>";if(namedList.length!==2)throw Error("shadow isolation");
 globalThis.detachedNamed=document.implementation.createHTMLDocument("");const otherList=detachedNamed.getElementsByName("target");
 detachedNamed.body.appendChild(frame);if(namedList.length!==1||otherList.length!==1||otherList[0]!==frame||frame.ownerDocument!==detachedNamed)throw Error("adoption and root identity");
 document.body.appendChild(frame);if(namedList.length!==2||otherList.length||namedList[1]!==frame)throw Error("readoption");
 globalThis.specialName="q\"[]\\\u0000\u{1f600}";const special=document.createElement("input");special.name=specialName;document.body.appendChild(special);
 if(document.getElementsByName(specialName)[0]!==special)throw Error("DOMString lookup used selector syntax");
 console.log("named-list log");if(namedList.length!==2||!JSON.parse(__ladybirdSnapshot()).logs.includes("named-list log"))throw Error("console output changed collection behavior");
 true;
 ')! == 'true'
	scratch.finish()
	gc_collect()
	assert runtime.evaluate_host('namedList.length===2&&namedList[0]===metadata&&namedList[1]===frame')! == 'true'
	// A native insertion must appear without any compact mutation generation.
	mut native := document.create_element('span')!
	native.set_attribute_value('name', 'target')
	native.set_attribute_value('id', 'native-added')
	document.body()?.as_node().append_child(native.as_node())!
	assert runtime.evaluate_host('namedList.length===3&&namedList[2]===document.getElementById("native-added")')! == 'true'
	assert document.get_elements_by_name('').length() == 1
}

fn test_compact_document_named_node_lists_preserve_webidl_conversion_and_receiver_checks() {
	address := dom.URL{value: 'https://named-list.test/'}
	mut document := html.parse_navigation_document('<!doctype html><body><input name="undefined" id="undefined-name"><input name="null" id="null-name"></body>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
 const method=Document.prototype.getElementsByName,descriptor=Object.getOwnPropertyDescriptor(Document.prototype,"getElementsByName");
 if(method.name!=="getElementsByName"||method.length!==1||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable||Object.hasOwn(method,"prototype"))throw Error("operation descriptor");
 let reads=0;const value={[Symbol.toPrimitive](hint){if(hint!=="string")throw Error("ToString hint");reads++;return "converted"}};
 for(const receiver of [null,undefined,{},window,document.body,Object.create(Document.prototype)]){let rejected=false;try{method.call(receiver,value)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw Error("Document brand")}
 if(reads!==0)throw Error("conversion preceded receiver check");
 let missing=false,symbol=false;try{document.getElementsByName()}catch(error){missing=error instanceof TypeError}try{document.getElementsByName(Symbol())}catch(error){symbol=error instanceof TypeError}if(!missing||!symbol)throw Error("required argument/DOMString Symbol");
 if(document.getElementsByName(undefined)[0]!==document.getElementById("undefined-name")||document.getElementsByName(null)[0]!==document.getElementById("null-name"))throw Error("DOMString undefined/null");
 const before=document.getElementsByName(value);if(reads!==1||before.length)throw Error("single ToString");
 const converted=document.createElement("input");converted.name="converted";document.body.appendChild(converted);if(before.length!==1||before[0]!==converted||reads!==1)throw Error("lookup retained converted name");
 const marker={};let original=false;try{document.getElementsByName({toString(){throw marker}})}catch(error){original=error===marker}if(!original)throw Error("original conversion exception");
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
}
