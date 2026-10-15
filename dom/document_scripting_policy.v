module dom

// A navigation policy belongs to its Document, independently of the Page's
// user preference. Replacing that document must not disable the next site.
pub fn (d &Document) is_scripting_enabled_by_embedder() bool {
	return d.scripting_enabled_by_embedder_
}

// Install before parsing so script elements, handlers and preloads can stay
// inert without constructing JavaScript resources in the first place.
pub fn (mut d Document) set_scripting_enabled_by_embedder(enabled bool) {
	d.scripting_enabled_by_embedder_ = enabled
}
