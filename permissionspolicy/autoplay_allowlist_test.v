module permissionspolicy

import dom

fn test_default_self_global_and_explicit_origin_modes() {
	assert AutoplayAllowlist.the() == AutoplayAllowlist.the()
	self := dom.URL{'https://self.test/'}.origin()
	other := dom.URL{'https://other.test/'}.origin()
	mut allowlist := AutoplayAllowlist.new()
	assert allowlist.is_allowed_for_origin(self, false, self, false) == .enabled
	assert allowlist.is_allowed_for_origin(self, false, other, false) == .disabled
	allowlist.enable_globally()
	assert allowlist.is_allowed_for_origin(self, false, other, false) == .enabled
	allowlist.enable_for_origins(['other.test', ':// invalid'])
	assert allowlist.is_allowed_for_origin(self, false, other, false) == .enabled
	assert allowlist.is_allowed_for_origin(self, false, dom.URL{'https://third.test'}.origin(), false) == .disabled
	assert allowlist.is_allowed_for_origin(dom.Origin{'opaque'}, true, dom.Origin{'opaque'}, true) == .enabled
	allowlist.enable_for_origins(['https:other.test', 'data:text/plain,opaque'])
	assert allowlist.is_allowed_for_origin(self, false, other, false) == .enabled
	assert allowlist.is_allowed_for_origin(self, false, dom.origin_create_opaque(), false) == .disabled
}
