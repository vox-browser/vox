module browserjs

fn test_dom_rect_read_only_binding_native_edges_and_brands() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	assert runtime.evaluate_host(r'
 class DerivedRect extends DOMRectReadOnly{};const rect=new DerivedRect(10,20,-4,-6);
 const json=rect.toJSON();rect.x=99;
 let brands=0;for(const read of [()=>DOMRectReadOnly.prototype.toJSON.call({}),()=>Object.getOwnPropertyDescriptor(DOMRectReadOnly.prototype,"x").get.call(new Proxy(rect,{})),()=>DOMRectReadOnly(1)])try{read()}catch(e){if(e instanceof TypeError)brands++}
 rect instanceof DerivedRect&&rect instanceof DOMRectReadOnly&&rect.x===10&&rect.left===6&&rect.right===10&&rect.top===14&&rect.bottom===20&&JSON.stringify(json)==="{\"x\":10,\"y\":20,\"width\":-4,\"height\":-6,\"top\":14,\"right\":10,\"bottom\":20,\"left\":6}"&&Object.prototype.toString.call(rect)==="[object DOMRectReadOnly]"&&brands===3;
 ')! == 'true'
}

fn test_dom_rect_read_only_binding_dictionary_order_and_original_exceptions() {
	$if !darwin && !linux {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	assert runtime.evaluate_host(r'
 const order=[],source={};for(const name of ["x","y","width","height"])Object.defineProperty(source,name,{get(){order.push(name);return {valueOf(){order.push("number "+name);return 2}}}});
 const rect=DOMRectReadOnly.fromRect(source),marker={};let same=false,big=false;
 try{new DOMRectReadOnly({valueOf(){throw marker}})}catch(e){same=e===marker}
 try{new DOMRectReadOnly(1n)}catch(e){big=e instanceof TypeError}
 const nan=new DOMRectReadOnly(NaN,0,1,1);
 const infinity=new DOMRectReadOnly(Infinity,0,1,1);
 same&&big&&Number.isNaN(nan.left)&&infinity.right===Infinity&&rect.x===2&&order.join(",")==="height,number height,width,number width,x,number x,y,number y"&&DOMRectReadOnly.fromRect(null).width===0;
 ')! == 'true'
}
