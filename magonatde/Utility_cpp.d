module Utility_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Utility;
// #include <MagoEED.h>

  /* SYNTAX ERROR: (12): expected ; instead of namespace */ 
  /* SYNTAX ERROR: (13): expected ; instead of namespace */ 


wstring  BuildCommandLine( const(wchar_t) * exe, const(wchar_t) * args )
{
    _ASSERT( exe !is  null );

    wstring          cmdLine;
    const(wchar_t) *  firstSpace = wcschr( exe, ' 'w );

    if ( firstSpace !is  null )
    {
        cmdLine.append( 1, '"'w );
        cmdLine.append( exe );
        cmdLine.append( 1, '"'w );
    }
    else
    {
        cmdLine = exe;
    }

    if ( (args !is  null) && (args[0] != '\0'w) )
    {
        cmdLine.append( 1, ' 'w );
        cmdLine.append( args );
    }

    return  cmdLine;
}


HRESULT  GetProcessId( IDebugProcess2* proc, ref DWORD  id )
{
    _ASSERT( proc !is  null );

    HRESULT          hr = S_OK;
    AD_PROCESS_ID    physProcId = { 0 };

    hr = proc.GetPhysicalProcessId( &physProcId );
    if ( FAILED( hr ) )
        return  hr;

    if ( physProcId.ProcessIdType != AD_PROCESS_ID_SYSTEM )
        return  HRESULT_FROM_WIN32( ERROR_NOT_SUPPORTED );

    id = physProcId.ProcessId.dwProcessId;

    return  S_OK;
}

HRESULT  GetProcessId( IDebugProgram2* prog, ref DWORD  id )
{
    HRESULT          hr = S_OK;
    CComPtr<IDebugProcess2> proc;

    hr = prog.GetProcess( &proc );
    if ( FAILED( hr ) )
        return  hr;

    return  GetProcessId( proc, id );
}

HRESULT  Utf8To16( const(char) * u8Str, size_t  u8StrLen, ref BSTR  u16Str )
{
    int          nChars = 0;
    BSTR         bstr = null;
    CComBSTR     ccomBstr;

    nChars = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, u8Str, u8StrLen, null, 0 );
    if ( nChars == 0 )
        return  GetLastHr();

    bstr = SysAllocStringLen( null, nChars );       // allocates 1 more char
    if ( bstr  is  null )
        return  GetLastHr();

    ccomBstr.Attach( bstr );

    nChars = MultiByteToWideChar( CP_UTF8, MB_ERR_INVALID_CHARS, u8Str, u8StrLen, ccomBstr.m_str, nChars + 1 );
    if ( nChars == 0 )
        return  GetLastHr();

    ccomBstr.m_str[nChars] = '\0'w;

    u16Str = ccomBstr.Detach();

    return  S_OK;
}

HRESULT  Utf16To8( const(wchar_t) * u16Str, size_t  u16StrLen, ref char *  u8Str, ref size_t  u8StrLen )
{
    int      nChars = 0;
    CAutoVectorPtr<char>    chars;
    DWORD    flags = 0;

static if(_WIN32_WINNT >= _WIN32_WINNT_LONGHORN) {
    flags = WC_ERR_INVALID_CHARS;
}

    nChars = WideCharToMultiByte( CP_UTF8, flags, u16Str, u16StrLen, null, 0, null, null );
    if ( nChars == 0 )
        return  HRESULT_FROM_WIN32( GetLastError() );

    chars.Attach( new  char[ nChars + 1 ] );
    if ( chars  is  null )
        return  E_OUTOFMEMORY;

    nChars = WideCharToMultiByte( CP_UTF8, flags, u16Str, u16StrLen, chars, nChars + 1, null, null );
    if ( nChars == 0 )
        return  HRESULT_FROM_WIN32( GetLastError() );
    chars[nChars] = '\0';

    u8Str = chars.Detach();
    u8StrLen = nChars;

    return  S_OK;
}


