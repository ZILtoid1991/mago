module EED.EnumValues;

import EED._EED;
import EED.Common;

//import core.stdc.inttypes;

class EEDEnumValues : IEEDEnumValues
{
    long mRefCount;

protected:
    wstring mParentExprText;
    DataObject mParentVal;
    IValueBinder* mBinder;
    RefPtr!(ITypeEnv) mTypeEnv;
    RefPtr!(NameTable) mStrTable;
public:
    this()
    {

    }

    void Release()
    {
        long newRef = InterlockedDecrement(&mRefCount);
        assert(newRef >= 0);
        if (newRef == 0)
        {
            delete this;
        }
    }

    HRESULT Init(IValueBinder binder, const wchar_t* parentExprText,
            const ref DataObject parentVal, ITypeEnv typeEnv, NameTable strTable)
    {
        mBinder = binder;
        mParentExprText = parentExprText;
        mParentVal = parentVal;
        mTypeEnv = typeEnv;
        mStrTable = strTable;

        return S_OK;
    }

    // fallback when unable to evaluate directly from parent value
    HRESULT EvaluateExpr(const ref EvalOptions options, ref EvalResult result, ref wstring expr)
    {
        HRESULT hr = S_OK;
        IEEDParsedExpr parsedExpr;

        hr = ParseText(expr.c_str(), mTypeEnv, mStrTable, parsedExpr);
        if (FAILED(hr))
            return hr;

        hr = parsedExpr.Bind(options, mBinder);
        if (FAILED(hr))
            return hr;

        hr = parsedExpr.Evaluate(options, mBinder, result);
        if (FAILED(hr))
            return hr;

        return S_OK;
    }
}

class EEDEnumPointer : EEDEnumValues
{
    uint32_t mCountDone;

public:
    this()
    {
        super();
    }

    uint32_t GetCount()
    {
        return 1;
    }

    uint32_t GetIndex()
    {
        return mCountDone;
    }

    void Reset()
    {
        mCountDone = 0;
    }

    HRESULT Skip(uint32_t count)
    {
        if (count > (GetCount() - mCountDone))
        {
            mCountDone = GetCount();
            return S_FALSE;
        }

        mCountDone += count;

        return S_OK;
    }

    HRESULT Clone(IEEDEnumValues copiedEnum)
    {
        HRESULT hr = S_OK;
        RefPtr en = new EEDEnumPointer();

        if (en == NULL)
            return E_OUTOFMEMORY;

        hr = en.Init(mBinder, mParentExprText.c_str(), mParentVal, mTypeEnv, mStrTable);
        if (FAILED(hr))
            return hr;

        en.mCountDone = mCountDone;

        copiedEnum = en;
        return S_OK;
    }

    HRESULT EvaluateNext(const ref EvalOptions options, ref EvalResult result,
            ref wstring name, ref wstring fullName)
    {
        if (mCountDone >= GetCount())
            return E_FAIL;

        IEEDParsedExpr parsedExpr;

        name.length = 9;
        fullName.length = 0;
        fullName ~= "*("w;
        fullName ~= mParentExprText;
        fullName ~= ')';

        mCountDone++;

        if (mParentVal.Value.Addr == 0)
            return E_MAGOEE_NO_ADDRESS;

        auto tn = mParentVal._Type[0].AsTypeNext();
        if (tn == NULL)
            return E_FAIL;

        result.ObjVal._Type = tn[0].GetNext();
        result.ObjVal.Addr = mParentVal.Value.Addr;

        HRESULT hr = mBinder[0].GetValue(result.ObjVal.Addr,
                result.ObjVal._Type, result.ObjVal.Value);
        if (FAILED(hr))
            return hr;

        FillValueTraits(result, nullptr);
        return S_OK;
    }
}

class EEDEnumSArray : EEDEnumValues
{
    uint32_t mCountDone;

public:
    this()
    {
        super();
    }

