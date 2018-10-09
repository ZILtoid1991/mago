module EED.Expression;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// #pragma once

import EED.Token;
import EED._object;
import EED.Eval;
import EED.Common;
//import EED.Strings;

enum EvalMode
{
    EvalMode_Value,
    EvalMode_Address,
}

enum DataKind
{
    DataKind_None,
    DataKind_Declaration,
    DataKind_Type,
    DataKind_Value,
}

struct EvalData
{
    EvalOptions Options;
    ITypeEnv* TypeEnv;
    bool HasArrayLength;
    dlength_t ArrayLength;
}

const HRESULT E_NOT_FOUND = HRESULT_FROM_WIN32(ERROR_NOT_FOUND);

HRESULT Eval(ref IValueBinder binder, ref Declaration decl, ref DataObject obj)
{
    if (obj.Addr == 0)
    {
        // no address, rely on declaration for address and type
        return binder.GetValue(decl, obj.Value);
    }
    else
    {
        // has address
        assert(obj._Type !is null);

        return binder.GetValue(obj.Addr, obj._Type, obj.Value);
    }
}

HRESULT TypeCheckAAKey(ref Type actualKeyType, ref Type declaredKeyType)
{
    assert(actualKeyType !is null);
    assert(declaredKeyType !is null);

    if (!declaredKeyType.IsBasic() && !declaredKeyType.IsPointer()
            && (declaredKeyType.AsTypeEnum() is null) && !declaredKeyType.IsDelegate()
            && (declaredKeyType.AsTypeStruct() is null)
            && !declaredKeyType.IsSArray() && !declaredKeyType.IsDArray())
        return E_MAGOEE_BAD_INDEX;
    if (declaredKeyType.IsReference())
        return E_MAGOEE_BAD_INDEX;
    if (declaredKeyType.IsSArray() || declaredKeyType.IsDArray())
    {
        Type elemType = declaredKeyType.AsTypeNext().GetNext();

        if (!elemType.IsBasic() && !elemType.IsPointer()
                && (elemType.AsTypeEnum() is null) && !elemType.IsDelegate()
                && (elemType.AsTypeStruct() is null))
            return E_MAGOEE_BAD_INDEX;
        if (elemType.IsReference())
            return E_MAGOEE_BAD_INDEX;
    }
    if ((declaredKeyType.AsTypeStruct() !is null) || declaredKeyType.IsSArray())
    {
        if (!actualKeyType.Equals(declaredKeyType))
            return E_MAGOEE_BAD_INDEX;
    }
    else
    {
        if (!CastExpr.CanCast(actualKeyType, declaredKeyType))
            return E_MAGOEE_BAD_INDEX;
    }

    return S_OK;
}

HRESULT FindAAElement(ref const DataObject array, ref const DataObject key,
        Type keyType, ref IValueBinder binder, ref Address addr)
{
    assert(keyType !is null);
    assert(binder !is null);

    DataObject finalKey = {0};

    finalKey._Type = keyType;
    finalKey.Addr = key.Addr;

    if ((keyType.AsTypeStruct() !is null) || keyType.IsSArray())
    {
        if (key.Addr == 0)
            return E_FAIL;
    }
    else
    {
        CastExpr.AssignValue(key, finalKey);
    }

    return binder.GetValue(array.Value.Addr, finalKey, addr);
}

class Expression : _Object
{
public:
    Type _Type;
    DataKind Kind;
    // Kind = 
    //  Declaration : NamingExpression::Decl is set
    //  Type : Expression::_Type is set
    //  Value : Expression::_Type is set, NamingExpression::Decl might be set
    //          Decl can be set if there is a declaration.
    //          It's used for its value, address, and other properties,
    //          like offset. But its type must be copied to the _Type member.

    this();
    ObjectKind GetObjectKind();
    // TODO: abstract
    HRESULT Semantic(ref const EvalData evalData, ITypeEnv* typeEnv, IValueBinder* binder)
    {
        //UNREFERENCED_PARAMETER(evalData);
        //UNREFERENCED_PARAMETER(typeEnv);
        //UNREFERENCED_PARAMETER(binder);
        assert(false);
        return E_NOTIMPL;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER(evalData);
        //UNREFERENCED_PARAMETER(mode);
        //UNREFERENCED_PARAMETER(binder);
        //UNREFERENCED_PARAMETER(obj);
        assert(false);
        return E_NOTIMPL;
    }

    bool TrySetType(Type type)
    {

    }

    NamingExpression AsNamingExpression()
    {

    }

    // returns E_MAGOEE_SYMBOL_NOT_FOUND 
    //          if this node does not support making up a dotted name
    HRESULT MakeName(uint32_t capacity, ref SharedString namePath);

    static bool ConvertToBool(ref const DataObject obj)
    {
        if (obj._Type.IsPointer())
        {
            return obj.Value.Addr != 0;
        }
        else if (obj._Type.IsComplex())
        {
            // TODO: this needs to be cleared up
            //       In DMD, explicitly casting to bool treats all imaginaries as a 0 zero, known as false.
            //       While implicit casting (for example in and && expr) treats non-zero as true, and zero as false.
            static if (0)
            {
                return !obj.Value.Complex80Value.RealPart.IsZero();
            }
            else
            {
                return !obj.Value.Complex80Value.RealPart.IsZero()
                    || !obj.Value.Complex80Value.ImaginaryPart.IsZero();
            }
        }
        else if (obj._Type.IsImaginary())
        {
            // TODO: this needs to be cleared up
            //       In DMD, explicitly casting to bool treats all imaginaries as a 0 zero, known as false.
            //       While implicit casting (for example in and && expr) treats non-zero as true, and zero as false.
            static if (0)
            {
                return false;
            }
            else
            {
                return !obj.Value.Float80Value.IsZero();
            }
        }
        else if (obj._Type.IsFloatingPoint())
        {
            return !obj.Value.Float80Value.IsZero();
        }
        else if (obj._Type.IsIntegral())
        {
            return obj.Value.UInt64Value != 0;
        }
        else if (obj._Type.IsDArray())
        {
            return obj.Value.Array.Addr != 0;
        }
        else if (obj._Type.IsSArray())
        {
            return obj.Addr != 0;
        }
        else if (obj._Type.IsAArray())
        {
            return obj.Value.Addr != 0;
        }
        else if (obj._Type.IsDelegate())
        {
            return (obj.Value.Delegate.ContextAddr != 0) || (obj.Value.Delegate.FuncAddr != 0);
        }

        assert(false);
        return false;
    }

    static Complex10 ConvertToComplex(ref const DataObject x)
    {
        return ConvertToComplex(null, x);
    }

    static Complex10 ConvertToComplex(ref Type commonType, ref const DataObject x)
    {
        Complex10 result;

        Type type = x._Type;

        if (type.IsImaginary())
        {
            result.RealPart.Zero();
            result.ImaginaryPart = x.Value.Float80Value;
        }
        else if (type.IsReal())
        {
            result.RealPart = x.Value.Float80Value;
            result.ImaginaryPart.Zero();
        }
        else if (type.IsIntegral())
        {
            if (type.IsSigned())
                result.RealPart.FromInt64(x.Value.Int64Value);
            else
                result.RealPart.FromUInt64(x.Value.UInt64Value);
            result.ImaginaryPart.Zero();
        }
        else if (type.IsPointer())
        {
            result.RealPart.FromUInt64(x.Value.Addr);
            result.ImaginaryPart.Zero();
        }
        else
        {
            assert(type.IsComplex());
            result = x.Value.Complex80Value;
        }

        if (commonType !is null)
        {
            if (commonType.GetBackingTy() == Tcomplex32)
            {
                result.RealPart.FromFloat(result.RealPart.ToFloat());
                result.ImaginaryPart.FromFloat(result.ImaginaryPart.ToFloat());
            }
            else if (commonType.GetBackingTy() == Tcomplex64)
            {
                result.RealPart.FromDouble(result.RealPart.ToDouble());
                result.ImaginaryPart.FromDouble(result.ImaginaryPart.ToDouble());
            }
        }

        return result;
    }

    static Real10 ConvertToFloat(ref const DataObject x)
    {
        return ConvertToFloat(null, x);
    }

    static Real10 ConvertToFloat(ref Type commonType, ref const DataObject x)
    {
        Real10 result;

        Type* type = x._Type.Get();

        if (type.IsIntegral())
        {
            if (type.IsSigned())
                result.FromInt64(x.Value.Int64Value);
            else
                result.FromUInt64(x.Value.UInt64Value);
        }
        else
        {
            assert(type.IsReal() || type.IsImaginary());
            result = x.Value.Float80Value;
        }

        if (commonType !is null)
        {
            ENUMTY backingTy = commonType.GetBackingTy();

            if ((backingTy == Tfloat32) || (backingTy == Timaginary32))
            {
                result.FromFloat(result.ToFloat());
            }
            else if ((backingTy == Tfloat64) || (backingTy == Timaginary64))
            {
                result.FromDouble(result.ToDouble());
            }
        }

        return result;
    }

    static void ConvertToDArray(ref const DataObject source, ref DataObject dest)
    {
        Type* destType = dest._Type;
        Type* srcType = source._Type;
        Address addr = 0;
        dlength_t srcLen = 0;

        assert(srcType.IsSArray() || srcType.IsDArray());

        if (srcType.IsSArray())
        {
            addr = source.Addr;
            srcLen = srcType.AsTypeSArray().GetLength();
        }
        else if (srcType.IsDArray())
        {
            addr = source.Value.Array.Addr;
            srcLen = source.Value.Array.Length;
        }

        Type* srcElemType = srcType.AsTypeNext().GetNext();
        Type* destElemType = destType.AsTypeNext().GetNext();
        dlength_t totalSize = srcLen * srcElemType.GetSize();
        dlength_t destLen = 0;

        // get the length if the sizes line up
        if ((destElemType.GetSize() > 0) && ((totalSize % destElemType.GetSize()) == 0))
            destLen = totalSize / destElemType.GetSize();
        // TODO: maybe we should fail if the sizes don't line up
        //      ...and we can tell the user with an explicit error code

        if (destLen == 0)
            addr = 0;

        dest.Value.Array.Addr = addr;
        dest.Value.Array.Length = destLen;

        if (srcType.IsDArray())
            dest.Value.Array.LiteralString = source.Value.Array.LiteralString;
    }

    static void PromoteInPlace(ref DataObject x)
    {
        assert(x._Type !is null);

        switch (x._Type.GetBackingTy())
        {
        case Tint32:
            x.Value.UInt64Value = cast(int32_t) x.Value.UInt64Value;
            break;
        case Tuns32:
            x.Value.UInt64Value = cast(uint32_t) x.Value.UInt64Value;
            break;
        case Tint16:
            x.Value.UInt64Value = cast(int16_t) x.Value.UInt64Value;
            break;
        case Tuns16:
            x.Value.UInt64Value = cast(uint16_t) x.Value.UInt64Value;
            break;
        case Tint8:
            x.Value.UInt64Value = cast(int8_t) x.Value.UInt64Value;
            break;
        case Tuns8:
            x.Value.UInt64Value = cast(uint8_t) x.Value.UInt64Value;
            break;
        default:
            assert(x._Type.GetSize() == 8);
        }
    }

    static void PromoteInPlace(ref DataObject x, ref Type targetType)
    {
        assert(x._Type !is null);
        assert(targetType !is null);

        if ((targetType.GetSize() == 8) || targetType.IsSigned())
        {
            PromoteInPlace(x);
        }
        else
        {
            assert(targetType.GetSize() == 4);
            assert(x._Type.GetSize() <= 4);

            uint32_t y = 0;

            // certain operations have intermediate results where the operands were promoted to uint
            // the standard PromoteInPlace assumes an end result

            switch (x._Type.GetBackingTy())
            {
            case Tint32:
                y = cast(int32_t) x.Value.UInt64Value;
                break;
            case Tuns32:
                y = cast(uint32_t) x.Value.UInt64Value;
                break;
            case Tint16:
                y = cast(int16_t) x.Value.UInt64Value;
                break;
            case Tuns16:
                y = cast(uint16_t) x.Value.UInt64Value;
                break;
            case Tint8:
                y = cast(int8_t) x.Value.UInt64Value;
                break;
            case Tuns8:
                y = cast(uint8_t) x.Value.UInt64Value;
                break;
            default:
                assert(x._Type.GetSize() == 8);
            }

            x.Value.UInt64Value = y;
        }
    }

    static Type PromoteComplexType(ref ITypeEnv typeEnv, ref Type t)
    {
        assert(t.IsIntegral() || t.IsFloatingPoint());

        Type type; //RefPtr < Type > type;

        if (t.IsComplex())
        {
            type = typeEnv.GetType(t.GetBackingTy());
        }
        else if (t.IsFloatingPoint())
        {
            switch (t.GetBackingTy())
            {
                //case Tfloat32:
            case Timaginary32, Tfloat32:
                type = typeEnv.GetType(Tcomplex32);
                break;
                //case Tfloat64:
            case Timaginary64, Tfloat64:
                type = typeEnv.GetType(Tcomplex64);
                break;
                //case Tfloat80:
            case Timaginary80, Tfloat80:
                type = typeEnv.GetType(Tcomplex80);
                break;
            default:
                assert(false, "Unknown float size."w);
            }
        }
        else if (t.IsIntegral())
            type = typeEnv.GetType(Tcomplex32);
        else
            assert(false, "Can't cast to float."w);

        return type;
    }