void  ConvertVariantToDataVal( ref const  MagoST.Variant  var, ref MagoEE.DataValue  dataVal )
{
    switch ( var.Tag )
    {
    case  VarTag_Char:   dataVal.Int64Value = var.Data.I8;   break;
    case  VarTag_Short:  dataVal.Int64Value = var.Data.I16;  break;
    case  VarTag_UShort: dataVal.UInt64Value = var.Data.U16;  break;
    case  VarTag_Long:   dataVal.Int64Value = var.Data.I32;  break;
    case  VarTag_ULong:  dataVal.UInt64Value = var.Data.U32;  break;
    case  VarTag_Quadword:   dataVal.Int64Value = var.Data.I64;  break;
    case  VarTag_UQuadword:  dataVal.UInt64Value = var.Data.U64;  break;

    case  VarTag_Real32: dataVal.Float80Value.FromFloat( var.Data.F32 ); break;
    case  VarTag_Real64: dataVal.Float80Value.FromDouble( var.Data.F64 ); break;
    case  VarTag_Real80: memcpy( &dataVal.Float80Value, var.Data.RawBytes,  dataVal.Float80Value.sizeof ); break;
        break;

    case  VarTag_Complex32:  
        dataVal.Complex80Value.RealPart.FromFloat( var.Data.C32.Real );
        dataVal.Complex80Value.ImaginaryPart.FromFloat( var.Data.C32.Imaginary );
        break;
    case  VarTag_Complex64: 
        dataVal.Complex80Value.RealPart.FromDouble( var.Data.C64.Real );
        dataVal.Complex80Value.ImaginaryPart.FromDouble( var.Data.C64.Imaginary );
        break;
    case  VarTag_Complex80: 
        C_ASSERT( offsetof( Complex10, RealPart ) < offsetof( Complex10, ImaginaryPart ) );
        memcpy( &dataVal.Complex80Value, var.Data.RawBytes,  dataVal.Complex80Value.sizeof );
        break;

    case  VarTag_Real48:
    case  VarTag_Real128:
    case  VarTag_Complex128:
    case  VarTag_Varstring: 
    default:
        memset( &dataVal, 0,  dataVal.sizeof );
        break;
    }
}


uint64_t  ReadInt( const(void) * srcBuf, uint32_t  bufOffset, size_t  size, bool  isSigned )
{
    union  Integer
    {
        uint8_t      i8;
        uint16_t     i16;
        uint32_t     i32;
        uint64_t     i64;
    };
    Integer      i = { 0 };
    uint64_t     u = 0;

    _ASSERT( size <=  u.sizeof );

    memcpy( &i, cast(uint8_t*) srcBuf + bufOffset, size );

    switch ( size )
    {
    case  1:
        if ( isSigned )
            u = cast(int8_t) i.i8;
        else
             u = cast(uint8_t) i.i8;
        break;

    case  2:
        if ( isSigned )
            u = cast(int16_t) i.i16;
        else
             u = cast(uint16_t) i.i16;
        break;

    case  4:
        if ( isSigned )
            u = cast(int32_t) i.i32;
        else
             u = cast(uint32_t) i.i32;
        break;

    case  8:
        u = i.i64;
        break;
    default: break;
    }

    return  u;
}

Real10  ReadFloat( const(void) * srcBuf, uint32_t  bufOffset, MagoEE.Type* type )
{
    union  Float
    {
        float    f32;
        double   f64;
        Real10   f80;
    };
    Float    f = { 0 };
    Real10   r;
    MagoEE.ENUMTY   ty = MagoEE.Tnone;
    size_t   size = 0;

    r.Zero();

    if ( type.IsComplex() )
    {
        switch ( type.GetSize() )
        {
        case  8:     ty = MagoEE.Tfloat32;  break;
        case  16:    ty = MagoEE.Tfloat64;  break;
        case  20:    ty = MagoEE.Tfloat80;  break;
        default: break;
        }
    }
    else    // is real or imaginary
    {
        switch ( type.GetSize() )
        {
        case  4:     ty = MagoEE.Tfloat32;  break;
        case  8:     ty = MagoEE.Tfloat64;  break;
        case  10:    ty = MagoEE.Tfloat80;  break;
        default: break;
        }
    }

    switch ( ty )
    {
    case  MagoEE.Tfloat32:  size = 4;   break;
    case  MagoEE.Tfloat64:  size = 8;   break;
    case  MagoEE.Tfloat80:  size = 10;  break;
    default: break;
    }

    memcpy( &f, cast(uint8_t*) srcBuf + bufOffset, size );

    switch ( ty )
    {
    case  MagoEE.Tfloat32:  r.FromFloat( f.f32 );   break;
    case  MagoEE.Tfloat64:  r.FromDouble( f.f64 );  break;
    case  MagoEE.Tfloat80:  r = f.f80;  break;
    default: break;
    }

    return  r;
}

