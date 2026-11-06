module main

import browserjs
import css
import dom
import html
import layout
import os
import page
import painting
import platform
import time
import x.json2

fn test_launch_options_select_javascript_engine_in_both_flag_forms() {
	assert parse_launch_options([])!.js_engine == .javascriptcore
	assert parse_launch_options(['--js-engine=javascriptcore', 'about:blank'])!.js_engine == .javascriptcore
	separate := parse_launch_options(['--js-engine', 'libjs', '--headless-smoke', 'page.html'])!
	assert separate.js_engine == .libjs
	assert separate.headless_smoke && separate.source == 'page.html'
	inline := parse_launch_options(['page.html', '--js-engine=libjs', '--window-width=900'])!
	assert inline.js_engine == .libjs && inline.source == 'page.html' && inline.width == 900
	for args in [['--js-engine'], ['--js-engine='], ['--js-engine=unknown'], ['--js-engine', 'unknown']] {
		if _ := parse_launch_options(args) { assert false }
	}
}

fn test_launch_options_accept_short_window_size_flags() {
	a := parse_launch_options(['-width', '900', '-height=700', 'page.html'])!
	assert a.width == 900 && a.height == 700 && a.source == 'page.html'
	b := parse_launch_options(['--width=640', '--height', '480'])!
	assert b.width == 640 && b.height == 480
	if _ := parse_launch_options(['-width', '0']) { assert false }
}

fn test_native_libjs_scripts_execute_without_the_javascriptcore_dom_bootstrap() {
	document := html.parse_document('<div id="result">static</div>')
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/page.html', [
		'const answer=40;',
		'document.getElementById("result").textContent="changed";',
		'var result=answer+2;',
		'var boxedAnswer=new (Boolean.bind(null,true))(); var symbolKey=Symbol.for("native");',
		'globalThis[symbolKey]=result;',
	], runtime, mut messages)
	assert runtime.evaluate('result;')! == '42'
	assert runtime.evaluate('boxedAnswer.valueOf();')! == 'true'
	assert runtime.evaluate('globalThis[Symbol.for("native")];')! == '42'
	assert runtime.evaluate('Symbol.keyFor(symbolKey);')! == 'native'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'static'
	assert messages.len == 2
	assert messages[0].contains('DOM bindings')
	assert messages[1].contains("ReferenceError: 'document' is not defined")
	assert messages[1].contains('https://example.test/page.html')
}

fn test_native_browser_scripts_use_libjs_errors_global_bindings_and_readiness_order() {
	$if darwin {
		document := html.parse_document('<div id="result"></div>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		run_document_javascript(document, 'https://example.test/page.html', [
			'const prefix="LibJS"; Promise.resolve().then(() => result.textContent=prefix);',
			'result.textContent="broken"; let duplicate; let duplicate;',
			'result.textContent += " integrated"; addEventListener("load", () => result.textContent += " ready");',
		], runtime, mut messages)
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'LibJS integrated ready'
		assert messages.len == 1
		assert messages[0].contains('SyntaxError: https://example.test/page.html:')
	}
}

