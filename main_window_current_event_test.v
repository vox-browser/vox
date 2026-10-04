module main

import page

fn test_native_readiness_and_parser_body_handler_observe_actual_window_current_event() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://native-window-event.example/readiness'
		content_type: 'text/html'
		markup:       '<!doctype html><body onload="window.rawCurrentEvent=window.event===event&&event.isTrusted&&event.target===document"><script>window.currentReadiness=[];document.addEventListener("DOMContentLoaded",function(value){currentReadiness.push(window.event===value&&value.target===document&&value.isTrusted)});window.addEventListener("load",function(value){currentReadiness.push(window.event===value&&value.target===document&&value.currentTarget===window&&value.isTrusted)});</script></body>'
	}, false)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime.evaluate_host('rawCurrentEvent&&currentReadiness.length===2&&currentReadiness.every(Boolean)&&window.event===undefined')! == 'true'
	assert document.get_window()?.current_event() == none
	assert app.js_messages == []
}

fn test_native_static_parser_body_handler_observes_window_event_without_script_sources() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://native-window-event.example/static'
		content_type: 'text/html'
		markup:       '<!doctype html><body onload="window.staticCurrentEvent=window.event===event&&event.isTrusted&&event.target===document">static document</body>'
	}, false)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_runtime != unsafe { nil }
	assert app.js_runtime.evaluate_host('staticCurrentEvent&&window.event===undefined')! == 'true'
	assert document.get_window()?.current_event() == none
	assert app.js_messages == []
}