HRESULT  WriteInt( uint8_t* buffer, uint32_t  bufSize, MagoEE.Type* type, uint64_t  val )
{
    union  Integer
    {
        uint8_t      i8;
        uint16_t     i16;
        uint32_t     i32;
        uint64_t     i64;
    };

    uint32_t     size = type.GetSize();
    Integer      iVal = { 0 };

    _ASSERT( size <= bufSize );
    if ( size > bufSize )
        return  E_FAIL;

    switch ( size )
    {
    case  1: iVal.i8 = cast(uint8_t) val;    break;
    case  2: iVal.i16 = cast(uint16_t) val;   break;
    case  4: iVal.i32 = cast(uint32_t) val;   break;
    case  8: iVal.i64 = cast(uint64_t) val;   break;
    default:
        return  E_FAIL;
    }

    memcpy( buffer, &iVal, size );

    return  S_OK;
}

HRESULT  WriteFloat( uint8_t* buffer, uint32_t  bufSize, MagoEE.Type* type, ref const  Real10  val )
{
    MagoEE.ENUMTY   ty = MagoEE.Tnone;

    if ( type.IsComplex() )
    {
        switch ( type.GetSize() )
        {
        case  8:     ty = MagoEE.Tfloat32;  break;
        case  16:    ty = MagoEE.Tfloat64;  break;
        case  20:    ty = MagoEE.Tfloat80;  break;
        default: break;
        }
    }
    else    // is real or imaginary
    {
        switch ( type.GetSize() )
        {
        case  4:     ty = MagoEE.Tfloat32;  break;
        case  8:     ty = MagoEE.Tfloat64;  break;
        case  10:    ty = MagoEE.Tfloat80;  break;
        default: break;
        }
    }

    union  Float
    {
        float        f32;
        double       f64;
        Real10       f80;
    };

    uint32_t     size = 0;
    Float        fVal = { 0 };

    switch ( ty )
    {
    case  MagoEE.Tfloat32: fVal.f32 = val.ToFloat();    size = 4;   break;
    case  MagoEE.Tfloat64: fVal.f64 = val.ToDouble();   size = 8;   break;
    case  MagoEE.Tfloat80: fVal.f80 = val;   size = 10; break;
    default:
        return  E_FAIL;
    }

    _ASSERT ( size <= bufSize );
    if ( size > bufSize )
        return  E_FAIL;

    memcpy( buffer, &fVal, size );

    return  S_OK;
}

HRESULT  FromRawValue( const(void) * srcBuf, MagoEE.Type* type, ref MagoEE.DataValue  value )
{
    _ASSERT( srcBuf !is  null );
    _ASSERT( type !is  null );

    size_t  size = type.GetSize();

    if ( type.IsPointer() )
    {
        value.Addr = ReadInt( srcBuf, 0, size, false );
    }
    else  if ( type.IsIntegral() )
    {
        value.UInt64Value = ReadInt( srcBuf, 0, size, type.IsSigned() );
    }
    else  if ( type.IsReal() || type.IsImaginary() )
    {
        value.Float80Value = ReadFloat( srcBuf, 0, type );
    }
    else  if ( type.IsComplex() )
    {
        const  size_t     PartSize = type.GetSize() / 2;

        value.Complex80Value.RealPart = ReadFloat( srcBuf, 0, type );
        value.Complex80Value.ImaginaryPart = ReadFloat( srcBuf, PartSize, type );
    }
    else  if ( type.IsDArray() )
    {
        const  size_t  LengthSize = type.AsTypeDArray().GetLengthType().GetSize();
        const  size_t  AddressSize = type.AsTypeDArray().GetPointerType().GetSize();

        value.Array.Length = cast(MagoEE.dlength_t) ReadInt( srcBuf, 0, LengthSize, false );
        value.Array.Addr = ReadInt( srcBuf, LengthSize, AddressSize, false );
    }
    else  if ( type.IsAArray() )
    {
        value.Addr = ReadInt( srcBuf, 0, size, false );
    }
    else  if ( type.IsDelegate() )
    {
        MagoEE.TypeDelegate* delType = cast(MagoEE.TypeDelegate*) type;
        const  size_t  AddressSize = delType.GetNext().GetSize();

        value.Delegate.ContextAddr = cast(MagoEE.dlength_t) ReadInt( srcBuf, 0, AddressSize, false );
        value.Delegate.FuncAddr = ReadInt( srcBuf, AddressSize, AddressSize, false );
    }
    else
         return  E_FAIL;

    return  S_OK;
}