fn test_native_browser_readable_stream_runs_real_default_reader_and_source_owner_jobs() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/streams.html', [
		'const chunk={label:"native"};const stream=new ReadableStream({start(controller){controller.enqueue(chunk);controller.close()}});const reader=stream.getReader();const closed=reader.closed;reader.read().then(value=>{result.textContent=value.value===chunk&&!value.done&&closed===reader.closed&&reader instanceof ReadableStreamDefaultReader?"source read":"wrong identity"});',
		'addEventListener("load",()=>result.textContent+=" ready");',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source read ready'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_queuing_strategies_feed_source_stream_records_and_dom_replay() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/strategies.html', [
		'const count=new CountQueuingStrategy({highWaterMark:2});const bytes=new ByteLengthQueuingStrategy({highWaterMark:8});let controller;const source=new ReadableStream({start(value){controller=value}},count);controller.enqueue(result);source.getReader().read().then(value=>{const target=new WritableStream({write(chunk){result.textContent=value.value===result&&count.size===new CountQueuingStrategy({highWaterMark:0}).size&&chunk.byteLength===bytes.size(chunk)?"source strategies":"wrong strategy"}},bytes);target.getWriter().write(new Uint8Array(3))});',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source strategies'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_abort_signal_dispatches_source_event_and_replays_author_dom_mutation() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/abort.html', [
		'globalThis.actualController=new AbortController();const signal=actualController.signal;const reason={};const dependent=AbortSignal.any([signal]);signal.addEventListener("abort",function(event){result.textContent=this===signal&&event.target===signal&&event.isTrusted&&dependent.reason===reason?"source abort":"wrong event"});actualController.abort(reason);',
		'addEventListener("load",()=>result.textContent+=" ready");',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source abort ready'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_timer_waits_for_source_task_before_replaying_author_dom_mutation() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/timer.html', [
		'setTimeout(function(value){result.textContent=this===window&&value===result?"source timer":"wrong timer"},5,result);',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'pending'
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for runtime.evaluate_host('result.textContent')! == 'pending' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
	}
	assert runtime.evaluate_host('result.textContent')! == 'source timer'
	mut app := BrowserApp{
		document: document
		js_runtime: runtime
		layout_tree_only: true
		viewport_width: 320
		viewport_height: 200
	}
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source timer'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_writable_sink_uses_source_controller_before_replaying_author_dom_mutation() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/writable.html', [
		'globalThis.nativeSink={write(value,controller){result.textContent=this===nativeSink&&value===result&&controller.signal instanceof AbortSignal&&!controller.signal.aborted?"source write":"wrong sink"}};new WritableStream(nativeSink).getWriter().write(result);',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source write'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_transform_pipeline_replays_actual_chunk_identity_to_author_dom() {
	$if !darwin { return }
	document := html.parse_document('<div id="result">pending</div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/transform.html', [
		'globalThis.nativeTransformer={transform(value,controller){controller.enqueue(value)}};const stream=new TransformStream(nativeTransformer);stream.readable.getReader().read().then(value=>result.textContent=value.value===result&&!value.done?"source transform":"wrong chunk");stream.writable.getWriter().write(result);',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'source transform'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_browser_script_sources_keep_urls_and_module_parse_goal() {
	document := html.parse_document_with_url('<script>const inline=1;</script><script src="app.js"></script><script type="module">export default 42;</script><script type="application/json">{}</script>', dom.URL{value: 'https://example.test/page.html'})
	mut messages := []string{}
	sources := script_sources(document, 'https://cdn.example.test/assets/', {
		'https://cdn.example.test/assets/app.js': PreloadedResource{body: 'const external=2;'}
	}, mut messages)
	assert sources.len == 3
	assert sources[0].url == 'https://example.test/page.html'
	assert sources[1].url == 'https://cdn.example.test/assets/app.js'
	assert sources[1].code == 'const external=2;'
	assert sources[2].source_type == .module
	assert messages.len == 0
}

fn test_native_svg_turbulence_forwards_stitch_tile_size_only_for_stitched_noise() {
	stitched := painting.GfxFilterNode{
		kind: 'turbulence'
		parameters: {
			'tile_width':  120.5
			'tile_height': 80.25
		}
		string_parameters: {
			'stitch': 'stitch'
		}
	}
	assert native_svg_turbulence_tile_size(stitched) == [f32(120.5), 80.25]!

	not_stitched := painting.GfxFilterNode{
		kind: 'turbulence'
		parameters: {
			'tile_width':  120.5
			'tile_height': 80.25
		}
		string_parameters: {
			'stitch': 'no-stitch'
		}
	}
	assert native_svg_turbulence_tile_size(not_stitched) == [f32(0), 0]!
}

fn test_parse_launch_options_keeps_interactive_defaults() {
	options := parse_launch_options(['https://example.com']) or { panic(err) }
	assert options.source == 'https://example.com'
	assert options.width == initial_width
	assert options.height == initial_height
}

fn test_javascript_bridge_exposes_media_start_date_as_a_date_object() {
	$if darwin {
		document := html.parse_document('<!doctype html>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const video = document.createElement("video"); console.log(video.getStartDate() instanceof Date); console.log(isNaN(video.getStartDate().getTime()));',
		], runtime, mut messages)
		assert messages == ['true', 'true']
	}
}

fn test_javascript_bridge_applies_force_dark_internals_settings() {
	$if darwin {
		document := html.parse_document('<!doctype html><div>content</div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'internals.setForceDarkEnabled(true); internals.setForceDarkThresholds(31, 47); internals.setShowLineBoxBorders(true);',
		], runtime, mut messages)
		assert messages == []
		model := html.NavigableModel.navigable_with_active_document(document) or {
			panic('missing compact browser navigable')
		}
		assert model.force_dark_enabled()
		assert model.force_dark_foreground_threshold() == 31
		assert model.force_dark_background_threshold() == 47
		assert model.should_show_line_box_borders()
		assert document.preferred_color_scheme() == 'dark'
	}
}

fn test_javascript_bridge_refreshes_color_scheme_after_live_meta_insertion() {
	$if darwin {
		document := html.parse_document('<!doctype html><head></head><body>content</body>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'internals.setForceDarkEnabled(true); const meta = document.createElement("meta"); meta.name = "color-scheme"; meta.content = "only light"; document.head.appendChild(meta);',
		], runtime, mut messages)
		assert messages == []
		meta := css.query_selector(unsafe { &dom.Node(document) }, 'meta') or {
			panic('missing script-created meta')
		}
		assert meta.get_attribute_value('name') == 'color-scheme'
		assert meta.get_attribute_value('content') == 'only light'
		assert document.supported_color_schemes()? == ['light']
		assert document.supported_color_schemes_are_only()
		model := html.NavigableModel.navigable_with_active_document(document) or {
			panic('missing compact browser navigable')
		}
		assert model.active_document_opts_out_of_force_dark()
	}
}

fn test_javascript_bridge_runs_window_load_mutations() {
	$if darwin {
		document := html.parse_document('<!doctype html><div id="target"></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'onload = () => requestAnimationFrame(() => { target.classList.add("ready"); target.style.marginLeft = "100px"; });',
		], runtime, mut messages)
		assert messages == []
		element := document.get_element_by_id('target') or { panic('missing target') }
		assert element.get_attribute_value('class') == ''
		bridge_test_rendering_frame(document)
		assert element.get_attribute_value('class') == 'ready'
		assert element.get_attribute_value('style') == 'margin-left: 100px'
	}
}

fn test_javascript_bridge_reflects_the_hidden_property() {
	$if darwin {
		document := html.parse_document('<!doctype html><div id="hide"></div><div id="show" hidden></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'hide.hidden = true; show.hidden = false; console.log(hide.hidden, show.hidden);',
		], runtime, mut messages)
		assert messages == ['true false']
		assert document.get_element_by_id('hide') or { panic('missing hidden element') }.has_attribute('hidden')
		assert !(document.get_element_by_id('show') or { panic('missing shown element') }).has_attribute('hidden')
	}
}

fn test_javascript_bridge_maps_webkit_font_smoothing_idl_name() {
	$if darwin {
		document := html.parse_document('<!doctype html><div id="target">Text</div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'target.style.webkitFontSmoothing = "antialiased"; console.log(target.style.webkitFontSmoothing);',
		], runtime, mut messages)
		assert messages == ['antialiased']
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_attribute_value('style') == '-webkit-font-smoothing: antialiased'

		result := layout.run_document_layout(document, 200, 100) or { panic('missing layout') }
		text := result.paint_tree.paint_commands().filter(it.kind == 'draw_text' && it.text == 'Text')
		assert text.len == 1
		assert text[0].font_smoothing == .antialiased
	}
}

fn test_javascript_bridge_exposes_completed_images_and_delivers_late_load_listeners() {
	$if darwin {
		document := html.parse_document('<!doctype html><img id="preload" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="><div id="target"></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'if (preload.complete) target.classList.add("complete"); preload.addEventListener("load", () => target.classList.add("loaded"), { once: true });',
		], runtime, mut messages)
		assert messages == []
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_attribute_value('class') == 'complete loaded'
	}
}

fn test_javascript_bridge_resolves_detached_image_decode_promises() {
	$if darwin {
		mut document := html.parse_document('<!doctype html><div id="target"></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const image=new Image(); image.src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="; image.decode().then(() => target.classList.add("decoded"));',
		], runtime, mut messages)
		assert messages == []
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_attribute_value('class') == ''
		mut loop := html.main_thread_event_loop()
		for loop.task_queue().has_runnable_tasks() { loop.process() }
		mut app := BrowserApp{document: document, js_runtime: runtime, layout_tree_only: true}
		app.poll_javascript_tasks()
		assert target.get_attribute_value('class') == 'decoded'
	}
}

