module css

import dom

// An animation frame re-resolves its target's background layers into the
// current sample arena. Paint boxes copy them out, since a box can outlive
// that arena; layers in ordinary storage are used as they are.
fn test_sampled_background_layers_are_copied_for_paint() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := css_style_computer_for(document)
	mut storage := computer.animation_sample_storage()
	storage.begin_update(document)
	storage.enter()
	calculated := parse_css_value_logic(.width, 'calc(10% + 4px)') or { panic('missing calc') }
	sampled := [
		BackgroundLayerData{
			image:      'linear-gradient(red, blue)'.clone()
			position_x: LengthPercentage.from_percentage(Percentage.new(25))
			position_y: LengthPercentage.from_style_value_logic(calculated)
			size_x:     LengthPercentageOrAuto{
				length_percentage_: LengthPercentage.from_length(Length.make_px(40))
			}
		},
	]
	storage.leave()
	assert storage.contains(sampled.data)
	owned := background_layers_outside_samples(document, sampled)
	assert !storage.contains(owned.data)
	assert !storage.contains(owned[0].image.str)
	assert owned == sampled
	assert owned[0].position_y.is_calculated()

	plain := [BackgroundLayerData{}]
	assert background_layers_outside_samples(document, plain).data == plain.data
}
