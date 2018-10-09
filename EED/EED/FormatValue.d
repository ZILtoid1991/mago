module EED.FormatValue;

import EED.Common;

static immutable uint32_t kMaxFormatValueLength = 100; /// soft limit to eventually abort recursions

const uint32_t MaxStringLen = 1048576;
const uint32_t RawStringChunkSize = 65536;

// RawStringChunkSize: FormatRawStringInternal uses this constant to define
// the size of a buffer it uses for Unicode translation. This many bytes
// are meant to be read from the debuggee at a time.
//
// I didn't want the size to be in the megabytes, but it should still be 
// big enough that we don't need to make many cross process memory reads.
//
// It should be a multiple of four, so that if we break up a code point at
// the end of a read, we can always get back on track quickly during the 
// next chunk.

HRESULT FormatSimpleReal(ref const Real10 val, int digits, ref wstring outStr)
{
    wchar_t[Real10.Float80DecStrLen + 1] buf = "";

    val.ToString(buf, _countof(buf), digits + 2); // a more digit than what's exact

    outStr.append(buf);

    return S_OK;
}

HRESULT FormatComplex(ref const DataObject objVal, ref wstring outStr)
{
    HRESULT hr = S_OK;
    int digits;
    if (!PropertyFloatDigits.GetDigits(objVal._Type, digits))
        return E_INVALIDARG;

    hr = FormatSimpleReal(objVal.Value.Complex80Value.RealPart, digits, outStr);
    if (FAILED(hr))
        return hr;

    // Real10::ToString won't add a leading '+', but it's needed
    if (objVal.Value.Complex80Value.ImaginaryPart.GetSign() >= 0)
        outStr ~= '+';

    hr = FormatSimpleReal(objVal.Value.Complex80Value.ImaginaryPart, digits, outStr);
    if (FAILED(hr))
        return hr;

    outStr ~= 'i';

    return S_OK;
}

HRESULT FormatBool(ref const DataObject objVal, ref wstring outStr)
{
    if (objVal.Value.UInt64Value == 0)
    {
        outStr ~= "false"w;
    }
    else
    {
        outStr ~= "true"w;
    }

    return S_OK;
}

HRESULT FormatInt(uint64_t number, Type type, ref const FormatOptions fmtopt, ref wstring outStr)
{
    // 18446744073709551616
    wchar_t[20 + 9 + 1] buf = ""w;

    if (fmtopt.radix == 16)
    {
        int width = type.GetSize() * 2;

        swprintf_s(buf, "0x%0*I64x"w, width, number);
    }
    else // it's 10, or make it 10
    {
        if (type.IsSigned())
        {
            swprintf_s(buf, "%I64d"w, number);
        }
        else
        {
            swprintf_s(buf, "%I64u"w, number);
        }
    }

    outStr ~= buf;

    return S_OK;
}

HRESULT FormatInt(ref const DataObject objVal, ref const FormatOptions fmtopt, ref std
        .wstring outStr)
{
    return FormatInt(objVal.Value.UInt64Value, objVal._Type, fmtopt, outStr);
}

HRESULT FormatAddress(Address addr, Type type, ref std.wstring outStr)
{
    FormatOptions fmtopt = FormatOptions(16);
    return FormatInt(addr, type, fmtopt, outStr);
}

HRESULT FormatChar(ref const DataObject objVal, ref const FormatOptions fmtopt,
        ref std.wstring outStr)
{
    // object replacement char U+FFFC
    // replacement character U+FFFD
    const(wchar_t) ReplacementChar = 0xFFFD;

    HRESULT hr = S_OK;

    hr = FormatInt(objVal, fmtopt, outStr);
    if (FAILED(hr))
        return hr;

    outStr ~= " '"w;

    switch (objVal._Type.GetSize())
    {
    case 1:
        {
            uint8_t c = cast(uint8_t) objVal.Value.UInt64Value;
            wchar_t wc = ReplacementChar;

            if (c < 0x80)
                wc = cast(wchar_t) c;

            outStr ~= wc;
        }
        break;

    case 2:
        {
            wchar_t wc = cast(wchar_t) objVal.Value.UInt64Value;

            if ((wc >= 0xD800) && (wc <= 0xDFFF))
                wc = ReplacementChar;

            outStr ~= wc;
        }
        break;

    case 4:
        AppendChar32(outStr, cast(dchar_t) objVal.Value.UInt64Value);
        break;
    default:
        break;
    }

    outStr ~= '\'';

    return S_OK;
}

