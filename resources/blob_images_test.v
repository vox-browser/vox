module main

import dom
import domurl
import encoding.base64
import fileapi
import html
import page
import time

const native_blob_image_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn native_blob_image_document(address string) &dom.Document {
	owner := page.Page.create(1) or { panic(err) }
	return parse_browser_navigation_document_for_page_with_response_time('<!doctype html><img id="picture">',
		dom.URL{value: address}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn test_script_created_blob_png_reaches_the_native_image_model() {
	for address in ['https://blob-image.example/', 'file:///tmp/vox-script-blob-image.html'] {
		assert_script_created_blob_png_image(address)!
	}
}

fn assert_script_created_blob_png_image(address string) ! {
	bytes_literal := base64.decode(native_blob_image_png).map(it.str()).join(',')
	mut app := &BrowserApp{
		page_model: page.Page.create(1)!
		script_policy: .enabled
		viewport_width: 320
		viewport_height: 200
	}
	app.install_loaded_page(LoadedPage{
		url: address
		content_type: 'text/html'
		markup: '<!doctype html><img id="picture"><script>globalThis.sourceSetReturned=false;globalThis.loadWidth=-1;globalThis.imageBytes=new Uint8Array([${bytes_literal}]);globalThis.imageBlob=new Blob([imageBytes],{type:"image/png"});globalThis.imageAddress=URL.createObjectURL(imageBlob);picture.addEventListener("load",()=>{loadWidth=sourceSetReturned?picture.naturalWidth:-2;URL.revokeObjectURL(imageAddress)});picture.src=imageAddress;sourceSetReturned=true;</script>'
	}, false)
	defer { app.js_runtime.close(); app.document.run_unloading_cleanup_steps(); app.document.finalize() }
	assert app.js_messages == []string{}
	assert app.js_runtime.evaluate_host('imageBytes.length===68&&imageBlob.size===68')! == 'true'
	assert app.js_runtime.evaluate_host('picture.src===imageAddress')! == 'true'
	image := unsafe { &dom.HTMLImageElement(app.document.get_element_by_id('picture') or { panic('picture') }) }
	assert app.document.is_fully_active()
	model := html.html_image_element_model_for_dom_element(image)
	assert model.has_fetch_hook()
	metadata := app.js_runtime.evaluate_host('JSON.stringify([loadWidth,imageBytes.length,imageBlob.size,picture.complete,picture.naturalWidth])')!
	assert html.html_image_element_is_image_available(image), '${address}: ${metadata}'
	assert html.html_image_element_natural_width(image) == 1
	assert html.html_image_element_natural_height(image) == 1
	settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .dom_manipulation }) or { break }
		task.execute()
	}
	assert app.js_runtime.evaluate_host('loadWidth')! == '1'
	assert app.js_runtime.evaluate_host('URL.revokeObjectURL(imageAddress);picture.complete&&picture.naturalWidth===1')! == 'true'
}

