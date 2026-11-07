module main

import dom
import page

fn native_window_find_app(markup string) !&BrowserApp {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://native-window-find.example/page'
		content_type: 'text/html'
		markup:       markup
	}, false)
	return app
}

fn test_native_window_find_uses_rendered_source_ranges_and_preserves_selection_after_exhaustion() {
	$if !darwin {
		return
	}
	mut app := native_window_find_app('<!doctype html><p id="visible">needle needle</p><p style="display:none">ghost needle</p><style>.unused{content:"ghost"}</style><script>globalThis.findResults=[window.find("ghost"),window.find("NEEDLE"),window.find("NEEDLE"),window.find("NEEDLE"),window.find("missing")];</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('findResults.join(",")')! == 'false,true,true,false,false'
	selection := document.get_selection() or { panic('selection') }
	range := selection.range() or { panic('selected rendered match') }
	assert range.to_string() == 'needle'
	assert range.start_container() == document.get_element_by_id('visible')?.as_node().first_child()?
	assert range.start_offset() == 7 && range.end_offset() == 13
	assert range.get_client_rects().length() > 0
	assert app.js_messages == []
}

fn test_native_window_find_replays_coercion_dom_mutations_before_actual_rendered_search() {
	$if !darwin {
		return
	}
	mut app := native_window_find_app('<!doctype html><p id="result" style="display:none">old text</p><script>globalThis.findCoercions=0;globalThis.liveFind=window.find({toString(){findCoercions++;result.style.display="block";result.textContent="fresh target";return "fresh target"}});globalThis.oldFind=window.find("old text");console.log("find replay log");</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('liveFind&&oldFind===false&&findCoercions===1')! == 'true'
	selection := document.get_selection() or { panic('selection') }
	assert (selection.range() or { panic('coerced live match') }).to_string() == 'fresh target'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'fresh target'
	assert app.js_messages == ['find replay log']
}

fn test_native_window_find_uses_optional_idl_default_and_original_coercion_errors_after_brand_check() {
	$if !darwin {
		return
	}
	mut app := native_window_find_app('<!doctype html><p>needle null 42</p><script>globalThis.metadata=find.name==="find"&&find.length===0&&find.prototype===undefined&&(()=>{try{new find();return false}catch(error){return error instanceof TypeError}})()&&(()=>{const descriptor=Object.getOwnPropertyDescriptor(window,"find");return descriptor.writable&&descriptor.enumerable&&descriptor.configurable})();globalThis.emptyResults=[find(),find(undefined)];globalThis.nullFind=find(null);globalThis.ignoredCoercions=0;globalThis.numberFind=find(42,{toString(){ignoredCoercions++;return "extra"}});globalThis.brandCoercions=0;try{find.call({},{toString(){brandCoercions++;return "needle"}})}catch(error){globalThis.brandCorrect=error instanceof TypeError}globalThis.originalFindError={};try{find({toString(){throw originalFindError}})}catch(error){globalThis.originalReason=error===originalFindError}try{find(Symbol("needle"))}catch(error){globalThis.symbolCorrect=error instanceof TypeError}</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('metadata&&emptyResults.every(value=>value===false)&&nullFind&&numberFind&&ignoredCoercions===0&&brandCorrect&&brandCoercions===0&&originalReason&&symbolCorrect')! == 'true'
	assert app.page_model.last_find_in_page_query()?.string_ == '42'
	assert (document.get_selection()?.range() or { panic('numeric match') }).to_string() == '42'
	assert app.js_messages == []
}

fn test_native_window_find_keeps_owning_page_and_actual_global_after_author_global_this_replacement() {
	$if !darwin {
		return
	}
	mut foreign := native_window_find_app('<!doctype html><p>foreign needle</p>')!
	mut foreign_document := foreign.document
	defer { foreign_document.finalize() }
	mut app := native_window_find_app('<!doctype html><p id="own">owner 😀 text</p><script>globalThis={};window.findOwn=window.find("owner 😀 text");window.findForeign=window.find("foreign needle");</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('window.findOwn&&window.findForeign===false')! == 'true'
	selected := document.get_selection()?.range() or { panic('owning Page match') }
	assert selected.to_string() == 'owner 😀 text'
	assert selected.start_offset() == 0 && selected.end_offset() == 13
	assert foreign_document.get_selection()?.range() == none
	assert voidptr(document.page()) == voidptr(app.page_model)
	assert app.js_messages == []
}