    uint32_t GetCount()
    {
        uint32_t count = 0;

        if (mParentVal._Type[0].IsSArray())
        {
            count = mParentVal._Type[0].AsTypeSArray()[0].GetLength();
        }
        else if (mParentVal._Type.IsDArray())
        {
            if (mParentVal.Value.Array.Length > MaxArrayLength)
                count = MaxArrayLength;
            else
                count = cast(uint32_t) mParentVal.Value.Array.Length;
        }

        return count;
    }

    @nogc @property uint32_t GetIndex()
    {
        return mCountDone;
    }

    @nogc void Reset()
    {
        mCountDone = 0;
    }

    HRESULT Skip(uint32_t count)
    {
        if (count > (GetCount() - mCountDone))
        {
            mCountDone = GetCount();
            return S_FALSE;
        }

        mCountDone += count;

        return S_OK;
    }

    HRESULT Clone(IEEDEnumValues copiedEnum)
    {
        HRESULT hr = S_OK;
        EEDEnumSArray en = new EEDEnumSArray();

        if (en == NULL)
            return E_OUTOFMEMORY;

        hr = en.Init(mBinder, mParentExprText.c_str(), mParentVal, mTypeEnv, mStrTable);
        if (FAILED(hr))
            return hr;

        en.mCountDone = mCountDone;

        copiedEnum = en.Detach();
        return S_OK;
    }

    HRESULT EvaluateNext(const ref EvalOptions options, ref EvalResult result,
            ref wstring name, ref wstring fullName)
    {
        if (mCountDone >= GetCount())
            return E_FAIL;

        // 4294967295
        const int MaxIntStrLen = 10;
        // "[indexInt]", and add some padding
        const int MaxIndexStrLen = MaxIntStrLen + 2 + 10;

        wchar_t[MaxIndexStrLen + 1] indexStr = ""w;

        swprintf_s(indexStr, "[%d]"w, mCountDone);

        name.clear();
        name.append(indexStr);

        bool isIdent = IsIdentifier(mParentExprText.data());
        fullName.clear();
        if (!isIdent)
            fullName.append("("w);
        fullName.append(mParentExprText);
        if (!isIdent)
            fullName.append(")"w);
        fullName.append(name);

        uint32_t index = mCountDone++;

        Address addr;
        if (mParentVal._Type.IsSArray())
        {
            result.ObjVal._Type[0] = mParentVal._Type[0].AsTypeSArray[0].GetElement();
            addr = mParentVal.Addr;
        }
        else if (mParentVal._Type[0].IsDArray())
        {
            result.ObjVal._Type[0] = mParentVal._Type[0].AsTypeDArray[0].GetElement();
            addr = mParentVal.Value.Array.Addr;
        }
        else
            return E_FAIL;

        if (addr == 0)
            return E_MAGOEE_NO_ADDRESS;

        result.ObjVal.Addr = addr + index * result.ObjVal._Type[0].GetSize();

        HRESULT hr = mBinder.GetValue(result.ObjVal.Addr, result.ObjVal._Type, result.ObjVal.Value);
        if (FAILED(hr))
            return hr;

        FillValueTraits(result, nullptr);
        return S_OK;
    }
}

//alias EEDEnumSArray = EEDEnumDArray;

class EEDEnumRawDArray : EEDEnumValues
{
    uint32_t mCountDone;

public:
    this()
    {
        super();
    }

    @nogc @property uint32_t GetCount()
    {
        return 2;
    }

    @nogc @property uint32_t GetIndex()
    {
        return mCountDone;
    }

    @nogc void Reset()
    {
        mCountDone = 0;
    }

    HRESULT Skip(uint32_t count)
    {
        if (count > (GetCount() - mCountDone))
        {
            mCountDone = GetCount();
            return S_FALSE;
        }

        mCountDone += count;

        return S_OK;
    }

    HRESULT Clone(IEEDEnumValues copiedEnum)
    {
        HRESULT hr = S_OK;
        EEDEnumRawDArray en = new EEDEnumRawDArray();

        if (en == NULL)
            return E_OUTOFMEMORY;

        hr = en.Init(mBinder, mParentExprText.c_str(), mParentVal, mTypeEnv, mStrTable);
        if (FAILED(hr))
            return hr;

        en.mCountDone = mCountDone;

        copiedEnum = en;
        return S_OK;
    }