fn test_javascript_bridge_loads_object_images_after_data_property_changes() {
	$if darwin {
		mut document := html.parse_document('<!doctype html><style>object{display:block;width:100px;height:100px}</style><object id="target" type="image/png"></object>')
		document.set_url(dom.URL{ value: 'https://example.test/' })
		install_object_image_fetch_hooks(document)
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'https://example.test/', [
			'target.addEventListener("load", () => console.log("loaded")); target.data="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";',
		], runtime, mut messages)
		assert messages == ['loaded']
		element := document.get_element_by_id('target') or { panic('missing object') }
		object_element := unsafe { &dom.HTMLObjectElement(element) }
		model := html.html_object_element_model_for_dom_element(object_element)
		assert model.representation() == .image
		assert model.image_data()?.width == 1
		assert model.image_data()?.height == 1

		result := layout.run_document_layout(document, 100, 100) or { panic('missing layout') }
		commands := result.paint_tree.paint_commands()
		assert commands.any(it.kind == 'draw_replaced_image'), commands.map(it.kind).join(', ')
	}
}

fn test_browser_installs_decoded_video_poster_frames() {
	$if darwin {
		mut document := html.parse_document('<!doctype html><style>video{display:block;width:100px;height:100px}</style><video id="target" poster="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="></video>')
		document.set_url(dom.URL{ value: 'https://example.test/' })
		install_video_poster_fetch_hooks(document)
		element := document.get_element_by_id('target') or { panic('missing video') }
		video_element := unsafe { &dom.HTMLVideoElement(element) }
		model := html.html_video_element_model_for_dom_element(video_element)
		assert model.current_representation() == .poster_frame
		assert model.poster_frame()?.width == 1
		assert model.poster_frame()?.height == 1

		result := layout.run_document_layout(document, 100, 100) or { panic('missing layout') }
		commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_video')
		assert commands.len == 1
		assert commands[0].video_bitmap?.width == 1
		assert commands[0].video_bitmap?.height == 1
	}
}

fn test_native_bitmap_markers_preserve_video_row_order_and_alpha() {
	video := &dom.Bitmap_{native_rows_are_top_down: true}
	quartz := &dom.Bitmap_{}
	assert native_bitmap_channel_marker(video, false) == 6
	assert native_bitmap_channel_marker(video, true) == 7
	assert native_bitmap_channel_marker(quartz, false) == 4
	assert native_bitmap_channel_marker(quartz, true) == 5
	assert video.clone().native_rows_are_top_down
}

fn test_javascript_bridge_applies_image_source_replacements_before_relayout() {
	$if darwin {
		red := "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 1 1'%3E%3Crect width='1' height='1' fill='red'/%3E%3C/svg%3E"
		green := "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 1 1'%3E%3Crect width='1' height='1' fill='green'/%3E%3C/svg%3E"
		document := html.parse_document('<!doctype html><style>body{margin:0}img{display:block}</style><img id="target" src="${red}">')
		initial := layout.run_document_layout(document, 200, 150) or { panic('missing initial layout') }
		initial_images := initial.paint_tree.paint_commands().filter(it.kind == 'paint_nested_display_list')
		assert initial_images.len == 1

		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'target.addEventListener("load", () => console.log("loaded")); target.src = ${json2.encode(green)};',
		], runtime, mut messages)
		// The compact host reports the already-complete old source when the
		// listener is attached, then the synchronously decoded replacement.
		assert messages == ['loaded', 'loaded']
		target := document.get_element_by_id('target') or { panic('missing image') }
		assert target.get_attribute_value('src') == green

		updated := layout.run_document_layout(document, 200, 150) or { panic('missing updated layout') }
		updated_images := updated.paint_tree.paint_commands().filter(it.kind == 'paint_nested_display_list')
		assert updated_images.len == 1
		assert updated_images[0].nested_viewport_commands.any(it.kind == 'draw_svg_path'
			&& it.color == css.Color{0, 128, 0, 255}.serialize())
	}
}

fn test_javascript_bridge_replays_svg_paint_server_mutations() {
	$if darwin {
		document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div id="collision" style="display:none"></div><svg width="500" height="100"><defs><linearGradient id="attribute"><stop id="changed-stop" stop-color="red"/></linearGradient><linearGradient id="append" gradientUnits="userSpaceOnUse" x1="-100" x2="100"><stop offset="0" stop-color="red"/></linearGradient><linearGradient id="move"><stop id="green-stop" offset="0" stop-color="green"/><stop offset="0" stop-color="red"/></linearGradient><linearGradient id="animated"><stop id="animated-stop" offset="0" stop-color="red"/><stop offset="1" stop-color="green"/></linearGradient><linearGradient id="collision"><stop stop-color="green"/></linearGradient></defs><rect width="100" height="100" fill="url(#attribute)"/><rect x="100" width="100" height="100" fill="url(#append)"/><rect x="200" width="100" height="100" fill="url(#move)"/><rect x="300" width="100" height="100" fill="url(#animated)"/><rect x="400" width="100" height="100" fill="url(#collision) red"/></svg>')
		layout.run_document_layout(document, 500, 100) or { panic('missing initial layout') }

		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'document.getElementById("changed-stop").setAttribute("stop-color", "green"); document.getElementById("attribute").setAttribute("gradientTransform", "translate(0)"); const stop=document.createElementNS("http://www.w3.org/2000/svg", "stop"); stop.setAttribute("offset", "0"); stop.setAttribute("stop-color", "green"); document.getElementById("append").appendChild(stop); const move=document.getElementById("move"); move.moveBefore(document.getElementById("green-stop"), null); document.getElementById("animated-stop").animate([{stopColor:"red"},{stopColor:"green"}], {duration:50,fill:"forwards"}).finished.then(() => {}); document.querySelector("div").id="other";',
		], runtime, mut messages)
		assert messages == []
		assert document.get_element_by_id('changed-stop') or { panic('missing changed stop') }.get_attribute_value('stop-color') == 'green'
		assert document.get_element_by_id('attribute') or { panic('missing gradient') }.get_attribute_value('gradientTransform') == 'translate(0)'

		append_gradient := document.get_element_by_id('append') or { panic('missing append gradient') }
		appended_node := append_gradient.as_node().last_child() or { panic('missing appended stop') }
		appended_stop := appended_node.as_element() or { panic('appended child is not an element') }
		assert appended_stop.namespace_uri() or { '' } == 'http://www.w3.org/2000/svg'
		assert appended_stop.get_attribute_value('stop-color') == 'green'

		move_gradient := document.get_element_by_id('move') or { panic('missing move gradient') }
		moved_node := move_gradient.as_node().last_child() or { panic('missing moved stop') }
		moved_stop := moved_node.as_element() or { panic('moved child is not an element') }
		assert moved_stop.get_attribute_value('id') == 'green-stop'
		assert document.get_element_by_id('animated-stop') or { panic('missing animated stop') }.get_attribute_value('stop-color') == 'green'
		assert document.get_element_by_id('collision') or { panic('missing collision gradient') }.local_name() == 'linearGradient'

		updated := layout.run_document_layout(document, 500, 100) or { panic('missing updated layout') }
		gradients := updated.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path'
			&& it.fill_linear_gradient() != none)
		assert gradients.len == 5
		for command in gradients {
			gradient := command.fill_linear_gradient() or { panic('missing retained gradient') }
			assert gradient.gradient.color_stops.last().color == painting.Color{0, 128, 0, 255}
		}
	}
}

