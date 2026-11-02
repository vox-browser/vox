module main

import browserjs

fn test_shared_geometry_descriptors_keep_live_reads_flags_and_receiver_checks() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	_ = runtime.evaluate_host(r'
const __elementRecords=new WeakMap(),__elementRecordGet=WeakMap.prototype.get,__elementApply=Reflect.apply;
const __compactScrollFinite=Number.isFinite,requests=[],sizes={a:30,b:80,s:90};
function __queryElements(key,action,name){
 requests.push([key,action,name]);
 if(action==="setScroll"){sizes[key]=JSON.parse(name).value;return null;}
 if(action==="offsetParent")return key;
 return name==="rect"?{width:sizes[key]}:sizes[key];
}
const a={},b={},svg={};
const sa={bridgeKey:"a",namespaceURI:"http://www.w3.org/1999/xhtml"};
const sb={bridgeKey:"b",namespaceURI:sa.namespaceURI};
const ss={bridgeKey:"s",namespaceURI:"http://www.w3.org/2000/svg"};
__elementRecords.set(a,sa);__elementRecords.set(b,sb);__elementRecords.set(svg,ss);
')!
	_ = runtime.evaluate_host(compact_element_geometry_bindings())!
	_ = runtime.evaluate_host(r'
__compactElementGeometry(a,sa);__compactElementGeometry(b,sb);__compactElementGeometry(svg,ss);
for(const name of ["clientTop","clientLeft","clientWidth","clientHeight","scrollWidth","scrollHeight","scrollTop","scrollLeft","offsetTop","offsetLeft","offsetWidth","offsetHeight","offsetParent"]){
 const descriptor=Object.getOwnPropertyDescriptor(a,name);
 if(!descriptor||!descriptor.enumerable||!descriptor.configurable||typeof descriptor.get!=="function")throw new Error("own descriptor "+name);
 if((name==="scrollTop"||name==="scrollLeft")!==(typeof descriptor.set==="function"))throw new Error("setter "+name);
}
const method=Object.getOwnPropertyDescriptor(a,"getBoundingClientRect");
if(!method.writable||!method.enumerable||!method.configurable||method.value.name!=="getBoundingClientRect"||method.value.length!==0)throw new Error("method descriptor");
if(a.clientWidth!==30||b.clientWidth!==80||svg.clientWidth!==90||a.getBoundingClientRect().width!==30)throw new Error("initial values");
sizes.a=45;
if(a.clientWidth!==45||a.getBoundingClientRect().width!==45||b.clientWidth!==80)throw new Error("live geometry");
if(Object.hasOwn(svg,"offsetWidth")||Object.hasOwn(svg,"offsetParent"))throw new Error("SVG offsets");
for(const receiver of [{},Object.create(a),null]){
 for(const action of [()=>Object.getOwnPropertyDescriptor(a,"clientWidth").get.call(receiver),()=>a.getBoundingClientRect.call(receiver)]){
  let caught=false;try{action();}catch(error){caught=error instanceof TypeError;}
  if(!caught)throw new Error("receiver check");
 }
}
// Keep the pre-existing owner-bound offsetParent accessor behavior.
if(Object.getOwnPropertyDescriptor(a,"offsetParent").get.call(b)!=="a")throw new Error("offset owner");
let conversions=0;
a.scrollTop={valueOf(){conversions++;return 17.5;}};
if(conversions!==1||a.scrollTop!==17.5)throw new Error("scroll conversion");
b.scrollLeft=Infinity;if(b.scrollLeft!==0)throw new Error("nonfinite scroll");
const writes=requests.length;
try{Object.getOwnPropertyDescriptor(a,"scrollTop").set.call({}, {valueOf(){conversions++;return 2;}});throw new Error("missing brand error");}catch(error){if(!(error instanceof TypeError))throw error;}
try{a.scrollTop=Symbol();throw new Error("missing symbol error");}catch(error){if(!(error instanceof TypeError))throw error;}
if(conversions!==1||requests.length!==writes)throw new Error("conversion before brand or query on error");
a.getBoundingClientRect=()=>"replacement";
if(a.getBoundingClientRect()!=="replacement"||b.getBoundingClientRect().width!==0)throw new Error("method assignment");
delete a.clientWidth;if(Object.hasOwn(a,"clientWidth"))throw new Error("descriptor deletion");
')!
	if !disable_shared_element_geometry {
		assert runtime.evaluate_host(r'
Object.getOwnPropertyDescriptor(a,"clientHeight").get===Object.getOwnPropertyDescriptor(b,"clientHeight").get
&&Object.getOwnPropertyDescriptor(a,"scrollTop").set===Object.getOwnPropertyDescriptor(b,"scrollTop").set
&&Object.getOwnPropertyDescriptor(a,"offsetWidth").get===Object.getOwnPropertyDescriptor(b,"offsetWidth").get
')! == 'true'
	}
}
