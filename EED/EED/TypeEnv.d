module EED.TypeEnv;

import EED.Type;
import EED.Common;

interface ITypeEnv
{
public:
    void AddRef();
    void Release();

    int GetPointerSize();
    Type* GetType(ENUMTY ty);
    Type* GetVoidPointerType();
    Type* GetAliasType(ALIASTY ty);

    HRESULT NewPointer(Type pointed, ref Type pointer);
    HRESULT NewReference(Type pointed, ref Type pointer);
    HRESULT NewDArray(Type elem, ref Type type);
    HRESULT NewAArray(Type elem, Type key, ref Type type);
    HRESULT NewSArray(Type elem, uint32_t length, ref Type type);
    HRESULT NewStruct(Declaration decl, ref Type type);
    HRESULT NewEnum(Declaration decl, ref Type type);
    HRESULT NewTypedef(const(wchar_t)* name, Type aliasedType, ref Type type);
    HRESULT NewParam(StorageClass storage, Type type, ref Parameter param);
    HRESULT NewParams(ref ParameterList paramList);
    HRESULT NewFunction(Type returnType, ParameterList params, uint8_t callConv,
            int varArgs, ref Type type);
    HRESULT NewDelegate(Type funcType, ref Type type);
}

class TypeEnv : ITypeEnv
{
    int mRefCount;
    Type[ENUMTY.TMAX] mBasic;
    Type mVoidPtr;
    ENUMTY[ALIASTY.ALIASTMAX] mAlias;
    int mPtrSize;

public:
    this(int pointerSize)
    {
        mPtrSize = pointerSize;
    }

    bool Init()
    {
        static ENUMTY[] basicTys = [{
            Tvoid, Tint8, Tuns8, Tint16, Tuns16, Tint32, Tuns32, Tint64, Tuns64,
        }, {
            Tfloat32, Tfloat64, Tfloat80,
        }, {
            Timaginary32, Timaginary64, Timaginary80,
        }, {
            Tcomplex32, Tcomplex64, Tcomplex80,
        }, {Tbool,}, // Tbit is obsolete
        {Tchar, Twchar, Tdchar},];

        for (int i = 0; i < basicTys.length; i++)
        {
            ENUMTY ty = basicTys[i];
            Type type = new TypeBasic(ty);

            mBasic[ty] = type;
        }

        memset(mAlias, 0, mAlias.sizeof);

        if (mPtrSize == 8)
        {
            mAlias[Tsize_t] = Tuns64;
            mAlias[Tptrdiff_t] = Tint64;
        }
        else if (mPtrSize == 4)
        {
            mAlias[Tsize_t] = Tuns32;
            mAlias[Tptrdiff_t] = Tint32;
        }
        else
        {
            assert(false, "Unknown pointer size."w);
            return false;
        }

        mVoidPtr = new TypePointer(GetType(Tvoid), mPtrSize);

        return true;
    }

    void AddRef()
    {
        mRefCount++;
    }

    void Release()
    {
        mRefCount--;
        assert(mRefCount >= 0);
        if (mRefCount == 0)
        {
            delete this;
        }
    }

    int GetPointerSize()
    {
        return mPtrSize;
    }

    Type GetType(ENUMTY ty)
    {
        if ((ty < 0) || (ty >= ENUMTY.TMAX))
            return null;

        return mBasic[ty];
    }

    Type GetVoidPointerType()
    {
        return mVoidPtr;
    }

    Type GetAliasType(ALIASTY ty)
    {
        if ((ty < 0) || (ty >= ALIASTMAX))
            return null;

        return GetType(mAlias[ty]);
    }

    HRESULT NewPointer(Type pointed, ref Type pointer)
    {
        pointer = new TypePointer(pointed, mPtrSize);
        pointer.AddRef();
        return S_OK;
    }

    HRESULT NewReference(Type pointed, ref Type pointer)
    {
        pointer = new TypeReference(pointed, mPtrSize);
        pointer.AddRef();
        return S_OK;
    }

    HRESULT NewDArray(Type elem, ref Type type)
    {
        // TODO: don't allocate these every time
        Type lenType = GetType(mPtrSize == 8 ? ENUMTY.Tuns64 : ENUMTY.Tuns32);
        Type ptrType = new TypePointer(elem, mPtrSize);

        type = new TypeDArray(elem, lenType, ptrType);
        type.AddRef();
        return S_OK;
    }

    HRESULT NewAArray(Type elem, Type key, ref Type type)
    {
        Type ptrType = GetVoidPointerType();

        if (ptrType is null)
            return E_OUTOFMEMORY;

        type = new TypeAArray(elem, key, ptrType.GetSize());
        type.AddRef();
        return S_OK;
    }

    HRESULT NewSArray(Type elem, uint32_t length, ref Type type)
	{
        type = new  TypeSArray( elem, length );
        type.AddRef();
        return  S_OK;
    }

    HRESULT NewStruct(Declaration decl, ref Type type)
	{
        type = new  TypeStruct( decl );
        type.AddRef();
        return  S_OK;
    }
    HRESULT NewEnum(Declaration decl, ref Type type)
	{
        type = new  TypeEnum( decl );
        type.AddRef();
        return  S_OK;
    }
    HRESULT NewTypedef(const(wchar_t)* name, Type aliasedType, ref Type type)
	{
        type = new  TypeTypedef( name, aliasedType );
        type.AddRef();
        return  S_OK;
    }
    HRESULT NewParam(StorageClass storage, Type type, ref Parameter param)
	{
        param = new  Parameter( storage, type );
        param.AddRef();
        return  S_OK;
    }
    HRESULT NewParams(ref ParameterList paramList)
	{
        paramList = new  ParameterList();
        paramList.AddRef();
        return  S_OK;
    }
    HRESULT NewFunction(Type returnType, ParameterList params, uint8_t callConv,
            int varArgs, ref Type type)
			{
        type = new  TypeFunction( params, returnType, callConv, varArgs );
        type.AddRef();
        return  S_OK;
    }
    HRESULT NewDelegate(Type funcType, ref Type type)
	{
        Type ptrToFunc = new  TypePointer( funcType, mPtrSize );
        type = new  TypeDelegate( ptrToFunc );
        type.AddRef();
        return  S_OK;
    }
}