fn test_javascript_bridge_removes_an_svg_pattern_referencer_before_image_load() {
	$if darwin {
		image_url := 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
		document := html.parse_document('<!doctype html><svg width="100" height="100"><defs><pattern id="tile" width="100" height="100" patternUnits="userSpaceOnUse"><image id="tile-image" width="100" height="100"/></pattern></defs><rect id="first" width="100" height="100" fill="url(#tile)"/><rect id="second" width="100" height="100" fill="url(#tile)"/></svg>')
		layout.run_document_layout(document, 120, 120) or { panic('missing initial layout') }
		second := document.get_element_by_id('second') or { panic('missing second referencer') }

		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'second.remove(); console.log(document.getElementById("second") === null); document.getElementById("tile-image").setAttribute("href", ${json2.encode(image_url)});',
		], runtime, mut messages)
		assert messages == ['true']
		assert second.as_node().parent() == none
		image := document.get_element_by_id('tile-image') or { panic('missing pattern image') }
		assert image.get_attribute_value('href') == image_url

		updated := layout.run_document_layout(document, 120, 120) or {
			panic('missing updated layout')
		}
		paths := updated.paint_tree.paint_commands().filter(it.kind == 'draw_svg_path')
		assert paths.len == 1
		pattern := paths[0].svg().fill_pattern or { panic('missing surviving pattern fill') }
		operations := (pattern.tile_display_list or {
			panic('missing surviving pattern display list')
		}).operations
		images := operations.filter(it.kind == .image)
		assert images.len == 1
		assert images[0].transform.map_rect(images[0].image_rect) == painting.Rect{0, 0, 100, 100}
		assert operations.any(it.kind == .image && it.image_url == image_url)
	}
}

fn test_javascript_bridge_selects_text_before_selection_restyle() {
	$if darwin {
		document := html.parse_document('<!doctype html><style>p{font-size:20px;line-height:1.5;margin:10px 0}.restyled::selection{background-color:transparent;color:green}</style><p id="target">Restyled after the selection was painted</p>')

		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const range=document.createRange(); range.selectNodeContents(target.firstChild); getSelection().addRange(range); requestAnimationFrame(() => requestAnimationFrame(() => { target.className="restyled"; }));',
		], runtime, mut messages)
		assert messages == []
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_attribute_value('class') == ''
		bridge_test_rendering_frame(document)
		assert target.get_attribute_value('class') == ''
		bridge_test_rendering_frame(document)
		assert target.get_attribute_value('class') == 'restyled'
		text_node := target.as_node().first_child() or { panic('missing target text') }
		selection := document.get_selection() or { panic('missing selection') }
		range := selection.range() or { panic('missing selected range') }
		assert voidptr(range.start_container()) == voidptr(text_node)
		assert voidptr(range.end_container()) == voidptr(text_node)
		assert range.start_offset() == 0
		assert range.end_offset() == text_node.length()

		layout.run_document_layout(document, 800, 600) or { panic('missing updated layout') }
		mut mutable_document := unsafe { &dom.Document(document) }
		commands := layout.display_list_commands(mutable_document.record_display_list() or {
			panic('missing selected display list')
		})
		selected := commands.filter(it.kind == 'draw_text'
			&& it.text == 'Restyled after the selection was painted'
			&& it.color == css.Color{0, 128, 0, 255}.serialize())
		assert selected.len == 1
		assert commands.all(it.kind != 'fill_rect')
	}
}

fn test_javascript_bridge_keeps_boundary_selection_live_across_node_insertion() {
	$if darwin {
		document := html.parse_document('<!doctype html><style>span::selection { background: lime; color: black; }</style><div id="selected"><span id="first">first</span><span id="last">last</span></div><div><span id="moved">middle</span></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const range=document.createRange(); range.setStart(first.firstChild,0); range.setEnd(last.firstChild,4); getSelection().addRange(range); selected.getBoundingClientRect(); selected.insertBefore(moved,last); selected.getBoundingClientRect();',
		], runtime, mut messages)
		assert messages == []

		selected := document.get_element_by_id('selected') or { panic('missing selected container') }
		assert selected.as_node().children.len == 3
		moved_child := selected.as_node().children[1].as_element() or {
			panic('missing moved child')
		}
		assert moved_child.get_attribute_value('id') == 'moved'
		selection := document.get_selection() or { panic('missing selection') }
		range := selection.range() or { panic('missing range') }
		first := document.get_element_by_id('first') or { panic('missing first') }
		last := document.get_element_by_id('last') or { panic('missing last') }
		assert voidptr(range.start_container()) == voidptr(first.as_node().first_child() or {
			panic('missing first text')
		})
		assert voidptr(range.end_container()) == voidptr(last.as_node().first_child() or {
			panic('missing last text')
		})

		layout.run_document_layout(document, 800, 600) or { panic('missing layout') }
		mut mutable_document := unsafe { &dom.Document(document) }
		commands := layout.display_list_commands(mutable_document.record_display_list() or {
			panic('missing selected display list')
		})
		assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 255 0)')
	}
}

fn test_javascript_bridge_moves_selection_after_css_rule_mutation() {
	$if darwin {
		document := html.parse_document('<!doctype html><style id="rules">span::selection { background: red; color: black; }</style><div><span id="first">first</span></div><div><span id="second">second</span></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const selection=getSelection(); selection.selectAllChildren(first); first.getBoundingClientRect(); selection.removeAllRanges(); second.getBoundingClientRect(); rules.sheet.cssRules[0].style.backgroundColor="lime"; second.getBoundingClientRect(); selection.selectAllChildren(first); first.getBoundingClientRect(); selection.selectAllChildren(second); second.getBoundingClientRect();',
		], runtime, mut messages)
		assert messages == []

		rules := document.get_element_by_id('rules') or { panic('missing style element') }
		assert rules.as_node().text_content() or { '' }.contains('background-color: lime')
		selection := document.get_selection() or { panic('missing selection') }
		range := selection.range() or { panic('missing range') }
		second := document.get_element_by_id('second') or { panic('missing second') }
		assert voidptr(range.start_container()) == voidptr(second.as_node())
		assert voidptr(range.end_container()) == voidptr(second.as_node())

		layout.run_document_layout(document, 800, 600) or { panic('missing layout') }
		mut mutable_document := unsafe { &dom.Document(document) }
		commands := layout.display_list_commands(mutable_document.record_display_list() or {
			panic('missing selected display list')
		})
		assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 255 0)')
		assert !commands.any(it.kind == 'fill_rect' && it.color == 'rgb(255 0 0)')
	}
}

