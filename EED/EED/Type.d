module EED.Type;

import EED._object;
import EED.EE;
import common.stringutil;

enum ENUMTY
{
    Tarray, // slice array, aka T[]
    Tsarray, // static array, aka T[dimension]
    Tnarray, // resizable array, aka T[new]
    Taarray, // associative array, aka T[type]
    Tpointer,
    Treference,
    Tfunction,
    Tident,
    Tclass,
    Tstruct,
    Tenum,
    Ttypedef,
    Tdelegate,

    Tnone,
    Tvoid,
    Tint8,
    Tuns8,
    Tint16,
    Tuns16,
    Tint32,
    Tuns32,
    Tint64,
    Tuns64,
    Tfloat32,
    Tfloat64,
    Tfloat80,

    Timaginary32,
    Timaginary64,
    Timaginary80,

    Tcomplex32,
    Tcomplex64,
    Tcomplex80,

    Tbit,
    Tbool,
    Tchar,
    Twchar,
    Tdchar,

    Terror,
    Tinstance,
    Ttypeof,
    Ttuple,
    Tslice,
    Treturn,
    TMAX
}

enum ALIASTY
{
    Tsize_t,
    Tptrdiff_t,

    ALIASTMAX
}

enum UdtKind
{
    Udt_Struct,
    Udt_Class,
    Udt_Union
}

class Parameter : _Object
{
public:
    StorageClass Storage;
    RefPtr!(Type) _Type;

    this(StorageClass storage, Type type)
    {
        Storage = (storage);
        _Type = (type);
    }

    ObjectKind GetObjectKind()
    {
        return ObjectKind_Parameter;
    }
}

class ParameterList : _Object
{
public:
    //alias std.list!(RefPtr!(Parameter)) ListType;

    ListType[] List;

    this()
    {

    }

    ObjectKind GetObjectKind()
    {
        return ObjectKind_ParameterList;
    }
}

class Type : _Object
{
public:
    ENUMTY Ty;
    MOD Mod;

    this(ENUMTY ty)
    {
        Ty = ty;
        Mod = MOD.MODnone;
    }

    // Object
    ObjectKind GetObjectKind()
    {
        return ObjectKind_Type;
    }

    // Type
    abstract Type Copy();

    Type MakeMutable()
    {
        Type type = Copy();
        type.Mod = cast(MOD)(MOD.Mod & MOD.MODshared);
        return type;
    }

    Type MakeShared()
    {
        Type type = Copy();
        type.Mod = MOD.MODshared;
        return type;
    }

    Type MakeSharedConst()
    {
        Type type = Copy();
        type.Mod = cast(MOD)(MOD.MODconst | MOD.MODshared);
        return type;
    }

    Type MakeConst()
    {
        Type type = Copy();
        type.Mod = MOD.MODconst;
        return type;
    }

    Type MakeInvariant()
    {
        Type type = Copy();
        type.Mod = MOD.MODinvariant;
        return type;
    }

    Type MakeMod(MOD m)
    {
        Type type = Copy();
        type.Mod = m;
        return type;
    }

    @property @nogc bool IsConst()
    {
        return (Mod & MOD.MODconst) != 0;
    }

    @property @nogc bool IsInvariant()
    {
        return (Mod & MOD.MODinvariant) != 0;
    }

    @property @nogc bool IsMutable()
    {
        return (Mod & (MOD.MODconst | MOD.MODinvariant)) == 0;
    }

    @property @nogc bool IsShared()
    {
        return (Mod & MOD.MODshared) != 0;
    }

    @property @nogc bool IsSharedConst()
    {
        return (Mod & (MOD.MODconst | MOD.MODshared)) != 0;
    }
    /// adds modifiers
    void ToString(ref wstring str)
    {
        size_t len = str.length;
        _ToString(str);
        if (Mod == 0)
            return;
        std.wstring sub = str.substr(len);
        if (Mod & MODinvariant)
            sub = "immutable("w + sub + ")"w;
        else if (Mod & MODconst)
            sub = "const("w + sub + ")"w;
        if (Mod & MODshared)
            sub = "shared("w + sub + ")"w;
        str = str[0 .. len] ~ sub;
    }

protected:
    /// no modifier
    abstract void _ToString(ref wstring str);

public:
    bool CanImplicitCastToBool()
    {
        return IsScalar() || IsDArray() || IsSArray() || IsAArray() || IsDelegate();
    }

    bool IsBasic()
    {
        return false;
    }

    bool IsPointer()
    {
        return false;
    }

    bool IsReference()
    {
        return false;
    }

    bool IsSArray()
    {
        return false;
    }

    bool IsDArray()
    {
        return false;
    }

    bool IsAArray()
    {
        return false;
    }

    bool IsFunction()
    {
        return false;
    }

    bool IsDelegate()
    {
        return false;
    }