    HRESULT EvaluateNext(const ref EvalOptions options, ref EvalResult result,
            ref wstring name, ref wstring fullName)
    {
        if (mCountDone >= GetCount())
            return E_FAIL;

        const wchar_t* field = (mCountDone == 0 ? "length"w : "ptr"w);

        name.length = 0;
        name ~= field;

        bool isIdent = IsIdentifier(mParentExprText.data());
        fullName.length = 0;
        if (!isIdent)
            fullName ~= "("w;
        fullName ~= (mParentExprText);
        if (!isIdent)
            fullName ~= ")"w;
        fullName ~= "."w;
        fullName ~= name;

        mCountDone++;
        return EvaluateExpr(options, result, fullName);
    }
}

class EEDEnumAArray : EEDEnumValues
{
    int mAAVersion;
    uint64_t mCountDone;
    uint64_t mBucketIndex;
    Address mNextNode;
    union
    {
        BB64 mBB;
        BB64_V1 mBB_V1;
    };

    HRESULT ReadBB()
    {
        HRESULT hr = S_OK;
        uint32_t sizeRead;

        if (mBB.nodes != UINT64_MAX)
            return S_OK;

        assert(mParentVal._Type[0].IsAArray());
        Address address = mParentVal.Value.Addr;

        if (address == NULL)
        {
            memset( & mBB, 0, mBB.sizeof);
            return S_OK;
        }

        if (mParentVal._Type[0].GetSize() == 4)
        {
            BB32 bb32;
            BB32_V1 bb32_v1;
            if (mAAVersion == 1)
                hr = mBinder.ReadMemory(address, bb32_v1.sizeof, sizeRead,
                        cast(uint8_t*)&bb32_v1);
            else
                hr = mBinder.ReadMemory(address, bb32.sizeof, sizeRead, cast(uint8_t*)&bb32);

            if (FAILED(hr))
                return hr;

            if (mAAVersion == -1)
            {
                if ((bb32.b.length <= 4 && bb32.b.ptr != address + bb32.sizeof)
                        || // init bucket in Impl
                        (bb32.b.length > 4 && (bb32.b.length & (bb32.b.length - 1)) == 0))
                {
                    mAAVersion = 1; // power of 2 indicates new AA
                    hr = mBinder.ReadMemory(address, bb32_v1.sizeof, sizeRead,
                            cast(uint8_t*)&bb32_v1);
                    if (FAILED(hr))
                        return hr;
                }
                else
                {
                    mAAVersion = 0;
                }
            }

            if (mAAVersion == 1)
            {
                mBB_V1.buckets.length = bb32_v1.buckets.length;
                mBB_V1.buckets.ptr = bb32_v1.buckets.ptr;
                mBB_V1.used = bb32_v1.used;
                mBB_V1.deleted = bb32_v1.deleted;
                mBB_V1.entryTI = bb32_v1.entryTI;
                mBB_V1.firstUsed = bb32_v1.firstUsed;
                mBB_V1.keysz = bb32_v1.keysz;
                mBB_V1.valsz = bb32_v1.valsz;
                mBB_V1.valoff = bb32_v1.valoff;
                mBB_V1.flags = bb32_v1.flags;
            }
            else
            {
                if (bb32.firstUsedBucket > bb32.nodes)
                {
                    bb32.keyti = bb32.firstUsedBucket; // compatibility fix for dmd before 2.067
                    bb32.firstUsedBucket = 0;
                }
                mBB.b.length = bb32.b.length;
                mBB.b.ptr = bb32.b.ptr;
                mBB.firstUsedBucket = bb32.firstUsedBucket;
                mBB.keyti = bb32.keyti;
                mBB.nodes = bb32.nodes;
            }
        }
        else
        {
            if (mAAVersion == 1)
                hr = mBinder.ReadMemory(address, mBB_V1.sizeof , sizeRead, cast(uint8_t*)&mBB_V1);
            else
                hr = mBinder.ReadMemory(address, mBB.sizeof , sizeRead, cast(uint8_t*)&mBB);
            if (FAILED(hr))
                return hr;

            if (mAAVersion == -1)
            {
                if ((mBB.b.length <= 4 && mBB.b.ptr != address + mBB.sizeof )
                        || // init bucket in Impl
                        (mBB.b.length > 4 && (mBB.b.length & (mBB.b.length - 1)) == 0))
                {
                    mAAVersion = 1; // power of 2 indicates new AA
                    hr = mBinder.ReadMemory(address, mBB_V1.sizeof , sizeRead,
                            cast(uint8_t * ) & mBB_V1);
                    if (FAILED(hr))
                        return hr;
                }
                else
                {
                    mAAVersion = 0;
                }
            }

            if (mAAVersion == 0 && mBB.firstUsedBucket > mBB.nodes)
            {
                mBB.keyti = mBB.firstUsedBucket; // compatibility fix for dmd before 2.067
                mBB.firstUsedBucket = 0;
            }
        }

        return S_OK;
    }
    HRESULT ReadAddress(Address baseAddr, uint64_t index, Address ptrValue)
    {
        HRESULT hr = S_OK;
        uint32_t ptrSize = mParentVal._Type.GetSize();
        uint64_t addr = baseAddr + (index * ptrSize);
        uint32_t sizeRead;

        if (ptrSize == 4)
        {
            uint32_t ptrValue32;

            hr = mBinder.ReadMemory(addr, ptrSize, sizeRead, cast(uint8_t*)&ptrValue32);
            if (FAILED(hr))
                return hr;

            ptrValue = ptrValue32;
        }
        else
        {
            hr = mBinder.ReadMemory(addr, ptrSize, sizeRead, cast(uint8_t*)&ptrValue);
            if (FAILED(hr))
                return hr;
        }

        return S_OK;
    }

