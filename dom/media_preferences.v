module dom

pub fn (d &Document) prefers_reduced_transparency() bool {
	return d.page_ != unsafe { nil } && d.page_.prefers_reduced_transparency()
}

pub fn (p &Page) prefers_reduced_transparency() bool {
	return p.target != unsafe { nil }
		&& p.prefers_reduced_transparency_callback != unsafe { nil }
		&& p.prefers_reduced_transparency_callback(p.target)
}
