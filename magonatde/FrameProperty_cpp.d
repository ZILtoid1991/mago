module FrameProperty_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import FrameProperty;
import ExprContext;
import EnumPropertyInfo;
import EnumX86Reg;
import RegisterSet;
import ArchData;
import Thread;
import IDebuggerProxy;
import RegProperty;
import ICoreProcess;
// #include <MagoEED.h>
// #include <MagoCVConst.h>


namespace  Mago
{
    EnumLocalValues : public  MagoEE.IEEDEnumValues
    {
        alias  std.vector!(BSTR) NameList;

        int                     mRefCount;
        uint32_t                 mIndex;
        NameList                 mNames;
        RefPtr<ExprContext>     mExprContext;

    public:
        EnumLocalValues();
        ~EnumLocalValues();

        void  AddRef();
        void  Release();

        uint32_t  GetCount();
        uint32_t  GetIndex();
        void  Reset();
        HRESULT  Skip( uint32_t  count );
        HRESULT  Clone = HRESULT( MagoEE.IEEDEnumValues*& copiedEnum );

        HRESULT  EvaluateNext( 
            ref const  MagoEE.EvalOptions  options, 
            ref MagoEE.EvalResult  result,
            ref std.wstring  name,
            ref std.wstring  fullName );

        HRESULT  Init = HRESULT( ExprContext* exprContext );
    } /* SYNTAX ERROR: (54): expected <identifier> instead of ; */ 

    this.EnumLocalValues()
    {   mRefCount = ( 0 );
            mIndex = ( 0 );
    }

    this.~EnumLocalValues()
    {
        for ( NameList.iterator  it = mNames.begin(); it != mNames.end(); it++ )
        {
            SysFreeString( *it );
        }
    }

    void  EnumLocalValues.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  EnumLocalValues.Release()
    {
        int     newRef = InterlockedDecrement( &mRefCount );
        _ASSERT( newRef >= 0 );
        if ( newRef == 0 )
        {
            delete  this;
        }
    }

    uint32_t  EnumLocalValues.GetCount()
    {
        return  mNames.size();
    }

    uint32_t  EnumLocalValues.GetIndex()
    {
        return  mIndex;
    }

    void  EnumLocalValues.Reset()
    {
        mIndex = 0;
    }

    HRESULT  EnumLocalValues.Skip( uint32_t  count )
    {
        if ( count > (GetCount() - mIndex) )
        {
            mIndex = GetCount();
            return  S_FALSE;
        }

        mIndex += count;

        return  S_OK;
    }

    HRESULT  EnumLocalValues.Clone( ref IEEDEnumValues*  copiedEnum )
    {
        HRESULT  hr = S_OK;
        RefPtr<EnumLocalValues>  en = new  EnumLocalValues();

        if ( en  is  null )
            return  E_OUTOFMEMORY;

        hr = en.Init( mExprContext );
        if ( FAILED( hr ) )
            return  hr;

        en.mIndex = mIndex;

        copiedEnum = en.Detach();
        return  S_OK;
    }

