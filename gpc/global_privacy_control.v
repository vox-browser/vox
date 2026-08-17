// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of GPC/GlobalPrivacyControl.{h,cpp,idl}.
module gpc

import loader

// GlobalPrivacyControlMixin models the Web IDL interface mixin used by
// Navigator. Its getter reflects whether ResourceLoader would emit Sec-GPC.
pub struct GlobalPrivacyControlMixin {}

// https://w3c.github.io/gpc/#dom-globalprivacycontrol-globalprivacycontrol
pub fn (_ &GlobalPrivacyControlMixin) global_privacy_control() bool {
	return loader.the().enable_global_privacy_control
}
