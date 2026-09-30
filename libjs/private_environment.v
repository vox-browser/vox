module libjs

// Translated from LibJS/Runtime/PrivateEnvironment.{h,cpp}. The upstream unique
// id counter is a process-wide static; here the VM hands out ids so hosts can
// own several VMs.

pub struct PrivateName {
pub:
	unique_id   u64
	description Utf16String
}

pub fn (a PrivateName) == (b PrivateName) bool {
	return a.unique_id == b.unique_id && a.description == b.description
}

@[heap]
pub struct PrivateEnvironment {
pub mut:
	outer_environment ?&PrivateEnvironment // [[OuterEnv]]
	private_names     []PrivateName        // [[Names]]
	unique_id         u64
}

pub fn PrivateEnvironment.create(mut vm VM, outer ?&PrivateEnvironment) &PrivateEnvironment {
	return &PrivateEnvironment{
		outer_environment: outer
		unique_id:         vm.allocate_private_environment_id()
	}
}

fn (environment &PrivateEnvironment) find_private_name(description Utf16String) ?PrivateName {
	for private_name in environment.private_names {
		if private_name.description == description {
			return private_name
		}
	}
	return none
}

// 9.2.1.1 ResolvePrivateIdentifier ( privEnv, identifier ), https://tc39.es/ecma262/#sec-resolve-private-identifier
pub fn (environment &PrivateEnvironment) resolve_private_identifier(identifier Utf16String) PrivateName {
	if private_name := environment.find_private_name(identifier) {
		return private_name
	}
	// NOTE: We must either hold a matching private name or an outer environment,
	//       which together guarantee that a PrivateName is returned.
	outer := environment.outer_environment or {
		panic('ResolvePrivateIdentifier: ${identifier.str()} is not declared in any private environment')
	}
	return outer.resolve_private_identifier(identifier)
}

pub fn (environment &PrivateEnvironment) contains_private_identifier(identifier Utf16String) bool {
	if environment.find_private_name(identifier) != none {
		return true
	}
	outer := environment.outer_environment or { return false }
	return outer.contains_private_identifier(identifier)
}

pub fn (mut environment PrivateEnvironment) add_private_name(description Utf16String) {
	if environment.find_private_name(description) != none {
		return
	}
	environment.private_names << PrivateName{
		unique_id:   environment.unique_id
		description: description
	}
}