HRESULT FormatBasicValue(ref const DataObject objVal, ref const FormatOptions fmtopt,
        ref std.wstring outStr)
{
    assert(objVal._Type.IsBasic());

    HRESULT hr = S_OK;
    Type type = null;
    int digits;

    if ((objVal._Type is null) || !objVal._Type.IsScalar())
        return E_FAIL;

    type = objVal._Type;

    if (type.IsBool())
    {
        hr = FormatBool(objVal, outStr);
    }
    else if (type.IsChar())
    {
        hr = FormatChar(objVal, fmtopt, outStr);
    }
    else if (type.IsIntegral())
    {
        hr = FormatInt(objVal, fmtopt, outStr);
    }
    else if (type.IsComplex())
    {
        hr = FormatComplex(objVal, outStr);
    }
    else if (type.IsReal() && PropertyFloatDigits.GetDigits(type, digits))
    {
        hr = FormatSimpleReal(objVal.Value.Float80Value, digits, outStr);
    }
    else if (type.IsImaginary() && PropertyFloatDigits.GetDigits(type, digits))
    {
        hr = FormatSimpleReal(objVal.Value.Float80Value, digits, outStr);
        outStr ~= 'i';
    }
    else
        return E_FAIL;

    if (FAILED(hr))
        return hr;

    return S_OK;
}

HRESULT FormatEnum(ref const DataObject objVal, ref const FormatOptions fmtopt,
        ref std.wstring outStr)
{
    assert(objVal._Type.AsTypeEnum() !is null);

    HRESULT hr = S_OK;

    if ((objVal._Type is null) || (objVal._Type.AsTypeEnum() is null))
        return E_FAIL;

    ITypeEnum enumType = objVal._Type.AsTypeEnum();
    Declaration decl;
    const(wchar_t)* name = null;

    decl = enumType.FindObjectByValue(objVal.Value.UInt64Value);

    if (decl !is null)
    {
        name = decl.GetName();
    }

    if (name !is null)
    {
        objVal._Type.ToString(outStr);
        outStr ~= '.';
        outStr ~= name;
    }
    else
    {
        hr = FormatInt(objVal, fmtopt, outStr);
        if (FAILED(hr))
            return hr;
    }

    return S_OK;
}

//T* tmemchr(T* buf, T c, size_t size);
char* tmemchr(char* buf, char c, size_t size)
{
    return cast(char*) memchr(buf, c, size);
}

wchar_t* tmemchr(wchar_t* buf, wchar_t c, size_t size)
{
    return wmemchr(buf, c, size);
}

dchar_t* tmemchr(dchar_t* buf, dchar_t c, size_t size)
{
    return dmemchr(buf, c, size);
}

// Returns the number of translated characters written, or the required 
// number of characters for destCharBuf, if destCharLen is 0.

/*int Translate(T)(T* srcBuf, size_t srcCharLen, wchar_t * destBuf,
        size_t destCharLen, ref bool truncated);*/

int Translate(char* srcBuf, size_t srcCharLen, wchar_t* destBuf,
        size_t destCharLen, ref bool truncated)
{
    truncated = false;
    if (destCharLen > 0 && srcCharLen > destCharLen)
    {
        srcCharLen = destCharLen; // MultiByteToWideChar returns 0 on overflow
        truncated = true;
    }

    return MultiByteToWideChar(CP_UTF8, 0, // ignore errors
            srcBuf, srcCharLen, destBuf, destCharLen);
}

int Translate(wchar_t* srcBuf, size_t srcCharLen, wchar_t* destBuf,
        size_t destCharLen, ref bool truncated)
{
    if (destCharLen > 0)
    {
        assert(destBuf !is null);

        truncated = false;
        if (srcCharLen > destCharLen)
        {
            srcCharLen = destCharLen;
            truncated = true;
        }

        errno_t err = wmemcpy_s(destBuf, srcCharLen, srcBuf, srcCharLen);
        assert(err == 0);
        //UNREFERENCED_PARAMETER(err);
    }
    return srcCharLen;
}

