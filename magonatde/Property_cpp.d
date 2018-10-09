module Property_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Property;
import EnumPropertyInfo;
import ExprContext;
import CodeContext;

import Thread;
import ICoreProcess;
import ArchData;


namespace  Mago
{
    // Property

    this.Property()
    {   mPtrSize = ( 0 );
    }

    this.~Property()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugProperty2 

    HRESULT  Property.GetPropertyInfo( 
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
            std.wstring  txt = mExprText;
            MagoEE.AppendFormatSpecifier( txt, mFormatOpts );
            pPropertyInfo.bstrName = SysAllocString( txt.c_str() );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_NAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_FULLNAME) != 0 )
        {
            std.wstring  txt = mFullExprText;
            MagoEE.AppendFormatSpecifier( txt, mFormatOpts );
            pPropertyInfo.bstrFullName = SysAllocString( txt.c_str() );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_FULLNAME;
        }

        if ( (dwFields & DEBUGPROP_INFO_VALUE) != 0 )
        {
            pPropertyInfo.bstrValue = FormatValue( dwRadix );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_VALUE;
        }

        if ( (dwFields & DEBUGPROP_INFO_TYPE) != 0 )
        {
            if ( mObjVal.ObjVal._Type !is  null )
            {
                std.wstring     typeStr;
                mObjVal.ObjVal._Type.ToString( typeStr );

                pPropertyInfo.bstrType = SysAllocString( typeStr.c_str() );
                pPropertyInfo.dwFields |= DEBUGPROP_INFO_TYPE;
            }
        }

        if ( (dwFields & DEBUGPROP_INFO_PROP) != 0 )
        {
            QueryInterface( __uuidof( IDebugProperty2 ), cast(void **) &pPropertyInfo.pProperty );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_PROP;
        }

        if ( (dwFields & DEBUGPROP_INFO_ATTRIB) != 0 )
        {
            pPropertyInfo.dwAttrib = 0;
            if ( mObjVal.HasString )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_VALUE_RAW_STRING;
            if ( mObjVal.ReadOnly )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_VALUE_READONLY;

            if ( mFormatOpts.specifier != MagoEE.FormatSpecRaw && mObjVal.HasChildren )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_OBJ_IS_EXPANDABLE;
            if ( mFormatOpts.specifier == MagoEE.FormatSpecRaw && mObjVal.HasRawChildren )
                pPropertyInfo.dwAttrib |= DBG_ATTRIB_OBJ_IS_EXPANDABLE;

            if ( mObjVal.ObjVal._Type !is  null )
            {
                if( !mObjVal.ObjVal._Type.IsMutable() )
                    pPropertyInfo.dwAttrib |= DBG_ATTRIB_TYPE_CONSTANT;
                if( mObjVal.ObjVal._Type.IsShared() )
                    pPropertyInfo.dwAttrib |= DBG_ATTRIB_TYPE_SYNCHRONIZED;

                if( auto  /* SYNTAX ERROR: (109): expected ) instead of fun */  fun = mObjVal.ObjVal._Type.AsTypeFunction() )
                {
                    if ( fun.IsProperty() )
                        pPropertyInfo.dwAttrib |= DBG_ATTRIB_PROPERTY;
                     /* SYNTAX ERROR: (113): expression expected, not else */ else
                         pPropertyInfo.dwAttrib |= DBG_ATTRIB_METHOD;
                }
                else  if( auto  /* SYNTAX ERROR: (116): expected ) instead of clss */  clss = mObjVal.ObjVal._Type.AsTypeStruct() )
                    pPropertyInfo.dwAttrib |= DBG_ATTRIB_CLASS;
                 /* SYNTAX ERROR: (118): expression expected, not else */ else
                     pPropertyInfo.dwAttrib |= DBG_ATTRIB_DATA;
            }
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_ATTRIB;
        }

         /* SYNTAX ERROR: (124): expected <identifier> instead of return */ 
    }
    
    HRESULT  Property.SetValueAsString( 
        LPCOLESTR  pszValue,
        DWORD  dwRadix,
        DWORD  dwTimeout )
    {
        // even though it could be read only, let's parse and eval, so we get good errors

        HRESULT          hr = S_OK;
        CComBSTR         assignExprText = mFullExprText;
        CComBSTR         errStr;
        UINT             errPos;
        CComPtr<IDebugExpression2>  expr;
        CComPtr<IDebugProperty2>    prop;

        if ( assignExprText  is  null )
            return  E_OUTOFMEMORY;

        hr = assignExprText.Append( " = "w );
        if ( FAILED( hr ) )
            return  hr;

        hr = assignExprText.Append( pszValue );
        if ( FAILED( hr ) )
            return  hr;

        hr = mExprContext.ParseText( assignExprText, 0, dwRadix, &expr, &errStr, &errPos );
        if ( FAILED( hr ) )
            return  hr;

        hr = expr.EvaluateSync( 0, dwTimeout, null, &prop );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }
    
    HRESULT  Property.SetValueAsReference( 
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        IDebugReference2* pValue,
        DWORD  dwTimeout )
    {
        Log.LogMessage( "Property::SetValueAsReference\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.EnumChildren( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        REFGUID  guidFilter,
        DBG_ATTRIB_FLAGS  dwAttribFilter,
        LPCOLESTR  pszNameFilter,
        DWORD  dwTimeout,
        IEnumDebugPropertyInfo2** ppEnum )
    {
        HRESULT                          hr = S_OK;
        RefPtr<EnumDebugPropertyInfo2>  enumProps;
        RefPtr<MagoEE.IEEDEnumValues>  enumVals;

        hr = MagoEE.EnumValueChildren( 
            mExprContext, 
            mFullExprText, 
            mObjVal.ObjVal, 
            mExprContext.GetTypeEnv(),
            mExprContext.GetStringTable(),
            mFormatOpts,
            enumVals.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        hr = MakeCComObject( enumProps );
        if ( FAILED( hr ) )
            return  hr;

        MagoEE.FormatOptions  fmtopts (dwRadix);
        hr = enumProps.Init( enumVals, mExprContext, dwFields, fmtopts );
        if ( FAILED( hr ) )
            return  hr;

        return  enumProps.QueryInterface( __uuidof( IEnumDebugPropertyInfo2 ), cast(void **) ppEnum );
    }
    
    HRESULT  Property.GetParent( 
        IDebugProperty2** ppParent )
    {
        Log.LogMessage( "Property::GetParent\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetDerivedMostProperty( 
        IDebugProperty2** ppDerivedMost )
    {
        Log.LogMessage( "Property::GetDerivedMostProperty\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetMemoryBytes( 
        IDebugMemoryBytes2** ppMemoryBytes )
    {
        Log.LogMessage( "Property::GetMemoryBytes\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetMemoryContext( 
        IDebugMemoryContext2** ppMemory )
    {
        Log.LogMessage( "Property::GetMemoryContext\n" );

        if ( ppMemory  is  null )
            return  E_INVALIDARG;

        HRESULT  hr = S_OK;
        RefPtr<CodeContext> codeCxt;
        Address64  addr = 0;

        // TODO: let the EE figure this out
        if ( mObjVal.ObjVal._Type.IsPointer() )
        {
            addr = cast(Address64) mObjVal.ObjVal.Value.Addr;
        }
        else  if ( mObjVal.ObjVal._Type.IsIntegral() )
        {
            addr = cast(Address64) mObjVal.ObjVal.Value.UInt64Value;
        }
        else  if ( mObjVal.ObjVal._Type.IsSArray() )
        {
            addr = cast(Address64) mObjVal.ObjVal.Addr;
        }
        else  if ( mObjVal.ObjVal._Type.IsDArray() )
        {
            addr = cast(Address64) mObjVal.ObjVal.Value.Array.Addr;
        }
        else
             return  S_GETMEMORYCONTEXT_NO_MEMORY_CONTEXT;

        hr = MakeCComObject( codeCxt );
        if ( FAILED( hr ) )
            return  hr;

        hr = codeCxt.Init( addr, null, null, mPtrSize );
        if ( FAILED( hr ) )
            return  hr;

        return  codeCxt.QueryInterface( __uuidof( IDebugMemoryContext2 ), cast(void **) ppMemory );
    }
    
    HRESULT  Property.GetSize( 
        DWORD* pdwSize )
    {
        Log.LogMessage( "Property::GetSize\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetReference( 
        IDebugReference2** ppReference )
    {
        Log.LogMessage( "Property::GetReference\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetExtendedInfo( 
        REFGUID  guidExtendedInfo,
        VARIANT* pExtendedInfo )
    {
        Log.LogMessage( "Property::GetExtendedInfo\n" );
        return  E_NOTIMPL;
    }


    //////////////////////////////////////////////////////////// 
    // IDebugProperty3

    HRESULT  Property.GetStringCharLength( ULONG* pLen )
    {
        Log.LogMessage( "Property::GetStringCharLength\n" );

        return  MagoEE.GetRawStringLength( mExprContext, mObjVal.ObjVal, *cast(uint32_t*) pLen );
    }
    
    HRESULT  Property.GetStringChars( 
        ULONG  bufLen,
        WCHAR* rgString,
        ULONG* pceltFetched )
    {
        Log.LogMessage( "Property::GetStringChars\n" );

        return  MagoEE.FormatRawString(
            mExprContext,
            mObjVal.ObjVal,
            bufLen,
            *cast(uint32_t*) pceltFetched,
            rgString );
    }
    
    HRESULT  Property.CreateObjectID()
    {
        Log.LogMessage( "Property::CreateObjectID\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.DestroyObjectID()
    {
        Log.LogMessage( "Property::DestroyObjectID\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetCustomViewerCount( ULONG* pcelt )
    {
        Log.LogMessage( "Property::GetCustomViewerCount\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.GetCustomViewerList( 
        ULONG  celtSkip,
        ULONG  celtRequested,
        DEBUG_CUSTOM_VIEWER* rgViewers,
        ULONG* pceltFetched )
    {
        Log.LogMessage( "Property::GetCustomViewerList\n" );
        return  E_NOTIMPL;
    }
    
    HRESULT  Property.SetValueAsStringWithError( 
        LPCOLESTR  pszValue,
        DWORD  dwRadix,
        DWORD  dwTimeout,
        BSTR* errorString )
    {
        Log.LogMessage( "Property::SetValueAsStringWithError\n" );
        return  E_NOTIMPL;
    }


    //------------------------------------------------------------------------

    HRESULT  Property.Init( 
        const(wchar_t) * exprText, 
        const(wchar_t) * fullExprText, 
        ref const  MagoEE.EvalResult  objVal, 
        ExprContext* exprContext,
        ref const  MagoEE.FormatOptions  fmtopt )
    {
        mExprText = exprText;
        mFullExprText = fullExprText;
        mObjVal = objVal;
        mExprContext = exprContext;
        mFormatOpts = fmtopt;

        Thread*     thread = exprContext.GetThread();
        ArchData*   archData = thread.GetCoreProcess().GetArchData();

        mPtrSize = archData.GetPointerSize();

        return  S_OK;
    }

    BSTR  Property.FormatValue( int  radix )
    {
        if ( mObjVal.ObjVal._Type  is  null )
            return  null;

        HRESULT      hr = S_OK;
        CComBSTR     str;

        MagoEE.FormatOptions  fmtopts (mFormatOpts);
        if (fmtopts.radix == 0)
            fmtopts.radix = radix;
        hr = MagoEE.EED.FormatValue( mExprContext, mObjVal.ObjVal, fmtopts, str.m_str );
        if ( FAILED( hr ) )
            return  null;

        return  str.Detach();
    }
 /* SYNTAX ERROR: unexpected trailing } */ }