    HRESULT FindCurrent()
    {
        if (mAAVersion == 1)
        {
            uint32_t ptrSize = mParentVal._Type[0].GetSize();
            uint64_t hashFilledMark = 1L << (8 * ptrSize - 1);

            while (mNextNode == NULL && mBucketIndex < mBB.b.length)
            {
                Address hash;
                HRESULT hr = ReadAddress(mBB.b.ptr, 2 * mBucketIndex, hash);
                if (FAILED(hr))
                    return hr;

                if (hash & hashFilledMark)
                    return ReadAddress(mBB.b.ptr, 2 * mBucketIndex + 1, mNextNode);

                mBucketIndex++;
            }
        }
        else
        {
            while (mNextNode == NULL && mBucketIndex < mBB.b.length)
            {
                HRESULT hr = ReadAddress(mBB.b.ptr, mBucketIndex, mNextNode);
                if (FAILED(hr))
                    return hr;

                if (mNextNode != NULL)
                    return S_OK;

                mBucketIndex++;
            }
        }
        return S_OK;
    }

    HRESULT FindNext()
    {
        HRESULT hr = FindCurrent();
        if (FAILED(hr))
            return hr;

        if (mNextNode)
        {
            if (mAAVersion == 1)
            {
                mNextNode = NULL;
            }
            else
            {
                hr = ReadAddress(mNextNode, 0, mNextNode);
                if (FAILED(hr))
                    return hr;

                if (mNextNode != NULL)
                    return S_OK;
            }
            mBucketIndex++;
        }
        return FindCurrent();
    }

    uint32_t AlignTSize(uint32_t size)
    {
        uint32_t ptrSize = mParentVal._Type[0].GetSize();
        if (ptrSize == 4)
            return (size + sizeof(uint32_t) - 1) & ~(sizeof(uint32_t) - 1);
        else
            return (size + 16 - 1) & ~(16 - 1);
    }

public:
    this(int aaVersion)
    {
        mBB.nodes = UINT64_MAX;
        //mBucketIndex = 0;
        //mNextNode = NULL;
        super();
        this.mAAVersion = aaVersion;
    }

