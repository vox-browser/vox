// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/CredentialsContainer.{h,cpp,idl}.
module credentialmanagement

import dom

pub struct CredentialRequestOptions {
pub:
	mediation CredentialMediationRequirement = .optional
	signal    ?&dom.AbortSignal
	password  ?bool
	federated ?FederatedCredentialRequestOptions
}

pub struct CredentialCreationOptions {
pub:
	mediation CredentialMediationRequirement = .optional
	signal    ?&dom.AbortSignal
	password  ?PasswordCredentialInit
	federated ?FederatedCredentialInit
}

@[heap]
pub struct CredentialsContainer {}

pub fn CredentialsContainer.construct_impl() &CredentialsContainer {
	return &CredentialsContainer{}
}

fn reject_not_implemented_promise(operation string) &dom.Promise {
	return dom.Promise.rejected(dom.js_string('InternalError: Not implemented: ${operation}'))
}

// These four methods deliberately match Ladybird's current implementation:
// the Credential Management algorithms have not yet been wired to a browser
// credential store and each call returns an already-rejected promise.
pub fn (container &CredentialsContainer) get(options CredentialRequestOptions) &dom.Promise {
	_ = container
	_ = options
	return reject_not_implemented_promise('get')
}

pub fn (container &CredentialsContainer) store(credential &Credential) &dom.Promise {
	_ = container
	_ = credential
	return reject_not_implemented_promise('store')
}

pub fn (container &CredentialsContainer) create(options CredentialCreationOptions) &dom.Promise {
	_ = container
	_ = options
	return reject_not_implemented_promise('create')
}

pub fn (container &CredentialsContainer) prevent_silent_access() &dom.Promise {
	_ = container
	return reject_not_implemented_promise('prevent silent access')
}