    static Type PromoteImaginaryType(ref ITypeEnv typeEnv, ref Type t)
    {
        assert(t.IsIntegral() || t.IsReal() || t.IsImaginary());

        Type type;

        if (t.IsFloatingPoint())
        {
            switch (t.GetBackingTy())
            {
                //case Tfloat32:
            case Timaginary32, Tfloat32:
                type = typeEnv.GetType(Timaginary32);
                break;
                //case Tfloat64:
            case Timaginary64, Tfloat64:
                type = typeEnv.GetType(Timaginary64);
                break;
                //case Tfloat80:
            case Timaginary80, Tfloat80:
                type = typeEnv.GetType(Timaginary80);
                break;
            default:
                assert(false, "Unknown float size."w);
            }
        }
        else if (t.IsIntegral())
            type = typeEnv.GetType(Timaginary32);
        else
            assert(false, "Can't cast to float."w);

        return type;
    }

    static Type PromoteFloatType(ref ITypeEnv typeEnv, ref Type t)
    {
        assert(t.IsIntegral() || t.IsReal());

        Type type;

        if (t.IsFloatingPoint())
        {
            type = typeEnv.GetType(t.GetBackingTy());
        }
        else if (t.IsIntegral())
            type = typeEnv.GetType(Tfloat32);
        else
            assert(false, "Can't cast to float."w);

        return type;
    }

    static Type PromoteIntType(ref ITypeEnv typeEnv, ref Type t)
    {
        assert(t.IsIntegral());

        Type intType = typeEnv.GetType(Tint32);
        Type type;

        if (t.GetSize() >= intType.GetSize())
        {
            type = typeEnv.GetType(t.GetBackingTy());
        }
        else
        {
            type = intType;
        }

        return type;
    }

    static Type GetCommonType(ref ITypeEnv typeEnv, ref Type left, ref Type right)
    {
        Type ltype;
        Type rtype;
        Type type;

        // TODO: test if they're the same type and (floating-point or integral with size >= sizeof( int ))
        //      if so, the common type is the same as left and right's

        if (left.IsComplex() || right.IsComplex() || (left.IsImaginary() != right.IsImaginary()))
        {
            ltype = PromoteComplexType(typeEnv, left);
            rtype = PromoteComplexType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsImaginary() && right.IsImaginary())
        {
            ltype = PromoteImaginaryType(typeEnv, left);
            rtype = PromoteImaginaryType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsReal() || right.IsReal())
        {
            ltype = PromoteFloatType(typeEnv, left);
            rtype = PromoteFloatType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsIntegral() && right.IsIntegral())
        {
            ltype = PromoteIntType(typeEnv, left);
            rtype = PromoteIntType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() == rtype.GetSize())
            {
                if (!ltype.IsSigned())
                    type = ltype;
                else
                    type = rtype;
            }
            else if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else // is less
                type = rtype;
        }
        // else we're dealing with non-scalars, which can't be combined, so return NULL

        return type;
    }

    static Type GetMulCommonType(ITypeEnv typeEnv, Type left, Type right)
    {
        Type ltype;
        Type rtype;
        Type type;

        // TODO: test if they're the same type and (floating-point or integral with size >= sizeof( int ))
        //      if so, the common type is the same as left and right's

        if (left.IsComplex() || right.IsComplex())
        {
            ltype = PromoteComplexType(typeEnv, left);
            rtype = PromoteComplexType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsImaginary() && right.IsImaginary())
        {
            ltype = PromoteFloatType(typeEnv, left);
            rtype = PromoteFloatType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsImaginary() || right.IsImaginary())
        {
            ltype = PromoteImaginaryType(typeEnv, left);
            rtype = PromoteImaginaryType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsReal() || right.IsReal())
        {
            ltype = PromoteFloatType(typeEnv, left);
            rtype = PromoteFloatType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsIntegral() && right.IsIntegral())
        {
            ltype = PromoteIntType(typeEnv, left);
            rtype = PromoteIntType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() == rtype.GetSize())
            {
                if (!ltype.IsSigned())
                    type = ltype;
                else
                    type = rtype;
            }
            else if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else // is less
                type = rtype;
        }
        // else we're dealing with non-scalars, which can't be combined, so return NULL

        return type;
    }

    static Type GetModCommonType(ITypeEnv typeEnv, Type left, Type right)
    {
        Type ltype;
        Type rtype;
        Type type;

        // TODO: test if they're the same type and (floating-point or integral with size >= sizeof( int ))
        //      if so, the common type is the same as left and right's

        if (left.IsComplex() || right.IsComplex())
        {
            ltype = PromoteComplexType(typeEnv, left);
            rtype = PromoteComplexType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsImaginary())
        {
            ltype = PromoteImaginaryType(typeEnv, left);
            rtype = PromoteImaginaryType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsReal() || right.IsReal() || right.IsImaginary())
        {
            ltype = PromoteFloatType(typeEnv, left);
            rtype = PromoteFloatType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else
                type = rtype;
        }
        else if (left.IsIntegral() && right.IsIntegral())
        {
            ltype = PromoteIntType(typeEnv, left);
            rtype = PromoteIntType(typeEnv, right);

            if (ltype is null || rtype is null)
                return null;

            if (ltype.GetSize() == rtype.GetSize())
            {
                if (!ltype.IsSigned())
                    type = ltype;
                else
                    type = rtype;
            }
            else if (ltype.GetSize() > rtype.GetSize())
                type = ltype;
            else // is less
                type = rtype;
        }
        // else we're dealing with non-scalars, which can't be combined, so return NULL

        return type;
    }

protected:
    void ClearEvalData();
}

class ExpressionList : _Object
{
public:
    std.list!(Expression) List;

    ObjectKind GetObjectKind();
}

class BinExpr : Expression
{
public:
    Expression Left;
    Expression Right;

    this(Expression left, Expression right);

protected:
    // run Semantic on Left and Right, and verify that they're values
    HRESULT SemanticVerifyChildren(ref const EvalData evalData, ITypeEnv* typeEnv,
            IValueBinder* binder)
    {
        HRESULT hr = S_OK;

        hr = Left.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Left.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Left._Type is null)
            return E_MAGOEE_NO_TYPE;

        hr = Right.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Right.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Right._Type is null)
            return E_MAGOEE_NO_TYPE;

        return S_OK;
    }
};

class CommaExpr : BinExpr
{
public:
    this(Expression left, Expression right);
};

class AssignExpr : BinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (Right.TrySetType(Left._Type))
        {
            // OK
        }
        else if (!CastExpr.CanImplicitCast(Right._Type, Left._Type))
            return E_MAGOEE_BAD_CAST;

        _Type = Left._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        // strictly an r-value
        // it goes along with returning no address
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject right = {0};
        Declaration decl;

        if (Left.AsNamingExpression() !is null)
            decl = Left.AsNamingExpression().Decl;

        if ((decl !is null) && decl.IsVar())
        {
            // all set, this declaration will be used to set the value
            // it can be a memory object or a register, it doesn't matter
            obj._Type = _Type;
        }
        else
        {
            // otherwise, it has to be a declaration or expression with an address
            hr = Left.Evaluate(EvalMode_Address, evalData, binder, obj);
            if (FAILED(hr))
                return hr;
        }

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        CastExpr.AssignValue(right, obj);

        // TODO: if we can't set the value, then what value should we return?
        //       - right side?
        //       - old left side?
        //       - new left side?
        //       Right now we're returning new left side.
        //       All this applies to CombinedAssignExpr, too.

        if (evalData.Options.AllowAssignment)
        {
            if (obj.Addr != 0)
                hr = binder.SetValue(obj.Addr, _Type, obj.Value);
            else if (decl !is null)
                hr = binder.SetValue(decl, obj.Value);
            else
                hr = E_MAGOEE_LVALUE_EXPECTED;
        }

        // strictly an r-value
        // it goes along with disallowing mode == EvalMode_Address
        // note that we're also not a NamingExpression, 
        // so we don't have a declaration field to pass to our parent
        obj.Addr = 0;
        return hr;
    }
}

class CombinedAssignExpr : Expression
{
public:
    CombinableBinExpr Child;
    bool IsPostOp;
    // IsPostOp says that we're a post-increment or decrement instead of a pre-inc or dec

    this(CombinableBinExpr child, bool postOp = false);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (!CastExpr.CanImplicitCast(Child._Type, Child.Left._Type))
            return E_MAGOEE_BAD_CAST;

        _Type = Child.Left._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        // strictly an r-value
        // it goes along with returning no address
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject childObj = {0};

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, childObj);
        if (FAILED(hr))
            return hr;

        obj._Type = _Type;
        CastExpr.AssignValue(childObj, obj);

        Declaration decl;
        if (Child.Left.AsNamingExpression() !is null)
            decl = Child.Left.AsNamingExpression().Decl;

        if (evalData.Options.AllowAssignment)
        {
            obj.Addr = Child.LeftAddr;
            if (obj.Addr != 0)
                hr = binder.SetValue(obj.Addr, _Type, obj.Value);
            else if (decl !is null)
                hr = binder.SetValue(decl, obj.Value);
            else
                hr = E_MAGOEE_LVALUE_EXPECTED;
        }

        // strictly an r-value
        // it goes along with disallowing mode == EvalMode_Address
        // note that we're also not a NamingExpression, 
        // so we don't have a declaration field to pass to our parent
        obj.Addr = 0;

        if (IsPostOp)
        {
            // take the original value of the left child (the l-value of this assignment)
            // and return that as our end result
            obj.Value = Child.LeftValue;
        }

        return hr;
    }
}

class ConditionalExpr : Expression
{
public:
    Expression PredicateExpr;
    Expression TrueExpr;
    Expression FalseExpr;

    this(Expression predicate, Expression trueExpr, Expression falseExpr);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = PredicateExpr.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (PredicateExpr.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (PredicateExpr._Type is null)
            return E_MAGOEE_NO_TYPE;

        hr = TrueExpr.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (TrueExpr.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (TrueExpr._Type is null)
            return E_MAGOEE_NO_TYPE;

        hr = FalseExpr.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (FalseExpr.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (FalseExpr._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!PredicateExpr._Type.CanImplicitCastToBool())
            return E_MAGOEE_BAD_BOOL_CAST;
        // TODO: actually, they only have to be compatible with the thing this whole expression fits in
        if (!TrueExpr._Type.Equals(FalseExpr._Type))
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = TrueExpr._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;
        DataObject pred = {0};

        hr = PredicateExpr.Evaluate(EvalMode_Value, evalData, binder, pred);
        if (FAILED(hr))
            return hr;

        if (ConvertToBool(pred))
        {
            hr = TrueExpr.Evaluate(mode, evalData, binder, obj);
        }
        else
        {
            hr = FalseExpr.Evaluate(mode, evalData, binder, obj);
        }

        if (FAILED(hr))
            return hr;

        // our value can have a return address, the sub-expression will already have put it in obj
        return S_OK;
    }
}

class OrOrExpr : BinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (!Left._Type.CanImplicitCastToBool() || !Right._Type.CanImplicitCastToBool())
            return E_MAGOEE_BAD_BOOL_CAST;

        _Type = typeEnv.GetType(Tbool);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        if (!ConvertToBool(left))
        {
            hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
            if (FAILED(hr))
                return hr;

            obj.Value.UInt64Value = ConvertToBool(right) ? 1 : 0;
        }
        else
            obj.Value.UInt64Value = 1;

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
}

class AndAndExpr : BinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (!Left._Type.CanImplicitCastToBool() || !Right._Type.CanImplicitCastToBool())
            return E_MAGOEE_BAD_BOOL_CAST;

        _Type = typeEnv.GetType(Tbool);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        if (ConvertToBool(left))
        {
            hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
            if (FAILED(hr))
                return hr;

            obj.Value.UInt64Value = ConvertToBool(right) ? 1 : 0;
        }
        else
            obj.Value.UInt64Value = 0;

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
}

class CombinableBinExpr : BinExpr
{
public:
    Address LeftAddr; // for combined assign
    DataValue LeftValue; // for post-increment

    this(Expression left, Expression right)
    {
        super(left, right);
        LeftAddr = (0);
        memset(&LeftValue, 0, LeftValue.sizeof);
    }

protected:
    void ClearEvalData()
    {
        BinExpr.ClearEvalData();
        LeftAddr = 0;
        memset(&LeftValue, 0, LeftValue.sizeof);
    }
}

class ArithmeticBinExpr : CombinableBinExpr
{
public:
    this(Expression left, Expression right)
    {
        super(left, right);
    }

    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (AllowOnlyIntegral())
        {
            if (!Left._Type.IsIntegral() || !Right._Type.IsIntegral())
                return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        _Type = GetCommonType(typeEnv, Left._Type.Get(), Right._Type.Get());
        if (_Type.Get() is null)
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        obj._Type = _Type;
        obj.Addr = 0;

        if (_Type.IsComplex())
        {
            Complex10 leftVal = ConvertToComplex(left);
            Complex10 rightVal = ConvertToComplex(right);

            hr = Complex80Op(leftVal, rightVal, obj.Value.Complex80Value);
        }
        else if (_Type.IsFloatingPoint())
        {
            // same operation, no matter if it's real or imaginary
            Real10 leftVal = ConvertToFloat(left);
            Real10 rightVal = ConvertToFloat(right);

            hr = Float80Op(leftVal, rightVal, obj.Value.Float80Value);
        }
        else
        {
            _ASSERT(_Type.IsIntegral());
            PromoteInPlace(left, _Type.Get());
            PromoteInPlace(right, _Type.Get());

            if (_Type.IsSigned())
            {
                int64_t leftVal = left.Value.Int64Value;
                int64_t rightVal = right.Value.Int64Value;

                hr = Int64Op(leftVal, rightVal, obj.Value.Int64Value);
            }
            else
            {
                uint64_t leftVal = left.Value.UInt64Value;
                uint64_t rightVal = right.Value.UInt64Value;

                hr = UInt64Op(leftVal, rightVal, obj.Value.UInt64Value);
            }

            PromoteInPlace(obj);
        }

        if (FAILED(hr)) // failed the operation
            return hr;

        LeftAddr = left.Addr;
        LeftValue = left.Value;

        return S_OK;
    }

protected:
    bool AllowOnlyIntegral()
    {
        return false;
    }

    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        //UNREFERENCED_PARAMETER(left);
        //UNREFERENCED_PARAMETER(right);
        //UNREFERENCED_PARAMETER(result);
        assert(false);
        return E_NOTIMPL;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        //UNREFERENCED_PARAMETER(left);
        //UNREFERENCED_PARAMETER(right);
        //UNREFERENCED_PARAMETER(result);
        assert(false);
        return E_NOTIMPL;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        //UNREFERENCED_PARAMETER(left);
        //UNREFERENCED_PARAMETER(right);
        //UNREFERENCED_PARAMETER(result);
        assert(false);
        return E_NOTIMPL;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        //UNREFERENCED_PARAMETER(left);
        //UNREFERENCED_PARAMETER(right);
        //UNREFERENCED_PARAMETER(result);
        assert(false);
        return E_NOTIMPL;
    }
}

class OrExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);

protected:
    bool AllowOnlyIntegral()
    {
        return true;
    }

    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left | right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left | right;
        return S_OK;
    }
}

class XorExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);

protected:
    bool AllowOnlyIntegral();
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left ^ right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left ^ right;
        return S_OK;
    }
}

class AndExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);

protected:
    bool AllowOnlyIntegral()
    {
        return true;
    }

    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left & right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left & right;
        return S_OK;
    }
}

// D front end only makes CmpExp and their RelExp seems deprecated
// it's the other way around here
class CmpExpr : BinExpr
{
public:
    TOK OpCode;

    this(TOK opCode, Expression left, Expression right){
        super(left, right);
        OpCode = opCode;
    }
}

class CompareExpr : BinExpr
{
public:
    //TOK OpCode;

    this(TOK opCode, Expression left, Expression right){
        super(opCode, left, right);
    }

    HRESULT Semantic(ref const EvalData evalData, ITypeEnv typeEnv, IValueBinder binder)
    {
        HRESULT hr = S_OK;

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if ((!ltype.IsScalar() && !ltype.IsSArray() && !ltype.IsDArray()
                && !ltype.IsAArray() && !ltype.IsDelegate()) || (!rtype.IsScalar()
                && !rtype.IsSArray() && !rtype.IsDArray()
                && !rtype.IsAArray() && !rtype.IsDelegate()))
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        // if one is null, then try to set it to the other's type
        if (Left.TrySetType(rtype))
            ltype = rtype;
        else if (Right.TrySetType(ltype))
            rtype = ltype;

        if (ltype.IsPointer() != rtype.IsPointer())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (ltype.IsAArray() != rtype.IsAArray())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (ltype.IsDelegate() != rtype.IsDelegate())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        // you can mix and match S- and D-array, but it can't be anything else
        if ((ltype.IsSArray() || ltype.IsDArray()) != (rtype.IsSArray() || rtype.IsDArray()))
            return E_MAGOEE_BAD_TYPES_FOR_OP;
        if (ltype.IsSArray() || ltype.IsDArray())
        {
            assert(rtype.IsSArray() || rtype.IsDArray());
            // the element types have to match
            if (!ltype.AsTypeNext().GetNext().Equals(rtype.AsTypeNext().GetNext()))
                return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        if (ltype.IsAArray())
        {
            if (!ltype.AsTypeAArray().GetElement().Equals(rtype.AsTypeAArray()
                    .GetElement()) || !ltype.AsTypeAArray().GetIndex()
                    .Equals(rtype.AsTypeAArray().GetIndex()))
                return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        // TODO: in restrictions below (like for S- and D-arrays) also include delegate and A-array, 
        //       and class (actually ptr to class)
        //       except that for delegates, "==" is the same as "is"
        switch (OpCode)
        {
        case TOKequal, TOKnotequal:
            if (ltype.IsSArray() || rtype.IsSArray()
                    || ltype.IsDArray() || rtype.IsDArray() || ltype.IsAArray() || rtype.IsAArray())
                return E_MAGOEE_BAD_TYPES_FOR_OP;
            break;

            // TODO: can you really compare a real and an imaginary?
            // we'll allow comparing signed to unsigned integrals
        case TOKlt, TOKle, TOKgt, TOKge, TOKunord, TOKlg, TOKleg, TOKule,
                TOKul, TOKuge, TOKug, TOKue:
                if (ltype.IsComplex()
                        || rtype.IsComplex() || ltype.IsSArray() || rtype.IsSArray()
                        || ltype.IsDArray() || rtype.IsDArray() || ltype.IsAArray()
                        || rtype.IsAArray() || ltype.IsDelegate() || rtype.IsDelegate()) return E_MAGOEE_BAD_TYPES_FOR_OP;
            break;
        default:
            break;
        }

        _Type = typeEnv.GetType(Tbool);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type commonType;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        if (Left._Type.IsPointer() || Left._Type.IsAArray())
        {
            obj.Value.UInt64Value = IntegerOp(OpCode, left.Value.Addr, right.Value.Addr) ? 1 : 0;
        }
        else if (Left._Type.IsSArray() || Left._Type.IsDArray())
        {
            obj.Value.UInt64Value = ArrayRelational(OpCode, left, right) ? 1 : 0;
        }
        else if (Left._Type.IsDelegate())
        {
            obj.Value.UInt64Value = DelegateRelational(OpCode, left, right) ? 1 : 0;
        }
        else
        {
            // TODO: clear this up, which way do we do it?
            static if (1)
            {
                commonType = GetCommonType(evalData.TypeEnv, left._Type.Get(), right._Type.Get());
            }
            else
            {
                if ((OpCode == TOKequal) || (OpCode == TOKnotequal)
                        || (OpCode == TOKidentity) || (OpCode == TOKnotidentity))
                    commonType = GetCommonType(typeEnv, left._Type.Get(), right._Type.Get());
                else
                    commonType = GetModCommonType(typeEnv, left._Type.Get(), right._Type.Get());
            }

            if (commonType.IsComplex())
            {
                obj.Value.UInt64Value = ComplexRelational(OpCode, commonType, left, right) ? 1 : 0;
            }
            else if (commonType.IsFloatingPoint())
            {
                obj.Value.UInt64Value = FloatingRelational(OpCode, commonType, left, right) ? 1 : 0;
            }
            else
            {
                obj.Value.UInt64Value = IntegerRelational(OpCode, commonType, left, right) ? 1 : 0;
            }
        }

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    static bool IntegerOp(T)(TOK code, T left, T right)
    {
        switch (code)
        {
        case TOK.TOKidentity, TOK.TOKequal:
            return left == right;
            break;
        case TOK.TOKnotidentity, TOK.TOKnotequal:
            return left != right;
            break;
        case TOK.TOKlt:
            return left < right;
            break;
        case TOK.TOKle:
            return left <= right;
            break;
        case TOK.TOKgt:
            return left > right;
            break;
        case TOK.TOKge:
            return left >= right;
            break;
        case TOK.TOKunord:
            return false;
        case TOK.TOKlg:
            return left != right;
        case TOK.TOKleg:
            return true;
        case TOK.TOKule:
            return left <= right;
        case TOK.TOKul:
            return left < right;
        case TOK.TOKuge:
            return left >= right;
        case TOK.TOKug:
            return left > right;
        case TOK.TOKue:
            return left == right;
        default:
            assert(false, "Relational operator not allowed on integers."w);
        }

        return false;
    }

    static bool IntegerRelational(TOK code, Type exprType, ref DataObject left, ref DataObject right)
    {
        PromoteInPlace(left, exprType);
        PromoteInPlace(right, exprType);

        if (exprType.IsSigned())
        {
            return IntegerOp(code, left.Value.Int64Value, right.Value.Int64Value);
        }
        else
        {
            return IntegerOp(code, left.Value.UInt64Value, right.Value.UInt64Value);
        }
    }

    static bool FloatingRelational(TOK code, Type exprType, ref DataObject left, ref DataObject right)
    {
        if (((leftObj._Type.IsReal() || leftObj._Type.IsIntegral())
                && rightObj._Type.IsImaginary()) || (leftObj._Type.IsImaginary()
                && (rightObj._Type.IsReal() || rightObj._Type.IsIntegral())))
        {
            rightObj.Value.Float80Value.Zero();
        }

        Real10 leftVal = ConvertToFloat(exprType, leftObj);
        Real10 rightVal = ConvertToFloat(exprType, rightObj);
        uint16_t status = Real10.Compare(leftVal, rightVal);

        return FloatingRelational(code, status);
    }

    static bool ComplexRelational(TOK code, Type exprType, ref DataObject left, ref DataObject right)
    {
        Complex10 leftVal = ConvertToComplex(exprType, leftObj);
        Complex10 rightVal = ConvertToComplex(exprType, rightObj);
        uint16_t status = Complex10.Compare(leftVal, rightVal);

        return FloatingRelational(code, status);
    }

    static bool FloatingRelational(TOK code, uint16_t status)
    {
        switch (code)
        {
        case TOK.TOKidentity, TOK.TOKequal:
            return Real10.IsEqual(status);
        case TOK.TOKnotidentity, TOK.TOKnotequal:
            return !Real10.IsEqual(status);

        case TOK.TOKlt:
            return Real10.IsLess(status);
        case TOK.TOKle:
            return Real10.IsLess(status) || Real10.IsEqual(status);
        case TOK.TOKgt:
            return Real10.IsGreater(status);
        case TOK.TOKge:
            return Real10.IsGreater(status) || Real10.IsEqual(status);

        case TOK.TOKunord:
            return Real10.IsUnordered(status);
        case TOK.TOKlg:
            return Real10.IsLess(status) || Real10.IsGreater(status);
        case TOK.TOKleg:
            return Real10.IsLess(status) || Real10.IsGreater(status) || Real10.IsEqual(status);
        case TOK.TOKule:
            return Real10.IsUnordered(status) || Real10.IsLess(status) || Real10.IsEqual(status);
        case TOK.TOKul:
            return Real10.IsUnordered(status) || Real10.IsLess(status);
        case TOK.TOKuge:
            return Real10.IsUnordered(status) || Real10.IsGreater(status) || Real10.IsEqual(status);
        case TOK.TOKug:
            return Real10.IsUnordered(status) || Real10.IsGreater(status);
        case TOK.TOKue:
            return Real10.IsUnordered(status) || Real10.IsEqual(status);
        default:
            assert(false, "Relational operator not allowed on integers."w);
        }
        return false;
    }

    static bool ArrayRelational(TOK code, ref DataObject left, ref DataObject right)
    {
        Type* leftType = leftObj._Type;
        Type* rightType = rightObj._Type;
        Address leftAddr = 0;
        dlength_t leftLen = 0;
        Address rightAddr = 0;
        dlength_t rightLen = 0;

        if (leftType.IsSArray())
        {
            leftAddr = leftObj.Addr;
            leftLen = leftType.AsTypeSArray().GetLength();
        }
        else if (leftType.IsDArray())
        {
            leftAddr = leftObj.Value.Array.Addr;
            leftLen = leftObj.Value.Array.Length;
        }

        if (rightType.IsSArray())
        {
            rightAddr = rightObj.Addr;
            rightLen = rightType.AsTypeSArray().GetLength();
        }
        else if (rightType.IsDArray())
        {
            rightAddr = rightObj.Value.Array.Addr;
            rightLen = rightObj.Value.Array.Length;
        }

        if (code == TOK.TOKidentity)
        {
            return (leftAddr == rightAddr) && (leftLen == rightLen);
        }
        else if (code == TOK.TOKnotidentity)
        {
            return (leftAddr != rightAddr) || (leftLen != rightLen);
        }

        assert(false);
        return false;
    }

    static bool DelegateRelational(TOK code, ref DataObject left, ref DataObject right)
    {
        if ((code == TOK.TOKidentity) || (code == TOK.TOKequal))
        {
            return (left.Value.Delegate.ContextAddr == right.Value.Delegate.ContextAddr)
                && (left.Value.Delegate.FuncAddr == right.Value.Delegate.FuncAddr);
        }
        else if ((code == TOK.TOKnotidentity) || (code == TOK.TOKnotequal))
        {
            return (left.Value.Delegate.ContextAddr != right.Value.Delegate.ContextAddr)
                || (left.Value.Delegate.FuncAddr != right.Value.Delegate.FuncAddr);
        }

        assert(false);
        return false;
    }
};

class EqualExpr : CompareExpr
{
public:
    this(TOK opCode, Expression left, Expression right){
        super(opCode, left, right);
    }
}

class IdentityExpr : CompareExpr
{
public:
    this(TOK opCode, Expression left, Expression right){
        super(opCode, left, right);
    }
}

class RelExpr : CompareExpr
{
public:
    this(TOK opCode, Expression left, Expression right){
        super(opCode, left, right);
    }
}

class InExpr : BinExpr
{
public:
    this(Expression left, Expression right){
        super(left, right);
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT  hr = S_OK;
        ClearEvalData();

        hr = Right.Semantic( evalData, typeEnv, binder );
        if ( FAILED( hr ) )
            return  hr;
        if ( Right.Kind != DataKind_Value )
            return  E_MAGOEE_VALUE_EXPECTED;
        if ( Right._Type  is  null )
            return  E_MAGOEE_NO_TYPE;

        Type   childType = Right._Type;
        if ( !childType.IsAArray() )
            return  E_MAGOEE_BAD_INDEX;

        ITypeNext  typeNext = Right._Type.AsTypeNext();
        assert( typeNext !is  null );
        if ( typeNext.GetNext() is  null )
            return  E_MAGOEE_BAD_INDEX;

        Type    voidType = typeEnv.GetType( Tvoid );
        if ( typeNext.GetNext().Equals( voidType ) )
            return  E_MAGOEE_BAD_TYPES_FOR_OP;

        hr = Left.Semantic( evalData, typeEnv, binder );
        if ( FAILED( hr ) )
            return  hr;
        if ( Left.Kind != DataKind_Value )
            return  E_MAGOEE_VALUE_EXPECTED;
        if ( Left._Type  is  null )
            return  E_MAGOEE_NO_TYPE;

        hr = TypeCheckAAKey( Left._Type, childType.AsTypeAArray().GetIndex() );
        if ( FAILED( hr ) )
            return  hr;

        Left.TrySetType( childType.AsTypeAArray().GetIndex() );

        hr = typeEnv.NewPointer( typeNext.GetNext(), _Type.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        Kind = DataKind_Value;
        return  S_OK;
    }
    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if ( mode == EvalMode_Address )
            return  E_MAGOEE_NO_ADDRESS;

        HRESULT      hr = S_OK;
        DataObject   array = { 0 };
        DataObject   index = { 0 };
        Address      addr = 0;

        hr = Right.Evaluate( EvalMode_Value, evalData, binder, array );
        if ( FAILED( hr ) )
            return  hr;

        hr = Left.Evaluate( EvalMode_Value, evalData, binder, index );
        if ( FAILED( hr ) )
            return  hr;

        hr = FindAAElement( array, index, Right._Type.AsTypeAArray().GetIndex(), binder, addr );
        if ( hr == E_NOT_FOUND )
            addr = 0;
        else  if ( FAILED( hr ) )
            return  hr;

        obj.Addr = 0;
        obj._Type = _Type;
        obj.Value.Addr = addr;

        return  S_OK;
    }
}

abstract class ShiftBinExpr : CombinableBinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (!Left._Type.IsIntegral() || !Right._Type.IsIntegral())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (Left._Type.GetSize() < 4)
            _Type = typeEnv.GetType(Tint32);
        else
            _Type = Left._Type;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        _ASSERT(Left._Type.IsIntegral() && Right._Type.IsIntegral());
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        uint32_t shiftAmount = cast(uint32_t) right.Value.UInt64Value;

        // can't shift all the bits out
        if (_Type.GetSize() == 8)
            shiftAmount &= 0x3F;
        else
            shiftAmount &= 0x1F;

        obj.Value.UInt64Value = IntOp(left.Value.UInt64Value, shiftAmount, _Type.Get());
        obj._Type = _Type;
        obj.Addr = 0;

        PromoteInPlace(obj);

        LeftAddr = left.Addr;
        LeftValue = left.Value;

        _ASSERT(_Type.IsIntegral());
        return S_OK;
    }

protected:
    abstract uint64_t IntOp(uint64_t left, uint32_t right, ref Type type);
}

class ShiftLeftExpr : ShiftBinExpr
{
public:
    this(Expression left, Expression right)
    {
        super(left, right);
    }

protected:
    uint64_t IntOp(uint64_t left, uint32_t right, ref Type type)
    {
        //UNREFERENCED_PARAMETER( type );
        return left << right;
    }
}

class ShiftRightExpr : ShiftBinExpr
{
public:
    this(Expression left, Expression right)
    {
        super(left, right);
    }

protected:
    uint64_t IntOp(uint64_t left, uint32_t right, ref Type type)
    {
        // C, C++, C# behavior
        // the original value in its original size was already sign or zero extended to 64 bits
        if (type.IsSigned())
            return (cast(int64_t) left) >> right;
        else
            return (cast(uint64_t) left) >> right;
    }
}

class UShiftRightExpr : ShiftBinExpr
{
public:
    this(Expression left, Expression right)
    {
        super(left, right);
    }

protected:
    uint64_t IntOp(uint64_t left, uint32_t right, ref Type type)
    {
        switch (type.GetBackingTy())
        {
        case Tint8, Tuns8:
            return (cast(uint8_t) left) >> right;
        case Tint16, Tuns16:
            return (cast(uint16_t) left) >> right;
        case Tint32, Tuns32:
            return (cast(uint32_t) left) >> right;
        case Tint64, Tuns64:
            return (cast(uint64_t) left) >> right;
        default:
            return 0;
        }
    }
}

class AddExpr : ArithmeticBinExpr
{
public: 
    this(Expression left, Expression right){
        super(left,right);
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if (ltype.IsPointer())
        {
            if (!rtype.IsIntegral() || (ltype.AsTypeNext().GetNext() is null))
                return E_MAGOEE_BAD_TYPES_FOR_OP;

            _Type = ltype;
        }
        else if (rtype.IsPointer())
        {
            if (!ltype.IsIntegral() || (rtype.AsTypeNext().GetNext() is null))
                return E_MAGOEE_BAD_TYPES_FOR_OP;

            _Type = rtype;
        }
        else
        {
            _Type = GetCommonType(typeEnv, Left._Type, Right._Type);
            if (_Type is null)
                return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        Type* ltype = Left._Type;
        Type* rtype = Right._Type;

        if ((ltype.IsImaginary() && (rtype.IsReal() || rtype.IsIntegral()))
                || ((ltype.IsReal() || ltype.IsIntegral()) && rtype.IsImaginary()))
        {
            return EvaluateMakeComplex(mode, evalData, binder, obj);
        }
        else if (_Type.IsPointer())
        {
            return EvaluatePtrAdd(mode, evalData, binder, obj);
        }
        else
        {
            return ArithmeticBinExpr.Evaluate(mode, evalData, binder, obj);
        }
    }

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left + right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left + right;
        return S_OK;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        result.Add(left, right);
        return S_OK;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        result.Add(left, right);
        return S_OK;
    }

private:
    HRESULT EvaluateMakeComplex(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type ltype = Left._Type.Get();

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        if (ltype.IsReal() || ltype.IsIntegral())
        {
            Real10 y = ConvertToFloat(left);
            obj.Value.Complex80Value.RealPart = y;
            obj.Value.Complex80Value.ImaginaryPart = right.Value.Float80Value;
        }
        else
        {
            Real10 y = ConvertToFloat(right);
            obj.Value.Complex80Value.RealPart = y;
            obj.Value.Complex80Value.ImaginaryPart = left.Value.Float80Value;
        }

        // TODO: check all of this
        // if we're dealing with a += b, where ifloat a, float b; or float a, ifloat b
        // then that's an illegal operation, we can't return an address for the left side here,
        // we shouldn't have gotten this far, and Semantic should have caught that
        assert(LeftAddr == 0);

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    HRESULT EvaluatePtrAdd(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type* ltype = Left._Type.Get();

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        Type pointed = _Type.AsTypeNext().GetNext();
        uint32_t size = pointed.GetSize();
        doffset_t offset = 0;
        Address addr = 0;

        if (ltype.IsPointer())
        {
            addr = left.Value.Addr;
            offset = right.Value.Int64Value;

            LeftAddr = left.Addr;
            LeftValue = left.Value;
        }
        else
        {
            addr = right.Value.Addr;
            offset = left.Value.Int64Value;

            // TODO: you can't do (integral += pointer), so check for that somewhere else
            _ASSERT(LeftAddr == 0);
        }

        obj.Value.Addr = addr + (size * offset);

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
}

class MinExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if (ltype.IsPointer() && rtype.IsPointer())
        {
            if (!ltype.Equals(rtype))
                return E_MAGOEE_BAD_TYPES_FOR_OP;
            if ((ltype.AsTypeNext().GetNext() is null) || (rtype.AsTypeNext().GetNext() is null))
                return E_MAGOEE_BAD_TYPES_FOR_OP;

            _Type = typeEnv.GetAliasType(Tptrdiff_t);
        }
        else if (ltype.IsPointer())
        {
            if (!rtype.IsIntegral() || (ltype.AsTypeNext().GetNext() is null))
                return E_MAGOEE_BAD_TYPES_FOR_OP;

            _Type = ltype;
        }
        else
        {
            // (int - ptr) will make this fail, as it should
            _Type = GetCommonType(typeEnv, Left._Type, Right._Type);
            if (_Type is null)
                return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if ((ltype.IsImaginary() && (rtype.IsReal() || rtype.IsIntegral()))
                || ((ltype.IsReal() || ltype.IsIntegral()) && rtype.IsImaginary()))
        {
            return EvaluateMakeComplex(mode, evalData, binder, obj);
        }
        else if (ltype.IsImaginary() && rtype.IsComplex())
        {
            return EvaluateSpecialCase(mode, evalData, binder, obj);
        }
        else if (ltype.IsPointer() && rtype.IsPointer())
        {
            return EvaluatePtrDiff(mode, evalData, binder, obj);
        }
        else if (_Type.IsPointer())
        {
            return EvaluatePtrSub(mode, evalData, binder, obj);
        }
        else
        {
            return ArithmeticBinExpr.Evaluate(mode, evalData, binder, obj);
        }
    }

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left - right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left - right;
        return S_OK;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        result.Sub(left, right);
        return S_OK;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        result.Sub(left, right);
        return S_OK;
    }

private:
    HRESULT EvaluateMakeComplex(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type ltype = Left._Type.Get();

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        if (ltype.IsReal() || ltype.IsIntegral())
        {
            Real10 y = ConvertToFloat(left);
            obj.Value.Complex80Value.RealPart = y;
            obj.Value.Complex80Value.ImaginaryPart.Negate(right.Value.Float80Value);
        }
        else
        {
            Real10 y = ConvertToFloat(right);
            obj.Value.Complex80Value.RealPart.Negate(y);
            obj.Value.Complex80Value.ImaginaryPart = left.Value.Float80Value;
        }

        // TODO: check all of this
        // if we're dealing with a -= b, where ifloat a, float b; or float a, ifloat b
        // then that's an illegal operation, we can't return an address for the left side here,
        // we shouldn't have gotten this far, and Semantic should have caught that
        assert(LeftAddr == 0);

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    HRESULT EvaluatePtrSub(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        Type pointed = _Type.AsTypeNext().GetNext();
        uint32_t size = pointed.GetSize();
        doffset_t offset = 0;
        Address addr = 0;

        _ASSERT(Left._Type.IsPointer());
        _ASSERT(!Right._Type.IsPointer());

        addr = left.Value.Addr;
        offset = right.Value.Int64Value;

        LeftAddr = left.Addr;
        LeftValue = left.Value;

        obj.Value.Addr = addr - (size * offset);

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    HRESULT EvaluatePtrDiff(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        Type pointed = left._Type.AsTypeNext().GetNext();
        uint32_t size = pointed.GetSize();

        assert(Left._Type.IsPointer());
        assert(Right._Type.IsPointer());

        LeftAddr = left.Addr;
        LeftValue = left.Value;

        obj.Value.Int64Value = (left.Value.Addr - right.Value.Addr);
        obj.Value.Int64Value /= size; // make sure it's a signed divide

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    HRESULT EvaluateSpecialCase(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        assert(Left._Type.IsImaginary());
        assert(Right._Type.IsComplex());

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Complex10 & c = obj.Value.Complex80Value;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        c.RealPart.Negate(right.Value.Complex80Value.RealPart);
        c.ImaginaryPart.Sub(left.Value.Float80Value, right.Value.Complex80Value.ImaginaryPart);

        // obj.Value.Complex80Value already assigned to, because it's been aliased with c
        LeftAddr = left.Addr;
        LeftValue = left.Value;

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
}

class CatExpr : CombinableBinExpr
{
public:
    this(Expression left, Expression right);
};

class MulExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        _Type = GetMulCommonType(typeEnv, Left._Type, Right._Type);
        if (_Type is null)
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;
        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if (((ltype.IsImaginary() || ltype.IsReal() || ltype.IsIntegral())
                && rtype.IsComplex()) || (ltype.IsComplex()
                && (rtype.IsImaginary() || rtype.IsReal() || rtype.IsIntegral())))
        {
            return EvaluateShortcutComplex(mode, evalData, binder, obj);
        }

        hr = ArithmeticBinExpr.Evaluate(mode, evalData, binder, obj);
        if (FAILED(hr))
            return hr;

        if (ltype.IsImaginary() && rtype.IsImaginary())
        {
            // (a + bi)(c + di) = (0 + bi)(0 + di) = bi * di = -b*d
            obj.Value.Float80Value.Negate(obj.Value.Float80Value);
        }

        // ArithmeticBinExpr::Evaluate took care of the rest
        return S_OK;
    }

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        result = left * right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        result = left * right;
        return S_OK;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        result.Mul(left, right);
        return S_OK;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        result.Mul(left, right);
        return S_OK;
    }

private:
    /// For the (imaginary * complex) or (complex * imaginary) cases, I prefer a 
    /// way that doesn't depend on the order of the arguments (where the NaN is).
    /// But, this is how DMD does it.
    HRESULT EvaluateShortcutComplex(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type ltype = Left._Type;
        Type rtype = Right._Type;
        Complex10 & c = obj.Value.Complex80Value;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        if (ltype.IsReal() || ltype.IsIntegral())
        {
            Real10 r = ConvertToFloat(left);
            c.RealPart.Mul(r, right.Value.Complex80Value.RealPart);
            c.ImaginaryPart.Mul(r, right.Value.Complex80Value.ImaginaryPart);
        }
        else if (ltype.IsImaginary())
        {
            Real10 r = ConvertToFloat(left);
            Real10 nri;
            nri.Negate(right.Value.Complex80Value.ImaginaryPart);
            c.RealPart.Mul(r, nri);
            c.ImaginaryPart.Mul(r, right.Value.Complex80Value.RealPart);
        }
        else if (rtype.IsReal() || rtype.IsIntegral())
        {
            Real10 r = ConvertToFloat(right);
            c.RealPart.Mul(r, left.Value.Complex80Value.RealPart);
            c.ImaginaryPart.Mul(r, left.Value.Complex80Value.ImaginaryPart);
        }
        else if (rtype.IsImaginary())
        {
            Real10 r = ConvertToFloat(right);
            Real10 nli;
            nli.Negate(left.Value.Complex80Value.ImaginaryPart);
            c.RealPart.Mul(r, nli);
            c.ImaginaryPart.Mul(r, left.Value.Complex80Value.RealPart);
        }
        else
        {
            assert(false);
            return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        // obj.Value.Complex80Value already assigned to, because it's been aliased with c
        LeftAddr = left.Addr;
        LeftValue = left.Value;

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
};

class DivExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        _Type = GetMulCommonType(typeEnv, Left._Type, Right._Type);
        if (_Type.Get() is null)
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;
        Type ltype = Left._Type;
        Type rtype = Right._Type;

        if (ltype.IsComplex() && (rtype.IsReal() || rtype.IsIntegral() || rtype.IsImaginary()))
        {
            return EvaluateShortcutComplex(mode, evalData, binder, obj);
        }

        hr = ArithmeticBinExpr.Evaluate(mode, evalData, binder, obj);
        if (FAILED(hr))
            return hr;

        if ((ltype.IsReal() || ltype.IsIntegral()) && rtype.IsImaginary())
        {
            // (a + bi)(c + di) = (a + 0i)(0 + di) = -a/d
            obj.Value.Float80Value.Negate(obj.Value.Float80Value);
        }

        // ArithmeticBinExpr::Evaluate took care of the rest
        return S_OK;
    }

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        if (right == 0)
            return E_MAGOEE_DIVIDE_BY_ZERO;

        result = left / right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        if (right == 0)
            return E_MAGOEE_DIVIDE_BY_ZERO;

        result = left / right;
        return S_OK;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        result.Div(left, right);
        return S_OK;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        result.Div(left, right);
        return S_OK;
    }

private:
    HRESULT EvaluateShortcutComplex(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        assert(Left._Type.IsComplex());

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Type* rtype = Right._Type.Get();
        Complex10 & c = obj.Value.Complex80Value;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        if (rtype.IsReal() || rtype.IsIntegral())
        {
            Real10 r = ConvertToFloat(right);
            c.RealPart.Div(left.Value.Complex80Value.RealPart, r);
            c.ImaginaryPart.Div(left.Value.Complex80Value.ImaginaryPart, r);
        }
        else if (rtype.IsImaginary())
        {
            Real10 r = right.Value.Float80Value;
            Real10 ncleft;
            c.RealPart.Div(left.Value.Complex80Value.ImaginaryPart, r);
            ncleft.Negate(left.Value.Complex80Value.RealPart);
            c.ImaginaryPart.Div(ncleft, r);
        }
        else
        {
            assert(false);
            return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        // obj.Value.Complex80Value already assigned to, because it's been aliased with c
        LeftAddr = left.Addr;
        LeftValue = left.Value;

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
};

class ModExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = SemanticVerifyChildren(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;

        if (Right._Type.IsComplex())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = GetModCommonType(typeEnv, Left._Type.Get(), Right._Type.Get());
        if (_Type.Get() is null)
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        Type* ltype = Left._Type.Get();
        Type* rtype = Right._Type.Get();

        if (ltype.IsComplex() && (rtype.IsReal() || rtype.IsIntegral() || rtype.IsImaginary()))
        {
            return EvaluateShortcutComplex(mode, evalData, binder, obj);
        }

        return ArithmeticBinExpr.Evaluate(mode, evalData, binder, obj);
    }

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        if (right == 0)
            return E_MAGOEE_DIVIDE_BY_ZERO;

        result = left % right;
        return S_OK;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        if (right == 0)
            return E_MAGOEE_DIVIDE_BY_ZERO;

        result = left % right;
        return S_OK;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        result.Rem(left, right);
        return S_OK;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        //UNREFERENCED_PARAMETER( left );
        //UNREFERENCED_PARAMETER( right );
        //UNREFERENCED_PARAMETER( result );
        assert(false, "Function not implemented!");
        return E_NOTIMPL;
    }

private:
    HRESULT EvaluateShortcutComplex(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        _ASSERT(Left._Type.IsComplex() && !Right._Type.IsComplex());

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject left = {0};
        DataObject right = {0};
        Complex10 & c = obj.Value.Complex80Value;

        hr = Left.Evaluate(EvalMode_Value, evalData, binder, left);
        if (FAILED(hr))
            return hr;

        hr = Right.Evaluate(EvalMode_Value, evalData, binder, right);
        if (FAILED(hr))
            return hr;

        Real10 r = ConvertToFloat(right);
        c.RealPart.Rem(left.Value.Complex80Value.RealPart, r);
        c.ImaginaryPart.Rem(left.Value.Complex80Value.ImaginaryPart, r);

        // obj.Value.Complex80Value already assigned to, because it's been aliased with c
        LeftAddr = left.Addr;
        LeftValue = left.Value;

        assert(_Type.IsComplex());
        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
};

class PowExpr : ArithmeticBinExpr
{
public:
    this(Expression left, Expression right);

protected:
    HRESULT UInt64Op(uint64_t left, uint64_t right, ref uint64_t result)
    {
        // TODO:
        //UNREFERENCED_PARAMETER( left );
        //UNREFERENCED_PARAMETER( right );
        //UNREFERENCED_PARAMETER( result );
        assert(false, "Unimplemented function!");
        return E_NOTIMPL;
    }