int Translate(dchar_t* srcBuf, size_t srcCharLen, wchar_t* destBuf,
        size_t destCharLen, ref bool truncated)
{
    return Utf32To16(true, srcBuf, srcCharLen, destBuf, destCharLen, truncated);
}

int Translate(T)(BYTE* buf, size_t bufByteSize, wchar_t * transBuf,
        size_t transBufCharSize, ref bool truncated, ref bool foundTerm)
{
    // if we find a terminator, then translate up to that point, 
    // otherwise translate the whole buffer

    T * end = tmemchr(cast(T*) buf, T(0), bufByteSize / T.sizeof);
    uint32_t unitsAvail = bufByteSize / T.sizeof;

    if (end !is null)
        unitsAvail = end - cast(T*) buf;

    int nChars = Translate(cast(T*) buf, unitsAvail, transBuf, transBufCharSize, truncated);

    foundTerm = (end !is null);

    return nChars;
}

HRESULT FormatString(IValueBinder binder, Address addr, uint32_t unitSize, bool maxLengthKnown,
        uint32_t maxLength, ref std.wstring outStr, ref bool truncated, ref bool foundTerm)
{
    const(int) MaxBytes = 400;
    HRESULT hr = S_OK;
    BYTE[MaxBytes] buf;
    wchar_t[MaxBytes / wchar_t.sizeof] translatedBuf = [0];
    uint32_t sizeToRead = _countof(buf);
    uint32_t sizeRead = 0;
    int nChars = 0;

    if (maxLengthKnown)
    {
        sizeToRead = min(sizeToRead, maxLength * unitSize);
    }

    hr = binder.ReadMemory(addr, sizeToRead, sizeRead, buf);
    if (FAILED(hr))
        return hr;

    switch (unitSize)
    {
    case 1:
        nChars = Translate(buf, sizeRead, translatedBuf,
                _countof(translatedBuf), truncated, foundTerm);
        break;

    case 2:
        nChars = Translate(buf, sizeRead, translatedBuf,
                _countof(translatedBuf), truncated, foundTerm);
        break;

    case 4:
        nChars = Translate(buf, sizeRead, translatedBuf,
                _countof(translatedBuf), truncated, foundTerm);
        break;

    default:
        return E_FAIL;
    }

    outStr.append(translatedBuf, nChars);

    if (maxLengthKnown && sizeToRead < maxLength * unitSize)
        truncated = true;

    return S_OK;
}

void _formatString(IValueBinder* binder, Address addr, uint64_t slen,
        Type elementType, ref std.wstring outStr)
{
    bool foundTerm = true;
    bool truncated = false;
    uint32_t len = MaxStringLen;

    // cap it somewhere under the range of a long
    // do it this way, otherwise only truncating could leave us with a tiny array
    // which would not be useful

    if (slen < MaxStringLen)
        len = cast(uint32_t) slen;

    outStr ~= "\""w;

    FormatString(binder, addr, elementType.GetSize(), true, len, outStr, truncated, foundTerm);

    outStr ~= '"';

    ENUMTY ty = elementType.GetBackingTy();
    if (ty == Tuns16)
        outStr ~= 'w';
    else if (ty == Tuns32)
        outStr ~= 'd';

    if (truncated)
        outStr ~= "..."w;
}

HRESULT FormatSArray(IValueBinder binder, Address addr, Type type,
        ref const FormatOptions fmtopt, ref std.wstring outStr, uint32_t maxLength)
{
    assert(type.IsSArray());

    ITypeSArray arrayType = type.AsTypeSArray();

    if (arrayType is null)
        return E_FAIL;

    if (arrayType.GetElement().IsChar())
    {
        _formatString(binder, addr, arrayType.GetLength(), arrayType.GetElement(), outStr);
    }
    else
    {
        uint32_t length = arrayType.GetLength();
        uint32_t elementSize = arrayType.GetElement().GetSize();

        outStr ~= "["w;
        for (uint32_t i = 0; i < length; i++)
        {
            if (outStr.length() >= maxLength)
            {
                outStr ~= ", ..."w;
                break;
            }

            DataObject elementObj;
            elementObj._Type = arrayType.GetElement();
            elementObj.Addr = addr + elementSize * i;

            HRESULT hr = binder.GetValue(elementObj.Addr, elementObj._Type, elementObj.Value);
            if (FAILED(hr))
                return hr;

            std.wstring elemStr;
            hr = FormatValue(binder, elementObj, fmtopt, elemStr,
                    kMaxFormatValueLength - maxLength);
            if (FAILED(hr))
                return hr;

            if (outStr.length() > 1)
                outStr.append(", "w);
            outStr.append(elemStr);
        }
        outStr.append("]"w);
    }
    return S_OK;
}