fn test_javascript_bridge_collapses_selection_at_element_and_text_boundaries() {
	$if darwin {
		document := html.parse_document('<!doctype html><div id="editor" contenteditable><p id="target">text</p></div>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'editor.focus(); const selection=getSelection(); selection.collapse(target,0); selection.collapse(target.firstChild,2);',
		], runtime, mut messages)
		assert messages == []
		assert voidptr(document.focused_area() or { panic('missing focused area') }) == voidptr((document.get_element_by_id('editor') or { panic('missing editor') }).as_node())
		target := document.get_element_by_id('target') or { panic('missing target') }
		text_node := target.as_node().first_child() or { panic('missing target text') }
		selection := document.get_selection() or { panic('missing selection') }
		range := selection.range() or { panic('missing collapsed range') }
		assert range.collapsed()
		assert voidptr(range.start_container()) == voidptr(text_node)
		assert range.start_offset() == 2
	}
}

fn test_javascript_bridge_replays_live_range_surround_contents() {
	$if darwin {
		document := html.parse_document('<!doctype html><title>test</title><style id="sheet">html::first-letter { font-size: initial }</style>FAIL')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const sel=getSelection(); sel.selectAllChildren(document.documentElement); const range=sel.getRangeAt(0); document.body.remove(); document.documentElement.appendChild(document.createTextNode("PASS")); document.documentElement.offsetTop; range.surroundContents(sheet);',
		], runtime, mut messages)
		assert messages == []
		root := document.document_element() or { panic('missing document element') }
		assert document.body() == none
		pass_text := root.as_node().last_child() or { panic('missing appended PASS text') }
		assert pass_text.text_content() or { '' } == 'PASS'
		sheet := document.get_element_by_id('sheet') or { panic('missing surrounding style') }
		sheet_parent := sheet.as_node().parent() or { panic('surrounding style is detached') }
		assert voidptr(sheet_parent) == voidptr(root.as_node())
	}
}

fn test_javascript_bridge_inserts_created_nodes_and_document_fragments_before_first_child() {
	$if darwin {
		document := html.parse_document('<!doctype html>
			<fieldset id="direct" disabled><legend><input id="direct-input" type="checkbox" checked></legend></fieldset>
			<fieldset id="fragment" disabled><legend><input id="fragment-input" type="checkbox" checked></legend></fieldset>')
		direct_input := document.get_element_by_id('direct-input') or { panic('missing direct input') }
		fragment_input := document.get_element_by_id('fragment-input') or {
			panic('missing fragment input')
		}
		assert !direct_input.is_actually_disabled()
		assert !fragment_input.is_actually_disabled()

		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const legend=document.createElement("legend"); legend.id="direct-legend"; legend.style.display="none"; direct.insertBefore(legend,direct.firstChild); const container=document.createDocumentFragment(); const fragmentLegend=document.createElement("legend"); fragmentLegend.id="fragment-legend"; fragmentLegend.style.display="none"; container.appendChild(fragmentLegend); fragment.insertBefore(container,fragment.firstChild);',
		], runtime, mut messages)
		assert messages == []

		direct_group := document.get_element_by_id('direct') or { panic('missing direct fieldset') }
		fragment_group := document.get_element_by_id('fragment') or {
			panic('missing fragment fieldset')
		}
		direct_first := direct_group.as_node().first_child() or { panic('missing direct first child') }
		fragment_first := fragment_group.as_node().first_child() or {
			panic('missing fragment first child')
		}
		assert (direct_first.as_element() or { panic('direct first child is not an element') }).id() or {
			''
		} == 'direct-legend'
		assert (fragment_first.as_element() or { panic('fragment first child is not an element') }).id() or {
			''
		} == 'fragment-legend'
		assert direct_input.is_actually_disabled()
		assert fragment_input.is_actually_disabled()
	}
}

fn test_javascript_bridge_replays_live_input_state_properties() {
	$if darwin {
		document := html.parse_document('<!doctype html>
			<input id="box" type="checkbox"><input id="dot" type="radio">
			<input id="unbox" type="checkbox" checked><input id="mixed" type="checkbox">
			<fieldset id="group"><input id="group-input" type="checkbox" checked></fieldset>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'box.checked=true; dot.checked=true; unbox.checked=false; mixed.indeterminate=true; box.disabled=true; group.disabled=true;',
		], runtime, mut messages)
		assert messages == []

		box_element := document.get_element_by_id('box') or { panic('missing checkbox') }
		dot_element := document.get_element_by_id('dot') or { panic('missing radio') }
		unbox_element := document.get_element_by_id('unbox') or { panic('missing unchecked box') }
		mixed_element := document.get_element_by_id('mixed') or { panic('missing mixed box') }
		group := document.get_element_by_id('group') or { panic('missing fieldset') }
		group_input := document.get_element_by_id('group-input') or { panic('missing group input') }
		assert unsafe { &dom.HTMLInputElement(box_element) }.checked()
		assert unsafe { &dom.HTMLInputElement(dot_element) }.checked()
		assert !unsafe { &dom.HTMLInputElement(unbox_element) }.checked()
		assert unsafe { &dom.HTMLInputElement(mixed_element) }.indeterminate()
		assert box_element.has_attribute('disabled')
		assert group.has_attribute('disabled')
		assert group_input.is_actually_disabled()
	}
}