    HRESULT Int64Op(int64_t left, int64_t right, ref int64_t result)
    {
        // TODO:
        //UNREFERENCED_PARAMETER( left );
        //UNREFERENCED_PARAMETER( right );
        //UNREFERENCED_PARAMETER( result );
        assert(false, "Unimplemented function!");
        return E_NOTIMPL;
    }

    HRESULT Float80Op(ref const Real10 left, ref const Real10 right, ref Real10 result)
    {
        // TODO:
        //UNREFERENCED_PARAMETER( left );
        //UNREFERENCED_PARAMETER( right );
        //UNREFERENCED_PARAMETER( result );
        assert(false, "Unimplemented function!");
        return E_NOTIMPL;
    }

    HRESULT Complex80Op(ref const Complex10 left, ref const Complex10 right, ref Complex10 result)
    {
        // TODO:
        //UNREFERENCED_PARAMETER( left );
        //UNREFERENCED_PARAMETER( right );
        //UNREFERENCED_PARAMETER( result );
        assert(false, "Unimplemented function!");
        return E_NOTIMPL;
    }
};

class AddressOfExpr : Expression
{
public:
    RefPtr!(Expression) Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        hr = typeEnv.NewPointer(Child._Type, _Type.Ref());
        if (FAILED(hr))
            return hr;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject pointed = {0};