    bool IsScalar()
    {
        return false;
    }

    bool IsBool()
    {
        return false;
    }

    bool IsChar()
    {
        return false;
    }

    bool IsIntegral()
    {
        return false;
    }

    bool IsFloatingPoint()
    {
        return false;
    }

    bool IsSigned()
    {
        return false;
    }

    bool IsReal()
    {
        return false;
    }

    bool IsImaginary()
    {
        return false;
    }

    bool IsComplex()
    {
        return false;
    }

    bool CanRefMember()
    {
        return false;
    }

    Declaration GetDeclaration()
    {
        return null;
    }

    ENUMTY GetBackingTy()
    {
        return Ty;
    }

    uint32_t GetSize()
    {
        return 0;
    }

    bool Equals(Type other)
    {
        return false;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        //UNREFERENCED_PARAMETER( evalData );
        //UNREFERENCED_PARAMETER( typeEnv );
        //UNREFERENCED_PARAMETER( binder );
        return this;
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        return FindBaseProperty(name);
    }

    ITypeNext AsTypeNext()
    {
        return null;
    }

    ITypeStruct AsTypeStruct()
    {
        return null;
    }

    ITypeEnum AsTypeEnum()
    {
        return null;
    }

    ITypeFunction AsTypeFunction()
    {
        return null;
    }

    ITypeSArray AsTypeSArray()
    {
        return null;
    }

    ITypeDArray AsTypeDArray()
    {
        return null;
    }

    ITypeAArray AsTypeAArray()
    {
        return null;
    }

    Type Unaliased()
    {
        return this;
    }
}

class TypeBasic : Type
{
public:
    this(ENUMTY ty)
    {
        super(ty);
    }

    Type Copy()
    {
        Type type = new TypeBasic(Ty);
        return type;
    }

    bool IsBasic()
    {
        return true;
    }

    bool IsScalar()
    {
        switch (Ty)
        {
        case ENUMTY.Tint8, ENUMTY.Tuns8, ENUMTY.Tint16, ENUMTY.Tuns16,
                ENUMTY.Tint32, ENUMTY.Tuns32, ENUMTY.Tint64, ENUMTY.Tuns64,
                ENUMTY.Tbit, ENUMTY.Tbool, ENUMTY.Tchar, ENUMTY.Twchar, ENUMTY.Tdchar,
                ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32, ENUMTY.Tfloat64, ENUMTY.Timaginary64,
                ENUMTY.Tcomplex64, ENUMTY.Tfloat80, ENUMTY.Timaginary80,
                ENUMTY.Tcomplex80:
                return true;
        default:
            return false;
        }
    }

    bool IsBool()
    {
        return Ty == ENUMTY.Tbool;
    }

    bool IsChar()
    {
        switch (Ty)
        {
        case ENUMTY.Tchar, ENUMTY.Twchar, ENUMTY.Tdchar:
            return true;
        default:
            return false;
        }
    }

    bool IsIntegral()
    {
        switch (Ty)
        {
        case ENUMTY.Tint8, ENUMTY.Tuns8, ENUMTY.Tint16, ENUMTY.Tuns16,
                ENUMTY.Tint32, ENUMTY.Tuns32, ENUMTY.Tint64, ENUMTY.Tuns64,
                ENUMTY.Tbit, ENUMTY.Tbool, ENUMTY.Tchar, ENUMTY.Twchar, ENUMTY.Tdchar:
                return true;
        default:
            return false;
        }

    }

    bool IsFloatingPoint()
    {
        switch (Ty)
        {
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32, ENUMTY.Tcomplex32, ENUMTY.Tfloat64,
                ENUMTY.Timaginary64, ENUMTY.Tcomplex64, ENUMTY.Tfloat80,
                ENUMTY.Timaginary80, ENUMTY.Tcomplex80:
                return true;
        default:
            return false;
        }

    }

    bool IsSigned()
    {
        switch (ty)
        {
        case ENUMTY.Tint8, ENUMTY.Tint16, ENUMTY.Tint32, ENUMTY.Tint64:
            return true;
        default:
            return false;
        }

    }

    bool IsReal()
    {
        switch (Ty)
        {
        case ENUMTY.Tfloat32, ENUMTY.Tfloat64, ENUMTY.Tfloat80:
            return true;
        default:
            return false;
        }

    }

    bool IsImaginary()
    {
        switch (Ty)
        {
        case ENUMTY.Timaginary32, ENUMTY.Timaginary64, ENUMTY.Timaginary80:
            return true;
        default:
            return false;
        }

    }

    bool IsComplex()
    {
        switch (Ty)
        {
        case ENUMTY.Tcomplex32, ENUMTY.Tcomplex64, ENUMTY.Tcomplex80:
            return true;
        default:
            return false;
        }

    }

