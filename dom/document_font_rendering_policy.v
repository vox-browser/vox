module dom

pub enum FontRenderingPolicy {
	libweb
	chromium
}

pub fn (d &Document) font_rendering_policy() FontRenderingPolicy {
	return d.font_rendering_policy_
}

pub fn (mut d Document) set_font_rendering_policy(policy FontRenderingPolicy) {
	if d.font_rendering_policy_ == policy { return }
	d.font_rendering_policy_ = policy
	d.bump_style_environment_version()
	d.set_needs_full_style_update(true)
}