        hr = Child.Evaluate(EvalMode_Address, evalData, binder, pointed);
        if (FAILED(hr))
            return hr;

        if (pointed.Addr == 0)
            return E_MAGOEE_NO_ADDRESS;

        obj._Type = _Type;
        obj.Value.Addr = pointed.Addr;
        return S_OK;
    }
}

class PointerExpr : Expression
{
public:
    Expression Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!Child._Type.IsPointer() && !Child._Type.IsSArray() && !Child._Type.IsDArray())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (Child._Type.IsReference())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        assert(Child._Type.AsTypeNext() !is null);
        Type voidType = typeEnv.GetType(Tvoid);
        if (Child._Type.AsTypeNext().GetNext().Equals(voidType))
            return E_MAGOEE_BAD_TYPES_FOR_OP;
        if (Child._Type.AsTypeNext().GetNext().IsFunction())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = Child._Type.AsTypeNext().GetNext();
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;
        DataObject pointer = {0};

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, pointer);
        if (FAILED(hr))
            return hr;

        obj._Type = _Type;

        if (Child._Type.IsPointer())
            obj.Addr = pointer.Value.Addr;
        else if (Child._Type.IsSArray())
            obj.Addr = pointer.Addr;
        else if (Child._Type.IsDArray())
            obj.Addr = pointer.Value.Array.Addr;
        else
            assert(false);

        if (mode == EvalMode_Value)
        {
            hr = binder.GetValue(obj.Addr, _Type, obj.Value);
            if (FAILED(hr))
                return hr;
        }

        return S_OK;
    }
}

class NegateExpr : Expression
{
public:
    Expression Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!Child._Type.IsIntegral() && !Child._Type.IsFloatingPoint())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = Child._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        HRESULT hr = S_OK;

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, obj);
        if (FAILED(hr))
            return hr;

        if (_Type.IsComplex())
        {
            obj.Value.Complex80Value.Negate(obj.Value.Complex80Value);
        }
        else if (_Type.IsFloatingPoint())
        {
            obj.Value.Float80Value.Negate(obj.Value.Float80Value);
        }
        else if (_Type.IsIntegral())
        {
            obj.Value.UInt64Value = -obj.Value.Int64Value;

            PromoteInPlace(obj);
        }
        else
        {
            assert(false);
            return E_MAGOEE_BAD_TYPES_FOR_OP;
        }

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

}

class UnaryAddExpr : Expression
{
public:
    Expression Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!Child._Type.IsIntegral() && !Child._Type.IsFloatingPoint())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = Child._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        return Child.Evaluate(mode, evalData, binder, obj);
    }
}

class NotExpr : Expression
{
public:
    Expression Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!Child._Type.CanImplicitCastToBool())
            return E_MAGOEE_BAD_BOOL_CAST;

        _Type = typeEnv.GetType(Tbool);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject childObj = {0};

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, childObj);
        if (FAILED(hr))
            return hr;

        obj.Value.UInt64Value = ConvertToBool(childObj) ? 0 : 1;

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }
};

class BitNotExpr : Expression
{
public:
    Expression Child;

    this(Expression child);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        if (!Child._Type.IsIntegral())
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        _Type = Child._Type;
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, obj);
        if (FAILED(hr))
            return hr;

        obj.Value.UInt64Value = ~obj.Value.UInt64Value;

        obj._Type = _Type;
        obj.Addr = 0;

        PromoteInPlace(obj);

        return S_OK;
    }
}

class NewExpr : Expression
{
public:
    this(){

    }
}

class DeleteExpr : Expression
{
public:
    Expression Child;

    this(Expression child){
        this.Child = child;
    }
}

class CastExpr : Expression
{
public:
    Expression Child;
    MOD FlagsTo;
    Type _TypeTo;

    this(Expression child, MOD flags)
    {
        this.Child = child;
        this.FlagsTo = flags;
    }

    this(Expression child, Type* type)
    {
        this.Child = child;
        this._TypeTo = type;
    }

    HRESULT Semantic(ref const EvalData evalData, ITypeEnv* typeEnv, IValueBinder* binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        Type childType = Child._Type;

        if (_TypeTo !is null)
        {
            Type resolvedTypeTo = _TypeTo.Resolve(evalData, typeEnv, binder);

            if (resolvedTypeTo is null)
                return E_MAGOEE_TYPE_RESOLVE_FAILED;

            if (Child.TrySetType(resolvedTypeTo))
            {
                _Type = resolvedTypeTo;
            }
            else if (CanCast(childType, resolvedTypeTo))
            {
                _Type = resolvedTypeTo;
            }
            else
                return E_MAGOEE_BAD_CAST;
        }
        else if (childType.Mod == FlagsTo)
        {
            // no change
            _Type = childType;
        }
        else
        {
            switch (FlagsTo & (MODshared | MODconst))
            {
            case MODshared | MODconst:
                _Type = childType.MakeSharedConst();
                break;
            case MODconst:
                _Type = childType.MakeConst();
                break;
            case MODshared:
                _Type = childType.MakeShared();
                break;
            default:
                if ((FlagsTo & MODinvariant) == MODinvariant)
                    _Type = childType.MakeInvariant();
                else
                    _Type = childType.MakeMutable();
                break;
            }
        }

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        HRESULT hr = S_OK;
        DataObject childObj = {0};

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, childObj);
        if (FAILED(hr))
            return hr;

        obj._Type = _Type;

        //      it's not an l-value unless *casting to original type* and child was an l-value
        //      the point is that we're saying it's an r-value only, even though it could be an l-value

        // ***  But for simplicity, we'll leave this as an r-value.
        //      Note that we're not a NamingExpression so we don't have a Declaration field, 
        //      for those l-values that don't have addresses.
        assert(obj.Addr == 0);

        AssignValue(childObj, obj);

