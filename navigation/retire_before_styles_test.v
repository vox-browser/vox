module main

import css
import dom
import page

struct NavigationStyleRetirementObservation {
mut:
	closed int
	replacement_is_active bool
	old_is_inactive bool
	replacement_styles_installed bool
}

fn test_replacement_resources_are_installed_after_closing_the_inactive_realm() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{
		url: 'https://retire-before-styles.test/old'
		markup: '<!doctype html><p>Old</p><script>window.oldRealm=true</script>'
	}, false)
	mut previous := app.document
	mut previous_runtime := app.js_runtime
	assert previous_runtime != unsafe { nil }
	assert previous_runtime.evaluate_host('oldRealm')! == 'true'
	observation := &NavigationStyleRetirementObservation{}
	previous_runtime.add_close_handler(fn [app, previous, observation] () {
		mut seen := unsafe { &NavigationStyleRetirementObservation(observation) }
		seen.closed++
		seen.replacement_is_active = app.document.is_fully_active()
		seen.old_is_inactive = !previous.is_fully_active()
		seen.replacement_styles_installed = css.query_selector_all(app.document.as_node(),
			'style[data-libweb-v-source-url]').len > 0
	})
	sheet := 'https://retire-before-styles.test/new.css'
	app.resource_cache[sheet] = PreloadedResource{url: sheet, body: 'p{color:rgb(12,34,56)}'}
	app.install_loaded_page(LoadedPage{
		url: 'https://retire-before-styles.test/new'
		markup: '<!doctype html><link rel="stylesheet" href="/new.css"><p id="new">Replacement</p>'
	}, false)
	defer { previous.finalize(); app.document.finalize() }
	assert observation.closed == 1
	assert observation.replacement_is_active && observation.old_is_inactive
	assert !observation.replacement_styles_installed
	assert css.query_selector_all(app.document.as_node(), 'style[data-libweb-v-source-url]').len == 1
	assert app.paint_commands.any(it.text.contains('Replacement'))
	computed := css.computed_properties_for_element(app.document.get_element_by_id('new')?)?
	assert computed.property(.color, .no)?.css_text == 'rgb(12, 34, 56)'
}