HRESULT FormatDArray(IValueBinder binder, DArray array, Type type,
        ref const FormatOptions fmtopt, ref std.wstring outStr)
{
    assert(type.IsDArray());

    HRESULT hr = S_OK;
    ITypeDArray* arrayType = type.AsTypeDArray();

    if (arrayType is null)
        return E_FAIL;

    if (fmtopt.specifier != FormatSpecRaw && arrayType.GetElement().IsChar())
    {
        _formatString(binder, array.Addr, array.Length, arrayType.GetElement(), outStr);
    }
    else
    {
        outStr ~= "{length="w;

        hr = FormatInt(array.Length, arrayType.GetLengthType(), fmtopt, outStr);
        if (FAILED(hr))
            return hr;

        outStr ~= " ptr="w;

        hr = FormatAddress(array.Addr, arrayType.GetPointerType(), outStr);
        if (FAILED(hr))
            return hr;

        outStr ~= '}';
    }

    return S_OK;
}

HRESULT FormatAArray(Address addr, Type type, ref const FormatOptions fmtopt, ref std.wstring outStr)
{
    assert(type.IsAArray());
    //UNREFERENCED_PARAMETER(fmtopt);
    return FormatAddress(addr, type, outStr);
}

HRESULT FormatStruct(IValueBinder binder, Address addr, Type type,
        ref const FormatOptions fmtopt, ref wstring outStr, uint32_t maxLength)
{
    HRESULT hr = S_OK;

    _ASSERT(type.AsTypeStruct());
    Declaration decl = type.GetDeclaration();
    if (decl is null)
        return E_INVALIDARG;

    IEnumDeclarationMembers members;
    if (!decl.EnumMembers(members))
        return E_INVALIDARG;

    outStr ~= "{"w;
    for (;;)
    {
        Declaration member;
        if (!members.Next(member))
            break;
        if (member.IsBaseClass() || member.IsStaticField())
            continue;

        if (outStr.length() > maxLength)
        {
            outStr ~= ", ..."w;
            break;
        }

        DataObject memberObj;
        member.GetType(memberObj._Type.Ref());
        memberObj.Addr = addr;
        int offset;
        if (member.GetOffset(offset))
            memberObj.Addr += offset;

        hr = binder.GetValue(memberObj.Addr, memberObj._Type, memberObj.Value);
        if (FAILED(hr))
            return hr;

        std.wstring memberStr;
        hr = FormatValue(binder, memberObj, fmtopt, memberStr, maxLength - outStr.length());
        if (FAILED(hr))
            return hr;

        if (outStr.length() > 1)
            outStr ~= ", "w;
        outStr ~= member.GetName();
        outStr ~= "="w;
        outStr ~= memberStr;
    }
    outStr ~= "}"w;

    return hr;
}

HRESULT FormatPointer(IValueBinder binder, ref const DataObject objVal,
        ref const FormatOptions fmtopt, ref wstring outStr, uint32_t maxLength)
{
    assert(objVal._Type.IsPointer());

    HRESULT hr = S_OK;
    Type pointeeType = objVal._Type.AsTypeNext().GetNext();

    hr = FormatAddress(objVal.Value.Addr, objVal._Type, outStr);
    if (FAILED(hr))
        return hr;

    if (pointeeType.IsChar())
    {
        bool foundTerm = false;
        bool truncated = false;

        outStr ~= " \""w;

        FormatString(binder, objVal.Value.Addr, pointeeType.GetSize(), false,
                0, outStr, truncated, foundTerm);
        // don't worry about an error here, we still want to show the address

        if (foundTerm)
            outStr ~= '"';
        if (truncated)
            outStr ~= "..."w;
    }
    else
    {
        std.wstring symName;
        hr = binder.SymbolFromAddr(objVal.Value.Addr, symName);
        if (hr == S_OK)
        {
            outStr ~= " {"w;
            outStr ~= symName;
            outStr ~= "}"w;
        }

        if (objVal.Value.Addr !is null && outStr.length() < maxLength)
        {
            DataObject pointeeObj = {0};
            pointeeObj._Type = pointeeType;
            pointeeObj.Addr = objVal.Value.Addr;

            hr = binder.GetValue(pointeeObj.Addr, pointeeObj._Type, pointeeObj.Value);
            if (!FAILED(hr))
            {
                std.wstring memberStr;
                hr = FormatValue(binder, pointeeObj, fmtopt, memberStr,
                        maxLength - outStr.length());
                if (!FAILED(hr) && !memberStr.empty())
                {
                    if (memberStr[0] == '{')
                        outStr ~= " "w;
                    else
                        outStr ~= " {"w;
                    outStr ~= memberStr;
                    if (memberStr[0] != '{')
                        outStr ~= "}"w;
                }
            }
        }
    }

    return S_OK;
}

