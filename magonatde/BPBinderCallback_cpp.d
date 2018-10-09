module BPBinderCallback_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import BPBinderCallback;

import PendingBreakpoint;
import BoundBreakpoint;
import BreakpointResolution;
import ErrorBreakpoint;
import ErrorBreakpointResolution;
import BPDocumentContext;
import CodeContext;
import Program;
import Module;
import ICoreProcess;
import ArchData;


namespace  Mago
{
    this.BPBinderCallback( 
        BPBinder* binder,
        PendingBreakpoint* pendingBP, 
        BPDocumentContext* docContext )
    {   mBinder = ( binder );
            mPendingBP = ( pendingBP );
            mDocContext = ( docContext );
            mBoundBPCount = ( 0 );
            mErrorBPCount = ( 0 );
        _ASSERT( binder !is  null );
        _ASSERT( pendingBP !is  null );

        HRESULT          hr = S_OK;

        if ( docContext !is  null )
        {
            hr = docContext.QueryInterface( __uuidof( IDebugDocumentContext2 ), cast(void **) &mDocContextInterface );
            _ASSERT( hr == S_OK );
        }
    }

    int  BPBinderCallback.GetBoundBPCount()
    {
        return  mBoundBPCount;
    }

    int  BPBinderCallback.GetErrorBPCount()
    {
        return  mErrorBPCount;
    }

    bool  BPBinderCallback.GetDocumentContext( ref RefPtr!(BPDocumentContext)  docContext )
    {
        docContext = mDocContext;
        return  docContext.Get() !is  null;
    }

    bool  BPBinderCallback.GetLastErrorBP( ref RefPtr!(ErrorBreakpoint)  errorBP )
    {
        errorBP = mLastErrorBP;
        return  errorBP.Get() !is  null;
    }

    bool  BPBinderCallback.AcceptProgram( Program* prog )
    {
        _ASSERT( prog !is  null );

        mCurProg = prog;
        prog.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &mCurProgInterface );

        prog.ForeachModule( this );

