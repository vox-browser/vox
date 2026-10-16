module dom

// Font-size keyword tables are a user-agent preference. Translation fixtures
// retain LibWeb's mapping; the native embedder can select a compatibility table.
pub enum FontSizeKeywordPolicy {
	libweb
	chromium
}

pub fn (d &Document) font_size_keyword_policy() FontSizeKeywordPolicy {
	return d.font_size_keyword_policy_
}

pub fn (mut d Document) set_font_size_keyword_policy(policy FontSizeKeywordPolicy) {
	if d.font_size_keyword_policy_ == policy { return }
	d.font_size_keyword_policy_ = policy
	d.bump_style_environment_version()
	d.set_needs_full_style_update(true)
}