    ENUMTY GetBackingTy()
    {
        switch (Ty)
        {
        case ENUMTY.Tbit, ENUMTY.Tbool, ENUMTY.Tchar:
            return Tuns8;
        default:
            return Ty;
        }

    }

    uint32_t GetSize()
    {
        return GetTypeSize(Ty);
    }

    bool Equals(Type other)
    {
        if (other.IsBasic())
            return other.Ty == Ty;

        return false;
    }

    void _ToString(ref wstring str)
    {
        str ~= GetTypeName(Ty);
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        StdProperty prop = null;

        if (IsIntegral())
        {
            prop = FindIntProperty(name);
            if (prop !is null)
                return prop;
        }

        if (IsFloatingPoint())
        {
            prop = FindFloatProperty(name);
            if (prop !is null)
                return prop;
        }

        return Type.FindProperty(name);
    }

    static bool IsSigned(ENUMTY ty)
    {
        switch (ty)
        {
        case ENUMTY.Tint8, ENUMTY.Tint16, ENUMTY.Tint32, ENUMTY.Tint64:
            return true;
        default:
            return false;
        }

    }

    static const(wchar_t)* GetTypeName(ENUMTY ty)
    {
        switch (ty)
        {
        case Tvoid:
            return "void"w;
        case Tint8:
            return "byte"w;
        case Tuns8:
            return "ubyte"w;
        case Tint16:
            return "short"w;
        case Tuns16:
            return "ushort"w;
        case Tint32:
            return "int"w;
        case Tuns32:
            return "uint"w;
        case Tint64:
            return "long"w;
        case Tuns64:
            return "ulong"w;
        case Tfloat32:
            return "float"w;
        case Timaginary32:
            return "ifloat"w;
        case Tfloat64:
            return "double"w;
        case Timaginary64:
            return "idouble"w;
        case Tfloat80:
            return "real"w;
        case Timaginary80:
            return "ireal"w;
        case Tcomplex32:
            return "cfloat"w;
        case Tcomplex64:
            return "cdouble"w;
        case Tcomplex80:
            return "creal"w;
        case Tbit:
        case Tbool:
            return "bool"w;
        case Tchar:
            return "char"w;
        case Twchar:
            return "wchar"w;
        case Tdchar:
            return "dchar"w;
        default:
            break;
        }

        assert(false);
        return null;
    }

    static string getTypeNameSTR(ENUMTY ty) const
    {
        switch (ty)
        {
        case ENUMTY.Tvoid:
            return "void"w;
        case ENUMTY.Tint8:
            return "byte"w;
        case ENUMTY.Tuns8:
            return "ubyte"w;
        case ENUMTY.Tint16:
            return "short"w;
        case ENUMTY.Tuns16:
            return "ushort"w;
        case ENUMTY.Tint32:
            return "int"w;
        case ENUMTY.Tuns32:
            return "uint"w;
        case ENUMTY.Tint64:
            return "long"w;
        case ENUMTY.Tuns64:
            return "ulong"w;
        case ENUMTY.Tfloat32:
            return "float"w;
        case ENUMTY.Timaginary32:
            return "ifloat"w;
        case ENUMTY.Tfloat64:
            return "double"w;
        case ENUMTY.Timaginary64:
            return "idouble"w;
        case ENUMTY.Tfloat80:
            return "real"w;
        case ENUMTY.Timaginary80:
            return "ireal"w;
        case ENUMTY.Tcomplex32:
            return "cfloat"w;
        case ENUMTY.Tcomplex64:
            return "cdouble"w;
        case ENUMTY.Tcomplex80:
            return "creal"w;
        case ENUMTY.Tbit, ENUMTY.Tbool:
            return "bool"w;
        case ENUMTY.Tchar:
            return "char"w;
        case ENUMTY.Twchar:
            return "wchar"w;
        case ENUMTY.Tdchar:
            return "dchar"w;
        default:
            break;
        }

        assert(false);
        return null;
    }

    static uint32_t GetTypeSize(ENUMTY ty)
    {
        switch (ty)
        {
        case ENUMTY.Tvoid:
            return 0;
        case ENUMTY.Tint8, ENUMTY.Tuns8:
            return 1;
        case ENUMTY.Tint16, ENUMTY.Tuns16:
            return 2;
        case ENUMTY.Tint32, ENUMTY.Tuns32:
            return 4;
        case ENUMTY.Tint64, ENUMTY.Tuns64:
            return 8;
        case ENUMTY.Tfloat32, ENUMTY.Timaginary32:
            return 4;
        case ENUMTY.Tfloat64, ENUMTY.Timaginary64:
            return 8;
        case ENUMTY.Tfloat80, ENUMTY.Timaginary80:
            return 10;
        case ENUMTY.Tcomplex32:
            return 8;
        case ENUMTY.Tcomplex64:
            return 16;
        case ENUMTY.Tcomplex80:
            return 20;
        case ENUMTY.Tbit, ENUMTY.Tbool:
            return 1;
        case ENUMTY.Tchar:
            return 1;
        case ENUMTY.Twchar:
            return 2;
        case ENUMTY.Tdchar:
            return 4;
        default:
            assert(false);
            break;
        }
        return 0;
    }
};

