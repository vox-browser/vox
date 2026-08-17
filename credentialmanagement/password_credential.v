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
	return create_password_credential(data, origin)
}

pub fn PasswordCredential.construct_impl_from_form(form &html.HTMLFormElementModel, origin dom.Origin) !&PasswordCredential {
	return create_password_credential_from_form(form, origin)
}

fn PasswordCredential.create(data PasswordCredentialData, origin dom.Origin) &PasswordCredential {
	return &PasswordCredential{
		Credential:         Credential.create(data.id, 'password')
		CredentialUserData: CredentialUserData.create(data.name or { '' }, data.icon_url or { '' })
		password_:          data.password
		origin_:            origin
	}
}

pub fn (credential &PasswordCredential) password() string {
	return credential.password_
}

pub fn (credential &PasswordCredential) origin() dom.Origin {
	return credential.origin_
}

pub fn (credential &PasswordCredential) as_credential() &Credential {
	return unsafe { &Credential(credential) }
}
