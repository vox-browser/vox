// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// Restrictions shared by Metal lowering and native GLES submission. The GLES
// driver checks remaining ESSL expression types and syntax.
pub fn validate_source(source string, stage Stage, context_version int) ! {
    if context_version !in [2, 3] { return error('Invalid WebGL context version') }
    processed := preprocess(source)!
    validate_input_identifiers(processed.tokens)!
    if context_version == 2 && processed.version != 100 { return error('ESSL300 requires WebGL2') }
    tokens:=normalize_constant_expressions(processed.tokens)!
    validate_essl_language(tokens, processed.version)!
    analysis := analyze_shader(tokens,processed.version,stage)!
    validate_global_initializers(tokens,analysis.functions,stage,processed.version)!
    _ = normalize_shader_expressions(tokens,processed.version,stage)!
}

fn validate_input_identifiers(tokens []string) ! {
    for word in tokens {
        if word.starts_with('_webgl_') || word.starts_with('webgl_') {
            return error('Reserved WebGL identifier: '+word)
        }
    }
}

// Two-pass copying keeps V-managed memory out of the C allocator's ownership.
// The terminating NUL is not included in the returned length.
@[export: 'vox_v_prepare_essl']
pub fn prepare_native(source &char, length i32, fragment i32, context_version i32, destination &char, capacity i32) i32 {
    if source == unsafe { nil } || length < 0 || capacity < 0 { return 0 }
    prepared := prepare_source(unsafe { tos(source, int(length)) }, if fragment != 0 { Stage.fragment } else { Stage.vertex }, int(context_version)) or { return 0 }
    if destination != unsafe { nil } {
        if int(capacity) <= prepared.len { return 0 }
        unsafe { vmemcpy(destination, prepared.str, prepared.len); destination[prepared.len] = 0 }
    }
    return i32(prepared.len)
}

@[export: 'vox_v_validate_essl']
pub fn validate_native(source &char, length i32, fragment i32, context_version i32) i32 {
    if source == unsafe { nil } || length < 0 { return 0 }
    validate_source(unsafe { tos(source, int(length)) }, if fragment != 0 { Stage.fragment } else { Stage.vertex }, int(context_version)) or { return 0 }
    return 1
}
