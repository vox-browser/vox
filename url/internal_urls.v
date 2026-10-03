// LibURL/InternalURLs.h exact WebUI URL membership. URL::equals compares the
// complete serialization, including query and fragment.
module url

pub fn is_webui_url(value &URL) bool {
	return value.serialize(false) in ['about:bookmarks', 'about:downloads', 'about:history',
		'about:newtab', 'about:processes', 'about:settings', 'about:version']
}
