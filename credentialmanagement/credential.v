// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/Credential.{h,cpp,idl} and
// CredentialUserData.h.
module credentialmanagement

import dom

// https://www.w3.org/TR/credential-management-1/#dictdef-credentialdata
pub struct CredentialData {
pub:
	id string
}

// https://www.w3.org/TR/credential-management-1/#enumdef-credentialmediationrequirement
pub enum CredentialMediationRequirement {
	silent
	optional
	conditional
	required
}

// https://www.w3.org/TR/credential-management-1/#credential
//
// V has no abstract methods, so the concrete credential's WebIDL type is
// stored in the base record. Only this module creates base records.
@[heap]
pub struct Credential {
mut:
	id_   string
	type_ string
}

fn Credential.create(id string, type_ string) Credential {
	return Credential{
		id_: id
		type_: type_
	}
}

pub fn (credential &Credential) id() string {
	return credential.id_
}

pub fn (credential &Credential) type_() string {
	return credential.type_
}

// https://www.w3.org/TR/credential-management-1/#dom-credential-isconditionalmediationavailable
pub fn Credential.is_conditional_mediation_available() &dom.Promise {
	return Credential.is_conditional_mediation_available_impl()
}

pub fn Credential.is_conditional_mediation_available_impl() &dom.Promise {
	return dom.Promise.resolved(dom.js_bool(false))
}

// https://www.w3.org/TR/credential-management-1/#credentialuserdata
pub struct CredentialUserData {
mut:
	name_     string
	icon_url_ string
}

fn CredentialUserData.create(name string, icon_url string) CredentialUserData {
	return CredentialUserData{
		name_: name
		icon_url_: icon_url
	}
}

pub fn (data &CredentialUserData) name() string {
	return data.name_
}

pub fn (data &CredentialUserData) icon_url() string {
	return data.icon_url_
}