class HeapDeleter
{
public:
    static void Delete(uint8_t* p)
    {
        HeapFree(GetProcessHeap(), 0, p);
    }
}

alias UniquePtrBase!(uint8_t*, null, HeapDeleter) HeapPtr;

//------------------------------------------------------------------------
//  FormatRawStringInternal
//
//      Reads string data from a binder and converts it to UTF-16.
//      Lengths refer to whole numbers of Unicode code units.
//      A terminating character is not added to the output buffer or 
//      included in the output length.
//
//      This function works by reading fixed size chunks of the original
//      string. When it reaches the maximum known length, a terminator 
//      character, memory that can't be read, or the end of the output
//      buffer, then it stops reading and translating.
//
//  Parameters:
//      binder - allows us to read original string data
//      unitSize - original code unit size. 1, 2, or 4 (char, wchar, dchar)
//      knownLength - the maximum length of the original string
//      bufLen - the length of the buffer we'll translate to
//      length - length written to the output buffer, or,
//               if outBuf is NULL, the required length for outBuf
//      outBuf - the buffer we'll write translated UTF-16 characters to
//------------------------------------------------------------------------

HRESULT FormatRawStringInternal(IValueBinder binder, Address address, uint32_t unitSize,
        uint32_t knownLength, uint32_t bufLen, ref uint32_t length, wchar_t* outBuf)
{
    assert((unitSize == 1) || (unitSize == 2) || (unitSize == 4));
    assert(binder !is null);

    HRESULT hr = S_OK;
    HeapPtr chunk = HeapPtr(cast(uint8_t*) HeapAlloc(GetProcessHeap(), 0, RawStringChunkSize));
    bool foundTerm = false;
    bool truncated = false;
    uint32_t totalSizeToRead = (knownLength * unitSize);
    uint32_t chunkCount = (totalSizeToRead + RawStringChunkSize - 1) / RawStringChunkSize;
    Address addr = address;
    uint32_t totalSizeLeftToRead = totalSizeToRead;
    uint32_t transLen = 0;
    wchar_t* curBufPtr = outBuf;
    uint32_t bufLenLeft = 0;

    if (chunk is null)
        return E_OUTOFMEMORY;

    if (outBuf !is null)
        bufLenLeft = bufLen;

    for (uint32_t i = 0; i < chunkCount; i++)
    {
        uint32_t sizeToRead = totalSizeLeftToRead;
        uint32_t sizeRead = 0;
        int nChars = 0;

        if (sizeToRead > RawStringChunkSize)
            sizeToRead = RawStringChunkSize;

        hr = binder.ReadMemory(addr, sizeToRead, sizeRead, chunk);
        if (FAILED(hr))
            return hr;

        final switch (unitSize)
        {
        case 1:
            nChars = Translate(chunk, sizeRead, curBufPtr,
                    bufLenLeft, truncated, foundTerm);
            break;

        case 2:
            nChars = Translate(chunk, sizeRead, curBufPtr,
                    bufLenLeft, truncated, foundTerm);
            break;

        case 4:
            nChars = Translate(chunk, sizeRead, curBufPtr,
                    bufLenLeft, truncated, foundTerm);
            break;
        /*default:
            break;*/
        }

        transLen += nChars;

        // finish counting when there's a terminator, or we can't read any more memory
        if (foundTerm || (sizeRead < sizeToRead))
            break;

        if (outBuf !is null)
        {
            curBufPtr += nChars;
            bufLenLeft -= nChars;

            // one more condition for stopping: no more space to write in
            if (bufLenLeft == 0)
                break;
        }

        addr += sizeRead;
        totalSizeLeftToRead -= sizeRead;
    }

    // when we get here we either found a terminator,
    // read to the known length and found no terminator (i >= chunkCount),
    // reached the end of contiguous readable memory,
    // or reached the end of the writable buffer
    // in any case, it's success, and tell the user how many wchars there are
    length = transLen;

    return S_OK;
}

