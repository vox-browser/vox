module main

import dom
import gg
import http
import loader
import page

fn test_native_link_destination_survives_collection_and_resource_work_in_click_replay() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  320
		viewport_height: 200
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://navigation-lifetime.invalid/'
		content_type: 'text/html'
		markup:       '<!doctype html><a id="target" href="https://navigation-lifetime.invalid/target/retained-through-native-click-and-resource-layout">Open target</a><script>globalThis.clickRuns=0;target.addEventListener("click",function(){clickRuns++;__collectDuringClick();target.style.color="red";});</script>'
	}, false)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	mut runtime := app.js_runtime
	runtime.define_host_function('__collectDuringClick', fn (_ string) !string {
		gc_collect()
		mut resource_loader := loader.ResourceLoader.create()
		for index in 0 .. 128 {
			mut request := loader.LoadRequest.create(http.HeaderList.create())
			request.set_url(dom.URL{
				value: 'https://www.redditstatic.com/sprite-expando.69EqpDZz3HM.png?${index}'
			})
			_ = resource_loader.load(mut request)
		}
		return ''
	})!
	link := document.get_element_by_id('target') or { panic('missing link') }
	rect := link.get_bounding_client_rect()
	x := rect.x + rect.width / 2
	y := rect.y + rect.height / 2
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
	assert app.pending_native_navigation? == link.get_attribute_value('href')
	// Queue the request without fetching it or replacing this document.
	app.ctx = &gg.Context{}
	app.replay_compact_javascript_click()
	assert runtime.evaluate_host('clickRuns')! == '1'
	assert app.pending_navigation?.resolved == link.get_attribute_value('href')
	assert app.pending_native_navigation == none
	assert app.navigation_generation == 1
	assert voidptr(app.document) == voidptr(document)
}
