module main

import browserjs
import dom
import html

fn test_compact_document_domain_reads_live_native_origins_and_brands_receivers() {
	address := dom.URL{value: 'https://github.com/vlang/v'}
	mut document := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
 const property=Object.getOwnPropertyDescriptor(Document.prototype,"domain");
 if(!property.enumerable||!property.configurable||property.get.name!=="get domain"||property.set.name!=="set domain"||property.get.length!==0||property.set.length!==1)throw Error("domain descriptor");
 if(document.domain!=="github.com"||property.get.call(document)!=="github.com")throw Error("native domain getter");
 const detached=document.implementation.createHTMLDocument("");
 if(detached.domain!=="github.com")throw Error("detached document inherits native origin");
 globalThis.detachedDomainDocument=detached;
 let conversions=0;const value={toString(){conversions++;return "github.com"}};
 for(const receiver of [null,undefined,{},window,document.body,Object.create(Document.prototype)]){
  for(const action of [()=>property.get.call(receiver),()=>property.set.call(receiver,value)]){let rejected=false;try{action()}catch(error){rejected=error instanceof TypeError}if(!rejected)throw Error("domain receiver brand");}
 }
 if(conversions!==0)throw Error("converted before checking receiver");
 globalThis.readNativeDomain=property.get;
 '], runtime, mut messages)
	assert messages == []string{}, messages.str()
	// The URL stays github.com; the getter follows the actual native origin.
	document.set_origin(dom.origin_from_tuple('https', 'nested.example.co.uk', u16(8443)))
	assert runtime.evaluate_host('document.domain==="nested.example.co.uk"&&readNativeDomain.call(document)==="nested.example.co.uk"&&document.URL==="https://github.com/vlang/v"&&detachedDomainDocument.domain==="github.com"')! == 'true'
	document.set_origin(dom.origin_from_tuple('http', '[::1]', u16(8080)))
	assert document.domain() == '[::1]'
	assert runtime.evaluate_host('document.domain')! == '[::1]'
	document.set_origin(dom.origin_create_opaque())
	assert runtime.evaluate_host('document.domain')! == ''
	wrapper := runtime.evaluate_host_value('detachedDomainDocument')!
	defer { runtime.release_javascript_value(wrapper) }
	mut detached := unsafe { &dom.Document(runtime.native_event_target(wrapper)!) }
	detached.set_origin(dom.origin_create_opaque())
	assert runtime.evaluate_host('detachedDomainDocument.domain')! == ''
}

fn test_compact_document_domain_setter_uses_native_validation_and_actual_webidl_conversion() {
	address := dom.URL{value: 'https://www.example.co.uk/page'}
	mut document := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	// The native setter requires an actual browsing-context association.
	document.set_browsing_context(&dom.BrowsingContext{})
	assert runtime.evaluate_host(r'
 const set=Object.getOwnPropertyDescriptor(Document.prototype,"domain").set;
 function security(call){let rejected=false;try{call()}catch(error){rejected=error instanceof DOMException&&error.name==="SecurityError"}if(!rejected)throw Error("native SecurityError");}
 let conversions=0;const value={[Symbol.toPrimitive](hint){if(hint!=="string")throw Error("conversion hint");conversions++;return "example.co.uk"}};
 if(set.call(document,value)!==undefined||conversions!==1)throw Error("native setter conversion");
 // Native origin relaxation is still a stub, matching the pinned upstream.
 if(document.domain!=="www.example.co.uk")throw Error("binding fabricated domain mutation");
 set.call(document,"www.example.co.uk");
 for(const invalid of ["", "co.uk", "uk", "other.co.uk", "ample.co.uk", "127.0.0.1", "bad host", null, undefined])security(()=>set.call(document,invalid));
 let symbols=0;try{set.call(document,Symbol())}catch(error){if(error instanceof TypeError)symbols++}if(symbols!==1)throw Error("Symbol conversion");
 const marker={};let same=false;try{set.call(document,{toString(){throw marker}})}catch(error){same=error===marker}if(!same)throw Error("original conversion exception");
 security(()=>set.call(document.implementation.createHTMLDocument(""),{toString(){conversions++;return "example.co.uk"}}));
 if(conversions!==2)throw Error("conversion must precede native browsing-context check");
 true;
 ')! == 'true'
	document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{sandboxed_document_domain: true})
	assert runtime.evaluate_host('let blocked=false;try{document.domain="www.example.co.uk"}catch(error){blocked=error instanceof DOMException&&error.name==="SecurityError"}blocked')! == 'true'
	document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{})
	document.set_origin(dom.origin_create_opaque())
	assert runtime.evaluate_host('let opaque=false;try{document.domain="www.example.co.uk"}catch(error){opaque=error instanceof DOMException&&error.name==="SecurityError"}opaque')! == 'true'
}
