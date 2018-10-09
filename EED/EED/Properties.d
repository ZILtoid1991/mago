module EED.Properties;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import EED.Common;
import EED.Property;
import EED.Type;
import EED.TypeEnv;
import EED.Declaration;
import EED.Eval;

//------------------------------------------------------------------------
//  Base
//------------------------------------------------------------------------

class PropertyBase : StdProperty
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        assert(false);
        return false;
    }

    bool UsesParentValue()
    {
        return false;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );
        //UNREFERENCED_PARAMETER( parentType );
        //UNREFERENCED_PARAMETER( result );
        assert(false);
        return false;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );
        //UNREFERENCED_PARAMETER( parentType );
        //UNREFERENCED_PARAMETER( result );
        assert(false);
        return false;
    }
}

//------------------------------------------------------------------------
//  Size for all
//------------------------------------------------------------------------

class PropertySize : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if (parentType is null)
            return false;

        type = typeEnv.GetAliasType(Tsize_t);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        result.UInt64Value = parentType.GetSize();
        return true;
    }
}

//------------------------------------------------------------------------
//  Integrals
//------------------------------------------------------------------------

class PropertyIntegralMax : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if (parentType is null)
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsIntegral())
            return false;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tint8:
            result.UInt64Value = byte.max;
            break;
        case ENUMTY.Tuns8:
            result.UInt64Value = ubyte.max;
            break;
        case ENUMTY.Tint16:
            result.UInt64Value = short.max;
            break;
        case ENUMTY.Tuns16:
            result.UInt64Value = ushort.max;
            break;
        case ENUMTY.Tint32:
            result.UInt64Value = int.max;
            break;
        case ENUMTY.Tuns32:
            result.UInt64Value = uint.max;
            break;
        case ENUMTY.Tint64:
            result.UInt64Value = long.max;
            break;
        case ENUMTY.Tuns64:
            result.UInt64Value = ulong.max;
            break;
        default:
            break;
        }
        return true;
    }
}

class PropertyIntegralMin : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsIntegral())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsIntegral())
            return false;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tint8:
            result.UInt64Value = byte.min;
            break;
        case ENUMTY.Tuns8:
            result.UInt64Value = ubyte.min;
            break;
        case ENUMTY.Tint16:
            result.UInt64Value = short.min;
            break;
        case ENUMTY.Tuns16:
            result.UInt64Value = ushort.min;
            break;
        case ENUMTY.Tint32:
            result.UInt64Value = int.min;
            break;
        case ENUMTY.Tuns32:
            result.UInt64Value = uint.min;
            break;
        case ENUMTY.Tint64:
            result.UInt64Value = long.min;
            break;
        case ENUMTY.Tuns64:
            result.UInt64Value = ulong.min;
            break;
        default:
            break;
        }
        return true;
    }
}

//------------------------------------------------------------------------
//  Floats
//------------------------------------------------------------------------

class PropertyFloatMax : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        Real10 r;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            r.FromFloat(float.max);
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            r.FromDouble(double.max);
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            r.LoadMax();
            break;
        default:
            return false;
        }

        if (parentType.IsComplex())
        {
            result.Complex80Value.RealPart = r;
            result.Complex80Value.ImaginaryPart = r;
        }
        else
            result.Float80Value = r;

        return true;
    }
}

class PropertyFloatMin : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        // UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        Real10 r;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            r.FromFloat(float.min());
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            r.FromDouble(double.min());
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            r.LoadMinNormal();
            break;
        default:
            return false;
        }

        if (parentType.IsComplex())
        {
            result.Complex80Value.RealPart = r;
            result.Complex80Value.ImaginaryPart = r;
        }
        else
            result.Float80Value = r;

        return true;
    }
}

class PropertyFloatEpsilon : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        Real10 r;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            r.FromFloat(float.epsilon);
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            r.FromDouble(double.epsilon);
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            r.LoadEpsilon();
            break;
        default:
            return false;
        }

        if (parentType.IsComplex())
        {
            result.Complex80Value.RealPart = r;
            result.Complex80Value.ImaginaryPart = r;
        }
        else
            result.Float80Value = r;

        return true;
    }
}

class PropertyFloatNan : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        Real10 r;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            r.FromFloat(float.nan);
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            r.FromDouble(double.nan);
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            r.LoadNan();
            break;
        default:
            return false;
        }

        if (parentType.IsComplex())
        {
            result.Complex80Value.RealPart = r;
            result.Complex80Value.ImaginaryPart = r;
        }
        else
            result.Float80Value = r;

        return true;
    }
}

class PropertyFloatInfinity : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = parentType;
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        Real10 r;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            r.FromFloat(float.infinity);
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            r.FromDouble(double.infinity);
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            r.LoadInfinity();
            break;
        default:
            return false;
        }

        if (parentType.IsComplex())
        {
            result.Complex80Value.RealPart = r;
            result.Complex80Value.ImaginaryPart = r;
        }
        else
            result.Float80Value = r;

        return true;
    }
}

class PropertyFloatDigits : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        int v = 0;
        if (!GetDigits(parentType, v))
            return false;

        result.UInt64Value = v;
        return true;
    }

    static bool GetDigits(Type parentType, ref int digits)
    {
        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            digits = float.dig;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            digits = double.dig;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            digits = Real10.Digits;
            break;
        default:
            return false;
        }

        return true;
    }
}

class PropertyFloatMantissaDigits : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        int v = 0;
        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            v = float.mant_dig;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            v = double.mant_dig;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            v = Real10.MantissaDigits();
            break;
        default:
            return false;
        }

        result.UInt64Value = v;
        return true;
    }
}

