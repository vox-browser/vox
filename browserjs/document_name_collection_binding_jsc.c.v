module browserjs

import dom
import platform

pub type DocumentNameElementWrapper = fn (&dom.Element) !voidptr

// The JavaScript facade owns a real native LiveNodeList. Reading it flushes
// compact writes before consulting that list and reuses native node wrappers.
pub fn (mut runtime Runtime) install_document_name_collection_binding(wrap DocumentNameElementWrapper) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdDocumentNameCollection', fn [owner, wrap] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len == 0 { return runtime.event_binding_type_error('Illegal Document receiver') }
		target := runtime.native_event_target(args[0])!
		if target.data.kind != .node { return runtime.event_binding_type_error('Illegal Document receiver') }
		document := unsafe { &dom.Node(target) }.as_document() or {
			return runtime.event_binding_type_error('Illegal Document receiver')
		}
		if args.len < 2 { return runtime.event_binding_type_error('getElementsByName requires a name') }
		name := (runtime.binding_dom_utf16(args[1])!).str()
		mut storage := document.native_storage()
		mut scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { scope = storage.enter_nested() }
		defer { scope.finish() }
		list := document.get_elements_by_name(name)
		return runtime.make_value_host_function(fn [owner, list, wrap] (_ voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			mut values := []voidptr{}
			for node in list.collection() {
				element := node.as_element() or { continue }
				values << wrap(element)!
			}
			mut exception := voidptr(0)
			array := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			return array
		})
	})!
}
