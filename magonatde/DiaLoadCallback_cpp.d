module DiaLoadCallback_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import DiaLoadCallback;


namespace  Mago
{
    this.DiaLoadCallback()
    {   mRefCount = ( 0 );
    }

    this.~DiaLoadCallback()
    {
    }

    void  DiaLoadCallback.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  DiaLoadCallback.Release()
    {
        int  newRef = InterlockedDecrement( &mRefCount );
        _ASSERT( newRef >= 0 );
        if ( newRef == 0 )
            delete  this;
    }

    HRESULT  DiaLoadCallback.NotifyDebugDir( 
        bool  fExecutable,
        DWORD  cbData,
        BYTE* pbData )
    {
        return  S_OK;
    }

    HRESULT  DiaLoadCallback.NotifyOpenDBG( 
        LPCOLESTR  dbgPath,
        HRESULT  resultCode )
    {
        mSearchList.push_back( SearchStatus() );

        mSearchList.back().Path = dbgPath;
        mSearchList.back().ResultCode = resultCode;

        return  S_OK;
    }

    HRESULT  DiaLoadCallback.RestrictRegistryAccess()
    {
        return  S_OK;
    }

    HRESULT  DiaLoadCallback.RestrictSymbolServerAccess()
    {
        return  S_OK;
    }

    ref const  DiaLoadCallback.SearchList    DiaLoadCallback.GetSearchList()
    {
        return  mSearchList;
    }

    HRESULT  DiaLoadCallback.GetSearchText( BSTR* text )
    {
        _ASSERT( text !is  null );

        HRESULT      hr = S_OK;
        CComBSTR     bstr;
        int          i = 0;

        for ( SearchList.iterator  it = mSearchList.begin(); 
            it != mSearchList.end();
            it++, i++ )
        {
            if ( i > 0 )
                bstr.Append( "\r\n"w );

            bstr.Append( it.Path.c_str() );

                // TODO: get the right strings for each declared error code
            if ( it.ResultCode == S_OK )
                bstr.Append( "... Opened"w );
            else
                 bstr.Append( "... Not found"w );
        }

        *text = bstr.Detach();

        return  hr;
    }
}
