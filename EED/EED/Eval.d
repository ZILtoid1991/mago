module EED.Eval;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// Base: Base class methods, stubs, and conversions

import EED.Common;
import EED.Expression;
import EED.Declaration;
import EED.Type;
import EED.TypeCommon;
import EED.ITypeEnv;

struct DArray
{
	dlength_t Length;
	Address Addr;
	String* LiteralString;
}

struct DDelegate
{
	Address ContextAddr;
	Address FuncAddr;
}

enum DataValueKind
{
	DataValueKind_None,
	DataValueKind_Int64,
	DataValueKind_UInt64,
	DataValueKind_Float80,
	DataValueKind_Complex80,
	DataValueKind_Addr,
	DataValueKind_Array,
	DataValueKind_Delegate,
}

union DataValue
{
	int64_t Int64Value;
	uint64_t UInt64Value;
	Real10 Float80Value;
	Complex10 Complex80Value;
	Address Addr;
	DArray Array;
	DDelegate Delegate;
}

struct DataObject
{
	// Includes a Declaration member that can be used for things like S.a and s1.a 
	//      where S is a struct type, and s1 is a var of S type. 
	//      That needs to carry properties like offsetof.
	RefPtr!(Type) _Type;
	Address Addr;
	DataValue Value;

	// Since we're dealing only with values, we always have to have a type.
	// Objects with non-scalar types leave Value unused.
	//  literal or calculated value:    _Type
	//  calculated value with address:  _Type, Addr
}

struct EvalOptions
{
	bool AllowAssignment;
	bool AllowFuncExec;
	uint8_t Radix;
	int Timeout;

	static EvalOptions defaults = {false, false, 10, 1000};
}

struct FormatOptions
{
	uint32_t radix;
	uint32_t specifier; // some of https://msdn.microsoft.com/en-us/library/75w45ekt.aspx

	this(uint32_t r = 0, uint32_t s = 0)
	{
		radix = (r);
		specifier = (s);
	}
}

enum SupportedFormatSpecifiers
{
	FormatSpecRaw = '!',
}

interface IScope
{
public:
	HRESULT FindObject(const(wchar_t)* name, ref Declaration* decl);
	// TODO: add GetThis and GetSuper from IValueBinder?
}

// TODO: derive from IScope?
interface IValueBinder
{
public:
	HRESULT FindObject(const(wchar_t)* name, ref Declaration* decl);

	HRESULT GetThis(ref Declaration* decl);
	HRESULT GetSuper(ref Declaration* decl);
	HRESULT GetReturnType(ref Type* type);

	HRESULT GetValue(Declaration* decl, ref DataValue value);
	HRESULT GetValue(Address addr, Type* type, ref DataValue value);
	HRESULT GetValue(Address aArrayAddr, ref const DataObject key, ref Address valueAddr);
	int GetAAVersion();
	HRESULT GetClassName(Address addr, ref std.wstring className);

	HRESULT SetValue(Declaration* decl, ref const DataValue value);
	HRESULT SetValue(Address addr, Type* type, ref const DataValue value);

	HRESULT ReadMemory(Address addr, uint32_t sizeToRead, ref uint32_t sizeRead, uint8_t* buffer);
	HRESULT SymbolFromAddr(Address addr, ref std.wstring symName);
	HRESULT CallFunction(Address addr, ITypeFunction* func, Address arg, ref DataObject value);
}