interface ITypeNext
{
public:
    Type GetNext();
}

class TypeNext : ITypeNext, Type
{
    protected Type Next;
public:
    this(ENUMTY ty, Type next)
    {
        super(ty);
        this.Next = next;
    }

    // Type
    Type MakeShared()
    {
        TypeNext type = cast(TypeNext) Type.MakeShared();
        if ((Ty != Tfunction) && (Ty != Tdelegate) && !Next.IsInvariant() && !Next.IsShared())
        {
            if (Next.IsConst())
                type.Next = Next.MakeSharedConst();
            else
                type.Next = Next.MakeShared();
        }
        return type;
    }

    Type MakeSharedConst()
    {
        TypeNext type = cast(TypeNext) Type.MakeSharedConst();
        if ((Ty != ENUMTY.Tfunction) && (Ty != ENUMTY.Tdelegate)
                && !Next.IsInvariant() && !Next.IsSharedConst())
        {
            type.Next = Next.MakeSharedConst();
        }
        return type;
    }

    Type MakeConst()
    {
        TypeNext type = cast(TypeNext) Type.MakeConst();
        if ((Ty != ENUMTY.Tfunction) && (Ty != ENUMTY.Tdelegate)
                && !Next.IsInvariant() && !Next.IsConst())
        {
            if (Next.IsShared())
                type.Next = Next.MakeSharedConst();
            else
                type.Next = Next.MakeConst();
        }
        return type;
    }

    Type MakeInvariant()
    {
        TypeNext type = cast(TypeNext*) Type.MakeInvariant();
        if ((Ty != Tfunction) && (Ty != Tdelegate) && !Next.IsInvariant())
        {
            type.Next = Next.MakeInvariant();
        }
        return type;
    }

    ITypeNext AsTypeNext()
    {
        return this;
    }

    // ITypeNext
    Type GetNext()
    {
        return Next;
    }
}

class TypePointer : TypeNext
{
    int mPtrSize;

public:
    this(Type child, int ptrSize)
    {
        super(ENUMTY.Tpointer);
        mPtrSize = ptrSize;
    }

    Type Copy()
    {
        Type type = new TypePointer(Next, mPtrSize);
        return type;
    }

    bool IsPointer()
    {
        return true;
    }

    bool IsScalar()
    {
        return true;
    }

    bool CanRefMember()
    {
        assert(Next !is null);
        return Next.AsTypeStruct() !is null;
    }

    uint32_t GetSize()
    {
        return mPtrSize;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Tpointer)
            return false;

        return Next.Equals(other.AsTypeNext().GetNext());
    }

    void _ToString(ref wstring str)
    {
        Next.ToString(str);
        str ~= "*"w;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        Type type = new TypePointer(resolvedNext, mPtrSize);
        type.Mod = Mod;
        return type;
    }
}

class TypeReference : TypeNext
{
    int mPtrSize;

public:
    this(Type child, int ptrSize)
    {
        super(ENUMTY.Treference, child);
        this.mPtrSize = ptrSize;
    }

    Type Copy()
    {
        Type type = new TypeReference(Next, mPtrSize);
        return type;
    }

    bool IsPointer()
    {
        return true;
    }

    bool IsReference()
    {
        return true;
    }

    bool IsScalar()
    {
        return true;
    }

    bool CanRefMember()
    {
        assert(Next !is null);
        return Next.AsTypeStruct() !is null;
    }

    uint32_t GetSize()
    {
        return mPtrSize;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Treference)
            return false;

        return Next.Equals(other.AsTypeNext().GetNext());
    }

    void _ToString(ref std.wstring str)
    {
        Next.ToString(str);
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        Type type = new TypeReference(resolvedNext, mPtrSize);
        type.Mod = Mod;
        return type;
    }
}

interface ITypeDArray
{
public:
    Type GetLengthType();
    Type GetPointerType();
    Type GetElement();
}

/* SYNTAX ERROR: (232): expected ; instead of ITypeDArray */
class TypeDArray : TypeNext, ITypeDArray
{
    Type mLenType;
    Type mPtrType;

public:
    this(Type element, Type lenType, Type ptrType)
    {
        super(ENUMTY.Tarray, element);
        this.mLenType = lenType;
        this.mPtrType = ptrType;
    }

    Type Copy()
    {
        Type type = new TypeDArray(Next, mLenType, mPtrType);
        return type;
    }

    bool IsDArray()
    {
        return true;
    }

