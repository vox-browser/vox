// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/PasswordCredential.{h,cpp,idl}.
module credentialmanagement

import dom
import html

// https://www.w3.org/TR/credential-management-1/#dictdef-passwordcredentialdata
pub struct PasswordCredentialData {
pub mut:
	id       string
	name     ?string
	icon_url ?string
	password string
}

// WebIDL: (PasswordCredentialData or HTMLFormElement).
pub type PasswordCredentialInit = PasswordCredentialData | html.HTMLFormElementModel

// https://www.w3.org/TR/credential-management-1/#passwordcredential
@[heap]
pub struct PasswordCredential {
	Credential
	CredentialUserData
mut:
	password_ string
	origin_   dom.Origin
}

// V cannot overload construct_impl by dictionary/form argument like WebIDL,
// so the two generated constructor entry points have explicit suffixes.
pub fn PasswordCredential.construct_impl(data PasswordCredentialData, origin dom.Origin) !&PasswordCredential {
	return PasswordCredential.create_for_constructor(data, origin)
}

pub fn PasswordCredential.construct_impl_from_form(form &html.HTMLFormElementModel, origin dom.Origin) !&PasswordCredential {
	return PasswordCredential.create_for_constructor(*form, origin)
}

// V represents WebIDL's overloaded constructor argument with a sum type. The
// caller supplies the relevant settings object's origin explicitly.
pub fn PasswordCredential.create_for_constructor(initializer PasswordCredentialInit, origin dom.Origin) !&PasswordCredential {
	return match initializer {
		PasswordCredentialData { create_password_credential(initializer, origin) }
		html.HTMLFormElementModel { create_password_credential_from_form(&initializer, origin) }
	}
}

fn PasswordCredential.create(data PasswordCredentialData, origin dom.Origin) &PasswordCredential {
	return &PasswordCredential{
		Credential: Credential.create(data.id, 'password')
		CredentialUserData: CredentialUserData.create(data.name or { '' }, data.icon_url or { '' })
		password_: data.password
		origin_: origin
	}
}

pub fn (credential &PasswordCredential) password() string {
	return credential.password_
}

pub fn (credential &PasswordCredential) origin() dom.Origin {
	return credential.origin_
}

// `type` is a V keyword; type_ is the direct spelling used for the override.
pub fn (_ &PasswordCredential) type_() string {
	return 'password'
}

pub fn (credential &PasswordCredential) as_credential() &Credential {
	return unsafe { &Credential(credential) }
}
