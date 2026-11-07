module browserjs

import dom
import html

fn test_hash_change_event_constructor_defaults_conversion_and_brands() {
	url := dom.URL{value: 'https://hash-change.example/'}
	mut document := html.parse_navigation_document('<!doctype html><p>hash</p>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_event_target_binding()!
	assert runtime.evaluate_host(r'(()=>{
 const check=(v,n)=>{if(!v)throw new Error(n)},C=HashChangeEvent,p=C.prototype;
 check(C.name==="HashChangeEvent"&&C.length===1&&Object.getPrototypeOf(C)===Event&&Object.getPrototypeOf(p)===Event.prototype,"constructor metadata");
 for(const name of ["oldURL","newURL"]){const d=Object.getOwnPropertyDescriptor(p,name);check(d.get.name==="get "+name&&d.set===undefined&&d.enumerable&&d.configurable,"getter "+name);}
 const empty=new C("hashchange");
 check(empty.oldURL===""&&empty.newURL===""&&!empty.bubbles&&!empty.cancelable&&!empty.isTrusted&&Object.prototype.toString.call(empty)==="[object HashChangeEvent]","defaults");
 const order=[],init={get bubbles(){order.push("bubbles");return true},get cancelable(){order.push("cancelable");return false},get composed(){order.push("composed");return false},
  get newURL(){order.push("newURL");return "https://a.test/#\uD800"},get oldURL(){order.push("oldURL");return {toString(){return "https://a.test/"}}}};
 const event=new C("hashchange",init);
 check(order.join()==="bubbles,cancelable,composed,newURL,oldURL","dictionary order "+order.join());
 check(event.bubbles&&event.newURL==="https://a.test/#�"&&event.oldURL==="https://a.test/","USVString members");
 let rejected=0;for(const op of [()=>C("x"),()=>new C(),()=>new C("x",1),()=>Object.getOwnPropertyDescriptor(p,"oldURL").get.call(new Event("x"))])try{op()}catch(e){if(e instanceof TypeError)rejected++}
 check(rejected===4,"type errors");return true;
})()')! == 'true'
}