    uint32_t GetSize()
    {
        return mLenType.GetSize() + mPtrType.GetSize();
    }

    bool Equals(Type other)
    {
        if (other.Ty != Tarray)
            return false;

        return Next.Equals(other.AsTypeNext().GetNext());
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        Type type = new TypeDArray(resolvedNext, mLenType, mPtrType);
        type.Mod = Mod;
        return type;
    }

    void _ToString(ref wstring str)
    {
        size_t len = str.length;
        Next.ToString(str);
        wstring sub = str[0 .. len];
        if (sub == "immutable(char)"w)
            str = str[0, len] + "string"w;
        else if (sub == "immutable(wchar)"w)
            str = str[0, len] + "wstring"w;
        else if (sub == "immutable(dchar)"w)
            str = str[0, len] + "dstring"w;
        else
            str.append("[]"w);
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        StdProperty* prop = FindDArrayProperty(name);
        if (prop !is null)
            return prop;

        return Type.FindProperty(name);
    }

    ITypeDArray AsTypeDArray()
    {
        return this;
    }

    // ITypeDArray
    Type GetLengthType()
    {
        return mLenType;
    }

    Type GetPointerType()
    {
        return mPtrType;
    }

    Type GetElement()
    {
        return Next;
    }
    /* SYNTAX ERROR: unexpected trailing } */
} /* SYNTAX ERROR: (252): expected <identifier> instead of ; */

interface ITypeAArray
{
public:
    Type GetElement();
    Type GetIndex();
}

class TypeAArray : TypeNext, ITypeAArray
{
    uint32_t mSize;
    Type Index;

public:
    this(Type elem, Type index, uint32_t size)
    {
        super(ENUMTY.Taarray, elem);
        this.Index = index;
        this.mSize = size;
    }

    abstract Type Copy()
    {
        Type type = new TypeAArray(Next, Index, mSize);
        return type;
    }

    bool IsAArray()
    {
        return true;
    }

    uint32_t GetSize()
    {
        return mSize;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Taarray)
            return false;

        if (!Next.Equals(other.AsTypeNext().GetNext()))
            return false;

        return Index.Equals((cast(TypeAArray*) other).Index.Get());
    }

    void _ToString(ref std.wstring str)
    {
        Next.ToString(str);
        str ~= "["w;
        Index.ToString(str);
        str ~= "]"w;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        Type resolvedIndex = Index.Resolve(evalData, typeEnv, binder);
        if (resolvedIndex is null)
            return null;

        Type type = new TypeAArray(resolvedNext, resolvedIndex, mSize);
        type.Mod = Mod;
        return type;
    }

    ITypeAArray AsTypeAArray()
    {
        return this;
    }

    // ITypeAArray
    Type GetElement()
    {
        return Next;
    }

    Type GetIndex()
    {
        return Index;
    }
    /* SYNTAX ERROR: unexpected trailing } */
} /* SYNTAX ERROR: (281): expected <identifier> instead of ; */

interface ITypeSArray
{
public:
    uint32_t GetLength();
    Type GetElement();
}

class TypeSArray : TypeNext, ITypeSArray
{
    uint32_t Length;
public:
    this(Type elem, uint32_t len)
    {
        super(ENUMTY.Tsarray);
        this.Lenght = len;
    }

    Type Copy()
    {
        Type type = new TypeSArray(Next.Get(), Length);
        return type;
    }

    bool IsSArray()
    {
        return true;
    }

    uint32_t GetSize()
    {
        return Next.GetSize() * Length;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Tsarray)
            return false;

        if (!Next.Equals(other.AsTypeNext().GetNext()))
            return false;

        return Length == (cast(TypeSArray*) other).Length;
    }

    Type Resolve(ref const EvalData evalData, ref ITypeEnv typeEnv, ref IValueBinder binder)
    {
        Type resolvedNext = Next.Resolve(evalData, typeEnv, binder);
        if (resolvedNext is null)
            return null;

        Type type = new TypeSArray(resolvedNext, Length);
        type.Mod = Mod;
        return type;
    }

    void _ToString(ref std.wstring str)
    {
        // we're using space for a ulong's digits, but we only need that for a uint
        const(int) UlongDigits = 20;
        wchar_t[UlongDigits + 1] numStr = ""w;
        errno_t err = 0;

        err = _ultow_s(Length, numStr, 10);
        assert(err == 0);

        Next.ToString(str);
        str ~= "["w;
        str ~= numStr;
        str ~= "]"w;
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        StdProperty prop = FindSArrayProperty(name);
        if (prop !is null)
            return prop;

        return Type.FindProperty(name);
    }

    ITypeSArray AsTypeSArray()
    {
        return this;
    }

    // ITypeSArray
    uint32_t GetLength()
    {
        return Length;
    }

    Type GetElement()
    {
        return Next;
    }

}