fn test_javascript_bridge_replays_post_paint_canvas_creation_and_resize() {
	$if darwin {
		document := html.parse_document('<!doctype html><canvas id="canvas" width="50" height="50"></canvas>')
		layout.run_document_layout(document, 120, 120) or { panic('missing initial layout') }
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const context=canvas.getContext("2d"); context.fillStyle="rgb(255, 0, 0)"; context.fillRect(0,0,50,50); canvas.width=100; canvas.height=100; context.fillStyle="rgb(0, 255, 0)"; context.fillRect(0,0,100,100);',
		], runtime, mut messages)
		assert messages == []
		canvas_element := document.get_element_by_id('canvas') or { panic('missing canvas') }
		canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
		bitmap := html.html_canvas_element_surface(canvas) or { panic('missing canvas bitmap') }
		assert bitmap.width == 100
		assert bitmap.height == 100
		assert bitmap.data[0..4] == [u8(0), 255, 0, 255]

		updated := layout.run_document_layout(document, 120, 120) or { panic('missing updated layout') }
		assert updated.paint_tree.paint_commands().any(it.kind == 'draw_canvas')
	}
}

fn test_javascript_bridge_replays_created_canvas_glyph_runs() {
	$if darwin {
		document := html.parse_document('<!doctype html><body></body>')
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
		}
		mut messages := []string{}
		run_document_javascript(document, 'about:blank', [
			'const canvas=document.createElement("canvas");canvas.id="text-canvas";canvas.width=120;canvas.height=80;document.body.appendChild(canvas);const context=canvas.getContext("2d");context.fillRect(0,0,1,1);context.font="24px serif";context.save();context.translate(5,10);context.fillText("Text",0,30);context.restore();',
		], runtime, mut messages)
		assert messages == []
		canvas_element := document.get_element_by_id('text-canvas') or { panic('missing canvas') }
		canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
		bitmap := html.html_canvas_element_surface(canvas) or { panic('missing canvas bitmap') }
		assert bitmap.width == 120
		assert bitmap.height == 80
		assert bitmap.data.any(it != 0)
	}
}

fn test_browser_animation_frame_refreshes_paint_only_transforms() {
	mut document := html.parse_document('<!doctype html><style>@keyframes flip{0%{transform:rotateY(60deg)}0.01%,100%{transform:rotateY(180deg)}}.flip{animation:10s linear infinite flip}#scene{width:100px;height:100px;transform:rotateY(60deg);transform-style:preserve-3d}#target{position:absolute;top:0;left:0;width:200px;height:200px;background:lightblue;transform:rotateY(180deg);backface-visibility:hidden}</style><div id="scene" class="flip"><div id="target"></div></div>')
	mut app := BrowserApp{
		document: document
		animation_epoch_ns: time.sys_mono_now() - 16_000_000
	}
	app.relayout(200, 232)
	assert css.document_has_running_css_animations(document)
	app.begin_frame_preparation()
	app.advance_document_animations(200, 120)
	app.finish_frame_preparation()
	scene_element := document.get_element_by_id('scene') or { panic('missing scene') }
	scene := app.root_box.find_box(i64(scene_element.as_node().unique_id())) or {
		panic('missing scene paint box')
	}
	assert scene.own_paint_transform_4x4.m33 < -0.9
	assert app.paint_commands.any(it.color.contains('173') || it.color.to_lower().contains('add8e6')), app.paint_commands.map('${it.kind}:${it.color}').join(', ')
	// An unchanged sampled value reuses the retained paint snapshot rather than
	// replacing it with an empty cache on every browser frame.
	app.begin_frame_preparation()
	app.advance_document_animations(200, 120)
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color.contains('173') || it.color.to_lower().contains('add8e6')), app.paint_commands.map('${it.kind}:${it.color}').join(', ')
}

fn test_browser_relayout_focuses_its_top_level_navigable_before_painting() {
	mut document := html.parse_document('<!doctype html><style>html,body,p{margin:0}p{caret-color:rgb(71 72 73)}</style><p id="editor" contenteditable>text</p>')
	mut app := BrowserApp{
		document: document
	}
	app.relayout(200, 232)
	editor := document.get_element_by_id('editor') or { panic('missing editor') }
	text_node := editor.as_node().first_child() or { panic('missing editor text') }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_focused_area(editor.as_node())
	mut selection := document.get_selection() or { panic('missing selection') }
	selection.collapse(text_node, 1) or { panic(err) }
	app.relayout(200, 232)
	navigable := document.navigable() or { panic('missing document navigable') }
	assert navigable.is_focused()
	assert app.paint_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(71 72 73)')
}

fn test_parse_launch_options_accepts_explicit_window_dimensions() {
	options := parse_launch_options([
		'--window-width=640',
		'--window-height',
		'480',
		'<p>Hello</p>',
	]) or { panic(err) }
	assert options.source == '<p>Hello</p>'
	assert options.width == 640
	assert options.height == 480
}

fn test_parse_launch_options_accepts_screenshot_output() {
	options := parse_launch_options([
		'--screenshot',
		'/tmp/example.png',
		'https://example.com',
	]) or { panic(err) }
	assert options.screenshot == '/tmp/example.png'
	assert options.source == 'https://example.com'
}

fn test_parse_launch_options_accepts_a_tall_screenshot_viewport_override() {
	options := parse_launch_options([
		'--screenshot-viewport-height',
		'4700',
		'--screenshot=/tmp/example.png',
		'page.html',
	]) or { panic(err) }
	assert options.screenshot_viewport_height == 4700
	assert options.height == initial_height
}

fn test_parse_launch_options_accepts_a_screenshot_scroll_offset() {
	options := parse_launch_options([
		'--screenshot-scroll-y=3612',
		'--screenshot=/tmp/example.png',
		'page.html',
	]) or { panic(err) }
	assert options.screenshot_scroll_y == 3612
}

fn test_parse_launch_options_rejects_empty_screenshot_output() {
	parse_launch_options(['--screenshot=']) or {
		assert err.msg().contains('PNG output path')
		return
	}
	assert false, 'an empty screenshot output path must be rejected'
}

fn test_parse_launch_options_rejects_invalid_dimensions() {
	parse_launch_options(['--window-height', '0']) or {
		assert err.msg().contains('positive integer')
		return
	}
	assert false, 'a non-positive window dimension must be rejected'
}

fn test_initial_document_loads_a_percent_encoded_file_url() {
	path := os.join_path(os.temp_dir(), 'ladybird-v local document ${os.getpid()}.html')
	os.write_file(path, '<title>Local report</title><p>Loaded</p>') or { panic(err) }
	defer {
		os.rm(path) or {}
	}
	encoded_path := path.replace(' ', '%20')
	page_url, markup, source_label := initial_document('file://${encoded_path}')
	assert page_url == 'file://${os.real_path(path)}'
	assert markup == '<title>Local report</title><p>Loaded</p>'
	assert source_label == os.real_path(path)
}