//----------------------------------------------------------------------------
//  Compare values
//----------------------------------------------------------------------------

bool  EqualFloat32( const(void) * leftBuf, const(void) * rightBuf )
{
    const(float) * left = cast(const(float) *) leftBuf;
    const(float) * right = cast(const(float) *) rightBuf;

    // NaNs have to match
    if ( (*left != *left) && (*right != *right) )
        return  true;

    return *left == *right;
}

bool  EqualFloat64( const(void) * leftBuf, const(void) * rightBuf )
{
    const(double) * left = cast(const(double) *) leftBuf;
    const(double) * right = cast(const(double) *) rightBuf;

    // NaNs have to match
    if ( (*left != *left) && (*right != *right) )
        return  true;

    return *left == *right;
}

bool  EqualFloat80( const(void) * leftBuf, const(void) * rightBuf )
{
    const  Real10* left = cast(const  Real10*) leftBuf;
    const  Real10* right = cast(const  Real10*) rightBuf;

    if ( left.IsNan() && right.IsNan() )
        return  true;

    uint16_t  comp = Real10.Compare( *left, *right );
    return  Real10.IsEqual( comp );
}

bool  EqualComplex32( const(void) * leftBuf, const(void) * rightBuf )
{
    const(float) * left = cast(const(float) *) leftBuf;
    const(float) * right = cast(const(float) *) rightBuf;

    if ( !EqualFloat32( &left[0], &right[0] ) )
        return  false;

    return  EqualFloat32( &left[1], &right[1] );
}

bool  EqualComplex64( const(void) * leftBuf, const(void) * rightBuf )
{
    const(double) * left = cast(const(double) *) leftBuf;
    const(double) * right = cast(const(double) *) rightBuf;

    if ( !EqualFloat64( &left[0], &right[0] ) )
        return  false;

    return  EqualFloat64( &left[1], &right[1] );
}

bool  EqualComplex80( const(void) * leftBuf, const(void) * rightBuf )
{
    const  Real10* left = cast(const  Real10*) leftBuf;
    const  Real10* right = cast(const  Real10*) rightBuf;

    if ( !EqualFloat80( &left[0], &right[0] ) )
        return  false;

    return  EqualFloat80( &left[1], &right[1] );
}

EqualsFunc  GetFloatingEqualsFunc( MagoEE.Type* type )
{
    _ASSERT( type !is  null );
    _ASSERT( type.IsFloatingPoint() );

    EqualsFunc   equals = null;

    if ( type.IsComplex() )
    {
        switch ( type.GetSize() )
        {
        case  8: equals = EqualComplex32;  break;
        case  16: equals = EqualComplex64;  break;
        case  20: equals = EqualComplex80;  break;
        default: _ASSERT( false ); break;
        }
    }
    else
    {
        switch ( type.GetSize() )
        {
        case  4: equals = EqualFloat32;  break;
        case  8: equals = EqualFloat64;  break;
        case  10: equals = EqualFloat80;  break;
        default: _ASSERT( false ); break;
        }
    }

    return  equals;
}