interface ITypeFunction
{
public:
    Type GetReturnType();
    int GetVarArgs();
    ParameterList GetParams();

    uint8_t GetCallConv();
    bool IsPure();
    bool IsNoThrow();
    bool IsProperty();
    TRUST GetTrust();

    void SetCallConv(uint8_t value);
    void SetPure(bool value);
    void SetNoThrow(bool value);
    void SetProperty(bool value);
    void SetTrust(TRUST value);
}

// in DMD source this is also a TypeNext
/* SYNTAX ERROR: (335): expected ; instead of ITypeFunction */
class TypeFunction : TypeNext, ITypeFunction
{

    bool mIsPure;
    bool mIsNoThrow;
    bool mIsProperty;
    uint8_t mCallConv; // as CV_call_e in cvconst.h
    TRUST mTrust;
    ParameterList Params;
    int VarArgs;

public:
    this(ParameterList params, Type retType, uint8_t callConv, int varArgs)
    {
        super(ENUMTY.Tfunction, retType);
        Params = params;
        VarArgs = varArgs;
        mCallConv = callConv;
        mIsPure = false;
        mIsNoThrow = false;
        mIsProperty = false;
        mTrust = TRUST.TRUSTdefault;
    }

    Type Copy()
    {
        Type type = new TypeFunction(Params.Get(), Next.Get(), mCallConv, VarArgs);
        ITypeFunction funcType = type.AsTypeFunction();
        funcType.SetPure(mIsPure);
        funcType.SetNoThrow(mIsNoThrow);
        funcType.SetProperty(mIsProperty);
        funcType.SetTrust(mTrust);
        return type;
    }

    bool IsFunction()
    {
        return true;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Ty)
            return false;

        ITypeFunction otherFunc = other.AsTypeFunction();

        if (!Next.Equals(otherFunc.GetReturnType()))
            return false;

        if (VarArgs != otherFunc.GetVarArgs())
            return false;

        if (mCallConv != otherFunc.GetCallConv())
            return false;

        ParameterList otherParams = otherFunc.GetParams();

        if (Params.List.size() != otherParams.List.size())
            return false;

        for (ParameterList.ListType.iterator it = Params.List.begin(),
                otherIt = otherParams.List.begin(); it != Params.List.end(); it++, otherIt++)
        {
            Parameter param = it;
            Parameter otherParam = otherIt;

            if (param.Storage != otherParam.Storage)
                return false;

            if (!param._Type.Equals(otherParam._Type))
                return false;
        }

        // TODO: do we have to check pure, trust, and the rest?
        // TODO: does this class really need to store those attributes?

        return true;
    }

    void _ToString(ref wstring str)
    {
        FunctionToString("function"w, AsTypeFunction(), str);
    }

    ITypeFunction AsTypeFunction()
    {
        return this;
    }

    // ITypeFunction
    Type GetReturnType()
    {
        return Next;
    }

    int GetVarArgs()
    {
        return VarArgs;
    }

    ParameterList GetParams()
    {
        return Params;
    }

    @nogc @property uint8_t GetCallConv()
    {
        return mCallConv;
    }

    @nogc @property bool IsPure()
    {
        return mIsPure;
    }

    @nogc @property bool IsNoThrow()
    {
        return mIsNoThrow;
    }

    @nogc @property bool IsProperty()
    {
        return mIsProperty;
    }

    TRUST GetTrust()
    {
        return mTrust;
    }

    void SetCallConv(uint8_t value)
    {
        mCallConv = value;
    }

    void SetPure(bool value)
    {
        mIsPure = value;
    }

    void SetNoThrow(bool value)
    {
        mIsNoThrow = value;
    }

    void SetProperty(bool value)
    {
        mIsProperty = value;
    }

    void SetTrust(TRUST value)
    {
        mTrust = value;
    }

}

void StorageClassToString(StorageClass storage, ref wstring str)
{
    if ((storage & STCconst) != 0)
        str ~= "const "w;

    if ((storage & STCimmutable) != 0)
        str ~= "immutable "w;

    if ((storage & STCshared) != 0)
        str ~= "shared "w;

    if ((storage & STCin) != 0)
        str ~= "in "w;

    if ((storage & STCout) != 0)
        str ~= "out "w;

    // it looks like ref is preferred over inout
    if ((storage & STCref) != 0)
        str ~= "ref "w;

    if ((storage & STClazy) != 0)
        str ~= "lazy "w;

    if ((storage & STCscope) != 0)
        str ~= "scope "w;

    if ((storage & STCfinal) != 0)
        str ~= "final "w;

    // TODO: any more storage classes?
}

