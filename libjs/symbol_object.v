module libjs

// Runtime/SymbolObject.{h,cpp}. The retained primitive is the [[SymbolData]]
// slot and its upstream GC edge; V's heap record keeps its identity alive.
@[heap]
pub struct SymbolObject {
pub:
	object &Object
	symbol &Symbol
}

pub fn SymbolObject.create(realm &Realm, symbol &Symbol) &SymbolObject {
	mut object := Object.create(realm, realm.symbol_prototype_record())
	object.class_name = 'Symbol'
	wrapper := &SymbolObject{object: object, symbol: symbol}
	object.symbol_object = wrapper
	return wrapper
}
