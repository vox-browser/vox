module browserjs

import dom
import html
import page

@[heap]
struct DragMediaHandlerReplay {
mut:
	calls int
}

@[heap]
struct DragMediaHandlerFixture {
	runtime  &Runtime
	host     &MediaElementHost
	video    &html.HTMLMediaElement
	audio    &html.HTMLMediaElement
	owner    &page.Page
	settings &html.EnvironmentSettingsObject
}

fn drag_media_handler_fixture(replay ?MediaElementReplayHook) !&DragMediaHandlerFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-drag-media-handlers.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<video id="video"></video><audio id="audio"></audio>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}");0')!
		}
	}
	handle := voidptr(runtime)
	runtime.define_value_host_function('__dragMediaHandlerContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	video_element := document.get_element_by_id('video') or { return error('missing drag media video') }
	video := html.html_media_element_for_dom_element(video_element) or { return error('missing drag video model') }
	audio_element := document.get_element_by_id('audio') or { return error('missing drag media audio') }
	audio := html.html_media_element_for_dom_element(audio_element) or { return error('missing drag audio model') }
	return &DragMediaHandlerFixture{ runtime: runtime, host: host, video: video, audio: audio,
		owner: owner, settings: settings }
}

// This public descriptor guard compiles against the parent implementation.
fn drag_media_handler_guard(runtime &Runtime) !bool {
	return runtime.evaluate_host('["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"].every(name=>!!Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"on"+name))')! == 'true'
}

fn drag_media_handler_install_files(mut runtime Runtime, document &dom.Document) ! {
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := FileHost.create(document)!
	files.install(mut runtime)!
	files.install_constructor()!
	mut lists := FileListHost.create(document)!
	lists.install(mut runtime)!
	lists.install_constructor()!
}

fn drag_media_handler_event(name string, transfer ?&html.DataTransfer) &html.DragEvent {
	return html.DragEvent.create(name, html.DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{ cancelable: true }
					detail:    7
				}
			}
			client_x: 3.75
			client_y: 4.25
		}
		data_transfer: transfer
	}, 19.75, 22.25, 1.75, 2.25)
}

fn drag_media_handler_assert_contexts(fixture &DragMediaHandlerFixture) {
	assert fixture.settings.realm().reported_exceptions.len == 0
	assert fixture.settings.realm().script_execution_depth == 0
		&& fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_media_drag_handler_descriptors_check_brands_before_replay_and_author_traps() {
	$if !darwin { return }
	state := &DragMediaHandlerReplay{}
	fixture := drag_media_handler_fixture(fn [state] (_ &Runtime) ! {
		mut observation := unsafe { &DragMediaHandlerReplay(state) }
		observation.calls++
	})!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert drag_media_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const prototype=HTMLMediaElement.prototype,names=["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"];
 let traps=0,conversions=0;
 const proxies=[video,audio].map(player=>new Proxy(player,{get(){traps++;throw "proxy get"},getPrototypeOf(){traps++;throw "proxy prototype"}})),value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};
 for(const name of names){
  const property="on"+name,descriptor=Object.getOwnPropertyDescriptor(prototype,property);
  if(!descriptor||!descriptor.enumerable||!descriptor.configurable||descriptor.get.name!=="get "+property||descriptor.get.length!==0||descriptor.set.name!=="set "+property||descriptor.set.length!==1||![descriptor.get,descriptor.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))||Object.hasOwn(video,property)||Object.hasOwn(audio,property))return false;
  for(const receiver of [Object.create(prototype),...proxies,null,undefined,1]){
   let getterError=false,setterError=false;
   try{descriptor.get.call(receiver)}catch(error){getterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   try{descriptor.set.call(receiver,value)}catch(error){setterError=error instanceof TypeError&&error.message==="Not an object of type HTMLMediaElement"}
   if(!getterError||!setterError)return false;
  }
 }
 return traps===0&&conversions===0;
})()')! == 'true'
	assert state.calls == 0
	assert runtime.evaluate_host('[video,audio].every(player=>["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"].every(name=>player["on"+name]===null))')! == 'true'
	assert state.calls == 14
	drag_media_handler_assert_contexts(fixture)
}