void FunctionToString(const(wchar_t)* keyword, ITypeFunction funcType, ref wstring str)
{
    funcType.GetReturnType().ToString(str);
    str ~= " "w;
    str ~= keyword;
    str ~= "("w;

    ParameterList params = funcType.GetParams();

    for (ParameterList.ListType.iterator it = params.List.begin(); it != params.List.end();
            it++)
    {
        if (it != params.List.begin())
            str ~= ", "w;

        StorageClassToString((*it).Storage, str);

        (*it)._Type.ToString(str);
    }

    if (funcType.GetVarArgs() == 1)
    {
        str ~= ", ..."w;
    }
    else if (funcType.GetVarArgs() == 2)
    {
        str ~= "..."w;
    }

    str ~= ")"w;
}

class TypeDelegate : TypeNext
{
public:
    this(Type ptrToFunction)
    {
        super(ENUMTY.Tdelegate, ptrToFunction);
        ITypeNext ptrToFunc = ptrToFunction.AsTypeNext();
        assert(ptrToFunc !is null);
    }

    Type Copy()
    {
        Type type = new TypeDelegate(Next);
        return type;
    }

    bool IsDelegate()
    {
        return true;
    }

    uint32_t GetSize()
    {
        return Next.GetSize() * 2;
    }

    bool Equals(Type other)
    {
        if (other.Ty != Ty)
            return false;

        return Next.Equals(other.AsTypeNext().GetNext());
    }

    void _ToString(ref wstring str)
    {
        ITypeNext ptrToFunc = Next.AsTypeNext();

        if (ptrToFunc is null)
        {
            str ~= "delegate"w;
            return;
        }

        ITypeFunction funcType = ptrToFunc.GetNext().AsTypeFunction();

        if (funcType is null)
        {
            str ~= "delegate"w;
            return;
        }

        FunctionToString("delegate"w, funcType, str);
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        StdProperty prop = FindDelegateProperty(name);
        if (prop !is null)
            return prop;

        return Type.FindProperty(name);
    }
}

interface ITypeStruct
{
public:
    Declaration FindObject(const(wchar_t)* name);

    // TODO: where do we put the method that returns all the members?

    UdtKind GetUdtKind();
    bool GetBaseClassOffset(Type baseClass, ref int offset);
}

/* SYNTAX ERROR: (397): expected ; instead of ITypeStruct */
class TypeStruct : Type, ITypeStruct
{
    Declaration mDecl;
public:
    this(Declaration decl)
    {
        super(ENUMTY.Tstruct);
    }

    Declaration GetDeclaration()
    {
        return mDecl;
    }

    Type Copy()
    {
        Type type = new TypeStruct(mDecl);
        return type;
    }

    bool CanRefMember()
    {
        // TODO: assert size and decl is a type
        uint32_t size = 0;
        mDecl.GetSize(size);
        return size;
    }

    uint32_t GetSize()
    {
        // TODO: assert size and decl is a type
        uint32_t size = 0;
        mDecl.GetSize(size);
        return size;
    }

    bool Equals(Type other)
    {
        if (Ty != other.Ty)
            return false;

        return wcscmp(mDecl.GetName(), other.GetDeclaration().GetName()) == 0;
    }

    void _ToString(ref wstring str)
    {
        str ~= mDecl.GetName();
    }

    ITypeStruct AsTypeStruct()
    {
        return this;
    }

    // ITypeStruct
    Declaration FindObject(const(wchar_t)* name)
    {
        HRESULT hr = S_OK;
        Declaration childDecl;

        if (wcscmp(name, "__vfptr"w) == 0)
            if (GetUdtKind() == Udt_Class)
            {
                if (mDecl.GetVTableShape(childDecl.Ref()))
                    return childDecl;
            }

        hr = mDecl.FindObject(name, childDecl.Ref());
        if (FAILED(hr))
            return null;

        return childDecl;
    }

    UdtKind GetUdtKind()
    {
        UdtKind kind = Udt_Struct;

        mDecl.GetUdtKind(kind);

        return kind;
    }

    bool GetBaseClassOffset(Type baseClass, ref int offset)
    {
        _ASSERT(baseClass !is null);
        if ((baseClass is null) || (baseClass.AsTypeStruct() is null))
            return false;

        return mDecl.GetBaseClassOffset(baseClass.GetDeclaration(), offset);
    }
    /* SYNTAX ERROR: unexpected trailing } */
} /* SYNTAX ERROR: (415): expected <identifier> instead of ; */

interface ITypeEnum
{
public:
    Declaration FindObject(const(wchar_t)* name);
    Declaration FindObjectByValue(uint64_t intVal);
}

class TypeEnum : Type, ITypeEnum
{
    Declaration mDecl;

    ENUMTY mBackingTy;

public:
    this(Declaration decl)
    {
        super(ENUMTY.Tenum);
        mDecl = decl;
        mBackingTy = Tint32;
        assert(decl.IsType());
        bool found = decl.GetBackingTy(mBackingTy);
        //UNREFERENCED_PARAMETER( found );
        assert(found);
    }