    @nogc @property uint32_t GetCount()
    {
        uint32_t count = 0;

        HRESULT hr = ReadBB();
        if (!FAILED(hr))
            count = mAAVersion == 1 ? mBB_V1.used - mBB_V1.deleted : cast(uint32_t) mBB.nodes;

        return count;
    }

    @nogc @property uint32_t GetIndex()
    {
        return cast(uint32_t) mCountDone;
    }

    @nogc void Reset()
    {
        mCountDone = 0;
        mBucketIndex = 0;
        mNextNode = NULL;
    }

    HRESULT Skip(uint32_t count)
    {
        if (count > (GetCount() - mCountDone))
        {
            mBucketIndex = mBB.b.length;
            mNextNode = NULL;
            mCountDone = GetCount();
            return S_FALSE;
        }

        HRESULT hr = FindCurrent();
        if (FAILED(hr))
            return hr;

        for (uint32_t i = 0; i < count; i++)
        {
            hr = FindNext();
            if (FAILED(hr))
                return E_FAIL;

            mCountDone++;
        }

        return S_OK;
    }

    HRESULT Clone(IEEDEnumValues copiedEnum)
    {
        HRESULT hr = S_OK;
        EEDEnumAArray en = new EEDEnumAArray(mAAVersion);

        if (en == NULL)
            return E_OUTOFMEMORY;

        hr = en.Init(mBinder, mParentExprText.c_str(), mParentVal, mTypeEnv, mStrTable);
        if (FAILED(hr))
            return hr;

        en.mAAVersion = mAAVersion;
        if (mAAVersion == 1)
            en.mBB_V1 = mBB_V1;
        else
            en.mBB = mBB;
        en.mCountDone = mCountDone;
        en.mBucketIndex = mBucketIndex;
        en.mNextNode = mNextNode;

        copiedEnum = en;
        return S_OK;
    }

    HRESULT EvaluateNext(const EvalOptions options, EvalResult result,
            ref wstring name, ref wstring fullName)
    {
        if (mCountDone >= GetCount())
            return E_FAIL;

        HRESULT hr = FindCurrent();
        if (FAILED(hr))
            return hr;

        if (!mNextNode)
            return E_FAIL;

        assert(mParentVal._Type.IsAArray());
        ITypeAArray* aa = mParentVal._Type.AsTypeAArray();

        uint32_t ptrSize = mParentVal._Type.GetSize();

        DataObject keyobj;
        keyobj._Type = aa.GetIndex();
        keyobj.Addr = mNextNode + (mAAVersion == 1 ? 0 : 2 * ptrSize);

        hr = mBinder.GetValue(keyobj.Addr, keyobj._Type, keyobj.Value);
        if (FAILED(hr))
            return hr;

        wstring keystr;
        FormatOptions fmt = FormatOptions(10);
        hr = FormatValue(mBinder, keyobj, fmt, keystr, kMaxFormatValueLength);
        if (FAILED(hr))
            return hr;

        name = "["w ~ keystr ~ "]"w;

        bool isIdent = IsIdentifier(mParentExprText.data());
        fullName.clear();
        if (!isIdent)
            fullName ~= "("w;
        fullName ~= mParentExprText;
        if (!isIdent)
            fullName ~= ")"w;
        fullName ~= name;

        uint32_t alignKeySize = (mAAVersion == 1 ? mBB_V1.valoff : AlignTSize(aa.GetIndex.GetSize()));

        result.ObjVal.Addr = keyobj.Addr + alignKeySize;
        result.ObjVal._Type = aa.GetElement();
        hr = mBinder.GetValue(result.ObjVal.Addr, result.ObjVal._Type, result.ObjVal.Value);
        if (FAILED(hr))
            return hr;

        FillValueTraits(result, nullptr);
        mCountDone++;

        return FindNext();
    }
}
class EEDEnumStruct : EEDEnumValues
{
    uint32_t mCountDone;
    bool mSkipHeadRef;
    bool mHasVTable;

    IEnumDeclarationMembers mMembers; //RefPtr<IEnumDeclarationMembers> mMembers;
    wstring mClassName;

public:
    this(bool skipHeadRef = false)
    {
        this.mSkipHeadRef = skipHeadRef;
    }