        return S_OK;
    }
    /// A := B
    ///      B-> integral    floating    pointer
    /// integral X           X           X
    /// floating X           X           X
    /// pointer  X           X           X
    static bool CanImplicitCast(ref Type source, ref Type dest)
    {
        // even though the D langauge doesn't allow the assignment of a float to a pointer,
        // we'll allow it here to for our own simplicity and convenience, and to 
        // match VC++'s debugger.
        // For reference, DMD gives this error when assigning a float to a pointer:
        // Real D: Error: cannot implicitly convert expression (99.9) of type double to int*

        return CanCast(source, dest);
    }
    /// TODO: is this all?
    /// down to across
    ///          integral    floating    pointer
    /// integral X           X           X
    /// floating X           X           
    /// pointer  X           X           X
    static bool CanCast(Type* source, Type* dest)
    {
        if ((dest.IsIntegral() && source.IsIntegral()) || (dest.IsIntegral()
                && source.IsFloatingPoint()) || (dest.IsIntegral() && source.IsPointer())

                || (dest.IsFloatingPoint() && source.IsIntegral()) || (dest.IsFloatingPoint()
                    && source.IsFloatingPoint()) || (dest.IsFloatingPoint()
                    && source.IsPointer()) || (dest.IsPointer() && source.IsIntegral())
                || (dest.IsPointer() && source.IsPointer()) || (dest.IsPointer()
                    && source.IsFloatingPoint()) || (dest.IsPointer() && source.IsSArray())
                || (dest.IsPointer() && source.IsDArray()) || (dest.IsPointer()
                    && source.IsAArray()) || (dest.IsPointer() && source.IsDelegate())

                || (dest.IsDArray() && source.IsSArray()) || (dest.IsDArray()
                    && source.IsDArray()) || (dest.IsBool() && source.IsSArray())
                || (dest.IsBool() && source.IsDArray()) || (dest.IsBool()
                    && source.IsAArray()) || (dest.IsBool() && source.IsDelegate()))
            return true;

        return false;
    }

    static void AssignValue(ref const DataObject source, ref DataObject dest)
    {
        Type destType = dest._Type;
        Type srcType = source._Type;

        if (destType.IsBool())
        {
            dest.Value.UInt64Value = ConvertToBool(source) ? 1 : 0;
        }
        else if (destType.IsComplex())
        {
            dest.Value.Complex80Value = ConvertToComplex(source);
        }
        else if (destType.IsImaginary())
        {
            if (srcType.IsComplex())
            {
                dest.Value.Float80Value = source.Value.Complex80Value.ImaginaryPart;
            }
            else if (srcType.IsImaginary())
            {
                dest.Value.Float80Value = source.Value.Float80Value;
            }
            else
            {
                assert(srcType.IsPointer() || srcType.IsIntegral() || srcType.IsReal());

                dest.Value.Float80Value.Zero();
            }
        }
        else if (destType.IsReal())
        {
            if (srcType.IsComplex())
            {
                dest.Value.Float80Value = source.Value.Complex80Value.RealPart;
            }
            else if (srcType.IsImaginary())
            {
                dest.Value.Float80Value.Zero();
            }
            else if (srcType.IsReal())
            {
                dest.Value.Float80Value = source.Value.Float80Value;
            }
            else if (srcType.IsIntegral())
            {
                if (srcType.IsSigned())
                    dest.Value.Float80Value.FromInt64(source.Value.Int64Value);
                else
                    dest.Value.Float80Value.FromUInt64(source.Value.UInt64Value);
            }
            else
            {
                assert(srcType.IsPointer());

                dest.Value.Float80Value.FromUInt64(source.Value.Addr);
            }
        }
        else if (destType.IsIntegral())
        {
            if (srcType.IsComplex())
            {
                if ((destType.GetSize() == 8) && !destType.IsSigned())
                    dest.Value.UInt64Value = source.Value.Complex80Value.RealPart.ToUInt64();
                else if ((destType.GetSize() == 8) || (!destType.IsSigned()
                        && destType.GetSize() == 4))
                    dest.Value.Int64Value = source.Value.Complex80Value.RealPart.ToInt64();
                else if ((destType.GetSize() == 4) || (!destType.IsSigned()
                        && destType.GetSize() == 2))
                    dest.Value.Int64Value = source.Value.Complex80Value.RealPart.ToInt32();
                else
                    dest.Value.Int64Value = source.Value.Complex80Value.RealPart.ToInt16();
            }
            else if (srcType.IsImaginary())
            {
                dest.Value.Int64Value = 0;
            }
            else if (srcType.IsReal())
            {
                if ((destType.GetSize() == 8) && !destType.IsSigned())
                    dest.Value.UInt64Value = source.Value.Float80Value.ToUInt64();
                else if ((destType.GetSize() == 8) || (!destType.IsSigned()
                        && destType.GetSize() == 4))
                    dest.Value.Int64Value = source.Value.Float80Value.ToInt64();
                else if ((destType.GetSize() == 4) || (!destType.IsSigned()
                        && destType.GetSize() == 2))
                    dest.Value.Int64Value = source.Value.Float80Value.ToInt32();
                else
                    dest.Value.Int64Value = source.Value.Float80Value.ToInt16();
            }
            else if (srcType.IsIntegral())
            {
                dest.Value.UInt64Value = source.Value.UInt64Value;
            }
            else
            {
                assert(srcType.IsPointer());
                dest.Value.UInt64Value = source.Value.Addr;
            }

            PromoteInPlace(dest);
        }
        else if (destType.IsPointer())
        {
            if (srcType.IsComplex())
            {
                dest.Value.Addr = source.Value.Complex80Value.RealPart.ToUInt64();
            }
            else if (srcType.IsImaginary())
            {
                dest.Value.Addr = 0;
            }
            else if (srcType.IsReal())
            {
                dest.Value.Addr = source.Value.Float80Value.ToUInt64();
            }
            else if (srcType.IsIntegral())
            {
                dest.Value.Addr = source.Value.UInt64Value;
            }
            else if (srcType.IsPointer())
            {
                Type nextSrc = srcType.AsTypeNext().GetNext();
                Type nextDest = destType.AsTypeNext().GetNext();
                Address srcAddr = source.Value.Addr;

                if ((nextSrc !is null) && (nextSrc.AsTypeStruct() !is null)
                        && (nextDest !is null) && (nextDest.AsTypeStruct() !is null))
                {
                    int offset = 0;

                    if (nextSrc.AsTypeStruct().GetBaseClassOffset(nextDest, offset))
                    {
                        srcAddr += offset;
                    }
                    else if (nextDest.AsTypeStruct().GetBaseClassOffset(nextSrc, offset))
                    {
                        srcAddr -= offset;
                    }
                }

                dest.Value.Addr = srcAddr;
            }
            else if (srcType.IsDArray())
            {
                dest.Value.Addr = source.Value.Array.Addr;
            }
            else if (srcType.IsSArray())
            {
                dest.Value.Addr = source.Addr;
            }
            else if (srcType.IsAArray())
            {
                dest.Value.Addr = source.Value.Addr;
            }
            else if (srcType.IsDelegate())
            {
                dest.Value.Addr = source.Value.Delegate.ContextAddr;
            }
            else
                assert(false);

            if (destType.GetSize() == 4)
                dest.Value.Addr &= 0xFFFFFFFF;
        }
        else if (destType.IsDArray())
        {
            ConvertToDArray(source, dest);
        }
        else
            assert(false);
    }
}

class NamingExpression : Expression
{
public:
    Declaration Decl;

    NamingExpression AsNamingExpression()
    {
        return this;
    }

protected:
    void ClearEvalData()
    {
        Expression.ClearEvalData();
        Decl = null;
    }
}

class DotExpr : NamingExpression
{
    SharedString mNamePath;
    // the length of the name path from the root to this node
    // we need to assign this value right after we append to the name path
    // because our parent might append its own name and change the length
    uint32_t mNamePathLen;

public:
    Expression Child;
    Utf16String Id;
    StdProperty Property;

    this(Expression child, Utf16String id);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();
        Property = null;

        SharedString namePath;
        hr = MakeName(0, namePath);
        if (FAILED(hr) && (hr != E_MAGOEE_SYMBOL_NOT_FOUND))
            return hr;

        if (SUCCEEDED(hr))
        {
            const(wchar_t)* name = mNamePath.GetCut(mNamePathLen);

            binder.FindObject(name, Decl.Ref());

            mNamePath.ReleaseCut();
        }

        if (Decl is null)
        {
            hr = Child.Semantic(evalData, typeEnv, binder);
            if (FAILED(hr))
                return hr;

            // if child is value or type
            if (Child.Kind != DataKind_Declaration)
            {
                ITypeStruct* t = null;

                if (Child._Type is null)
                    return E_MAGOEE_NO_TYPE;

                if (Child._Type.AsTypeStruct() !is null)
                    t = Child._Type.AsTypeStruct();
                else if (Child._Type.IsPointer() && (Child._Type.AsTypeNext()
                        .GetNext().AsTypeStruct() !is null))
                    t = Child._Type.AsTypeNext().GetNext().AsTypeStruct();

                if (t !is null)
                {
                    Decl = t.FindObject(Id.Str);
                }
            }
            else
            {
                NamingExpression namer = Child.AsNamingExpression();
                if (namer !is null)
                {
                    assert(namer.Decl !is null);
                    namer.Decl.FindObject(Id.Str, Decl.Ref());
                }
            }
        }

        if (Decl !is null)
        {
            Decl.GetType(_Type.Ref());

            if (Decl.IsVar() || Decl.IsConstant() || Decl.IsFunction())
            {
                Kind = DataKind_Value;
            }
            else if (Decl.IsField())
            {
                if (Child.Kind == DataKind_Value)
                    Kind = DataKind_Value;
                else
                    Kind = DataKind_Declaration;
            }
            else
            {
                Kind = DataKind_Declaration;
            }
        }
        else
        {
            hr = SemanticStdProperty(typeEnv);
            if (FAILED(hr))
                return hr;
        }

        if ((Kind == DataKind_Value) && (_Type is null))
            return E_MAGOEE_NO_TYPE;

        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT hr = S_OK;

        if (Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;

        obj._Type = _Type;

        if (Property !is null)
        {
            if (mode == EvalMode_Address)
                return E_MAGOEE_NO_ADDRESS;

            return EvaluateStdProperty(evalData, binder, obj);
        }

        if (Decl.IsField() || _Type.IsDelegate())
        {
            // apply the parent's address
            int offset = 0;
            DataObject parent = {0};

            hr = Child.Evaluate(EvalMode_Value, evalData, binder, parent);
            if (FAILED(hr))
                return hr;

            // as opposed to a pointer or reference to the class
            if (parent._Type.AsTypeStruct() !is null)
                parent.Value.Addr = parent.Addr;

            if (parent.Value.Addr == 0)
                return E_FAIL;

            if (_Type.IsDelegate())
            {
                if (!Decl.GetAddress(obj.Value.Delegate.FuncAddr))
                    return E_MAGOEE_NO_ADDRESS;

                obj.Value.Delegate.ContextAddr = parent.Value.Addr;
                return S_OK;
            }
            else
            {
                if (!Decl.GetOffset(offset))
                    return E_FAIL;

                obj.Addr = parent.Value.Addr + offset;
            }
        }
        // else is some other value: constant, var
        else
            Decl.GetAddress(obj.Addr);

        if (mode == EvalMode_Address)
        {
            if (obj.Addr != 0)
                return S_OK;

            return E_MAGOEE_NO_ADDRESS;
        }

        // evaluate a scalar we might have
        return Eval(binder, Decl, obj);
    }

protected:
    HRESULT MakeName(uint32_t capacity, ref SharedString namePath);

private:
    HRESULT SemanticStdProperty(ref ITypeEnv typeEnv)
    {
        StdProperty prop = null;
        Declaration childDecl;
        Type childType;

        if (Child.AsNamingExpression() !is null)
            childDecl = Child.AsNamingExpression().Decl;

        childType = Child._Type;

        if ((childDecl !is null) && childDecl.IsField())
        {
            prop = FindFieldProperty(Id.Str);
        }

        if ((prop is null) && (Child._Type !is null))
        {
            prop = Child._Type.FindProperty(Id.Str);
        }

        if (prop is null)
            return E_MAGOEE_SYMBOL_NOT_FOUND;

        if (!prop.GetType(typeEnv, childType, childDecl, _Type.Ref()))
            return E_FAIL;

        Property = prop;

        assert(_Type !is null);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT EvaluateStdProperty(ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        assert(Property !is null);

        HRESULT hr = S_OK;
        Declaration childDecl;
        Type childType;

        if (Child.AsNamingExpression() !is null)
            childDecl = Child.AsNamingExpression().Decl;

        childType = Child._Type;

        if (Property.UsesParentValue())
        {
            DataObject parent = {0};

            hr = Child.Evaluate(EvalMode_Value, evalData, binder, parent);
            if (FAILED(hr))
                return hr;

            Property.GetValue(Child._Type, childDecl, parent.Value, obj.Value);
        }
        else
        {
            Property.GetValue(Child._Type, childDecl, obj.Value);
        }

        return S_OK;
    }
}

class DotTemplateInstanceExpr : NamingExpression
{
    SharedString mNamePath;
    // the length of the name path from the root to this node
    // we need to assign this value right after we append to the name path
    // because our parent might append its own name and change the length
    uint32_t mNamePathLen;

public:
    Expression Child;
    TemplateInstancePart Instance;

    this(Expression child, TemplateInstancePart instance);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT  hr = S_OK;
        std.wstring     fullId;
        ClearEvalData();

        SharedString    namePath;
        hr = MakeName( 0, namePath );
        if ( FAILED( hr ) && (hr != E_MAGOEE_SYMBOL_NOT_FOUND) )
            return  hr;

        if ( SUCCEEDED( hr ) )
        {
            const(wchar_t) *  name = mNamePath.GetCut( mNamePathLen );

            binder.FindObject( name, Decl.Ref() );

            mNamePath.ReleaseCut();
        }

        if ( Decl  is  null )
        {
            hr = Child.Semantic( evalData, typeEnv, binder );
            if ( FAILED( hr ) )
                return  hr;

            fullId.append( Instance.Id.Str );
            fullId.append( Instance.ArgumentString.Str );

            // if child is value or type
            if ( Child.Kind != DataKind_Declaration )
            {
                ITypeStruct* t = null;

                if ( Child._Type  is  null )
                    return  E_MAGOEE_NO_TYPE;

                if ( Child._Type.AsTypeStruct() !is  null )
                    t = Child._Type.AsTypeStruct();
                else  if ( Child._Type.IsPointer() 
                    && (Child._Type.AsTypeNext().GetNext().AsTypeStruct() !is  null) )
                    t = Child._Type.AsTypeNext().GetNext().AsTypeStruct();

                if ( t !is  null )
                {
                    Decl = t.FindObject( fullId.c_str() );
                }
            }
            else
            {
                NamingExpression   namer = Child.AsNamingExpression();
                if ( namer !is  null )
                {
                    assert( namer.Decl !is  null );
                    namer.Decl.FindObject( fullId.c_str(), Decl.Ref() );
                }
            }
        }

        if ( (Decl  is  null) || !Decl.IsType() )
            return  E_MAGOEE_SYMBOL_NOT_FOUND;

        Decl.GetType( _Type.Ref() );

        Kind = DataKind_Declaration;

        if ( _Type  is  null )
            return  E_MAGOEE_NO_TYPE;

        return  S_OK;
    }
    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( mode );
        //UNREFERENCED_PARAMETER( binder );
        //UNREFERENCED_PARAMETER( obj );

        // can't evaluate a type
        return  E_MAGOEE_VALUE_EXPECTED;
    }