fn test_blob_image_fetch_uses_current_owner_and_rejects_revoked_urls() {
	mut document := native_blob_image_document('https://blob-image.example/')
	mut other := native_blob_image_document('https://other-blob-image.example/')
	defer { document.run_unloading_cleanup_steps(); document.finalize(); other.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	address := domurl.DOMURL.create_object_url(fileapi.BlobURLObject.from_blob(
		fileapi.Blob.create(base64.decode(native_blob_image_png), 'image/png')), settings)!
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	model := html.html_image_element_model_for_dom_element(image)
	decoded := browser_fetch_image_request(image, model, dom.URL{value: address})!
	assert decoded.intrinsic_width()? == 1
	assert !decoded.is_cors_cross_origin()
	other.adopt_node(unsafe { &dom.Node(image) })
	if _ := browser_fetch_image_request(image, model, dom.URL{value: address}) {
		assert false, 'cross-origin adopted image obtained the creator Blob'
	}
	document.adopt_node(unsafe { &dom.Node(image) })
	assert browser_fetch_image_request(image, model, dom.URL{value: address})!.intrinsic_width()? == 1
	domurl.DOMURL.revoke_object_url(address, settings)
	if _ := browser_fetch_image_request(image, model, dom.URL{value: address}) {
		assert false, 'revoked Blob URL still fetched'
	}
	assert decoded.intrinsic_width()? == 1
}

fn test_native_image_events_follow_the_latest_source_and_listener_options() {
	bytes_literal := base64.decode(native_blob_image_png).map(it.str()).join(',')
	mut app := &BrowserApp{
		page_model: page.Page.create(1)!
		script_policy: .enabled
		viewport_width: 320
		viewport_height: 200
	}
	app.install_loaded_page(LoadedPage{
		url: 'https://blob-events.example/'
		content_type: 'text/html'
		markup: '<!doctype html><img id="picture">'
	}, false)
	defer { app.js_runtime.close(); app.document.run_unloading_cleanup_steps(); app.document.finalize() }
	assert app.js_runtime.evaluate_host('globalThis.events=[];globalThis.onceCount=0;globalThis.removedCount=0;globalThis.imageBytes=new Uint8Array([${bytes_literal}]);globalThis.firstURL=URL.createObjectURL(new Blob([imageBytes],{type:"image/png"}));globalThis.secondURL=URL.createObjectURL(new Blob([imageBytes],{type:"image/png"}));globalThis.removed=()=>removedCount++;picture.addEventListener("load",removed);picture.removeEventListener("load",removed);picture.addEventListener("load",()=>onceCount++,{once:true});for(const type of ["load","error"])picture.addEventListener(type,e=>events.push([e.type,e instanceof Event,e.isTrusted,e.target===picture,e.currentTarget===picture]));picture.src=firstURL;picture.src=secondURL;JSON.stringify(events)')! == '[]'
	drain_native_blob_image_events(app.document)
	assert app.js_runtime.evaluate_host('JSON.stringify([events,onceCount,removedCount])')! == '[[["load",true,true,true,true]],1,0]'
	// An empty source mutates the existing request instead of replacing its
	// identity. Its changed URL/state must also cancel an earlier queued load.
	assert app.js_runtime.evaluate_host('events.length=0;picture.src=firstURL;picture.src="";JSON.stringify(events)')! == '[]'
	drain_native_blob_image_events(app.document)
	assert app.js_runtime.evaluate_host('JSON.stringify([events,onceCount,removedCount])')! == '[[["error",true,true,true,true]],1,0]'
	assert app.js_runtime.evaluate_host('URL.revokeObjectURL(firstURL);URL.revokeObjectURL(secondURL);picture.complete&&picture.naturalWidth===0')! == 'true'
}

fn drain_native_blob_image_events(document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .dom_manipulation }) or { break }
		task.execute()
	}
}

fn test_blob_svg_images_use_the_response_mime_type() {
	mut document := native_blob_image_document('https://blob-svg.example/')
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	address := domurl.DOMURL.create_object_url(fileapi.BlobURLObject.from_blob(
		fileapi.Blob.create('<svg xmlns="http://www.w3.org/2000/svg" width="7" height="5"><rect width="7" height="5" fill="green"/></svg>'.bytes(), 'image/svg+xml')), settings)!
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	decoded := browser_fetch_image_request(image, html.html_image_element_model_for_dom_element(image), dom.URL{value: address})!
	assert decoded.intrinsic_width()? == 7
	assert decoded.intrinsic_height()? == 5
	assert !decoded.is_cors_cross_origin()
}

fn test_local_document_blob_images_keep_the_creators_typed_file_origin() {
	mut document := native_blob_image_document('file:///tmp/vox-blob-image.html')
	defer { document.run_unloading_cleanup_steps(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	address := domurl.DOMURL.create_object_url(fileapi.BlobURLObject.from_blob(
		fileapi.Blob.create(base64.decode(native_blob_image_png), 'image/png')), settings)!
	parsed := settings.parse_url(address)?
	assert parsed.origin().is_opaque_file_origin()
	assert parsed.origin().is_same_origin(document.origin())
	image := unsafe { &dom.HTMLImageElement(document.get_element_by_id('picture')?) }
	decoded := browser_fetch_image_request(image, html.html_image_element_model_for_dom_element(image), parsed)!
	assert decoded.intrinsic_width()? == 1
	assert !decoded.is_cors_cross_origin()
}