    HRESULT Init(IValueBinder binder, const wchar_t* parentExprText,
            const ref DataObject parentVal, ITypeEnv typeEnv, NameTable strTable)
    {
        HRESULT hr = S_OK;
        Declaration decl;
        IEnumDeclarationMembers members;
        DataObject parentValCopy = parentVal;

        if (parentValCopy._Type == NULL)
            return E_INVALIDARG;

        if (mSkipHeadRef && parentValCopy._Type[0].IsReference())
        {
            parentValCopy._Type = parentValCopy._Type[0].AsTypeNext.GetNext();
            parentValCopy.Addr = parentValCopy.Value.Addr;
        }

        ITypeStruct* typeStruct = parentValCopy._Type[0].AsTypeStruct();
        if (typeStruct == NULL)
            return E_INVALIDARG;

        decl = parentValCopy._Type.GetDeclaration();
        if (decl == NULL)
            return E_INVALIDARG;

        if (!decl.EnumMembers(members))
            return E_INVALIDARG;

        hr = EEDEnumValues.Init(binder, parentExprText, parentValCopy, typeEnv, strTable);
        if (FAILED(hr))
            return hr;

        MagoEE.UdtKind kind;
        if (decl.GetUdtKind(kind) && kind == MagoEE.Udt_Class
                && wcsncmp(parentExprText, "cast("w, 5) != 0) // already inside the base/derived class enumeration?
                {
            Address addr = 0;
            uint32_t sizeRead;
            hr = binder.ReadMemory(parentVal.Addr, typeEnv.GetPointerSize(),
                    sizeRead, cast(uint8_t*)&addr);
            if (SUCCEEDED(hr) && sizeRead == uint32_t(typeEnv.GetPointerSize()))
                binder.GetClassName(addr, mClassName);

            // don't show runtime class if it is the same as the compile time type
            if (!mClassName.empty() && mClassName == decl.GetName())
                mClassName.clear();

            if (gShowVTable)
            {
                // if the class has a virtual function table, fake a member "__vfptr" (it is skipped by normal member iteration)
                Declaration vshape;
                mHasVTable = decl.GetVTableShape(vshape.Ref()) && vshape;
            }
        }

        mMembers = members;

        return S_OK;
    }

    uint32_t GetCount()
    {
        return mMembers.GetCount() + (mClassName.empty() ? 0 : 1) + (mHasVTable ? 1 : 0);
    }

    uint32_t GetIndex()
    {
        return mCountDone;
    }

    void Reset()
    {
        mCountDone = 0;
        mMembers.Reset();
    }

    HRESULT Skip(uint32_t count)
    {
        if (count > (GetCount() - mCountDone))
        {
            mCountDone = GetCount();
            return S_FALSE;
        }

        if (count > 0 && mCountDone == 0 && !mClassName.empty())
        {
            mCountDone++;
            count--;
        }
        if (count > 0 && mCountDone == VShapePos())
        {
            mCountDone++;
            count--;
        }
        mCountDone += count;
        mMembers.Skip(count);

        return S_OK;
    }

    HRESULT Clone(IEEDEnumValues copiedEnum)
    {
        HRESULT hr = S_OK;
        EEDEnumStruct en = new EEDEnumStruct(mSkipHeadRef);

        if (en == NULL)
            return E_OUTOFMEMORY;

        hr = en.Init(mBinder, mParentExprText.c_str(), mParentVal, mTypeEnv, mStrTable);
        if (FAILED(hr))
            return hr;

        en.Skip(mCountDone);

        copiedEnum = en.Detach();
        return S_OK;
    }