fn test_native_media_drag_handlers_keep_real_drag_file_item_entry_identity_and_listener_order() {
	$if !darwin { return }
	fixture := drag_media_handler_fixture(none)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	assert drag_media_handler_guard(runtime)!
	drag_media_handler_install_files(mut runtime, fixture.host.document)!
	assert runtime.evaluate_host(r'(()=>{
 const names=["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"],transfer=new DataTransfer(),file=new File(["bytes"],"drag-file.txt",{type:"TEXT/PLAIN",lastModified:7}),item=transfer.items.add(file),entry=item.webkitGetAsEntry(),fileSnapshot=item.getAsFile(),filesSnapshot=transfer.files;
 globalThis.dragMediaTransfer=transfer;globalThis.dragMediaFile=file;globalThis.dragMediaFileSnapshot=fileSnapshot;globalThis.dragMediaFiles=filesSnapshot;globalThis.dragMediaItem=item;globalThis.dragMediaEntry=entry;globalThis.dragMediaChecks=[];globalThis.dragMediaCallbacks={};
 if(fileSnapshot===file||filesSnapshot[0]===file||filesSnapshot[0]===fileSnapshot||fileSnapshot.name!==file.name||fileSnapshot.type!==file.type||fileSnapshot.size!==file.size||filesSnapshot[0].name!==file.name||entry.name!==file.name||!entry.isFile||entry.isDirectory)return false;
 for(const [ownerName,player] of [["video",video],["audio",audio]])for(const name of names){
  const property="on"+name,order=[];let expected;
  const valid=event=>{const nextFile=item.getAsFile(),nextFiles=event.dataTransfer.files;return event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof Event&&event.type===name&&event.target===player&&event.currentTarget===player&&event.dataTransfer===transfer&&event.dataTransfer.items[0]===item&&nextFile!==file&&nextFile!==fileSnapshot&&nextFiles!==filesSnapshot&&nextFiles[0]!==nextFile&&nextFiles[0].name===file.name&&nextFile.name===file.name&&nextFile.type===file.type&&nextFile.size===file.size&&entry.name===file.name&&entry.isFile&&!entry.isDirectory&&__dragMediaHandlerContext()};
  const before=function(){order.push("before")},after=function(){order.push("after")};
  const replacement=function(event){order.push("replacement");dragMediaChecks.push(this===player&&arguments.length===1&&event===expected&&!event.isTrusted&&valid(event));return false};
  player.addEventListener(name,before);player[property]=()=>order.push("old");player.addEventListener(name,after);player[property]=replacement;player[property]=replacement;
  player.addEventListener(name,replacement);player.removeEventListener(name,replacement);
  expected=new DragEvent(name,{cancelable:true,dataTransfer:transfer,clientX:3.75,clientY:4.25});
  if(player[property]!==replacement||Object.hasOwn(player,property)||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,replacement,after")return false;
  order.length=0;const zero=function(event){order.push("zero");dragMediaChecks.push(this===player&&event===expected&&!event.isTrusted&&valid(event));return 0};player[property]=zero;expected=new DragEvent(name,{cancelable:true,dataTransfer:transfer});
  if(player[property]!==zero||player.dispatchEvent(expected)!==true||expected.defaultPrevented||order.join(",")!=="before,zero,after")return false;
  order.length=0;player[property]=null;expected=new DragEvent(name,{cancelable:true,dataTransfer:transfer});
  if(player[property]!==null||player.dispatchEvent(expected)!==true||order.join(",")!=="before,after")return false;
  const reactivated=function(event){order.push("reactivated");const first=item.webkitGetAsEntry(),second=item.webkitGetAsEntry();dragMediaChecks.push(this===player&&arguments.length===1&&event===(event.isTrusted?dragMediaNativeExpected:expected)&&valid(event)&&first!==second&&first!==entry&&second!==entry&&first.name===entry.name&&second.name===entry.name&&first.isFile&&!first.isDirectory);return false};
  player[property]=reactivated;player[property]=reactivated;dragMediaCallbacks[ownerName+":"+name]=reactivated;expected=new DragEvent(name,{cancelable:true,dataTransfer:transfer});order.length=0;
  if(player[property]!==reactivated||player.dispatchEvent(expected)!==false||!expected.defaultPrevented||expected.currentTarget!==null||order.join(",")!=="before,after,reactivated")return false;
 }
 return dragMediaChecks.length===42&&dragMediaChecks.every(Boolean);
})()')! == 'true'
	transfer := runtime.native_data_transfer(runtime.evaluate_host_value('dragMediaTransfer')!)!
	item_wrapper := runtime.evaluate_host_value('dragMediaItem')!
	item := runtime.native_data_transfer_item(item_wrapper)!
	assert runtime.javascript_data_transfer_item(item)! == item_wrapper
	entry_wrapper := runtime.evaluate_host_value('dragMediaEntry')!
	entry := runtime.native_file_system_entry(entry_wrapper)!
	assert runtime.javascript_file_system_entry(entry)! == entry_wrapper
	for expression in ['dragMediaFile', 'dragMediaFileSnapshot', 'dragMediaFiles[0]'] {
		file_wrapper := runtime.evaluate_host_value(expression)!
		file := runtime.native_file(file_wrapper)!
		assert runtime.javascript_file(file)! == file_wrapper
		assert file.raw_bytes() == 'bytes'.bytes()
	}
	list_wrapper := runtime.evaluate_host_value('dragMediaFiles')!
	list := runtime.native_file_list(list_wrapper)!
	assert runtime.javascript_file_list(list)! == list_wrapper
	for index, media in [fixture.video, fixture.audio] {
		owner_name := if index == 0 { 'video' } else { 'audio' }
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value(owner_name)!)!) == voidptr(media.event_target())
		assert media.event_target().event_listener_list().len == 21
		for name in ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop'] {
			assert runtime.javascript_event_handler(media.event_target(), name)! == runtime.evaluate_host_value('dragMediaCallbacks["${owner_name}:${name}"]')!
			event := drag_media_handler_event(name, transfer)
			base := unsafe { &dom.Event(event) }
			wrapper := runtime.javascript_event(base)!
			assert runtime.javascript_event(base)! == wrapper
			assert voidptr(runtime.native_event(wrapper)!) == voidptr(base)
			// Native host globals are readonly/nonconfigurable. Give each export
			// its own name instead of trying to replace the first event function.
			export_name := '__dragMediaNativeEvent_${owner_name}_${name}'
			runtime.define_value_host_function(export_name, fn [wrapper] (_ voidptr, _ []voidptr) !voidptr {
				return wrapper
			})!
			runtime.evaluate_host('globalThis.dragMediaNativeExpected=${export_name}();0')!
			assert voidptr(runtime.native_event(runtime.evaluate_host_value('dragMediaNativeExpected')!)!) == voidptr(base)
			assert !media.event_target().dispatch_event(base)
			assert event.is_trusted() && event.default_prevented() && event.current_target() == none
			assert runtime.evaluate_host('dragMediaNativeExpected.currentTarget===null&&dragMediaNativeExpected.isTrusted&&dragMediaNativeExpected.dataTransfer===dragMediaTransfer')! == 'true'
		}
	}
	assert runtime.evaluate_host('dragMediaChecks.length===56&&dragMediaChecks.every(Boolean)&&dragMediaTransfer.items[0]===dragMediaItem&&dragMediaTransfer.files[0]!==dragMediaFile&&dragMediaTransfer.files[0].name===dragMediaFile.name&&dragMediaEntry.name==="drag-file.txt"')! == 'true'
	drag_media_handler_assert_contexts(fixture)
}