    HRESULT  EnumLocalValues.EvaluateNext( 
        ref const  MagoEE.EvalOptions  options, 
        ref MagoEE.EvalResult  result,
        ref std.wstring  name,
        ref std.wstring  fullName )
    {
        if ( mIndex >= GetCount() )
            return  E_FAIL;

        HRESULT  hr = S_OK;
        RefPtr<MagoEE.IEEDParsedExpr>  parsedExpr;
        uint32_t     curIndex = mIndex;

        mIndex++;

        name.clear();
        name.append( mNames[curIndex] );

        fullName.clear();
        fullName.append( name );

        hr = MagoEE.ParseText( 
            fullName.c_str(), 
            mExprContext.GetTypeEnv(), 
            mExprContext.GetStringTable(), 
            parsedExpr.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        hr = parsedExpr.Bind( options, mExprContext );
        if ( FAILED( hr ) )
            return  hr;

        hr = parsedExpr.Evaluate( options, mExprContext, result );
        if ( FAILED( hr ) )
            return  hr;

        return  S_OK;
    }

    HRESULT  EnumLocalValues.Init( ExprContext* exprContext )
    {
        _ASSERT( exprContext !is  null );

        HRESULT  hr = S_OK;
        RefPtr<MagoST.ISession>    session;
        MagoST.SymHandle            childSH = { 0 };
        MagoST.SymbolScope          scope = { 0 };

        hr = exprContext.GetSession( session.Ref() );
        if ( FAILED( hr ) )
            return  hr;

        ref const  std.vector!(MagoST.SymHandle)  blockSH = exprContext.GetBlockSH();

        for ( auto  it = blockSH.rbegin(); it != blockSH.rend(); it++)
        {
            hr = session.SetChildSymbolScope( *it, scope );
            if ( FAILED( hr ) )
                return  hr;

            while ( session.NextSymbol( scope, childSH, exprContext.GetPC() ) )
            {
                MagoST.SymInfoData      infoData = { 0 };
                MagoST.ISymbolInfo*    symInfo = null;
                SymString                pstrName;
                CComBSTR                 bstrName;

                hr = session.GetSymbolInfo( childSH, infoData, symInfo );
                if ( FAILED( hr ) )
                    continue;
            
                if ( symInfo.GetSymTag() != MagoST.SymTagData )
                    continue;

                if ( !symInfo.GetName( pstrName ) )
                    continue;

                if ( gOptions.hideInternalNames && pstrName.GetName()[0] == '_' && pstrName.GetName()[1] == '_' )
                    continue;

                hr = Utf8To16( pstrName.GetName(), pstrName.GetLength(), bstrName.m_str );
                if ( FAILED( hr ) )
                    continue;

                mNames.push_back( bstrName );
                bstrName.Detach();
            }
        }

        mExprContext = exprContext;

        return  S_OK;
    }

    ////////////////////////////////////////////////////////////////////////////// 


    // FrameProperty

    this.FrameProperty()
    {
    }

    this.~FrameProperty()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugProperty2 

    HRESULT  FrameProperty.GetPropertyInfo( 
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

        if ( (dwFields & DEBUGPROP_INFO_PROP) != 0 )
        {
            QueryInterface( __uuidof( IDebugProperty2 ), cast(void **) &pPropertyInfo.pProperty );
            pPropertyInfo.dwFields |= DEBUGPROP_INFO_PROP;
        }

        return  S_OK;
    }
    
    HRESULT  FrameProperty.SetValueAsString( 
        LPCOLESTR  pszValue,
        DWORD  dwRadix,
        DWORD  dwTimeout )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.SetValueAsReference( 
        IDebugReference2** rgpArgs,
        DWORD  dwArgCount,
        IDebugReference2* pValue,
        DWORD  dwTimeout )
    {
        return  E_NOTIMPL;
    }

    HRESULT  EnumRegisters(
        Thread* thread,
        IRegisterSet* regSet,
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        IEnumDebugPropertyInfo2** ppEnum )
    {
        _ASSERT( thread !is  null );

        ArchData*           archData = null;

        archData = thread.GetCoreProcess().GetArchData();

        return  EnumRegisters(
            archData,
            regSet,
            thread,
            dwFields,
            dwRadix,
            ppEnum );
    }
    
    HRESULT  FrameProperty.EnumChildren( 
        DEBUGPROP_INFO_FLAGS  dwFields,
        DWORD  dwRadix,
        REFGUID  guidFilter,
        DBG_ATTRIB_FLAGS  dwAttribFilter,
        LPCOLESTR  pszNameFilter,
        DWORD  dwTimeout,
        IEnumDebugPropertyInfo2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;

        if ( (guidFilter == guidFilterLocalsPlusArgs) 
            || (guidFilter == guidFilterAllLocalsPlusArgs) )
        {
        }
        else  if ( guidFilter == guidFilterRegisters )
        {
            return  EnumRegisters(
                mExprContext.GetThread(),
                mRegSet,
                dwFields,
                dwRadix,
                ppEnum );
        }
        else
             return  E_NOTIMPL;

        HRESULT                          hr = S_OK;
        RefPtr<EnumDebugPropertyInfo2>  enumProps;
        RefPtr<EnumLocalValues>         enumVals;

        enumVals = new  EnumLocalValues();
        if ( enumVals  is  null )
            return  E_OUTOFMEMORY;

        hr = enumVals.Init( mExprContext );
        if ( FAILED( hr ) )
            return  hr;

        hr = MakeCComObject( enumProps );
        if ( FAILED( hr ) )
            return  hr;

        MagoEE.FormatOptions  fmtopts = { dwRadix };
        hr = enumProps.Init( enumVals, mExprContext, dwFields, fmtopts );
        if ( FAILED( hr ) )
            return  hr;

        return  enumProps.QueryInterface( __uuidof( IEnumDebugPropertyInfo2 ), cast(void **) ppEnum );
    }
    
    HRESULT  FrameProperty.GetParent( 
        IDebugProperty2** ppParent )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetDerivedMostProperty( 
        IDebugProperty2** ppDerivedMost )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetMemoryBytes( 
        IDebugMemoryBytes2** ppMemoryBytes )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetMemoryContext( 
        IDebugMemoryContext2** ppMemory )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetSize( 
        DWORD* pdwSize )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetReference( 
        IDebugReference2** ppReference )
    {
        return  E_NOTIMPL;
    }
    
    HRESULT  FrameProperty.GetExtendedInfo( 
        REFGUID  guidExtendedInfo,
        VARIANT* pExtendedInfo )
    {
        return  E_NOTIMPL;
    }

    HRESULT  FrameProperty.Init( IRegisterSet* regSet, ExprContext* exprContext )
    {
        _ASSERT( regSet !is  null );
        _ASSERT( exprContext !is  null );

        mRegSet = regSet;
        mExprContext = exprContext;
        return  S_OK;
    }
}