HRESULT GetStringTypeData(ref const DataObject objVal, ref Address address,
        ref uint32_t unitSize, ref uint32_t knownLength)
{
    if (objVal._Type is null)
        return E_INVALIDARG;

    if (objVal._Type.IsSArray())
    {
        address = objVal.Addr;
        knownLength = objVal._Type.AsTypeSArray().GetLength();
    }
    else if (objVal._Type.IsDArray())
    {
        dlength_t bigLen = objVal.Value.Array.Length;

        if (bigLen > MaxStringLen)
            knownLength = MaxStringLen;
        else
            knownLength = cast(uint32_t) bigLen;

        address = objVal.Value.Array.Addr;
    }
    else if (objVal._Type.IsPointer())
    {
        knownLength = MaxStringLen;
        address = objVal.Value.Addr;
    }
    else
        return E_FAIL;

    assert(objVal._Type.AsTypeNext() !is null);
    unitSize = objVal._Type.AsTypeNext().GetNext().GetSize();

    if ((unitSize != 1) && (unitSize != 2) && (unitSize != 4))
        return E_FAIL;

    return S_OK;
}

HRESULT GetRawStringLength(IValueBinder binder, ref const DataObject objVal, ref uint32_t length)
{
    if (binder is null)
        return E_INVALIDARG;

    HRESULT hr = S_OK;
    Address address = 0;
    uint32_t unitSize = 0;
    uint32_t knownLen = 0;

    hr = GetStringTypeData(objVal, address, unitSize, knownLen);
    if (FAILED(hr))
        return hr;

    return FormatRawStringInternal(binder, address, unitSize, knownLen, 0, length, null);
}

HRESULT FormatRawString(IValueBinder binder, ref const DataObject objVal,
        uint32_t bufCharLen, ref uint32_t bufCharLenWritten, wchar_t* buf)
{
    if (binder is null)
        return E_INVALIDARG;
    if (buf is null)
        return E_INVALIDARG;

    HRESULT hr = S_OK;
    Address address = 0;
    uint32_t unitSize = 0;
    uint32_t knownLen = 0;

    hr = GetStringTypeData(objVal, address, unitSize, knownLen);
    if (FAILED(hr))
        return hr;

    return FormatRawStringInternal(binder, address, unitSize, knownLen,
            bufCharLen, bufCharLenWritten, buf);
}

HRESULT FormatValue(IValueBinder binder, ref const DataObject objVal,
        ref const FormatOptions fmtopt, ref std.wstring outStr, uint32_t maxLength)
{
    HRESULT hr = S_OK;
    Type type = null;

    type = objVal._Type;

    if (type is null)
        return E_FAIL;

    if (type.IsPointer())
    {
        hr = FormatPointer(binder, objVal, fmtopt, outStr, maxLength);
    }
    else if (type.IsBasic())
    {
        hr = FormatBasicValue(objVal, fmtopt, outStr);
    }
    else if (type.AsTypeEnum() !is null)
    {
        hr = FormatEnum(objVal, fmtopt, outStr);
    }
    else if (type.IsSArray())
    {
        hr = FormatSArray(binder, objVal.Addr, objVal._Type, fmtopt, outStr, maxLength);
    }
    else if (type.IsDArray())
    {
        hr = FormatDArray(binder, objVal.Value.Array, objVal._Type, fmtopt, outStr);
    }
    else if (type.IsAArray())
    {
        hr = FormatAArray(objVal.Value.Addr, objVal._Type, fmtopt, outStr);
    }
    else if (type.AsTypeStruct())
    {
        hr = FormatStruct(binder, objVal.Addr, type, fmtopt, outStr, maxLength);
    }
    else
        hr = E_FAIL;

    if (FAILED(hr))
        return hr;

    return S_OK;
}