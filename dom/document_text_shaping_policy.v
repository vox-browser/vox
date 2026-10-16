module dom

pub enum TextShapingPolicy {
	libweb
	chromium
}

pub fn (d &Document) text_shaping_policy() TextShapingPolicy {
	return d.text_shaping_policy_
}

pub fn (mut d Document) set_text_shaping_policy(policy TextShapingPolicy) {
	if d.text_shaping_policy_ == policy { return }
	d.text_shaping_policy_ = policy
	d.bump_style_environment_version()
	d.set_needs_full_style_update(true)
}
