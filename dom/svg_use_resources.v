module dom

pub fn (mut document Document) set_svg_use_resource_hook(hook DocumentSVGUseResourceHook) {
	document.svg_use_resource_hook_ = hook
	document.refresh_svg_use_shadow_trees()
}

fn (document &Document) svg_use_resource_document(url URL) ?&Document {
	hook := document.svg_use_resource_hook_ or { return none }
	if hook.resolve == unsafe { nil } { return none }
	return hook.resolve(hook.target, url)
}
