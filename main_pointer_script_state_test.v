module main

import dom
import page

fn test_pointer_hit_testing_consumes_the_previous_input_listener_mutations() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .enabled,
		viewport_width: 240, viewport_height: 140}
	app.install_loaded_page(LoadedPage{
		url: 'https://pointer-script-state.test/'
		content_type: 'text/html'
		markup: '<!doctype html><style>body{margin:0}[hidden]{display:none!important}textarea{position:absolute;left:0;top:0;width:160px;height:24px}a,button{position:absolute;left:20px;top:60px;width:80px;height:30px;margin:0;padding:0;border:0}</style><textarea id="field"></textarea><a id="voice" href="#voice">Voice</a><button id="send" hidden>Send</button><script>globalThis.clicked="";globalThis.clickCount=0;field.addEventListener("input",()=>{voice.hidden=true;send.hidden=false});voice.addEventListener("click",event=>{clicked="voice";clickCount++;event.preventDefault()});send.addEventListener("click",event=>{clicked="send";clickCount++;event.preventDefault()});</script>'
	}, false)
	mut document := app.document
	runtime := app.js_runtime
	defer { runtime.close(); document.finalize() }
	assert app.hit_test_at_viewport_point(30, 70)?.element.get_attribute_value('id') == 'voice'
	field := document.get_element_by_id('field') or { panic('field') }
	dom.run_focusing_steps_for_node(field.as_node(), none, .click)
	app.handle_page_character(u32(`x`))
	// No intervening draw or JavaScript query can flush the pending attributes.
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 30, 70)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 30, 70)
	clicked := runtime.evaluate_host('clicked')!
	assert clicked == 'send', 'clicked=${clicked}, voice_hidden=${document.get_element_by_id('voice')?.has_attribute('hidden')}, send_hidden=${document.get_element_by_id('send')?.has_attribute('hidden')}, errors=${app.js_messages}'
	assert runtime.evaluate_host('clickCount')! == '1'
	assert app.js_messages == []
}
