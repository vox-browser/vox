module css

import dom

// A transition that starts while its property is animated takes a sample as
// its start value. The transition outlives the sample arena, so the endpoint
// is copied into ordinary storage; the copy must stay typed, because keyframe
// computation reads the typed value.
fn test_sampled_transition_endpoints_stay_typed_outside_samples() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := css_style_computer_for(document)
	mut storage := computer.animation_sample_storage()
	storage.begin_update(document)
	storage.enter()
	sampled := parse_css_value(ParsingParams{}, 'translate(-50%, 0px) scale(1.025275, 1.025275)',
		.transform) or { panic('sampled transform did not parse') }
	storage.leave()
	assert storage.contains(voidptr(sampled))
	copy := computer.copy_sampled_style_value(.transform, sampled)
	assert !storage.contains(voidptr(copy))
	assert !storage.contains(copy.css_value_handle)
	assert typed_style_value_logic_from_dom(copy) != none
	assert copy.css_text == sampled.css_text

	plain := parse_css_value(ParsingParams{}, 'scale(2)', .transform) or {
		panic('transform did not parse')
	}
	assert voidptr(computer.copy_sampled_style_value(.transform, plain)) == voidptr(plain)
}
