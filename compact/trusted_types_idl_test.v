module main

import browserjs
import dom
import html
import page

fn run_trusted_types_idl_check(source string) {
	url := dom.URL{value: 'https://trusted-idl.test/'}
	owner := page.Page.create(1) or { panic(err) }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) }) or { panic(err) }
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><body><iframe id="child"></iframe></body>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.destroy_a_document_and_its_descendants(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [source], runtime, mut messages)
	assert messages == ['trusted IDL passed'], messages.join('\n')
}

fn test_trusted_types_idl_metadata_required_arguments_and_receiver_checks() {
	run_trusted_types_idl_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const rejects=operation=>{let caught=false;try{operation();}catch(error){caught=error instanceof TypeError;}check(caught,true);};
check(trustedTypes.createPolicy.length,1);
for(const name of ["emptyHTML","emptyScript","defaultPolicy"]){
 const descriptor=Object.getOwnPropertyDescriptor(TrustedTypePolicyFactory.prototype,name);
 check(descriptor.get.name,"get "+name);check(descriptor.get.length,0);check(descriptor.enumerable,true);check(descriptor.configurable,true);check(descriptor.set,undefined);
 for(const receiver of [{},Object.create(trustedTypes),TrustedTypePolicyFactory.prototype])rejects(()=>descriptor.get.call(receiver));
}
for(const method of ["isHTML","isScript","isScriptURL"]){
 check(trustedTypes[method].name,method);check(trustedTypes[method].length,1);rejects(()=>trustedTypes[method]());check(trustedTypes[method](undefined),false);
 rejects(()=>trustedTypes[method].call({},null));
}
let calls=0;const callback=value=>{calls++;return value;};
const policy=trustedTypes.createPolicy("idl",{createHTML:callback,createScript:callback,createScriptURL:callback});
const name=Object.getOwnPropertyDescriptor(TrustedTypePolicy.prototype,"name").get;
check(name.name,"get name");check(name.call(policy),"idl");rejects(()=>name.call(Object.create(policy)));
for(const method of ["createHTML","createScript","createScriptURL"]){
 check(policy[method].length,1);rejects(()=>policy[method]());rejects(()=>policy[method].call({},"input"));
}
check(calls,0);check(String(policy.createHTML(undefined)),"undefined");check(calls,1);
check(trustedTypes.createPolicy("empty").name,"empty");
console.log("trusted IDL passed");
')
}

fn test_window_trusted_types_getter_returns_the_receiver_windows_factory() {
	run_trusted_types_idl_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const getter=Object.getOwnPropertyDescriptor(window,"trustedTypes").get;
check(getter.name,"get trustedTypes");check(getter.length,0);check(getter.call(window),trustedTypes);check(getter.call(null),trustedTypes);check(getter.call(undefined),trustedTypes);
for(const receiver of [{},Object.create(Window.prototype),Object.create(window),document,document.body]){
 let rejected=false;try{getter.call(receiver);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);
}
const view=child.contentWindow,childFactory=view.trustedTypes;
check(!!childFactory,true);check(childFactory===trustedTypes,false);check(getter.call(view),childFactory);
// Reading trustedTypes creates the initial child realm. Read its global
// again so descriptor lookup uses that realm rather than the initial proxy.
const childGlobal=child.contentWindow;check(getter.call(childGlobal),childFactory);
const childGetter=Object.getOwnPropertyDescriptor(childGlobal,"trustedTypes").get;check(childGetter.call(window),trustedTypes);
const childPolicy=childFactory.createPolicy("child policy",{createHTML:value=>value});
check(childFactory.isHTML(childPolicy.createHTML("child value")),true);
check(globalThis.__ladybirdRegisterTrustedTypesFactory,undefined);check(globalThis.__ladybirdTrustedTypesFactoryGetter,undefined);
console.log("trusted IDL passed");
')
}
