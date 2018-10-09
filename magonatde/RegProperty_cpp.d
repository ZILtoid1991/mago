module RegProperty_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import RegProperty;
import RegisterSet;
import EnumPropertyInfo;
import FormatNum;
// #include <Real.h>
import Thread;
import ArchData;
import IDebuggerProxy;


namespace  Mago
{
    HRESULT  EnumRegisters(
        ArchData* archData,
        IRegisterSet* regSet, 
        Thread* thread,
        DEBUGPROP_INFO_FLAGS  fields,
        DWORD  radix,
        IEnumDebugPropertyInfo2** enumerator )
    {
        uint32_t  groupCount = archData.GetRegisterGroupCount();

        HRESULT              hr = S_OK;
        PropertyInfoArray    array = PropertyInfoArray( groupCount );

        if ( array.Get() is  null )
            return  E_OUTOFMEMORY;

        for ( uint32_t  i = 0; i < groupCount; i++ )
        {
            RegGroup                     regGroup;
            RefPtr<RegGroupProperty>    groupProp;

            hr = MakeCComObject( groupProp );
            if ( FAILED( hr ) )
                return  hr;

            archData.GetRegisterGroup( i, regGroup );

            hr = groupProp.Init( &regGroup, regSet, thread );
            if ( FAILED( hr ) )
                return  hr;

            hr = groupProp.GetPropertyInfo( 
                fields,
                radix,
                INFINITE,
                null,
                0,
                &array[i] );
            if ( FAILED( hr ) )
                return  hr;
        }

        return  MakeEnumWithCount<EnumDebugPropertyInfo>( array, enumerator );
    }


    //------------------------------------------------------------------------
    //  RegGroupProperty
    //------------------------------------------------------------------------

    this.RegGroupProperty()
    {   mRegs = ( null );
            mRegCount = ( 0 );
    }

    this.~RegGroupProperty()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugProperty2 