fn test_native_media_drag_handler_legacy_conversion_callable_proxy_script_gate_and_close_cleanup() {
	$if !darwin { return }
	fixture := drag_media_handler_fixture(none)!
	mut runtime := fixture.runtime
	mut owner := fixture.owner
	defer { runtime.close() }
	assert drag_media_handler_guard(runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const names=["drag","dragend","dragenter","dragleave","dragover","dragstart","drop"];
 globalThis.dragMediaLegacyReads=0;globalThis.dragMediaProxyCalls=0;globalThis.dragMediaProxyChecks=[];globalThis.dragMediaProxyCallbacks={};
 for(const [ownerName,player] of [["video",video],["audio",audio]])for(const name of names){
  const property="on"+name;
  for(const primitive of [null,undefined,false,0,"return false",Symbol("handler"),1n]){player[property]=primitive;if(player[property]!==null)return false}
  const object={get handleEvent(){dragMediaLegacyReads++;throw "handleEvent"},[Symbol.toPrimitive](){dragMediaLegacyReads++;throw "conversion"}},proxy=new Proxy({},{get(){dragMediaLegacyReads++;throw "proxy get"},getPrototypeOf(){dragMediaLegacyReads++;throw "proxy prototype"}});
  for(const value of [object,proxy]){player[property]=value;const event=new DragEvent(name,{cancelable:true});if(player[property]!==value||player.dispatchEvent(event)!==true||event.defaultPrevented)return false}
  const callable=new Proxy(function(event){dragMediaProxyCalls++;dragMediaProxyChecks.push(arguments.length===1&&this===player&&event instanceof DragEvent&&event.type===name&&event.target===player&&event.currentTarget===player&&event.dataTransfer===null&&__dragMediaHandlerContext());return false},{apply(callback,receiver,args){dragMediaProxyCalls++;return Reflect.apply(callback,receiver,args)},get(){dragMediaLegacyReads++;throw "callable get"}});
  player[property]=callable;dragMediaProxyCallbacks[ownerName+":"+name]=callable;const event=new DragEvent(name,{cancelable:true});
  if(player[property]!==callable||Object.hasOwn(player,property)||player.dispatchEvent(event)!==false||!event.defaultPrevented||event.currentTarget!==null)return false;
 }
 return dragMediaLegacyReads===0&&dragMediaProxyCalls===28&&dragMediaProxyChecks.length===14&&dragMediaProxyChecks.every(Boolean);
})()')! == 'true'
	owner.set_is_scripting_enabled(false)
	for media in [fixture.video, fixture.audio] {
		assert media.event_target().event_listener_list().len == 7
		for name in ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop'] {
			event := drag_media_handler_event(name, none)
			assert media.event_target().dispatch_event(unsafe { &dom.Event(event) })
			assert !event.default_prevented()
		}
	}
	assert runtime.evaluate_host('dragMediaProxyCalls===28&&dragMediaProxyChecks.length===14')! == 'true'
	owner.set_is_scripting_enabled(true)
	for index, media in [fixture.video, fixture.audio] {
		owner_name := if index == 0 { 'video' } else { 'audio' }
		for name in ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop'] {
			assert runtime.javascript_event_handler(media.event_target(), name)! == runtime.evaluate_host_value('dragMediaProxyCallbacks["${owner_name}:${name}"]')!
			event := drag_media_handler_event(name, none)
			assert !media.event_target().dispatch_event(unsafe { &dom.Event(event) })
			assert event.default_prevented() && event.current_target() == none
		}
	}
	assert runtime.evaluate_host('dragMediaLegacyReads===0&&dragMediaProxyCalls===56&&dragMediaProxyChecks.length===28&&dragMediaProxyChecks.every(Boolean)')! == 'true'
	drag_media_handler_assert_contexts(fixture)
	assert runtime.protected_values_.len > 0
	assert fixture.host.records.len == 2 && fixture.host.elements.len > 0
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert runtime.close_handlers_.len == 0
	assert fixture.host.closed && fixture.host.records.len == 0 && fixture.host.elements.len == 0
	for media in [fixture.video, fixture.audio] {
		for name in ['drag', 'dragend', 'dragenter', 'dragleave', 'dragover', 'dragstart', 'drop'] {
			event := drag_media_handler_event(name, none)
			assert media.event_target().dispatch_event(unsafe { &dom.Event(event) })
			assert !event.default_prevented()
		}
	}
	drag_media_handler_assert_contexts(fixture)
}
