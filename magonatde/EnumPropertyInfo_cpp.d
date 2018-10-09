module EnumPropertyInfo_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import EnumPropertyInfo;
import ExprContext;
import Property;
import ErrorProperty;
// #include <MagoEED.h>

  /* SYNTAX ERROR: (15): expected ; instead of namespace */ 


namespace  Mago
{
    HRESULT  _CopyPropertyInfo.copy( DEBUG_PROPERTY_INFO* dest, const  DEBUG_PROPERTY_INFO* source )
    {
        _ASSERT( dest !is  null && source !is  null );
        _ASSERT( dest != source );

        dest.bstrFullName = SysAllocString( source.bstrFullName );
        dest.bstrName = SysAllocString( source.bstrName );
        dest.bstrType = SysAllocString( source.bstrType );
        dest.bstrValue = SysAllocString( source.bstrValue );
        
        dest.dwAttrib = source.dwAttrib;
        dest.dwFields = source.dwFields;

        dest.pProperty = source.pProperty;
        if ( dest.pProperty !is  null )
            dest.pProperty.AddRef();

        return  S_OK;
    }

    void  _CopyPropertyInfo.init( DEBUG_PROPERTY_INFO* p )
    {
        _ASSERT( p !is  null );

        memset( p, 0, ( *p).sizeof );
    }

    void  _CopyPropertyInfo.destroy( DEBUG_PROPERTY_INFO* p )
    {
        _ASSERT( p !is  null );

        SysFreeString( p.bstrFullName );
        SysFreeString( p.bstrName );
        SysFreeString( p.bstrType );
        SysFreeString( p.bstrValue );
        
        if ( p.pProperty !is  null )
            p.pProperty.Release();
    }


    //------------------------------------------------------------------------

    this.EnumDebugPropertyInfo2()
    {   mFields = ( 0 );
        mFormatOpt.radix = 0;
    }

    this.~EnumDebugPropertyInfo2()
    {
    }