fn test_bundled_workspace_relative_file_path_resolves_relative_document_arguments() {
	workspace_root := os.join_path(os.temp_dir(), 'ladybird-v-workspace-${os.getpid()}')
	path := os.join_path(workspace_root, 'uk.html')
	os.mkdir_all(workspace_root) or { panic(err) }
	os.write_file(path, '<p>Ukraine report</p>') or { panic(err) }
	defer {
		os.rmdir_all(workspace_root) or {}
	}
	executable_path := os.join_path(workspace_root, 'Build', 'v', 'Ladybird.app', 'Contents', 'MacOS', 'Ladybird')
	resolved := bundled_workspace_relative_file_path('uk.html', executable_path) or {
		panic('relative document was not found from the bundle workspace')
	}
	assert resolved == path
}

fn test_resolve_url_canonicalizes_bare_host_for_cache_keys() {
	assert resolve_url('news.ycombinator.com', '') == 'https://news.ycombinator.com/'
	assert resolve_url('example.com/path', '') == 'https://example.com/path'
}

fn test_stale_pending_navigation_is_discarded_before_network_start() {
	mut app := BrowserApp{
		navigation_generation: 2
		pending_navigation: PendingNavigation{
			resolved: 'https://example.com/'
			generation: 1
		}
	}
	app.start_pending_navigation()
	assert app.pending_navigation == none
}

fn test_native_text_draw_y_converts_layout_line_box_to_cocoa_position() {
	assert native_text_draw_y(90, 28) == 104
	assert native_text_draw_y(134, 18) == 138
	assert native_text_draw_y(10, 10) == 10
}

fn test_native_gradient_clip_path_is_one_closed_tile_path() {
	path := native_gradient_clip_path(layout.PaintCommand{
		gradient_background_layer: true
	}, painting.Rect{10, 20, 30, 40})
	stride := layout.compatibility_clip_path_segment_stride
	assert path.len == 5 * stride
	assert path[0] == 0
	assert path[stride] == 1
	assert path[2 * stride] == 1
	assert path[3 * stride] == 1
	assert path[4 * stride] == 5
	assert path[1] == 10 && path[2] == 20
	assert path[2 * stride + 1] == 40 && path[2 * stride + 2] == 60
}

fn test_native_gradient_stop_data_preserves_hard_stops_and_applies_opacity() {
	gradient := layout.LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 128}]
		stops: [
			layout.GradientStop{css.Color{255, 0, 0, 255}, 0.0},
			layout.GradientStop{css.Color{255, 0, 0, 255}, 0.5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, 0.5},
			layout.GradientStop{css.Color{0, 0, 255, 128}, 1.0},
		]
	}
	data := native_gradient_stop_data(gradient, 0.5)
	mut half_offsets := 0
	for index := 0; index < data.len; index += 5 {
		if data[index + 4] == 0.5 {
			half_offsets++
		}
		assert data[index + 3] <= 0.5
	}
	assert half_offsets == 2
	assert data[3] == 0.5
	assert data[data.len - 2] > 0.25 && data[data.len - 2] < 0.252
}

fn test_backdrop_filter_canvas_detection_descends_into_nested_viewports() {
	assert !paint_commands_contain_backdrop_filter([
		layout.PaintCommand{ kind: 'fill_rect' },
	])
	assert paint_commands_contain_backdrop_filter([
		layout.PaintCommand{
			kind: 'paint_nested_display_list'
			nested_viewport_commands: [
				layout.PaintCommand{ kind: 'apply_backdrop_filter' },
			]
		},
	])
}

fn test_document_root_paintable_is_not_treated_as_an_element_wheel_scroller() {
	document := html.parse_document('<!doctype html><style>html, body { margin: 0 } #content { height: 1000px }</style><body><div id="content"></div></body>')
	_ = layout.layout_document_typed_in_viewport(document, 320, 200)
	document_element := document.document_element() or { panic('missing document element') }
	root_layout_node := document_element.as_node().layout_node() or {
		panic('missing document-root layout node')
	}
	assert layout_node_is_document_viewport_scroller(document, root_layout_node)
	viewport_layout_node := root_layout_node.containing_block() or {
		panic('missing synthetic viewport layout node')
	}
	assert layout_node_is_document_viewport_scroller(document, viewport_layout_node)

	content := document.get_element_by_id('content') or { panic('missing content') }
	content_layout_node := content.as_node().layout_node() or {
		panic('missing content layout node')
	}
	assert !layout_node_is_document_viewport_scroller(document, content_layout_node)
}

