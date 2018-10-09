module EnumFrameInfo_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import EnumFrameInfo;


namespace  Mago
{
    this.FrameInfoArray( size_t  length )
    {   mArray = ( new  FRAMEINFO[ length ] );
            mLen = ( length );
        size_t   size = length *  FRAMEINFO.sizeof;
        memset( mArray, 0, size );
    }

    this.~FrameInfoArray()
    {
        if ( mArray  is  null )
            return;

        for ( size_t  i = 0; i < mLen; i++ )
        {
            _CopyFrameInfo.destroy( &mArray[i] );
        }

        delete [] mArray;
    }

    size_t  FrameInfoArray.GetLength() const
    {
        return  mLen;
    }

    ref FRAMEINFO  FrameInfoArray.operator[]( size_t  i ) const
    {
        _ASSERT( i < mLen );
        return  mArray[i];
    }

    FRAMEINFO* FrameInfoArray.Get() const
    {
        return  mArray;
    }

    FRAMEINFO* FrameInfoArray.Detach()
    {
        FRAMEINFO*  array = mArray;
        mArray = null;
        return  array;
    }


    //------------------------------------------------------------------------

    HRESULT  _CopyFrameInfo.copy( FRAMEINFO* dest, const  FRAMEINFO* source )
    {
        _ASSERT( dest !is  null && source !is  null );
        _ASSERT( dest != source );

        dest.m_bstrFuncName = SysAllocString( source.m_bstrFuncName );
        dest.m_bstrReturnType = SysAllocString( source.m_bstrReturnType );
        dest.m_bstrArgs = SysAllocString( source.m_bstrArgs );
        dest.m_bstrLanguage = SysAllocString( source.m_bstrLanguage );
        dest.m_bstrModule = SysAllocString( source.m_bstrModule );
        
        dest.m_addrMax = source.m_addrMax;
        dest.m_addrMin = source.m_addrMin;
        dest.m_dwFlags = source.m_dwFlags;
        dest.m_dwValidFields = source.m_dwValidFields;
        dest.m_fHasDebugInfo = source.m_fHasDebugInfo;
        dest.m_fStaleCode = source.m_fStaleCode;

        dest.m_pFrame = source.m_pFrame;
        if ( dest.m_pFrame !is  null )
            dest.m_pFrame.AddRef();

        dest.m_pModule = source.m_pModule;
        if ( dest.m_pModule !is  null )
            dest.m_pModule.AddRef();

        return  S_OK;
    }

    void  _CopyFrameInfo.init( FRAMEINFO* p )
    {
        memset( p, 0, ( *p).sizeof );
    }

    void  _CopyFrameInfo.destroy( FRAMEINFO* p )
    {
        SysFreeString( p.m_bstrFuncName );
        SysFreeString( p.m_bstrReturnType );
        SysFreeString( p.m_bstrArgs );
        SysFreeString( p.m_bstrLanguage );
        SysFreeString( p.m_bstrModule );
        
        if ( p.m_pFrame !is  null )
            p.m_pFrame.Release();

        if ( p.m_pModule !is  null )
            p.m_pModule.Release();
    }
}
