// Component diagnostic of actual deterministic animation/style updates.
module main

import css
import dom
import html
import processmetrics

struct AnimationScanFrame {
	values []string
}

fn animation_scan_document(scene string, ordinary bool) (&dom.Document, &css.StyleComputer, []&dom.Element) {
	mut document := dom.Document.create(dom.URL{ value: 'https://animation-scan.test/' })
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish() }
	mut computer := css.css_style_computer_for(document)
	if ordinary { computer.disable_animation_sample_arenas() }
	html.parse_html_from_a_string(document, '<!doctype html><main>' +
		'<span class="target checked">target<i class="checked">child</i></span>'.repeat(32) + '</main>')
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.oldest_live_paint_scene_generation = 2
	frames := match scene {
		'opacity-transform' {
			'from{opacity:.25;transform:translateX(0px)}to{opacity:.75;transform:translateX(80px)}'
		}
		'inherited-color' { 'from{color:rgb(20,40,60)}to{color:rgb(220,140,80)}' }
		'mixed-layout-paint' {
			'from{width:20px;background-color:rgb(20,40,60);opacity:.25}to{width:80px;background-color:rgb(220,140,80);opacity:.75}'
		}
		else { 'from{opacity:.5}to{opacity:.5}' }
	}
	css.add_document_author_style_sheet(document, '.target{display:inline-block;animation:sample 1s linear infinite}@keyframes sample{' + frames + '}')
	computer.set_animation_time_ms(0)
	document.update_style()
	targets := css.query_selector_all(document.as_node(), '.checked')
	assert targets.len == 64
	return document, computer, targets
}

fn animation_scan_values(targets []&dom.Element) []string {
	mut values := []string{cap: targets.len * 5}
	for element in targets {
		computed := css.computed_properties_for_element(element) or { panic('missing style') }
		for property in [css.PropertyID.color, .opacity, .transform, .width, .background_color] {
			value := computed.property(property, .yes) or { panic('missing property') }
			values << value.css_text.clone()
		}
	}
	return values
}

fn check_animation_scan_frame(targets []&dom.Element, expected []string) u64 {
	mut position := 0
	mut checksum := u64(0)
	for element in targets {
		computed := css.computed_properties_for_element(element) or { panic('missing style') }
		for property in [css.PropertyID.color, .opacity, .transform, .width, .background_color] {
			value := computed.property(property, .yes) or { panic('missing property') }
			assert value.css_text == expected[position]
			checksum += u64(value.css_text.len)
			position++
		}
	}
	assert position == expected.len
	return checksum
}

fn measure_animation_scan(scene string) {
	mut reference, mut reference_computer, reference_targets := animation_scan_document(scene, true)
	mut expected := []AnimationScanFrame{cap: 128}
	for frame in 0 .. 128 {
		reference_computer.set_animation_time_ms(f64(frame + 1) * 16)
		reference.update_style()
		expected << AnimationScanFrame{animation_scan_values(reference_targets)}
	}
	if scene != 'unchanged-opacity' {
		assert expected[0].values != expected[31].values
	}
	reference.finalize()
	reference.release_native_storage()
	mut document, mut computer, targets := animation_scan_document(scene, false)
	defer {
		document.finalize()
		document.release_native_storage()
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for frame in 0 .. 128 {
		computer.set_animation_time_ms(f64(frame + 1) * 16)
		document.update_style()
		checksum += check_animation_scan_frame(targets, expected[frame].values)
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${scene}","instructions":${instructions},"frames":128,"targets":64,"checksum":${checksum}}')
}

fn main() {
	for scene in ['opacity-transform', 'inherited-color', 'mixed-layout-paint', 'unchanged-opacity'] {
		measure_animation_scan(scene)
	}
}
