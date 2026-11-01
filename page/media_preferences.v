module page

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
