module ErrorBreakpoint_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import ErrorBreakpoint;


namespace  Mago
{
    // ErrorBreakpoint

    this.ErrorBreakpoint()
    {
    }

    this.~ErrorBreakpoint()
    {
    }


    ////////////////////////////////////////////////////////////////////////////// 
    // IDebugErrorBreakpoint2 

    HRESULT  ErrorBreakpoint.GetPendingBreakpoint( IDebugPendingBreakpoint2** ppPendingBreakpoint ) 
    {
        if ( ppPendingBreakpoint  is  null )
            return  E_INVALIDARG;

        *ppPendingBreakpoint = mPendingBP;
        (*ppPendingBreakpoint).AddRef();
        return  S_OK;
    }

    HRESULT  ErrorBreakpoint.GetBreakpointResolution( IDebugErrorBreakpointResolution2** ppErrorResolution ) 
    {
        if ( ppErrorResolution  is  null )
            return  E_INVALIDARG;

        *ppErrorResolution = mBPRes;
        (*ppErrorResolution).AddRef();
        return  S_OK;
    }


    //----------------------------------------------------------------------------

    void  ErrorBreakpoint.Init( 
            IDebugPendingBreakpoint2* ppPendingBreakpoint, 
            IDebugErrorBreakpointResolution2* ppErrorResolution )
    {
        _ASSERT( ppPendingBreakpoint !is  null );
        _ASSERT( ppErrorResolution !is  null );

        mPendingBP = ppPendingBreakpoint;
        mBPRes = ppErrorResolution;
    } 
}
