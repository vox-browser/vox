// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of CredentialManagement/FederatedCredentialOperations.{h,cpp}.
module credentialmanagement

import dom
import net.urllib

fn parse_federated_provider_origin(provider string) !dom.Origin {
	parsed := urllib.parse(provider) or {
		return error("SyntaxError: 'provider' is not a valid URL.")
	}
	// LibURL's basic parser is invoked without a base URL upstream, so a
	// relative reference is not a provider URL.
	if !parsed.is_abs() || parsed.scheme == '' {
		return error("SyntaxError: 'provider' is not a valid URL.")
	}
	return dom.URL{
		value: parsed.str()
	}.origin()
}

// https://www.w3.org/TR/credential-management-1/#abstract-opdef-create-a-federatedcredential-from-federatedcredentialinit
pub fn create_federated_credential(init FederatedCredentialInit) !&FederatedCredential {
	if init.id == '' {
		return error("TypeError: 'id' must not be empty.")
	}
	if init.provider == '' {
		return error("TypeError: 'provider' must not be empty.")
	}
	origin := parse_federated_provider_origin(init.provider)!
	return FederatedCredential.create(init, origin)
}
