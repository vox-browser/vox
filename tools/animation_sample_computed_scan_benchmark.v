// Internal retirement component: add this CSS-package file with -file-list
// when compiling css/animation_sample_computed_scan_test.v, and select only
// test_animation_sample_computed_scan_component with -run-only.
module css

import dom
import platform
import processmetrics

fn measure_computed_retirement_scene(scene string) {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut arena := platform.new_arena('computed retirement component')
	defer { arena.release() }
	entry := arena.enter()
	sample := &dom.StyleValue{css_text: 'sample'}
	arena.leave(entry)
	mut retiring := RetiringAnimationSamples{arena: arena}
	for index in 0 .. 64 {
		element := document.create_element('div') or { panic(err) }
		mut target := dom.AbstractElement.new(element, none)
		mut style := computed_properties_with_initial_values()
		_ = style.display()
		if scene == 'first-held' && index == 0 { style.set_property_without_modifying_flags(.fill, sample) }
		target.set_computed_properties(&dom.CSSComputedProperties_{css_handle: voidptr(style)})
		if scene != 'live-only' {
			mut node := element.as_node()
			node.set_layout_node(&dom.LayoutNode{})
			if scene == 'last-applied-held' && index == 63 {
				mut applied := computed_properties_with_initial_values()
				applied.set_property_without_modifying_flags(.fill, sample)
				mut wrapper := element.layout_node_with_style_ or { panic('missing applied wrapper') }
				wrapper.applied_properties_ = &dom.CSSComputedProperties_{css_handle: voidptr(applied)}
			}
		}
		retiring.targets << AnimationSampleTarget{element: target}
		if scene == 'repeated-targets' {
			for _ in 0 .. 3 { retiring.targets << AnimationSampleTarget{element: target} }
		}
	}
	expected := scene in ['first-held', 'last-applied-held']
	// A separate nonmemoizing oracle precedes the counted interval.
	mut oracle := AnimationSampleReferenceScan{retiring: &retiring, use_clean_computed: false}
	assert oracle.styles_reference_arena() == expected
	assert retiring.styles_reference_arena() == expected
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for iteration in 0 .. 128 {
		actual := retiring.styles_reference_arena()
		assert actual == expected
		checksum += u64(iteration + 1) + if actual { u64(1) } else { u64(0) }
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${scene}","instructions":${instructions},"inspections":128,"targets":${retiring.targets.len},"checksum":${checksum}}')
}

fn test_animation_sample_computed_scan_component() {
	$if prealloc {
		for scene in ['live-applied', 'repeated-targets', 'live-only', 'first-held', 'last-applied-held'] {
			measure_computed_retirement_scene(scene)
		}
	}
}