    HRESULT  EnumDebugPropertyInfo2.Next( ULONG  celt, DEBUG_PROPERTY_INFO* rgelt, ULONG* pceltFetched )
    {
        if ( rgelt  is  null )
            return  E_INVALIDARG;
        if ( pceltFetched  is  null )
            return  E_INVALIDARG;

        HRESULT      hr = S_OK;
        uint32_t     countLeft = mEEEnum.GetCount() - mEEEnum.GetIndex();
        uint32_t     i = 0;
        MagoEE.EvalOptions  options = MagoEE.EvalOptions.defaults;
        wstring      name;
        wstring      fullName;

        if ( celt > countLeft )
            celt = countLeft;

        for ( i = 0; i < celt; i++ )
        {
            // make sure this is in the loop so it gets cleaned up every time
            MagoEE.EvalResult   result = { 0 };

            // keep enumerating even if we fail to get an item
            hr = mEEEnum.EvaluateNext( options, result, name, fullName );
            if ( FAILED( hr ) )
            {
                hr = GetErrorPropertyInfo( hr, name.c_str(), fullName.c_str(), rgelt[i] );
                if ( FAILED( hr ) )
                    return  hr;
                continue;
            }

            hr = GetPropertyInfo( result, name.c_str(), fullName.c_str(), rgelt[i] );
            if ( FAILED( hr ) )
            {
                hr = GetErrorPropertyInfo( hr, name.c_str(), fullName.c_str(), rgelt[i] );
                if ( FAILED( hr ) )
                    return  hr;
                continue;
            }
        }

        *pceltFetched = i;

        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.GetErrorPropertyInfo( 
        HRESULT  hrErr,
        const(wchar_t) * name,
        const(wchar_t) * fullName, 
        ref DEBUG_PROPERTY_INFO  info )
    {
        HRESULT  hr = S_OK;
        CComPtr<IDebugProperty2>    errProp;

        hr = MakeErrorProperty( hrErr, name, fullName, &errProp );
        if ( FAILED( hr ) )
            return  hr;

        hr = errProp.GetPropertyInfo( mFields, mFormatOpt.radix, INFINITE, null, 0, &info );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.MakeErrorProperty( 
        HRESULT  hrErr, 
        const(wchar_t) * name,
        const(wchar_t) * fullName, 
        IDebugProperty2** ppResult )
    {
        HRESULT       hr = S_OK;
        std.wstring  errStr;

        hr = MagoEE.GetErrorString( hrErr, errStr );

        // use a general error, if original error couldn't be found
        if ( hr == S_FALSE )
            hr = MagoEE.GetErrorString( E_MAGOEE_BASE, errStr );

        if ( hr == S_OK )
        {
            RefPtr<ErrorProperty>   errProp;

            hr = MakeCComObject( errProp );
            if ( SUCCEEDED( hr ) )
            {
                hr = errProp.Init( name, fullName, errStr.c_str() );
                if ( hr == S_OK )
                {
                    *ppResult = errProp.Detach();
                    return  S_OK;
                }
            }
        }

        return  hrErr;
    }

    HRESULT  EnumDebugPropertyInfo2.GetPropertyInfo( 
        ref const  MagoEE.EvalResult  result, 
        const(wchar_t) * name,
        const(wchar_t) * fullName,
        ref DEBUG_PROPERTY_INFO  info )
    {
        HRESULT  hr = S_OK;

        info.dwFields = 0;

        if ( (mFields & DEBUGPROP_INFO_NAME) != 0 )
        {
            info.bstrName = SysAllocString( name );
            info.dwFields |= DEBUGPROP_INFO_NAME;
        }

        if ( (mFields & DEBUGPROP_INFO_FULLNAME) != 0 )
        {
            info.bstrFullName = SysAllocString( fullName );
            info.dwFields |= DEBUGPROP_INFO_FULLNAME;
        }

        if ( (mFields & DEBUGPROP_INFO_VALUE) != 0 )
        {
            MagoEE.EED.FormatValue( mExprContext, result.ObjVal, mFormatOpt, info.bstrValue );
            info.dwFields |= DEBUGPROP_INFO_VALUE;
        }

        if ( (mFields & DEBUGPROP_INFO_TYPE) != 0 )
        {
            if ( result.ObjVal._Type !is  null )
            {
                std.wstring     typeStr;
                result.ObjVal._Type.ToString( typeStr );

                info.bstrType = SysAllocString( typeStr.c_str() );
                info.dwFields |= DEBUGPROP_INFO_TYPE;
            }
        }

        if ( (mFields & DEBUGPROP_INFO_PROP) != 0 )
        {
            RefPtr<Property>    prop;

            hr = MakeCComObject( prop );
            if ( SUCCEEDED( hr ) )
            {
                hr = prop.Init( name, fullName, result, mExprContext, mFormatOpt );
                if ( SUCCEEDED( hr ) )
                {
                    prop.QueryInterface( __uuidof( IDebugProperty2 ), cast(void **) &info.pProperty );
                    info.dwFields |= DEBUGPROP_INFO_PROP;
                }
            }
        }

        if ( (mFields & DEBUGPROP_INFO_ATTRIB) != 0 )
        {
            info.dwAttrib = 0;
            if ( result.HasString )
                info.dwAttrib |= DBG_ATTRIB_VALUE_RAW_STRING;
            if ( result.ReadOnly )
                info.dwAttrib |= DBG_ATTRIB_VALUE_READONLY;
            if ( mFormatOpt.specifier != MagoEE.FormatSpecRaw && result.HasChildren )
                info.dwAttrib |= DBG_ATTRIB_OBJ_IS_EXPANDABLE;
            if ( mFormatOpt.specifier == MagoEE.FormatSpecRaw && result.HasRawChildren )
                info.dwAttrib |= DBG_ATTRIB_OBJ_IS_EXPANDABLE;
            if ( result.IsBaseClass )
                info.dwAttrib |= DBG_ATTRIB_BASECLASS;
            if ( result.IsMostDerivedClass )
                info.dwAttrib |= DBG_ATTRIB_MOSTDERIVEDCLASS;
            if ( result.IsStaticField )
                info.dwAttrib |= DBG_ATTRIB_STORAGE_STATIC;
            info.dwFields |= DEBUGPROP_INFO_ATTRIB;
        }

        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.Skip( ULONG  celt )
    {
        return  mEEEnum.Skip( celt );
    }

    HRESULT  EnumDebugPropertyInfo2.Reset()
    {
        mEEEnum.Reset();
        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.Clone( IEnumDebugPropertyInfo2** ppEnum )
    {
        HRESULT  hr = S_OK;
        RefPtr<MagoEE.IEEDEnumValues>  eeEnumCopy;
        RefPtr<EnumDebugPropertyInfo2>  enumCopy;

        hr = mEEEnum.Clone( eeEnumCopy.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        hr = MakeCComObject( enumCopy );
        if ( FAILED( hr ) )
            return  hr;

        hr = enumCopy.Init( eeEnumCopy, mExprContext, mFields, mFormatOpt );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.GetCount( ULONG* count )
    {
        if ( count  is  null )
            return  E_INVALIDARG;

        *count = mEEEnum.GetCount();
        return  S_OK;
    }

    HRESULT  EnumDebugPropertyInfo2.Init( 
        MagoEE.IEEDEnumValues* eeEnum, 
        ExprContext* exprContext,
        DEBUGPROP_INFO_FLAGS  dwFields, 
        ref const  MagoEE.FormatOptions  fmtopts )
    {
        _ASSERT( eeEnum !is  null );
        if ( eeEnum  is  null )
            return  E_INVALIDARG;

        mEEEnum = eeEnum;
        mExprContext = exprContext;
        mFields = dwFields;
        mFormatOpt = fmtopts;

        return  S_OK;
    }
}