fn test_document_preload_resources_are_resolved_deduplicated_and_ordered() {
	document := html.parse_document('<html><head>
		<link rel="stylesheet" href="/news.css">
		<link rel="stylesheet" href="/news.css">
		<script src="hn.js"></script>
		<script type="application/json" src="ignored.json"></script>
		</head><body>
		<img src="/y18.svg"><img src="data:image/gif;base64,AA==">
		<svg><image href="/mask.png"/><image xlink:href="legacy.png"/>
		<image href="/y18.svg"/><image href="" xlink:href="ignored.png"/></svg>
		</body></html>')
	urls := document_preload_resource_urls(document, 'https://news.ycombinator.com/news')
	assert urls == [
		'https://news.ycombinator.com/news.css',
		'https://news.ycombinator.com/hn.js',
		'https://news.ycombinator.com/y18.svg',
		'https://news.ycombinator.com/mask.png',
		'https://news.ycombinator.com/legacy.png',
	]
}

fn test_document_preload_resources_use_the_document_base_element() {
	document_url := dom.dom_url_parse('https://example.test/pages/index.html', dom.url_about_blank(),
		'UTF-8') or { panic(err) }
	document := html.parse_document_with_url('<!doctype html><head><base href="https://cdn.example/assets/"><link rel="stylesheet" href="site.css"><script src="app.js"></script></head>',
		document_url)
	urls := document_preload_resource_urls(document, document.base_url().serialize())
	assert urls == [
		'https://cdn.example/assets/site.css',
		'https://cdn.example/assets/app.js',
	]
}

fn test_local_documents_do_not_block_on_remote_images() {
	document := html.parse_document('<html><head>
		<link rel="stylesheet" href="https://cdn.example/site.css">
		<script src="https://cdn.example/site.js"></script>
		</head><body>
		<img src="https://tracker.example/badge.png">
		<svg><image href="https://tracker.example/svg-badge.png"/></svg>
		</body></html>')
	urls := document_preload_resource_urls(document, 'file:///tmp/saved-page/index.html')
	assert urls == [
		'https://cdn.example/site.css',
		'https://cdn.example/site.js',
	]
}

fn test_svg_image_contain_destination_preserves_ratio_and_object_position() {
	x, y, width, height := contained_image_destination(10, 20, 100, 100, 200, 100, '25%', '75%')
	assert x == 10
	assert y == 57.5
	assert width == 100
	assert height == 50
}

fn test_svg_image_contain_destination_resolves_computed_edge_offsets() {
	x, y, width, height := contained_image_destination(10, 20, 100, 100, 50, 100, 'calc(100% - 10px)', 'calc(100% - 20px)')
	assert x == 50
	assert y == 0
	assert width == 50
	assert height == 100
}

fn test_successful_page_cache_round_trip() {
	cache_directory := os.join_path(os.temp_dir(), 'ladybird-v-cache-test-${os.getpid()}')
	os.rmdir_all(cache_directory) or {}
	previous_cache_directory := os.getenv_opt('LADYBIRD_CACHE_DIR')
	os.setenv('LADYBIRD_CACHE_DIR', cache_directory, true)
	defer {
		if previous := previous_cache_directory {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache_directory) or {}
	}

	cache_loaded_page(LoadedPage{
		url: 'https://news.ycombinator.com'
		markup: '<html><title>Cached HN</title></html>'
		status: 'HTTP 200'
		content_type: 'text/html; charset=utf-8'
	})
	cached := read_cached_page('https://news.ycombinator.com') or {
		panic('cached page was not restored')
	}
	assert cached.markup == '<html><title>Cached HN</title></html>'
	assert cached.status == 'Cached · refreshing'
	assert cached.content_type == 'text/html; charset=utf-8'
}

fn test_cached_status_is_replaced_without_relayout() {
	mut app := BrowserApp{
		load_status: 'Cached · refreshing'
		status: 'Cached · refreshing · 525 paints · 1200×1219 CSS px'
	}
	app.replace_load_status('HTTP 200 · 35000 bytes')
	assert app.load_status == 'HTTP 200 · 35000 bytes'
	assert app.status == 'HTTP 200 · 35000 bytes · 525 paints · 1200×1219 CSS px'
}

fn test_browser_snapshot_cache_is_opt_in() {
	previous := os.getenv_opt('LADYBIRD_ENABLE_SNAPSHOT_CACHE')
	os.unsetenv('LADYBIRD_ENABLE_SNAPSHOT_CACHE')
	defer {
		if value := previous {
			os.setenv('LADYBIRD_ENABLE_SNAPSHOT_CACHE', value, true)
		} else {
			os.unsetenv('LADYBIRD_ENABLE_SNAPSHOT_CACHE')
		}
	}
	assert !browser_snapshot_cache_enabled()
	os.setenv('LADYBIRD_ENABLE_SNAPSHOT_CACHE', '1', true)
	assert browser_snapshot_cache_enabled()
}

fn test_remote_background_image_bytes_never_fetches_on_the_paint_thread() {
	app := BrowserApp{
		resource_cache: map[string]PreloadedResource{}
	}
	app.background_image_bytes('https://example.com/background.png') or {
		assert err.msg() == 'remote image has not finished loading'
		return
	}
	assert false, 'an uncached remote image must not perform a synchronous fetch'
}

fn test_hit_testing_before_the_first_document_is_safe() {
	app := BrowserApp{}
	assert app.element_at_window_point(10, 10) == none
}

fn test_address_for_display_handles_a_narrow_toolbar() {
	assert address_for_display('file:///tmp/example.html', 0, false, 0) == ''
	assert address_for_display('file:///tmp/example.html', 0, true, -4) == ''
}

fn test_native_chrome_pointer_bridge_resizes_across_layout_updates() {
	mut document := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#resizable { width: 100px; height: 50px; overflow: auto; resize: both }
	</style><body><div id="resizable"></div></body>')
	mut page_model := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(page_model) })
	_ = html.WindowModel.create_top_level(document, none, 'resize fixture') or { panic(err) }
	assert document.is_fully_active()
	root := layout.layout_document_typed_in_viewport(document, 320, 200)
	element := document.get_element_by_id('resizable') or { panic('missing resizable element') }
	node_id := element.as_node().unique_id().value()
	box := root.find_box(node_id) or { panic('missing resizable box') }
	overlay := box.overlay or { panic('missing resizer overlay') }
	metrics := painting.new_chrome_metrics(1) or { panic(err) }
	border_rect := box.border_box()
	resizer_rect := painting.paintable_box_absolute_resizer_rect(painting.Rect{
		x: border_rect.x
		y: border_rect.y
		width: border_rect.width
		height: border_rect.height
	}, overlay.has_resizer, overlay.chrome_mirrored, metrics) or {
		panic('missing resize handle rect')
	}
	start_x := resizer_rect.right() - 1
	start_y := resizer_rect.bottom() - 1

	mut app := BrowserApp{
		page_model: page_model
		document: document
		root_box: root
		viewport_width: 320
		viewport_height: 200
	}
	app.install_chrome_widget_input_bridge()
	pointer_down := app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, start_x, start_y)
	assert pointer_down.target == 'resize-handle:${node_id}'
	assert pointer_down.handled
	assert pointer_down.cursor or { panic('missing native resize cursor') } == .se_resize
	assert page_model.event_handler.has_captured_chrome_widget()

	// The moved point is outside the old box, so only Page's captured-widget
	// route can deliver it. The resulting inline style triggers a fresh layout.
	pointer_move := app.dispatch_chrome_pointer_event_at_viewport_point('pointermove', 0, start_x + 30, start_y + 20)
	assert pointer_move.target == ''
	assert pointer_move.handled
	style := css.inline_style(element)
	assert style.get_property_value('width') == '130px'
	assert style.get_property_value('height') == '70px'
	assert page_model.event_handler.has_captured_chrome_widget()
	resized_box := app.root_box.find_box(node_id) or { panic('resized box was not adopted') }
	assert resized_box.border_box().width == 130

	pointer_up := app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, start_x + 30, start_y + 20)
	assert pointer_up.handled
	assert !page_model.event_handler.has_captured_chrome_widget()
}

fn bridge_test_rendering_frame(document &dom.Document) {
 mut page_ := page.Page.create(1) or { panic(err) }
 mut mutable_document := unsafe { &dom.Document(document) }
 mutable_document.set_page(unsafe { &dom.Page(page_) })
 page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or { panic(err) }
 mutable_document.update_the_visibility_state(.visible)
 mut app := BrowserApp{document: mutable_document, page_model: page_}
 app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
 mut event_loop := html.main_thread_event_loop()
 for event_loop.task_queue().has_runnable_tasks() { event_loop.process() }
}