protected:
    HRESULT MakeName(uint32_t capacity, ref RefPtr!(SharedString) namePath);
}

class CallExpr : Expression
{
public:
    Expression Child;
    ExpressionList Args;

    this(Expression child, ExpressionList args);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT  hr;

        hr = Child.Semantic( evalData, typeEnv, binder );
        if ( FAILED( hr ) )
            return  hr;
        if ( Child._Type  is  null )
            return  E_MAGOEE_NO_TYPE;

        auto  type = Child._Type;
        if ( type.IsDelegate() )
        { // delegate has pointer to function as "next"
            auto ptrtype = type.AsTypeNext().GetNext().AsTypeNext();
            if(ptrtype)
                type = ptrtype.GetNext();
        }
        ITypeFunction func = type.AsTypeFunction();
        if ( !func )
            return  E_MAGOEE_BAD_TYPES_FOR_OP;

        ParameterList* paramList = func.GetParams();
        if( !paramList )
            return  E_MAGOEE_TYPE_RESOLVE_FAILED;

        auto  it = paramList.List.begin();

        foreach( Expression expr ; Args.List )
        {
            if( it == paramList.List.end() )
                return  E_MAGOEE_TOO_MANY_ARGUMENTS;

            hr = expr.Semantic( evalData, typeEnv, binder );
            if ( FAILED( hr ) )
                return  hr;
            if ( expr.Kind != DataKind_Value )
                return  E_MAGOEE_VALUE_EXPECTED;
            if ( expr._Type  is  null )
                return  E_MAGOEE_NO_TYPE;

            if( !expr._Type.Equals( it.Get()._Type ) )
                return  E_MAGOEE_BAD_TYPES_FOR_OP;
            ++it;
        }
         /* SYNTAX ERROR: (1385): expected <identifier> instead of if */ 
        if( it != paramList.List.end() )
            return E_MAGOEE_TOO_FEW_ARGUMENTS;

        _Type = func.GetReturnType();
        Kind = DataKind_Value;
         /* SYNTAX ERROR: (1390): expected <identifier> instead of return */ 
        return S_OK;
    }
    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        HRESULT  hr;

        if ( mode == EvalMode_Address )
            return  E_MAGOEE_NO_ADDRESS;

        if ( !evalData.Options.AllowFuncExec )
            return  E_MAGOEE_NOFUNCCALL;

        if ( Args.List.size() != 0 )
            return  E_MAGOEE_CALLARGS_NOT_IMPLEMENTED;

        auto  ne = Child.AsNamingExpression();
        if (ne  is  null)
            return  E_MAGOEE_TYPE_RESOLVE_FAILED;

        DataObject  callee = { 0 };
        if ( Child.Kind == DataKind_Value )
        {
            hr = Child.Evaluate( EvalMode_Value, evalData, binder, callee );
            if ( FAILED( hr) )
                return  hr;
        }
        else
        {
            if( !ne.Decl || !ne.Decl.GetAddress( callee.Addr ) )
                return  E_MAGOEE_NO_ADDRESS;
        }

        Address  addr = callee.Addr;
        Address  ctxt = 0;

        auto  type = Child._Type;
        if ( type.IsDelegate() ) {// delegate has pointer to function as "next"{
            auto  ptrtype = type.AsTypeNext().GetNext().AsTypeNext() ;
            if(ptrtype)
            {
                type = ptrtype.GetNext();
                addr = callee.Value.Delegate.FuncAddr;
                ctxt = callee.Value.Delegate.ContextAddr;
            }
        }
        ITypeFunction func = type.AsTypeFunction();

        if ( !evalData.Options.AllowAssignment && !func.IsPure() )
            return E_MAGOEE_HASSIDEEFFECT;
            

        obj._Type = _Type;
        hr = binder.CallFunction( addr, func, ctxt, obj );
        
        return hr;
    }
}

class PostExpr : Expression
{
public:
    Expression Child;
    TOK Operator;

    this(Expression child, TOK op){
        this.Child = child;
        this.Operator = op;
    }
}

class IndexExpr : Expression
{
public:
    Expression Child;
    ExpressionList Args;

    this(Expression child, ExpressionList args){
        this.Child = child;
        this.Args = args;
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv* typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        Type childType = Child._Type;
        if (!childType.IsPointer() && !childType.IsSArray()
                && !childType.IsDArray() && !childType.IsAArray())
            return E_MAGOEE_BAD_INDEX;

        if (childType.IsReference())
            return E_MAGOEE_BAD_INDEX;

        ITypeNext typeNext = Child._Type.AsTypeNext();
        assert(typeNext !is null);
        if (typeNext.GetNext() is null)
            return E_MAGOEE_BAD_INDEX;

        Type voidType = typeEnv.GetType(Tvoid);
        if (typeNext.GetNext().Equals(voidType))
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (Args.List.size() != 1)
            return E_MAGOEE_BAD_INDEX;

        Expression index = Args.List.front();
        {
            EvalData indexData = evalData;

            if (childType.IsSArray() || childType.IsDArray())
                indexData.HasArrayLength = true;

            hr = index.Semantic(indexData, typeEnv, binder);
        }
        if (FAILED(hr))
            return hr;
        if (index.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (index._Type is null)
            return E_MAGOEE_NO_TYPE;
        if (childType.IsAArray())
        {
            hr = TypeCheckAAKey(index._Type, childType.AsTypeAArray().GetIndex());
            if (FAILED(hr))
                return hr;

            index.TrySetType(childType.AsTypeAArray().GetIndex());
        }
        else if (!index._Type.IsIntegral())
            return E_MAGOEE_BAD_INDEX;

        _Type = typeNext.GetNext();
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            IValueBinder* binder, ref DataObject obj)
    {
        // TODO: if index value is a signed integral, then should we allow negative?
        //  pointers allow it and work as expected
        //  static arrays don't allow it at compile time
        //  dynamic arrays throw a RangeError exception at runtime

        HRESULT hr = S_OK;
        DataObject array = {0};
        DataObject index = {0};
        EvalData indexData = evalData;
        Address addr = 0;

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, array);
        if (FAILED(hr))
            return hr;

        if (Child._Type.IsSArray())
        {
            if (array.Addr == 0)
                return E_FAIL;

            indexData.HasArrayLength = true;
            indexData.ArrayLength = Child._Type.AsTypeSArray().GetLength();
            array.Value.Addr = array.Addr;
        }
        else if (Child._Type.IsDArray())
        {
            indexData.HasArrayLength = true;
            indexData.ArrayLength = array.Value.Array.Length;
            array.Value.Addr = array.Value.Array.Addr;
        }
        else if (Child._Type.IsPointer()) // else if it's a pointer, then value already has address
        {
        }
        else if (Child._Type.IsAArray()) // assoc. arrays are handled differently
        {
        }
        else
        {
            _ASSERT(false);
            return E_NOTIMPL;
        }

        hr = Args.List.front().Evaluate(EvalMode_Value, indexData, binder, index);
        if (FAILED(hr))
            return hr;

        if (Child._Type.IsAArray())
        {
            hr = FindAAElement(array, index, Child._Type.AsTypeAArray().GetIndex(), binder, addr);
            if (hr == E_NOT_FOUND)
                return E_MAGOEE_ELEMENT_NOT_FOUND;
            if (FAILED(hr))
                return hr;
        }
        else
        {
            uint32_t size = _Type.GetSize();
            doffset_t offset = size * index.Value.Int64Value;
            addr = array.Value.Addr + offset;
        }

        elem.Addr = addr;
        elem._Type = _Type;

        if (mode == EvalMode_Value)
        {
            hr = binder.GetValue(elem.Addr, _Type, elem.Value);
            if (FAILED(hr))
                return hr;
        }

        return S_OK;
    }
}

class SliceExpr : Expression
{
public:
    Expression Child;
    Expression From;
    Expression To;

    this(Expression child, Expression from, Expression to);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        EvalData indexData = evalData;
        ClearEvalData();

        hr = Child.Semantic(evalData, typeEnv, binder);
        if (FAILED(hr))
            return hr;
        if (Child.Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;
        if (Child._Type is null)
            return E_MAGOEE_NO_TYPE;

        Type childType = Child._Type;
        if (!childType.IsPointer() && !childType.IsSArray() && !childType.IsDArray())
            return E_MAGOEE_BAD_INDEX;

        ITypeNext typeNext = Child._Type.AsTypeNext();
        assert(typeNext !is null);
        if (typeNext.GetNext() is null)
            return E_MAGOEE_BAD_INDEX;

        Type voidType = typeEnv.GetType(Tvoid);
        if (typeNext.GetNext().Equals(voidType))
            return E_MAGOEE_BAD_TYPES_FOR_OP;

        if (childType.IsPointer() && ((From is null) || (To is null)))
            return E_MAGOEE_BAD_INDEX;
        // only allow [] or [e1..e2]
        if ((childType.IsSArray() || childType.IsDArray()) && ((From is null) != (To is null)))
            return E_MAGOEE_BAD_INDEX;

        if (childType.IsSArray() || childType.IsDArray())
            indexData.HasArrayLength = true;

        if (From !is null)
        {
            hr = From.Semantic(indexData, typeEnv, binder);
            if (FAILED(hr))
                return hr;
            if (From.Kind != DataKind_Value)
                return E_MAGOEE_VALUE_EXPECTED;
            if (From._Type is null)
                return E_MAGOEE_NO_TYPE;
            if (!From._Type.IsIntegral())
                return E_MAGOEE_BAD_INDEX;
        }

        if (To !is null)
        {
            hr = To.Semantic(indexData, typeEnv, binder);
            if (FAILED(hr))
                return hr;
            if (To.Kind != DataKind_Value)
                return E_MAGOEE_VALUE_EXPECTED;
            if (To._Type is null)
                return E_MAGOEE_NO_TYPE;
            if (!To._Type.IsIntegral())
                return E_MAGOEE_BAD_INDEX;
        }

        if (childType.IsDArray())
            _Type = childType;
        else
        {
            hr = typeEnv.NewDArray(typeNext.GetNext(), _Type.Ref());
            if (FAILED(hr))
                return hr;
        }

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        // TODO: if index value is a signed integral, then should we allow negative?
        //  pointers allow it and work as expected
        //  static arrays don't allow it at compile time
        //  dynamic arrays throw a RangeError exception at runtime

        HRESULT hr = S_OK;
        DataObject array = {0};
        DataObject index = {0};
        DataObject limit = {0};
        EvalData indexData = evalData;
        Address addr = 0;

        hr = Child.Evaluate(EvalMode_Value, evalData, binder, array);
        if (FAILED(hr))
            return hr;

        if (Child._Type.IsSArray())
        {
            if (array.Addr == 0)
                return E_FAIL;

            indexData.HasArrayLength = true;
            indexData.ArrayLength = Child._Type.AsTypeSArray().GetLength();
            addr = array.Addr;
            limit.Value.Int64Value = Child._Type.AsTypeSArray().GetLength();
        }
        else if (Child._Type.IsDArray())
        {
            indexData.HasArrayLength = true;
            indexData.ArrayLength = array.Value.Array.Length;
            addr = array.Value.Array.Addr;
            limit.Value.Int64Value = array.Value.Array.Length;
        }
        else if (Child._Type.IsPointer()) // else if it's a pointer, then value already has address
        {
            addr = array.Value.Addr;
        }
        else
        {
            assert(false);
            return E_NOTIMPL;
        }

        if (From !is null)
        {
            hr = From.Evaluate(EvalMode_Value, indexData, binder, index);
            if (FAILED(hr))
                return hr;
        }
        else
            assert(index.Value.Int64Value == 0);

        if (To !is null)
        {
            hr = To.Evaluate(EvalMode_Value, indexData, binder, limit);
            if (FAILED(hr))
                return hr;
        }

        uint32_t size = _Type.AsTypeNext().GetNext().GetSize();
        doffset_t offset = size * index.Value.Int64Value;

        obj.Value.Array.Addr = addr + offset;
        obj.Value.Array.Length = limit.Value.Int64Value - index.Value.Int64Value;
        obj._Type = _Type;

        // can't have a negative length (Length is unsigned, but the idea still holds)
        if (limit.Value.Int64Value < index.Value.Int64Value)
            return E_MAGOEE_BAD_INDEX;

        return S_OK;
    }
}

class IdExpr : NamingExpression
{
    SharedString mNamePath;

public:
    Utf16String Id;

    this(Utf16String id);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        ClearEvalData();

        hr = FindObject(Id.Str, binder, Decl.Ref());
        if (FAILED(hr))
            return hr;

        Decl.GetType(_Type.Ref());

        if (Decl.IsField() // in this case, it's a field of "this"
             || Decl.IsVar() || Decl.IsConstant())
        {
            Kind = DataKind_Value;
        }
        else
        {
            Kind = DataKind_Declaration;
        }

        if ((Kind == DataKind_Value) && (_Type is null))
            return E_MAGOEE_NO_TYPE;

        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        UNREFERENCED_PARAMETER(evalData);

        if (Kind != DataKind_Value)
            return E_MAGOEE_VALUE_EXPECTED;

        obj._Type = _Type;

        if (Decl.IsField())
        {
            int offset = 0;
            Address thisAddr = 0;

            HRESULT hr = GetThisAddress(binder, thisAddr);
            if (FAILED(hr))
                return hr;

            if (!Decl.GetOffset(offset))
                return E_FAIL;

            obj.Addr = thisAddr + offset;
        }
        else if (!Decl.IsRegister())
        {
            if (!Decl.GetAddress(obj.Addr))
                return E_MAGOEE_NO_ADDRESS;
        }

        if (mode == EvalMode_Address)
        {
            if (obj.Addr != 0)
                return S_OK;

            return E_MAGOEE_NO_ADDRESS;
        }

        // evaluate a scalar we might have
        return Eval(binder, Decl, obj);
    }

protected:
    HRESULT MakeName(uint32_t capacity, ref SharedString namePath)
    {
        return HRESULT.init;
    }

