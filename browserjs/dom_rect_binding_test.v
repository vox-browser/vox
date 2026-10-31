module browserjs

import platform

fn test_mutable_dom_rect_uses_native_storage_with_readonly_inheritance() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	assert runtime.evaluate_host(r'
class Derived extends DOMRect{};const rect=new Derived(10,20,-4,-6);
rect.x=30;rect.y=40;rect.width=-8;rect.height=-12;
rect instanceof DOMRect&&rect instanceof DOMRectReadOnly&&rect instanceof Derived&&rect.left===22&&rect.right===30&&rect.top===28&&rect.bottom===40&&JSON.stringify(rect.toJSON())==="{\"x\":30,\"y\":40,\"width\":-8,\"height\":-12,\"top\":28,\"right\":30,\"bottom\":40,\"left\":22}"&&Object.prototype.toString.call(rect)==="[object DOMRect]";
')! == 'true'
}

fn test_mutable_dom_rect_conversion_order_and_setter_branding() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	assert runtime.evaluate_host(r'
const order=[],source={};for(const name of ["x","y","width","height"])Object.defineProperty(source,name,{get(){order.push(name);return 2}});
const rect=DOMRect.fromRect(source),setter=Object.getOwnPropertyDescriptor(DOMRect.prototype,"x").set;
let converted=false,brands=0;for(const receiver of [{},new DOMRectReadOnly(),new Proxy(rect,{})])try{setter.call(receiver,{valueOf(){converted=true;return 1}})}catch(error){if(error instanceof TypeError)brands++}
const marker={};let original=false,big=false;try{rect.x={valueOf(){throw marker}}}catch(error){original=error===marker}try{rect.width=1n}catch(error){big=error instanceof TypeError}
rect.x=NaN;
order.join(",")==="height,width,x,y"&&rect instanceof DOMRect&&rect.width===2&&brands===3&&!converted&&original&&big&&Number.isNaN(rect.left)&&DOMRect.fromRect(null).height===0;
')! == 'true'
}

fn test_native_rectangles_outlive_a_transient_host_allocation_scope() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_rect_read_only_binding()!
	mut scratch := platform.begin_thread_scratch('native rectangle lifetime')
	runtime.evaluate_host('globalThis.retainedMutable=new DOMRect(3,4,5,6);globalThis.retainedReadonly=new DOMRectReadOnly(7,8,9,10);')!
	scratch.finish()
	assert runtime.evaluate_host('retainedMutable.x=11;retainedMutable.left===11&&retainedMutable.right===16&&retainedReadonly.bottom===18')! == 'true'
}