class PropertyFloatMax10Exp : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        int v = 0;
        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            v = float.max_10_exp;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            v = double.max_10_exp;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            v = Real10.MaxExponentBase10();
            break;
        default:
            return false;
        }

        result.UInt64Value = v;
        return true;
    }
}

class PropertyFloatMaxExp : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        int v = 0;
        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            v = float.max_exp;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            v = double.max_exp;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            v = Real10.MaxExponentBase2();
            break;
        default:
            return false;
        }

        result.UInt64Value = v;
        return true;
    }
}

class PropertyFloatMin10Exp : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        int v = 0;
        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            v = float.min_10_exp;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            v = double.min_10_exp;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            v = Real10.MinExponentBase10();
            break;
        default:
            return false;
        }

        result.UInt64Value = v;
        return true;
    }
}

class PropertyFloatMinExp : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        type = typeEnv.GetType(ENUMTY.Tint32);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        int v = 0;
        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            v = float.min_exp;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            v = double.min_exp;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            v = Real10.MinExponentBase2();
            break;
        default:
            return false;
        }

        result.UInt64Value = v;
        return true;
    }
}

class PropertyFloatReal : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        ENUMTY ty = ENUMTY.Tnone;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            ty = Tfloat32;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            ty = Tfloat64;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            ty = Tfloat80;
            break;
        default:
            return false;
        }

        type = typeEnv.GetType(ty);
        type.AddRef();
        return true;
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Tfloat64, ENUMTY.Tfloat80:
            result.Float80Value = parentVal.Float80Value;
            break;

        case ENUMTY.Timaginary32, ENUMTY.Timaginary64, ENUMTY.Timaginary80:
            result.Float80Value.Zero();
            break;

        case ENUMTY.Tcomplex32, ENUMTY.Tcomplex64, ENUMTY.Tcomplex80:
            result.Float80Value = parentVal.Complex80Value.RealPart;
            break;

        default:
            return false;
        }

        return true;
    }
}

class PropertyFloatImaginary : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        ENUMTY ty = ENUMTY.Tnone;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32:
            ty = ENUMTY.Tfloat32;
            break;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64, ENUMTY.Tcomplex64:
            ty = ENUMTY.Tfloat64;
            break;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
            ty = ENUMTY.Tfloat80;
            break;
        default:
            return false;
        }

        type = typeEnv.GetType(ty);
        type.AddRef();
        return true;
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsFloatingPoint())
            return false;

        switch (parentType.GetBackingTy())
        {
        case ENUMTY.Tfloat32, ENUMTY.Tfloat64, ENUMTY.Tfloat80:
            result.Float80Value.Zero();
            break;

        case ENUMTY.Timaginary32, ENUMTY.Timaginary64, ENUMTY.Timaginary80:
            result.Float80Value = parentVal.Float80Value;
            break;

        case ENUMTY.Tcomplex32, ENUMTY.Tcomplex64, ENUMTY.Tcomplex80:
            result.Float80Value = parentVal.Complex80Value.ImaginaryPart;
            break;

        default:
            return false;
        }

        return true;
    }
}

class PropertySArrayLength : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsSArray())
            return false;

        type = typeEnv.GetAliasType(ENUMTY.Tsize_t);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsSArray())
            return false;

        result.UInt64Value = parentType.AsTypeSArray().GetLength();
        return true;
    }
}

class PropertyDArrayLength : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDArray())
            return false;

        type = typeEnv.GetAliasType(ENUMTY.Tsize_t);
        type.AddRef();
        return true;
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDArray())
            return false;

        result.UInt64Value = parentVal.Array.Length;
        return true;
    }
}

class PropertySArrayPtr : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsSArray())
            return false;

        HRESULT hr = S_OK;
        hr = typeEnv.NewPointer(parentType.AsTypeNext().GetNext(), type);
        return SUCCEEDED(hr);
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        if ((parentType is null) || !parentType.IsSArray())
            return false;

        return parentDecl.GetAddress(result.Addr);
    }
}

class PropertyDArrayPtr : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDArray())
            return false;

        HRESULT hr = S_OK;
        hr = typeEnv.NewPointer(parentType.AsTypeNext().GetNext(), type);
        return SUCCEEDED(hr);
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        UNREFERENCED_PARAMETER(parentDecl);

        if ((parentType is null) || !parentType.IsDArray())
            return false;

        result.Addr = parentVal.Array.Addr;
        return true;
    }
}

class PropertyDelegatePtr : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDelegate())
            return false;

        type = typeEnv.GetVoidPointerType();
        type.AddRef();
        return true;
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDelegate())
            return false;

        result.Addr = parentVal.Delegate.ContextAddr;
        return true;
    }
}

class PropertyDelegateFuncPtr : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDelegate())
            return false;

        type = parentType.AsTypeNext().GetNext();
        type.AddRef();
        return true;
    }

    bool UsesParentValue()
    {
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl,
            ref const DataValue parentVal, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentDecl );

        if ((parentType is null) || !parentType.IsDelegate())
            return false;

        result.Addr = parentVal.Delegate.FuncAddr;
        return true;
    }
}

class PropertyFieldOffset : PropertyBase
{
public:
    bool GetType(ITypeEnv typeEnv, Type parentType, Declaration parentDecl, ref Type type)
    {
        //UNREFERENCED_PARAMETER( parentType );

        if ((parentDecl is null) || !parentDecl.IsField())
            return false;

        type = typeEnv.GetAliasType(Tsize_t);
        type.AddRef();
        return true;
    }

    bool GetValue(Type parentType, Declaration parentDecl, ref DataValue result)
    {
        //UNREFERENCED_PARAMETER( parentType );

        if ((parentDecl is null) || !parentDecl.IsField())
            return false;

        int offset = 0;

        if (!parentDecl.GetOffset(offset))
            return false;

        result.UInt64Value = offset;
        return true;
    }
}

