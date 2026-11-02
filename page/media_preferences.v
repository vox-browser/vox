module page

pub fn (client &PageClient) prefers_reduced_motion() bool {
	return client.preferred_motion_ == 'reduce'
}

pub fn (p &Page) prefers_reduced_motion() bool {
	return p.client_.prefers_reduced_motion()
}

pub fn (mut p Page) set_prefers_reduced_motion(reduce bool) {
	if p.prefers_reduced_motion() == reduce { return }
	p.client_.preferred_motion_ = if reduce { 'reduce' } else { 'no-preference' }
	p.invalidate_style_for_preference_change()
}

fn page_prefers_reduced_motion_callback(target voidptr) bool {
	model := unsafe { &Page(target) }
	return model.prefers_reduced_motion()
}

pub fn (client &PageClient) prefers_reduced_transparency() bool {
	return client.prefers_reduced_transparency_
}

pub fn (p &Page) prefers_reduced_transparency() bool {
	return p.client_.prefers_reduced_transparency()
}

pub fn (mut p Page) set_prefers_reduced_transparency(reduce bool) {
	if p.client_.prefers_reduced_transparency_ == reduce { return }
	p.client_.prefers_reduced_transparency_ = reduce
	p.invalidate_style_for_preference_change()
}

fn page_prefers_reduced_transparency_callback(target voidptr) bool {
	model := unsafe { &Page(target) }
	return model.prefers_reduced_transparency()
}