    HRESULT  RegGroupProperty.GetPropertyInfo( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        DWORD  dwTimeout,
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        DEBUG_PROPERTY_INFO* pPropertyInfo )
    {
        if ( pPropertyInfo  is  null )
            return  E_INVALIDARG;

        pPropertyInfo.dwFields = 0;

        if ( (dwFields & DEBUGPROP_INFO_NAME) != 0 )
        {
            pPropertyInfo.bstrName = SysAllocString( mName );
            if ( pPropertyInfo.bstrName !is  null )
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_NAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_FULLNAME) != 0 )
        {
            pPropertyInfo.bstrFullName = SysAllocString( mName );
            if ( pPropertyInfo.bstrFullName !is  null )
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_FULLNAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_PROP) != 0 )
        {
            QueryInterface( __uuidof( IDebugProperty2 ), cast(void **) &pPropertyInfo.pProperty );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_PROP;
        }

        if ( (dwFields & DEBUGPROP_INFO_ATTRIB) != 0 )
        {
            pPropertyInfo.dwAttrib = DBG_ATTRIB_VALUE_READONLY;
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_ATTRIB;
        }

        return  S_OK;
    }

    HRESULT  RegGroupProperty.SetValueAsString( 
        LPCOLESTR  pszValue,
        DWORD  dwRadix,
        DWORD  dwTimeout )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.SetValueAsReference( 
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        IDebugReference2* pValue,
        DWORD  dwTimeout )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.EnumChildren( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        REFGUID  guidFilter,
        DBG_ATTRIB_FLAGS  dwAttribFilter,
        LPCOLESTR  pszNameFilter,
        DWORD  dwTimeout,
        IEnumDebugPropertyInfo2** ppEnum )
    {
        HRESULT              hr = S_OK;
        PropertyInfoArray    array = PropertyInfoArray( mRegCount );

        if ( array.Get() is  null )
            return  E_OUTOFMEMORY;

        for ( uint32_t  i = 0; i < mRegCount; i++ )
        {
            RefPtr<RegisterProperty>    regProp;

            hr = MakeCComObject( regProp );
            if ( FAILED( hr ) )
                return  hr;

            hr = regProp.Init( &mRegs[i], mRegSet, mThread );
            if ( FAILED( hr ) )
                return  hr;

            hr = regProp.GetPropertyInfo( 
                dwFields,
                dwRadix,
                dwTimeout,
                null,
                0,
                &array[i] );
            if ( FAILED( hr ) )
                return  hr;
        }

        return  MakeEnumWithCount<EnumDebugPropertyInfo>( array, ppEnum );
    }

    HRESULT  RegGroupProperty.GetParent( 
        IDebugProperty2** ppParent )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetDerivedMostProperty( 
        IDebugProperty2** ppDerivedMost )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetMemoryBytes( 
        IDebugMemoryBytes2** ppMemoryBytes )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetMemoryContext( 
        IDebugMemoryContext2** ppMemory )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetSize( 
        DWORD* pdwSize )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetReference( 
        IDebugReference2** ppReference )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.GetExtendedInfo( 
        REFGUID  guidExtendedInfo,
        VARIANT* pExtendedInfo )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegGroupProperty.Init( const  RegGroup* group, IRegisterSet* regSet, Thread* thread )
    {
        _ASSERT( group !is  null );
        _ASSERT( regSet !is  null );
        _ASSERT( thread !is  null );

        mRegs = group.Regs;
        mRegCount = group.RegCount;

        if ( !GetString( group.StrId, mName ) )
            return  E_FAIL;

        mRegSet = regSet;
        mThread = thread;

        return  S_OK;
    }


    //------------------------------------------------------------------------
    //  RegisterProperty
    //------------------------------------------------------------------------

    this.RegisterProperty()
    {   mReg = ( null );
    }

    this.~RegisterProperty()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugProperty2 

    HRESULT  RegisterProperty.GetPropertyInfo( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        DWORD  dwTimeout,
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        DEBUG_PROPERTY_INFO* pPropertyInfo )
    {
        bool     isValid = false;

        if ( pPropertyInfo  is  null )
            return  E_INVALIDARG;

        pPropertyInfo.dwFields = 0;

        if ( (dwFields & DEBUGPROP_INFO_NAME) != 0 )
        {
            pPropertyInfo.bstrName = SysAllocString( mReg.Name );
            if ( pPropertyInfo.bstrName !is  null )
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_NAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_FULLNAME) != 0 )
        {
            pPropertyInfo.bstrFullName = SysAllocString( mReg.Name );
            if ( pPropertyInfo.bstrFullName !is  null )
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_FULLNAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_VALUE) != 0 )
        {
            pPropertyInfo.bstrValue = GetValueStr( isValid );
            if ( pPropertyInfo.bstrValue !is  null )
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_VALUE;
        }

        if ( (dwFields & DEBUGPROP_INFO_PROP) != 0 )
        {
            QueryInterface( __uuidof( IDebugProperty2 ), cast(void **) &pPropertyInfo.pProperty );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_PROP;
        }

        if ( (dwFields & DEBUGPROP_INFO_ATTRIB) != 0 )
        {
            bool     readOnly = true;

            mRegSet.IsReadOnly( mReg.FullReg, readOnly );

            pPropertyInfo.dwAttrib = DBG_ATTRIB_STORAGE_REGISTER;
            if ( readOnly )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_VALUE_READONLY;
            if ( !isValid )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_VALUE_NAT;
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_ATTRIB;
        }

        return  S_OK;
    }

    HRESULT  RegisterProperty.SetValueAsString( 
        LPCOLESTR  pszValue,
        DWORD  dwRadix,
        DWORD  dwTimeout )
    {
        HRESULT          hr = S_OK;
        RegisterType     regType = mRegSet.GetRegisterType( mReg.FullReg );
        RegisterValue    regVal = { 0 };
        uint64_t         limit = 0;
        size_t           strValLen = wcslen( pszValue );
        bool             isReadOnly = false;

        hr = mRegSet.IsReadOnly( mReg.FullReg, isReadOnly );
        if ( FAILED( hr ) || isReadOnly )
            return  E_SETVALUE_VALUE_IS_READONLY;

        regVal.Type = regType;

        switch ( regType )
        {
        case  RegType_Int8:  limit = std.numeric_limits<uint8_t>.max();  goto  Ints;
        case  RegType_Int16: limit = std.numeric_limits<uint16_t>.max(); goto  Ints;
        case  RegType_Int32: limit = std.numeric_limits<uint32_t>.max(); goto  Ints;
        case  RegType_Int64: limit = std.numeric_limits<uint64_t>.max(); goto  Ints;
        Ints:
            {
                _set_errno( 0 );
                wchar_t *    endPtr = null;
                uint64_t     val = _wcstoui64( pszValue, &endPtr, 16 );

                if ( (errno != 0) || (val > limit) 
                    || (cast(size_t) (endPtr - pszValue) < strValLen) )
                    return  E_FAIL;

                if ( mReg.Length > 0 )
                {
                    RegisterValue    oldRegVal = { 0 };
                    uint64_t         oldVal = 0;

                    hr = mRegSet.GetValue( mReg.FullReg, oldRegVal );
                    if ( FAILED( hr ) )
                        return  hr;

                    oldVal = oldRegVal.GetInt();

                    val = (val & mReg.Mask) << mReg.Shift;
                    val |= oldVal & ~(cast(uint64_t) mReg.Mask << mReg.Shift);
                }

                regVal.SetInt( val );
            }
            break;

        case  RegType_Float32:
        case  RegType_Float64:
            {
                _set_errno( 0 );
                wchar_t *    endPtr = null;
                double       val = wcstod( pszValue, &endPtr );

                if ( (errno != 0) 
                    || (cast(size_t) (endPtr - pszValue) < strValLen) )
                    return  E_FAIL;

                switch ( regType )
                {
                case  RegType_Float32: regVal.Value.F32 = cast(float) val;   break;
                case  RegType_Float64: regVal.Value.F64 = cast(double) val;  break;
                default: break;
                }
            }
            break;

        case  RegType_Float80:
            {
                Real10   r;

                if ( Real10.Parse( pszValue, r ) != 0 )
                    return  E_FAIL;

                memcpy( regVal.Value.F80Bytes, r.Words,  r.Words.sizeof );
            }
            break;

        case  RegType_Vector128:
            {
                // 16 byte value, 32 character string, 2 hex chars each byte
                const(int)   ValSize = 16;
                const(int)   ByteChars = 2;
                wchar_t *    endPtr = null;
                wchar_t      byteStr[ByteChars + 1] = ""w;

                if ( strValLen != ValSize * ByteChars )
                    return  E_FAIL;

                for ( size_t  i = 0; i < ValSize; i++ )
                {
                    uint32_t     byte = 0;

                    wcsncpy_s( byteStr, &pszValue[ i * ByteChars ], ByteChars );
                    _set_errno( 0 );
                    byte = wcstoul( byteStr, &endPtr, 16 );

                    if ( (errno != 0) || (byte > std.numeric_limits<uint8_t>.max()) 
                        || (cast(size_t) (endPtr - byteStr) < ByteChars) )
                        return  E_FAIL;

                    regVal.Value.V8[i] = cast(uint8_t) byte;
                }
            }
            break;

        default:
            return  E_FAIL;
        }

        hr = mRegSet.SetValue( mReg.FullReg, regVal );
        if ( FAILED( hr ) )
            return  hr;

        ICoreThread* coreThread = mThread.GetCoreThread();
        ICoreProcess* coreProcess = mThread.GetCoreProcess();
        IDebuggerProxy* debugger = mThread.GetDebuggerProxy();

        hr = debugger.SetThreadContext( coreProcess, coreThread, mRegSet );
        if ( FAILED( hr ) )
            return  E_SETVALUE_VALUE_CANNOT_BE_SET;

        return  S_OK;
    }

    HRESULT  RegisterProperty.SetValueAsReference( 
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        IDebugReference2* pValue,
        DWORD  dwTimeout )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.EnumChildren( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        REFGUID  guidFilter,
        DBG_ATTRIB_FLAGS  dwAttribFilter,
        LPCOLESTR  pszNameFilter,
        DWORD  dwTimeout,
        IEnumDebugPropertyInfo2** ppEnum )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetParent( 
        IDebugProperty2** ppParent )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetDerivedMostProperty( 
        IDebugProperty2** ppDerivedMost )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetMemoryBytes( 
        IDebugMemoryBytes2** ppMemoryBytes )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetMemoryContext( 
        IDebugMemoryContext2** ppMemory )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetSize( 
        DWORD* pdwSize )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetReference( 
        IDebugReference2** ppReference )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.GetExtendedInfo( 
        REFGUID  guidExtendedInfo,
        VARIANT* pExtendedInfo )
    {
        return  E_NOTIMPL;
    }

    HRESULT  RegisterProperty.Init( const  Reg* reg, IRegisterSet* regSet, Thread* thread )
    {
        _ASSERT( reg !is  null );
        _ASSERT( regSet !is  null );
        _ASSERT( thread !is  null );

        mReg = reg;
        mRegSet = regSet;
        mThread = thread;

        return  S_OK;
    }

    BSTR  RegisterProperty.GetValueStr( ref bool  valid )
    {
        const  size_t     MaxVectorStrLen = (256 / 8) * 2;    // number of hex digits
        const  size_t     MaxFloatStrLen = .Float80DecStrLen;
        const  size_t     MaxValueStrLen = 
            MaxVectorStrLen > MaxFloatStrLen ? MaxVectorStrLen : MaxFloatStrLen;

        HRESULT          hr = S_OK;
        RegisterValue    val = { 0 };
        wchar_t          str[ MaxValueStrLen + 1 ] = ""w;
        size_t           digitLen = 0;

        hr = mRegSet.GetValue( mReg.FullReg, val );
        if ( FAILED( hr ) )
            return  SysAllocString( ""w );

        valid = (hr == S_OK);

        if ( mReg.Length > 0 )
        {
            // we know it's an integer
            digitLen = (mReg.Length + 3) / 4;
        }
        else
        {
            switch ( val.Type )
            {
            case  RegType_Int8:  digitLen = 1*2; break;
            case  RegType_Int16: digitLen = 2*2; break;
            case  RegType_Int32: digitLen = 4*2; break;
            case  RegType_Int64: digitLen = 8*2; break;
            default: break;
            }
        }

        switch ( val.Type )
        {
        case  RegType_Int8:
            if ( mReg.Length > 0 )
                val.Value.I8 = (val.Value.I8 >> mReg.Shift) & mReg.Mask;
            swprintf_s( str, "%0.*X"w, digitLen, val.Value.I8 );
            break;

        case  RegType_Int16:
            if ( mReg.Length > 0 )
                val.Value.I16 = (val.Value.I16 >> mReg.Shift) & mReg.Mask;
            swprintf_s( str, "%0.*X"w, digitLen, val.Value.I16 );
            break;

        case  RegType_Int32:
            if ( mReg.Length > 0 )
                val.Value.I32 = (val.Value.I32 >> mReg.Shift) & mReg.Mask;
            swprintf_s( str, "%0.*X"w, digitLen, val.Value.I32 );
            break;

        case  RegType_Int64:
            if ( mReg.Length > 0 )
                val.Value.I64 = (val.Value.I64 >> mReg.Shift) & mReg.Mask;
            swprintf_s( str, "%0.*I64X"w, digitLen, val.Value.I64 );
            break;

        case  RegType_Float32:
            FormatFloat32( val.Value.F32, str, .Float32DecStrLen + 1 );
            break;

        case  RegType_Float64:
            FormatFloat64( val.Value.F64, str, .Float64DecStrLen + 1 );
            break;

        case  RegType_Float80:
            FormatFloat80( val.Value.F80Bytes, str, .Float80DecStrLen + 1 );
            break;

        case  RegType_Vector128:
            // 16 byte value, 32 character string, 2 hex chars each byte
            for ( int  i = 0; i <  val.Value.V8.sizeof; i++ )
            {
                swprintf_s( &str[i * 2], _countof( str ) - (i * 2), "%02X"w, val.Value.V8[i] );
            }
            break;
        default: break;
        }

        return  SysAllocString( str );
    }
}