bool  EqualFloat( size_t  typeSize, ref const  Real10  left, ref const  Real10  right )
{
    if ( left.IsNan() && right.IsNan() )
        return  true;

    switch ( typeSize )
    {
    case  4: return  left.ToFloat() == right.ToFloat();
    case  8: return  left.ToDouble() == right.ToDouble();
    case  10: 
        uint16_t  comp = Real10.Compare( left, right );
        return  Real10.IsEqual( comp );
    default: break;
    }

    return  false;
}

bool  EqualValue( MagoEE.Type* type, ref const  MagoEE.DataValue  left, ref const  MagoEE.DataValue  right )
{
    if ( type.IsPointer() )
    {
        return  left.Addr == right.Addr;
    }
    else  if ( type.IsIntegral() )
    {
        return  left.UInt64Value == right.UInt64Value;
    }
    else  if ( type.IsReal() || type.IsImaginary() )
    {
        return  EqualFloat( type.GetSize(), left.Float80Value, right.Float80Value );
    }
    else  if ( type.IsComplex() )
    {
        size_t  size = type.GetSize() / 2;
        if ( !EqualFloat( size, left.Complex80Value.RealPart, right.Complex80Value.RealPart ) )
            return  false;

        return  EqualFloat( size, left.Complex80Value.ImaginaryPart, right.Complex80Value.ImaginaryPart );
    }
    else  if ( type.IsDelegate() )
    {
        return (left.Delegate.ContextAddr == right.Delegate.ContextAddr) 
            && (left.Delegate.FuncAddr == right.Delegate.FuncAddr);
    }

    return  false;
}


static  uint32_t  Get16bits( const  uint8_t* x )
{
    return *cast(uint16_t*) x;
}


T  HashOf (class  T)( const(void) * buffer, T  length )
{
    // This is what druntime uses to hash most values longer than 32 bits
    /*
    * This is Paul Hsieh's SuperFastHash algorithm, described here:
    *   http://www.azillionmonkeys.com/qed/hash.html
    * It is protected by the following open source license:
    *   http://www.azillionmonkeys.com/qed/weblicense.html
    */
    _ASSERT( buffer !is  null );

    const  uint8_t* data = cast(uint8_t*) buffer;
    int  rem = 0;
    T  hash = 0;

    rem = length & 3;
    length >>= 2;

    for ( ; length > 0; length-- )
    {
        hash += Get16bits( data );
        T  temp = (Get16bits( data + 2 ) << 11) ^ hash;
        hash = (hash << 16) ^ temp;
        data += 2 *  uint16_t.sizeof;
        hash += hash >> 11;
    }

    /* Handle end cases */
    switch ( rem )
    {
    case  3: hash += Get16bits( data );
            hash ^= hash << 16;
            hash ^= data[ uint16_t.sizeof] << 18;
            hash += hash >> 11;
            break;
    case  2: hash += Get16bits( data );
            hash ^= hash << 11;
            hash += hash >> 17;
            break;
    case  1: hash += *data;
            hash ^= hash << 10;
            hash += hash >> 1;
            break;
        default:
            break;
    }

    /* Force "avalanching" of final 127 bits */
    hash ^= hash << 3;
    hash += hash >> 5;
    hash ^= hash << 4;
    hash += hash >> 17;
    hash ^= hash << 25;
    hash += hash >> 6;

    return  hash;
}

uint32_t  HashOf32( const(void) * buffer, uint32_t  length )
{
    return  HashOf<uint32_t>( buffer, length );
}

uint64_t  HashOf64( const(void) * buffer, uint32_t  length )
{
    return  HashOf<uint64_t>( buffer, length );
}


namespace  Mago
{
    const(wchar_t) AddressPrefix[] = "0x"w;

    void  FormatAddress( wchar_t * str, size_t  length, Address64  address, int  ptrSize, bool  usePrefix )
    {
        const(wchar_t) * activePrefix = ""w;

        if ( usePrefix )
            activePrefix = AddressPrefix;

        if ( ptrSize == 8 )
            swprintf_s( str, length, "%s%016I64x"w, activePrefix, cast(uint64_t) address );
        else
             swprintf_s( str, length, "%s%08x"w, activePrefix, cast(uint32_t) address );
    }
}