    ENUMTY GetBackingTy()
    {
        return mBackingTy;
    }

    Declaration GetDeclaration();
    Type Copy()
    {
        TypeEnum type = new TypeEnum(mDecl);
        type.mBackingTy = mBackingTy;
        return type.Get();
    }

    bool IsIntegral()
    {
        return true;
    }

    bool IsSigned()
    {
        return TypeBasic.IsSigned(mBackingTy);
    }

    bool CanRefMember()
    {
        return true;
    }

    uint32_t GetSize()
    {
        uint32_t size = 0;
        mDecl.GetSize(size);
        return size;
    }

    bool Equals(Type other)
    {
        if (Ty != other.Ty)
            return false;

        return wcscmp(mDecl.GetName(), other.GetDeclaration().GetName()) == 0;
    }

    void _ToString(ref wstring str)
    {
        str.append(mDecl.GetName());
    }

    ITypeEnum AsTypeEnum()
    {
        return this;
    }

    Declaration FindObject(const(wchar_t)* name)
    {
        HRESULT hr = S_OK;
        Declaration childDecl;

        hr = mDecl.FindObject(name, childDecl.Ref());
        if (FAILED(hr))
            return null;

        return childDecl;
    }

    Declaration FindObjectByValue(uint64_t intVal)
    {
        HRESULT hr = S_OK;
        Declaration childDecl;

        hr = mDecl.FindObjectByValue(intVal, childDecl.Ref());
        if (FAILED(hr))
            return null;

        return childDecl;
    }
}

class TypeTypedef : Type
{
protected:
    Type mAliased;
    wstring mName;

public:
    this(const(wchar_t)* name, Type aliasedType)
    {
        super(ENUMTY.Ttypedef);
        mName = fromWStringz(name);
        mAliased = (aliasedType);
        Mod = aliasedType.Mod;
    }

    this(wstring name, Type aliasedType)
    {
        super(ENUMTY.Ttypedef);
        mName = name;
        mAliased = (aliasedType);
        Mod = aliasedType.Mod;
    }

    // Type
    Type Copy()
    {
        Type type = new TypeTypedef(mName, mAliased);
        return type;
    }

    bool IsBasic()
    {
        return mAliased.IsBasic();
    }

    bool IsPointer()
    {
        return mAliased.IsPointer();
    }

    bool IsReference()
    {
        return mAliased.IsReference();
    }

    bool IsSArray()
    {
        return mAliased.IsSArray();
    }

    bool IsDArray()
    {
        return mAliased.IsDArray();
    }

    bool IsScalar()
    {
        return mAliased.IsSArray();
    }

    bool IsBool()
    {
        return mAliased.IsBool();
    }

    bool IsChar()
    {
        return mAliased.IsChar();
    }

    bool IsIntegral()
    {
        return mAliased.IsIntegral();
    }

    bool IsFloatingPoint()
    {
        return mAliased.IsFloatingPoint();
    }

    bool IsSigned()
    {
        return mAliased.IsSigned();
    }

    bool IsReal()
    {
        return mAliased.IsReal();
    }

    bool IsImaginary()
    {
        return mAliased.IsImaginary();
    }

    bool IsComplex()
    {
        return mAliased.IsComplex();
    }

    bool CanRefMember()
    {
        return mAliased.CanRefMember();
    }

    Declaration GetDeclaration()
    {
        return mAliased.GetDeclaration();
    }

    ENUMTY GetBackingTy()
    {
        return mAliased.GetBackingTy();
    }

    uint32_t GetSize()
    {
        return mAliased.GetSize();
    }

    bool Equals(Type other)
    {
        if ( other.Ty != Ty )
            return  false;

        return  wcscmp( (cast(TypeTypedef*) other).mName.c_str(), mName.c_str() ) == 0;
    }
    void _ToString(ref wstring str)
    {
        str ~= mName;
    }

    StdProperty FindProperty(const(wchar_t)* name)
    {
        return  mAliased.FindProperty( name );
    }

    ITypeNext AsTypeNext()
    {
        return  mAliased.AsTypeNext();
    }
    ITypeStruct AsTypeStruct()
    {
        return  mAliased.AsTypeStruct();
    }
    ITypeEnum AsTypeEnum()
    {
        return  mAliased.AsTypeEnum();
    }
    ITypeFunction AsTypeFunction()
    {
        return  mAliased.AsTypeFunction();
    }
    ITypeSArray AsTypeSArray()
    {
        return  mAliased.AsTypeSArray();
    }
    ITypeDArray AsTypeDArray()
    {
        return  mAliased.AsTypeDArray();
    }
    ITypeAArray AsTypeAArray()
    {
        return  mAliased.AsTypeAArray();
    }

    Type Unaliased()
    {
        return  mAliased.Unaliased();
    }
}
