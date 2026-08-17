module html

fn test_bar_prop_visibility() {
	assert BarProp.create(none).visible()
	assert BarProp.create(false).visible()
	assert !BarProp.create(true).visible()
}
