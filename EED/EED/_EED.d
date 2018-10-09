module EED._EED;

import core.sys.windows.windows;

struct EvalResult
{
    DataObject ObjVal;

    bool ReadOnly;
    bool HasString;
    bool HasChildren;
    bool HasRawChildren;
    bool IsStaticField; // for struct enumerations
    bool IsBaseClass;
    bool IsMostDerivedClass;
}

interface IEEDParsedExpr
{
public:
    void AddRef();
    void Release();

    HRESULT Bind(const EvalOptions options, IValueBinder binder);
    HRESULT Evaluate(const EvalOptions options, IValueBinder binder, EvalResult* result);
}

class EEDParsedExpr : IEEDParsedExpr
{
    long mRefCount;
    //RefPtr < Expression > mExpr;
    Expression mExpr;
    //RefPtr < NameTable > mStrTable; // expr holds refs to strings in here
    NameTable mStrTable;
    //RefPtr < ITypeEnv > mTypeEnv; // eval will need this
    ITypeEnv mTypeEnv;
public:
    this(Expression e, NameTable strTable, ITypeEnv typeEnv)

    {
        //: mRefCount(0), mExpr(e), mStrTable(strTable), mTypeEnv(typeEnv)
        mExpr = e;
        mStrTable = strTable;
        mTypeEnv = typeEnv;
        assert(e != NULL);
        assert(strTable != NULL);
        assert(typeEnv != NULL);
    }

    void AddRef()
    {
        InterlockedIncrement(&mRefCount);
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

    HRESULT Bind(const EvalOptions options, ref IValueBinder binder)
    {
        HRESULT hr = S_OK;
        EvalData evalData = {0};

        evalData.Options = options;
        evalData.TypeEnv = mTypeEnv;

        hr = mExpr.Semantic(evalData, mTypeEnv, binder);
        if (FAILED(hr))
            return hr;

        return S_OK;
    }

    HRESULT Evaluate(const EvalOptions options, ref IValueBinder binder, EvalResult result)
    {
        HRESULT hr = S_OK;
        EvalData evalData = {0};

        evalData.Options = options;
        evalData.TypeEnv = mTypeEnv;

        hr = mExpr.Evaluate(EvalMode_Value, evalData, binder, result.ObjVal);
        if (FAILED(hr))
            return hr;

        FillValueTraits(result, mExpr);

        return S_OK;
    }

}

interface IEEDEnumValues
{
public:
    void AddRef();
    void Release();

    @nogc @property uint GetCount();
    @nogc @property uint GetIndex();
    @nogc void Reset();
    HRESULT Skip(uint count);
    HRESULT Clone(IEEDEnumValues copiedEnum);

