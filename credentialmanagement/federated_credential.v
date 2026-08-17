// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/FederatedCredential.{h,cpp,idl}.
module credentialmanagement

import dom

// https://www.w3.org/TR/credential-management-1/#dictdef-federatedcredentialrequestoptions
pub struct FederatedCredentialRequestOptions {
pub:
	providers ?[]string
	protocols ?[]string
}

// https://www.w3.org/TR/credential-management-1/#dictdef-federatedcredentialinit
pub struct FederatedCredentialInit {
pub:
	id       string
	name     ?string
	icon_url ?string
	provider string
	protocol ?string
}

// https://w3c.github.io/webappsec-credential-management/#federatedcredential
@[heap]
pub struct FederatedCredential {
	Credential
	CredentialUserData
mut:
	provider_ string
	protocol_ ?string
	origin_   dom.Origin
}

// https://www.w3.org/TR/credential-management-1/#dom-federatedcredential-federatedcredential
pub fn FederatedCredential.construct_impl(data FederatedCredentialInit) !&FederatedCredential {
	return create_federated_credential(data)
}

fn FederatedCredential.create(data FederatedCredentialInit, origin dom.Origin) &FederatedCredential {
	return &FederatedCredential{
		Credential:         Credential.create(data.id, 'federated')
		CredentialUserData: CredentialUserData.create(data.name or { '' }, data.icon_url or { '' })
		provider_:          data.provider
		protocol_:          data.protocol
		origin_:            origin
	}
}

pub fn (credential &FederatedCredential) provider() string {
	return credential.provider_
}

pub fn (credential &FederatedCredential) protocol() ?string {
	return credential.protocol_
}

pub fn (credential &FederatedCredential) origin() dom.Origin {
	return credential.origin_
}

pub fn (credential &FederatedCredential) as_credential() &Credential {
	return unsafe { &Credential(credential) }
}