    HRESULT EvaluateNext(const EvalOptions options, EvalResult result,
            ref wstring name, ref wstring fullName)
    {
        if (mCountDone >= GetCount())
            return E_FAIL;

        HRESULT hr = S_OK;
        Declaration decl;

        name.length = 0;
        fullName.length = 0;

        if (mCountDone == 0 && !mClassName.empty())
        {
            name = "["w ~ mClassName ~ "]"w;
            fullName = "cast("w ~ mClassName ~ ")("w ~ mParentExprText ~ ")"w;
            result.IsMostDerivedClass = true;
            mCountDone++;
        }
        else if (mCountDone == VShapePos())
        {
            name = "__vfptr"w;
            fullName = "("w ~ mParentExprText ~ ").__vfptr"w;
            mCountDone++;

            Address addr = mParentVal._Type.IsReference() ? mParentVal.Value.Addr : mParentVal.Addr;
            if (addr == 0)
                return E_MAGOEE_NO_ADDRESS;

            RefPtr!(Declaration) vshape;
            decl = mParentVal._Type.GetDeclaration();
            if (!decl.GetVTableShape(vshape.Ref()))
                return E_FAIL;

            int offset = 0;
            if (!vshape.GetOffset(offset))
                return E_FAIL;

            if (!vshape.GetType(result.ObjVal._Type.Ref()))
                return E_FAIL;

            result.ObjVal.Addr = addr + offset;

            hr = mBinder.GetValue(result.ObjVal.Addr, result.ObjVal._Type, result.ObjVal.Value);
            if (FAILED(hr))
                return hr;

            FillValueTraits(result, nullptr);
            return S_OK;
        }
        else
        {
            if (!mMembers.Next(decl.Ref()))
                return E_FAIL;

            mCountDone++;
            if (decl.IsBaseClass())
            {
                if (!NameBaseClass(decl, name, fullName))
                    return E_FAIL;
                result.IsBaseClass = true;
            }
            else if (decl.IsStaticField())
            {
                if (!NameStaticMember(decl, name, fullName))
                    return E_FAIL;
                result.IsStaticField = true;
            }
            else if (decl.IsField())
            {
                if (!NameRegularMember(decl, name, fullName))
                    return E_FAIL;

                Address addr = mParentVal._Type[0].IsReference()
                    ? mParentVal.Value.Addr : mParentVal.Addr;

                if (addr == 0)
                    return E_MAGOEE_NO_ADDRESS;

                int offset = 0;
                if (!decl.GetOffset(offset))
                    return E_FAIL;

                if (!decl.GetType(result.ObjVal._Type.Ref()))
                    return E_FAIL;

                result.ObjVal.Addr = addr + offset;

                hr = mBinder.GetValue(result.ObjVal.Addr, result.ObjVal._Type, result.ObjVal.Value);
                if (FAILED(hr))
                    return hr;

                FillValueTraits(result, nullptr);
                return S_OK;
            }
        }

        return EvaluateExpr(options, result, fullName);
    }

private:
    bool NameBaseClass(Declaration decl, ref wstring name, ref wstring fullName)
    {
        Type baseType;
        Declaration baseDecl;

        if (!decl.GetType(baseType))
            return false;

        baseDecl = baseType.GetDeclaration();
        if (baseDecl == NULL)
            return false;

        name.append(baseDecl.GetName());

        if (!mSkipHeadRef)
            fullName.append("*"w);

        fullName.append("cast("w);
        fullName.append(baseDecl.GetName());

        if (mSkipHeadRef)
            fullName.append(")("w);
        else
            fullName.append("*)&("w);

        fullName.append(mParentExprText);
        fullName.append(")"w);

        return true;
    }

    bool NameStaticMember(Declaration decl, ref wstring name, ref wstring fullName)
    {
        name ~= decl.GetName();

        if (mParentVal._Type)
            fullName ~= mParentVal._Type.toString;
        fullName ~= "."w;
        fullName ~= name;

        return true;
    }

    bool NameRegularMember(Declaration decl, ref wstring name, ref wstring fullName)
    {
        name ~= decl.GetName();

        const bool isIdent = IsIdentifier(mParentExprText.data());
        if (!isIdent)
            fullName ~= "("w;
        fullName ~= mParentExprText;
        if (!isIdent)
            fullName ~= ")"w;
        fullName ~= "."w;
        fullName ~= name;

        return true;
    }

    uint32_t VShapePos() const
    {
        if (!mHasVTable)
            return UINT32_MAX;
        return mClassName.empty() ? 0 : 1;
    }
}