        mCurProg.Release();
        mCurProgInterface.Release();
        return  true;
    }

    HRESULT  BPBinderCallback.BindToModule( Module* mod, Program* prog )
    {
        _ASSERT( mod !is  null );
        _ASSERT( prog !is  null );

        mCurProg = prog;
        prog.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &mCurProgInterface );

        AcceptModule( mod );

        mCurProg.Release();
        mCurProgInterface.Release();
        return  S_OK;
    }

    bool  BPBinderCallback.AcceptModule( Module* mod )
    {
        _ASSERT( mod !is  null );

        HRESULT          hr = S_OK;
        ModuleBinding*  binding = mPendingBP.AddOrFindBinding( mod.GetId() );
        Error            err;

        // nothing changed
        if ( binding.BoundBPs.size() > 0 )
            return  true;

        mBinder.Bind( mod, binding, this, err );

        // we got some new bound BPs
        if ( binding.BoundBPs.size() > 0 )
        {
            mBoundBPCount += binding.BoundBPs.size();
            binding.ErrorBP.Release();     // no more error, if there was one
            return  true;
        }

        // we already have an error, see if we have to replace it
        if ( binding.ErrorBP.Get() !is  null )
        {
            CComPtr<IDebugErrorBreakpointResolution2>   errRes;
            BP_ERROR_RESOLUTION_INFO     bpErrResInfo = { 0 };
            BP_ERROR_TYPE    errType = BPET_NONE;
            BP_ERROR_TYPE    errSev = BPET_NONE;

            binding.ErrorBP.GetBreakpointResolution( &errRes );
            errRes.GetResolutionInfo( BPERESI_TYPE, &bpErrResInfo );

            errType = bpErrResInfo.dwType & BPET_TYPE_MASK;
            errSev = bpErrResInfo.dwType & BPET_SEV_MASK;

            if ( (err.Type > errType) || ((err.Type == errType) && (err.Sev > errSev)) )
                binding.ErrorBP.Release(); // we're going to replace the error
            else
                 return  true;    // new type/severity is not greater, so nothing to change
        }

        // make an error BP

        hr = MakeErrorBP( err, binding.ErrorBP );
        if ( FAILED( hr ) )
            return  true;

        mErrorBPCount++;
        mLastErrorBP = binding.ErrorBP;

        return  true;
    }

    HRESULT  BPBinderCallback.MakeDocContext( MagoST.ISession* session, uint16_t  compIx, uint16_t  fileIx, ref const  MagoST.LineNumber  lineNumber )
    {
        _ASSERT( session !is  null );
        _ASSERT( compIx != 0 );

        HRESULT          hr = S_OK;
        CComBSTR         filename;
        CComBSTR         langName;
        GUID             langGuid;
        TEXT_POSITION    posBegin = { 0 };
        TEXT_POSITION    posEnd = { 0 };
        RefPtr<BPDocumentContext>             docCtx;

        // already exists; don't need to make a new one
        if ( mDocContext.Get() !is  null )
            return  S_FALSE;

        MagoST.FileInfo     fileInfo = { 0 };

        hr = session.GetFileInfo( compIx, fileIx, fileInfo );
        if ( FAILED( hr ) )
            return  hr;

        hr = Utf8To16( fileInfo.Name.ptr, fileInfo.Name.length, filename.m_str );
        if ( FAILED( hr ) )
            return  hr;

        // TODO:
        //compiland->get_language();

        posBegin.dwLine = lineNumber.Number;
        posEnd.dwLine = lineNumber.Number; // NumberEnd;?

        // AD7 lines are 0-based, DIA ones are 1-based
        posBegin.dwLine--;
        posEnd.dwLine--;

        hr = MakeCComObject( docCtx );
        if ( FAILED( hr ) )
            return  hr;

        hr = docCtx.Init( mPendingBP, filename, posBegin, posEnd, langName, langGuid );
        if ( FAILED( hr ) )
            return  hr;

        hr = docCtx.QueryInterface( __uuidof( IDebugDocumentContext2 ), cast(void **) &mDocContextInterface );
        _ASSERT( hr == S_OK );

        mDocContext = docCtx;

        return  hr;
    }

    HRESULT  BPBinderCallback.MakeErrorBP( ref Error  errDesc, ref RefPtr!(ErrorBreakpoint)  errorBP )
    {
        HRESULT          hr = S_OK;
        const(wchar_t) *  msg = null;
        BP_ERROR_TYPE    errType = errDesc.Type | errDesc.Sev;
        RefPtr<ErrorBreakpoint>                     errBP;
        RefPtr<ErrorBreakpointResolution>           errBPRes;
        BpResolutionLocation                         bpResLoc;
        CComPtr<IDebugErrorBreakpointResolution2>   errBPResInterface;
        CComPtr<IDebugPendingBreakpoint2>           pendBPInterface;

        hr = mPendingBP.QueryInterface( __uuidof( IDebugPendingBreakpoint2 ), cast(void **) &pendBPInterface );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( errBPRes );
        if ( FAILED( hr ) )
            return  true;

        msg = GetString( errDesc.StrId );

        hr = errBPRes.Init( bpResLoc, mCurProgInterface, null, msg, errType );
        if ( FAILED( hr ) )
            return  hr;

        hr = errBPRes.QueryInterface( __uuidof( IDebugErrorBreakpointResolution2 ), cast(void **) &errBPResInterface );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( errBP );
        if ( FAILED( hr ) )
            return  hr;

        errBP.Init( pendBPInterface, errBPResInterface );
        errorBP = errBP;

        return  hr;
    }

    void  BPBinderCallback.AddBoundBP( UINT64  address, Module* mod, ModuleBinding* binding )
    {
        HRESULT  hr = S_OK;
        RefPtr<CodeContext>             code;
        RefPtr<BreakpointResolution>    res;
        CComPtr<IDebugBreakpointResolution2>    breakpointResolution;
        CComPtr<IDebugCodeContext2>     codeContext;
        BpResolutionLocation             resLoc;
        RefPtr<BoundBreakpoint>         boundBP;
        ArchData*                       archData = null;

        hr = MakeCComObject( code );
        if ( FAILED( hr ) )
            return;

        // TODO: maybe we should be able to customize the code context with things like function and module

        archData = mCurProg.GetCoreProcess().GetArchData();

        hr = code.Init( cast(Address64) address, mod, mDocContextInterface, archData.GetPointerSize() );
        if ( FAILED( hr ) )
            return;

        hr = code.QueryInterface( __uuidof( IDebugCodeContext2 ), cast(void **) &codeContext );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( res );
        if ( FAILED( hr ) )
            return;

        hr = BpResolutionLocation.InitCode( resLoc, codeContext );
        if ( FAILED( hr ) )
            return;

        hr = res.Init( resLoc, mCurProgInterface, null );
        if ( FAILED( hr ) )
            return;

        hr = res.QueryInterface( 
            __uuidof( IDebugBreakpointResolution2 ), cast(void **) &breakpointResolution );
        _ASSERT( hr == S_OK );

        hr = MakeCComObject( boundBP );
        if ( FAILED( hr ) )
            return;

        const  DWORD  Id = mPendingBP.GetNextBPId();
        boundBP.Init( 
            Id, cast(Address64) address, mPendingBP, breakpointResolution, mCurProg.Get() );

        binding.BoundBPs.push_back( boundBP );
    }
}
