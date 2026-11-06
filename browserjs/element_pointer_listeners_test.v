module browserjs

fn test_element_pointer_listeners_share_native_dispatch_options_and_removal() {
	$if !darwin {
		return
	}
	fixture := element_wheel_fixture()!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut abort := AbortSignalHost.create(fixture.document)!
	abort.install(mut runtime)!
	for name in native_pointer_event_names() {
		assert runtime.evaluate_host(r'(function(type){
 const calls=[],target=wheelDiv;
 const removed=()=>{throw new Error("removed mouse listener")};
 target.addEventListener(type,removed);target.removeEventListener(type,removed);
 const controller=new AbortController();target.addEventListener(type,removed,{signal:controller.signal});controller.abort();
 function first(event){calls.push("first");if(this!==target||event.target!==target||event.currentTarget!==target||!(event instanceof MouseEvent))throw new Error("wrong native mouse target");event.preventDefault();}
 target.addEventListener(type,first,{once:true});target.addEventListener(type,first,{once:true});
 target.addEventListener(type,event=>{calls.push("passive");event.preventDefault()},{passive:true});
 const event=new MouseEvent(type,{cancelable:true,clientX:23,clientY:17});
 const firstResult=target.dispatchEvent(event),second=new MouseEvent(type,{cancelable:true});
 const secondResult=target.dispatchEvent(second);
 return !firstResult&&secondResult&&event.defaultPrevented&&!second.defaultPrevented&&calls.join(",")==="first,passive,passive"&&event.clientX===23&&event.clientY===17&&event.currentTarget===null&&target.legacyAdds.length===0;
})(' + '"${name}"' + ')')! == 'true', name
		element := fixture.document.get_element_by_id('wheelDiv')?
		assert element.as_node().has_event_listener(name), name
	}
	element_wheel_assert_contexts(fixture)
	assert fixture.settings.realm().reported_exceptions.len == 0
}
