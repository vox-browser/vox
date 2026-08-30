module gpc

import loader

fn test_global_privacy_control_reflects_resource_loader_configuration() {
	mut resource_loader := loader.initialize()
	mixin := &GlobalPrivacyControlMixin{}
	assert !mixin.global_privacy_control()
	resource_loader.set_enable_global_privacy_control(true)
	assert mixin.global_privacy_control()
	resource_loader.set_enable_global_privacy_control(false)
	assert !mixin.global_privacy_control()
}
