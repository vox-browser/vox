// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// Restrictions shared by Metal lowering and native GLES submission. The GLES
// driver checks remaining ESSL expression types and syntax without rewriting it.
pub fn validate_source(source string, stage Stage, context_version int) ! {
    if context_version !in [2, 3] { return error('Invalid WebGL context version') }
    processed := preprocess(source)!
    if context_version == 2 && processed.version != 100 { return error('ESSL300 requires WebGL2') }
    tokens:=normalize_constant_expressions(processed.tokens)!
    validate_essl_language(tokens, processed.version)!
    _ = analyze_shader(tokens,processed.version,stage)!
}

@[export: 'vox_v_validate_essl']
pub fn validate_native(source &char, length i32, fragment i32, context_version i32) i32 {
    if source == unsafe { nil } || length < 0 { return 0 }
    validate_source(unsafe { tos(source, int(length)) }, if fragment != 0 { Stage.fragment } else { Stage.vertex }, int(context_version)) or { return 0 }
    return 1
}