    /// TODO: can we use something else, like CString, instead of using wstring here?
    /// Now we're using D Strings!
    HRESULT EvaluateNext(const ref EvalOptions options, ref EvalResult result,
            ref wstring name, ref wstring fullName);
}

HRESULT Init()
{
    InitPropTables();
    return S_OK;
}

void Uninit()
{
    FreePropTables();
}

static bool gShowVTable;

HRESULT MakeTypeEnv(int ptrSize, ref ITypeEnv typeEnv)
{
    TypeEnv env = new TypeEnv(ptrSize);

    if (env == NULL)
        return E_OUTOFMEMORY;

    if (!env.Init())
        return E_FAIL;

    typeEnv = env;
    return S_OK;
}

HRESULT MakeNameTable(ref NameTable nameTable)
{
    nameTable = new SimpleNameTable();

    if (nameTable == NULL)
        return E_OUTOFMEMORY;

    nameTable.AddRef();
    return S_OK;
}

HRESULT ParseText(const wchar_t* text, ITypeEnv typeEnv, NameTable strTable, IEEDParsedExpr expr)
{
    if ((text == NULL) || (typeEnv == NULL) || (strTable == NULL))
        return E_INVALIDARG;

    Scanner scanner = new Scanner(text, wcslen(text), strTable);
    Parser parser = new Parser( & scanner, typeEnv);
    Expression e;

    try
    {
        scanner.NextToken();
        e = parser.ParseExpression();

        if (scanner.GetToken().Code != TOKeof)
            return E_MAGOEE_SYNTAX_ERROR;
    }
    catch (int errCode)
    {
        UNREFERENCED_PARAMETER(errCode);
        _RPT2(_CRT_WARN, "Failed to parse, error %d. Text=\"%ls\".\n", errCode, text);
        return E_MAGOEE_SYNTAX_ERROR;
    }

    expr = new EEDParsedExpr(e, strTable, typeEnv);
    if (expr == NULL)
        return E_OUTOFMEMORY;

    expr.AddRef();

    return S_OK;
}

HRESULT StripFormatSpecifier(ref wstring text, FormatOptions fmtopt)
{
    size_t textlen = text.length;
    if (textlen > 2 && text[textlen - 2] == ',')
    {
        fmtopt.specifier = text[textlen - 1];
        text.length = textlen - 2;
    }
    return S_OK;
}

HRESULT AppendFormatSpecifier(ref wstring text, const FormatOptions fmtopt)
{
    if (fmtopt.specifier)
    {
        text.push_back(',');
        text.push_back(cast(wchar_t) fmtopt.specifier);
    }
    return S_OK;
}

HRESULT EnumValueChildren(IValueBinder binder, const wchar_t* parentExprText, const DataObject parentVal,
        ITypeEnv typeEnv, NameTable strTable, const FormatOptions fmtopts,
        ref IEEDEnumValues enumerator)
{
    if ((binder == NULL) || (parentExprText == NULL) || (typeEnv == NULL) || (strTable == NULL))
        return E_INVALIDARG;

    HRESULT hr = S_OK;
    EEDEnumValues en;
    DataObject pointeeObj = {0};
    wstring pointeeExpr;
    const DataObject* pparentVal = &parentVal;

L_retry:
    if (pparentVal._Type.IsReference())
    {
        en = new EEDEnumStruct(true);
    }
    else if (pparentVal._Type.IsPointer())
    {
        // no children for void pointers
        auto ntype = pparentVal._Type.AsTypeNext.GetNext();
        if (ntype == NULL || ntype.GetBackingTy() == Tvoid)
            return E_FAIL;

        if (ntype.IsReference() || ntype.IsSArray() || ntype.IsDArray()
                || ntype.IsAArray() || ntype.AsTypeStruct())
        {
            pointeeObj._Type = ntype;
            pointeeObj.Addr = pparentVal.Value.Addr;

            hr = binder.GetValue(pointeeObj.Addr, pointeeObj._Type, pointeeObj.Value);
            if (hr == S_OK)
            {
                pointeeExpr ~= "*("w ~= parentExprText ~= ')';
                parentExprText = pointeeExpr.c_str();
                pparentVal = &pointeeObj;
                goto L_retry;
            }
        }
        en = new EEDEnumPointer();
    }
    else if (pparentVal._Type.IsSArray())
    {
        en = new EEDEnumSArray();
    }
    else if (pparentVal._Type.IsDArray())
    {
        if (fmtopts.specifier == FormatSpecRaw)
            en = new EEDEnumRawDArray();
        else
            en = new EEDEnumDArray();
    }
    else if (pparentVal._Type.IsAArray())
    {
        en = new EEDEnumAArray(binder.GetAAVersion());
    }
    else if (pparentVal._Type.AsTypeStruct() != NULL)
    {
        en = new EEDEnumStruct();
    }
    else
        return E_FAIL;

    if (en == NULL)
        return E_OUTOFMEMORY;

    hr = en.Init(binder, parentExprText, *pparentVal, typeEnv, strTable);
    if (FAILED(hr))
        return hr;

    enumerator = en.Detach();

    return S_OK;
}

void FillValueTraits(ref EvalResult result, Expression expr)
{
    {
        result.ReadOnly = true;
        result.HasString = false;
        result.HasChildren = false;
        result.HasRawChildren = false;

        if (!expr || expr.Kind == DataKind_Value)
        {
            Type type = result.ObjVal._Type;

            // ReadOnly
            if ((type.AsTypeStruct() != NULL) || type.IsSArray())
            {
                // some types just don't allow assignment
            }
            else if (result.ObjVal.Addr != 0)
            {
                result.ReadOnly = false;
            }
            else if (expr && expr.AsNamingExpression() != NULL)
            {
                Declaration* decl = expr.AsNamingExpression.Decl;
                result.ReadOnly = (decl == NULL) || decl.IsConstant();
            }

            // HasString
            if ((type.AsTypeNext() != NULL) && type.AsTypeNext.GetNext.IsChar())
            {
                if (type.IsPointer())
                    result.HasString = result.ObjVal.Value.Addr != 0;
                else if (type.IsSArray() || type.IsDArray())
                    result.HasString = true;
            }

            // HasChildren/HasRawChildren
            if (type.IsPointer())
            {
                if (type.AsTypeNext.GetNext.GetBackingTy() == Tvoid)
                    result.HasChildren = result.HasRawChildren = false;
                else
                    result.HasChildren = result.HasRawChildren = result.ObjVal.Value.Addr != 0;
            }
            else if (ITypeSArray* sa = type.AsTypeSArray())
            {
                result.HasChildren = result.HasRawChildren = sa.GetLength() > 0;
            }
            else if (type.IsDArray())
            {
                result.HasChildren = result.ObjVal.Value.Array.Length > 0;
                result.HasRawChildren = true;
            }
            else if (type.IsAArray())
            {
                result.HasChildren = result.HasRawChildren = result.ObjVal.Value.Addr != 0;
            }
            else if (type.AsTypeStruct())
            {
                result.HasChildren = result.HasRawChildren = true;
            }
        }
    }
}

static const wchar_t[] gCommonErrStr = ": Error: "w;

static const wchar_t*[] gErrStrs = [
    "Expression couldn't be evaluated"w, "Syntax error"w, "Incompatible types for operator"w, "Value expected"w, "Expression has no type"w,
        "Type resolve failed"w, "Bad cast"w, "Expression has no address"w, "L-value expected"w,
        "Can't cast to bool"w, "Divide by zero"w, "Bad indexing operation"w,
        "Symbol not found"w, "Element not found"w,
        "Too many function arguments"w,
        "Too few function arguments"w,
        "Calling functions not implemented"w,
        "Cannot call functions with arguments"w,
        "Failed to read register"w, "Unsupported calling convention"w,
        "Function calls not allowed"w, "Function call may have side effects"w,
];

HRESULT GetErrorString(HRESULT hresult, ref wstring outStr)
{
    DWORD fac = HRESULT_FACILITY(hresult);
    DWORD code = HRESULT_CODE(hresult);

    if (fac != HR_FACILITY)
        return S_FALSE;

    if (code >= _countof(gErrStrs))
        code = 0;

    wchar_t[10] codeStr;
    swprintf_s(codeStr, 10, "D%04d", code + 1);
    outStr = codeStr;
    outStr.append(gCommonErrStr);
    outStr.append(gErrStrs[code]);

    return S_OK;
}
