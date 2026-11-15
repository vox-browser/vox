// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs

// Public HTML interfaces supported by the native element factory. Tag lookup
// comes from the native HTMLConstructor table; internal HTMLSummaryElement
// storage still has the public HTMLElement interface.
const html_element_interfaces = [
	'HTMLMediaElement', 'HTMLAnchorElement', 'HTMLAreaElement', 'HTMLAudioElement',
	'HTMLBaseElement', 'HTMLBodyElement', 'HTMLBRElement', 'HTMLButtonElement',
	'HTMLCanvasElement', 'HTMLDataElement', 'HTMLDataListElement', 'HTMLDetailsElement',
	'HTMLDialogElement', 'HTMLDirectoryElement', 'HTMLDivElement', 'HTMLDListElement',
	'HTMLEmbedElement', 'HTMLFieldSetElement', 'HTMLFontElement', 'HTMLFormElement',
	'HTMLFrameElement', 'HTMLFrameSetElement', 'HTMLHeadElement', 'HTMLHeadingElement',
	'HTMLHRElement', 'HTMLHtmlElement', 'HTMLIFrameElement', 'HTMLImageElement',
	'HTMLInputElement', 'HTMLLabelElement', 'HTMLLegendElement', 'HTMLLIElement',
	'HTMLLinkElement', 'HTMLMapElement', 'HTMLMarqueeElement', 'HTMLMenuElement',
	'HTMLMetaElement', 'HTMLMeterElement', 'HTMLModElement', 'HTMLOListElement',
	'HTMLObjectElement', 'HTMLOptGroupElement', 'HTMLOptionElement', 'HTMLOutputElement',
	'HTMLParagraphElement', 'HTMLParamElement', 'HTMLPictureElement', 'HTMLPreElement',
	'HTMLProgressElement', 'HTMLQuoteElement', 'HTMLScriptElement', 'HTMLSelectedContentElement',
	'HTMLSelectElement', 'HTMLSlotElement', 'HTMLSourceElement', 'HTMLSpanElement',
	'HTMLStyleElement', 'HTMLTableCaptionElement', 'HTMLTableCellElement', 'HTMLTableColElement',
	'HTMLTableRowElement', 'HTMLTableElement', 'HTMLTableSectionElement', 'HTMLTemplateElement',
	'HTMLTextAreaElement', 'HTMLTimeElement', 'HTMLTitleElement', 'HTMLTrackElement',
	'HTMLUListElement', 'HTMLVideoElement', 'HTMLUnknownElement',
]

fn (mut host Host) install_html_element_interfaces() ! {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	host.html_element_prototypes['HTMLElement'] = host.html_element_prototype
	mut constructors := map[string]&libjs.Object{}
	constructors['HTMLElement'] = global.get(mut vm, libjs.PropertyName.from_str('HTMLElement'))!.as_object()
	for name in html_element_interfaces {
		parent_name := if name in ['HTMLAudioElement', 'HTMLVideoElement'] { 'HTMLMediaElement' } else { 'HTMLElement' }
		parent := host.html_element_prototypes[parent_name] or { return error('Missing HTML interface parent') }
		mut prototype := libjs.Object.create(host.realm, parent)
		host.html_element_prototypes[name] = prototype
		for tag in dom.valid_local_names_for_given_html_element_interface(name) { host.html_element_tags[tag] = name }
		construct := fn [host, name] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
			host.require_open(mut vm)!
			if name in ['HTMLMediaElement', 'HTMLUnknownElement'] { return vm.throw_error(.type_error, 'Illegal ' + name + ' constructor') }
			mut owner := unsafe { &Host(host) }
			return owner.construct_html_element(mut vm, new_target, name)
		}
		host.closures << voidptr(construct)
		mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
			fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'HTML interface constructor requires new') }, construct, 0, libjs.PropertyName.from_str(name)).object
		parent_constructor := constructors[parent_name] or { return error('Missing HTML interface constructor parent') }
		if !constructor.internal_set_prototype_of(parent_constructor) { return error('Unable to set HTML interface ancestry') }
		constructors[name] = constructor
		constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
		prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
		prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str(name)), libjs.attribute_configurable)
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	}
}