private:
    HRESULT FindObject(const(wchar_t)* name, ref IValueBinder binder, ref Declaration decl)
    {
        HRESULT hr = binder.FindObject(name, decl);
        if (FAILED(hr))
        {
            // now look in the class

            Declaration thisDecl;
            Type thisType;
            Declaration childDecl;

            hr = binder.GetThis(thisDecl.Ref());
            if (FAILED(hr))
                return E_MAGOEE_SYMBOL_NOT_FOUND;

            if (!thisDecl.GetType(thisType.Ref()))
                return E_MAGOEE_SYMBOL_NOT_FOUND;

            if (thisType.IsPointer())
                thisType = thisType.AsTypeNext().GetNext();

            if (thisType.AsTypeStruct() is null)
                return E_MAGOEE_SYMBOL_NOT_FOUND;

            childDecl = thisType.AsTypeStruct().FindObject(name);
            if (childDecl is null)
                return E_MAGOEE_SYMBOL_NOT_FOUND;

            decl = childDecl.Detach();
        }

        return S_OK;
    }

    HRESULT GetThisAddress(IValueBinder binder, ref Address addr)
    {
        HRESULT hr = S_OK;
        Declaration thisDecl;
        Type thisType;

        hr = binder.GetThis(thisDecl.Ref());
        if (FAILED(hr))
            return hr;

        if (!thisDecl.GetType(thisType.Ref()))
            return E_FAIL;

        if (!thisType.IsPointer())
        {
            if (!thisDecl.GetAddress(addr))
                return E_FAIL;
        }
        else
        {
            DataObject obj = {0};

            hr = Eval(binder, thisDecl, obj);
            if (FAILED(hr))
                return hr;

            addr = obj.Value.Addr;
        }

        return S_OK;
    }
}

class ScopeExpr : NamingExpression
{
    SharedString mNamePath;

public:
    TemplateInstancePart Instance;

    this(TemplateInstancePart instance);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT  hr = S_OK;
        std.wstring     fullId;
        ClearEvalData();

        fullId.append( Instance.Id.Str );
        fullId.append( Instance.ArgumentString.Str );

        hr = binder.FindObject( fullId.c_str(), Decl.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        Decl.GetType( _Type.Ref() );

        Kind = DataKind_Declaration;

        if ( !Decl.IsType() || (_Type  is  null) )
            return  E_MAGOEE_NO_TYPE;

        return  S_OK;
    }
    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( mode );
        //UNREFERENCED_PARAMETER( binder );
        //UNREFERENCED_PARAMETER( obj );

        // can't evaluate a type
        return  E_MAGOEE_VALUE_EXPECTED;
    }

protected:
    HRESULT MakeName(uint32_t capacity, ref RefPtr!(SharedString) namePath);
}

class ThisExpr : NamingExpression
{
public:
    this()
    {

    }

    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        ClearEvalData();

        hr = binder.GetThis(Decl.Ref());
        if (FAILED(hr))
            return hr;

        // has to have a type
        if (!Decl.GetType(_Type.Ref()))
            return E_MAGOEE_NO_TYPE;

        // and the type has to be struct compatible: struct or ptr to struct
        if (!_Type.CanRefMember())
            return E_FAIL;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );

        obj._Type = _Type;
        Decl.GetAddress(obj.Addr);

        if (mode == EvalMode_Address)
        {
            if (obj.Addr != 0)
                return S_OK;

            return E_MAGOEE_NO_ADDRESS;
        }

        // evaluate a scalar value (pointer) we might have
        return Eval(binder, Decl, obj);
    }
}

class SuperExpr : NamingExpression
{
public:
    this()
    {

    }

    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );

        HRESULT hr = S_OK;
        ClearEvalData();

        hr = binder.GetSuper(Decl.Ref());
        if (FAILED(hr))
            return hr;

        // has to have a type
        if (!Decl.GetType(_Type.Ref()))
            return E_FAIL;

        // and the type has to be struct compatible: struct or ptr to struct
        if (!_Type.CanRefMember())
            return E_FAIL;

        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );

        obj._Type = _Type;
        Decl.GetAddress(obj.Addr);

        if (mode == EvalMode_Address)
        {
            if (obj.Addr != 0)
                return S_OK;

            return E_MAGOEE_NO_ADDRESS;
        }

        // evaluate a scalar value (pointer) we might have
        return Eval(binder, Decl, obj);
    }
}

class DollarExpr : Expression
{
public:
    this();
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        UNREFERENCED_PARAMETER(binder);

        ClearEvalData();

        if (!evalData.HasArrayLength)
            return E_MAGOEE_BAD_INDEX;

        _Type = typeEnv.GetType(Tuns32);
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        UNREFERENCED_PARAMETER(binder);

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        obj.Value.UInt64Value = evalData.ArrayLength;
        obj._Type = _Type;
        _ASSERT(obj.Addr == 0);
        return S_OK;
    }
}

class TypeidExpr : Expression
{
public:
    _Object Child;

    this(_Object child){
        this.Child = child;
    }
}

class IsExpr : Expression
{
public:
    this(){

    }
}

class TraitsExpr : Expression
{
public:
    this(){

    }
}

class IntExpr : Expression
{
public:
    uint64_t Value;

    this(uint64_t value, Type type);
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( binder );

        Kind = DataKind_Value;
        assert(_Type !is null);
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER(evalData);
        //UNREFERENCED_PARAMETER(binder);

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        obj._Type = _Type;
        obj.Addr = 0;
        obj.Value.UInt64Value = Value;
        return S_OK;
    }
}

class RealExpr : Expression
{
public:
    Real10 Value;

    this(Real10 value, Type type){
        this.Value = value;
        this._Type = type;
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( binder );

        Kind = DataKind_Value;
        assert(_Type !is null);
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( binder );

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        obj._Type = _Type;
        obj.Addr = 0;
        obj.Value.Float80Value = Value;
        return S_OK;
    }
}

HRESULT MakeTypeForString(const String str, ref ITypeEnv typeEnv, ref Type type)
{
    HRESULT hr = S_OK;
    ENUMTY charTy = Tnone;
    Type charType = null;
    Type immutableCharType;

    switch (str.Kind)
    {
    case StringKind_Byte:
        charTy = Tchar;
        break;
    case StringKind_Utf16:
        charTy = Twchar;
        break;
    case StringKind_Utf32:
        charTy = Tdchar;
        break;
    default:
        return E_UNEXPECTED;
    }

    charType = typeEnv.GetType(charTy);

    immutableCharType = charType.MakeInvariant();
    if (immutableCharType is null)
        return E_OUTOFMEMORY;

    hr = typeEnv.NewDArray(immutableCharType, type);
    if (FAILED(hr))
        return hr;

    return S_OK;
}

HRESULT SetString(TChar, TString)(const(char)* utf8Str, int utf8Length,
        int function(const(char)* utf8Str, int utf8Len, TChar* utfXStr, int utfXLen) Utf8ToX,
        StringKind kind, ref TString newUtfStr, ref UniquePtr!(TChar[]) strBuf)
{
    assert(utf8Str !is null);

    int len = 0;
    int len2 = 0;
    TChar* utfXStr = null;

    len = Utf8ToX(utf8Str, utf8Length, null, 0);
    if ((len == 0) && (GetLastError() == ERROR_NO_UNICODE_TRANSLATION))
        return HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION);
    assert(len > 0);

    // len includes trailing '\0'
    utfXStr = new TChar[len];
    if (utfXStr is null)
        return E_OUTOFMEMORY;

    len2 = Utf8ToX(utf8Str, utf8Length, utfXStr, len);
    assert((len2 > 0) && (len2 == len));

    strBuf.Attach(utfXStr);

    newUtfStr.Kind = kind;
    newUtfStr.Length = len;
    newUtfStr.Str = utfXStr;

    return S_OK;
}

class StringExpr : Expression
{
    class AlternateStrings
    {
        Utf16String mNewUtf16Str;
        Utf32String mNewUtf32Str;

        wchar_t[] mStrBuf16;
        dchar_t[] mStrBuf32;

    public:
        this()
        {
            mNewUtf16Str.Kind = StringKind_Utf16;
            mNewUtf16Str.Length = 0;
            mNewUtf16Str.Str = null;

            mNewUtf32Str.Kind = StringKind_Utf32;
            mNewUtf32Str.Length = 0;
            mNewUtf32Str.Str = null;
        }

        //static AlternateStrings opCall();

        Utf16String GetUtf16String()
        {
            if (mNewUtf16Str.Str !is null)
                return mNewUtf16Str;

            return null;
        }

        Utf32String GetUtf32String()
        {
            if (mNewUtf32Str.Str !is null)
                return mNewUtf32Str;

            return null;
        }

        HRESULT SetUtf16String(const(char)* utf8Str, int utf8Length)
        {
            return SetString(utf8Str, utf8Length, &Utf8To16, StringKind_Utf16,
                    mNewUtf16Str, mStrBuf16);
        }

        HRESULT SetUtf32String(const(char)* utf8Str, int utf8Length)
        {
            return SetString(utf8Str, utf8Length, &Utf8To32, StringKind_Utf32,
                    mNewUtf32Str, mStrBuf32);
        }
    }

    ByteString* mUntypedStr;
    std.auto_ptr!(AlternateStrings) mAlternates;

public:
    String Value;
    bool IsSpecificType;

    this(String value, bool isSpecificType){
        this.Value = value;
        this.IsSpecificType = isSpecificType;
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( binder );

        HRESULT hr = S_OK;

        _Type = null;

        Kind = DataKind_Value;

        if (!IsSpecificType)
            Value = mUntypedStr;

        hr = MakeTypeForString(Value, typeEnv, _Type.Ref());
        if (FAILED(hr))
            return hr;

        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( binder );

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        obj._Type = _Type;
        obj.Addr = 0;
        obj.Value.Array.Addr = 0;
        obj.Value.Array.Length = Value.Length;
        obj.Value.Array.LiteralString = Value;
        return S_OK;
    }

    bool TrySetType(ref Type type)
    {
        assert(type !is null);

        // can only convert to other string types
        if (!type.IsDArray() || !type.AsTypeDArray().GetElement().IsChar())
            return false;

        Type* newCharType = type.AsTypeDArray().GetElement();

        HRESULT hr = S_OK;
        StringKind newKind;

        switch (newCharType.GetSize())
        {
        case 1:
            newKind = StringKind_Byte;
            break;
        case 2:
            newKind = StringKind_Utf16;
            break;
        case 4:
            newKind = StringKind_Utf32;
            break;
        default:
            assert(false);
            return false;
        }

        if (IsSpecificType)
        {
            if (Value.Kind != newKind)
                return false;
        }
        else if (newCharType.GetSize() == 1)
        {
            // no need to convert: untyped strings are stored as StringKind_Byte
            Value = mUntypedStr;
        }
        else
        {
            if (mAlternates.get() is null)
            {
                mAlternates.reset(new AlternateStrings());
                if (mAlternates.get() is null)
                    return false;
            }

            if (newCharType.GetSize() == 2)
            {
                if (mAlternates.GetUtf16String() is null)
                {
                    hr = mAlternates.SetUtf16String(mUntypedStr.Str, mUntypedStr.Length);
                    if (FAILED(hr))
                        return false;
                }
                Value = mAlternates.GetUtf16String();
            }
            else if (newCharType.GetSize() == 4)
            {
                if (mAlternates.GetUtf32String() is null)
                {
                    hr = mAlternates.SetUtf32String(mUntypedStr.Str, mUntypedStr.Length);
                    if (FAILED(hr))
                        return false;
                }
                Value = mAlternates.GetUtf32String();
            }
        }

        _Type = type;

        return true;
    }
}

class ArrayLiteralExpr : Expression
{
public:
    ExpressionList Values;

    this(ExpressionList values){
        this.Values = values;
    }
}

class AssocArrayLiteralExpr : Expression
{
public:
    ExpressionList Keys;
    ExpressionList Values;

    this(ExpressionList keys, ExpressionList values){
        this.Values = values;
        this.Keys = keys;
    }
}

class NullExpr : Expression
{
public:
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( binder );

        _Type = typeEnv.GetVoidPointerType();
        Kind = DataKind_Value;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( binder );

        if (mode == EvalMode_Address)
            return E_MAGOEE_NO_ADDRESS;

        if (_Type.IsPointer())
        {
            obj.Value.Addr = 0;
        }
        else if (_Type.IsDArray())
        {
            obj.Value.Array.Addr = 0;
            obj.Value.Array.Length = 0;
        }
        else if (_Type.IsAArray())
        {
            obj.Value.Addr = 0;
        }
        else if (_Type.IsDelegate())
        {
            obj.Value.Delegate.ContextAddr = 0;
            obj.Value.Delegate.FuncAddr = 0;
        }
        else
            return E_FAIL;

        obj._Type = _Type;
        obj.Addr = 0;
        return S_OK;
    }

    bool TrySetType(Type type)
    {
        if (type.IsDArray() || type.IsAArray() || type.IsDelegate())
        {
            _Type = type;
            return true;
        }

        return false;
    }
}

class TypeExpr : Expression
{
public:
    Type UnresolvedType;

    this(Type type){
        UnresolvedType = type;
    }
    HRESULT Semantic(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        ClearEvalData();

        _Type = UnresolvedType.Resolve(evalData, typeEnv, binder);
        if (_Type is null)
            return E_MAGOEE_TYPE_RESOLVE_FAILED;

        Kind = DataKind_Type;
        return S_OK;
    }

    HRESULT Evaluate(EvalMode mode, ref const EvalData evalData,
            ref IValueBinder binder, ref DataObject obj)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( mode );
        //UNREFERENCED_PARAMETER( binder );
        //UNREFERENCED_PARAMETER( obj );

        // can't evaluate a type
        return E_MAGOEE_VALUE_EXPECTED;
    }
}
