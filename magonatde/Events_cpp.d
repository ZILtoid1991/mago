module Events_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Events;
import Program;
import DRuntime;


static  const  DWORD   DExceptionCode = 0xE0440001;


namespace  Mago
{
//----------------------------------------------------------------------------
//  EngineCreateEvent
//----------------------------------------------------------------------------

    void  EngineCreateEvent.Init( IDebugEngine2* engine )
    {
        _ASSERT( engine !is  null );
        _ASSERT( mEngine  is  null );
        mEngine = engine;
    }

    HRESULT  EngineCreateEvent.GetEngine( IDebugEngine2** pEngine )
    {
        if ( pEngine  is  null )
            return  E_INVALIDARG;

        _ASSERT( mEngine !is  null );
        *pEngine = mEngine;
        (*pEngine).AddRef();
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  ProgramDestroyEvent
//----------------------------------------------------------------------------

    this.ProgramDestroyEvent()
    {   mExitCode = ( 0 );
    }

    void  ProgramDestroyEvent.Init( DWORD  exitCode )
    {
        _ASSERT( mExitCode == 0 );
        mExitCode = exitCode;
    }

    HRESULT  ProgramDestroyEvent.GetExitCode( DWORD* pdwExit )
    {
        if ( pdwExit  is  null )
            return  E_INVALIDARG;

        *pdwExit = mExitCode;
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  ThreadDestroyEvent
//----------------------------------------------------------------------------

    this.ThreadDestroyEvent()
    {   mExitCode = ( 0 );
    }

    void  ThreadDestroyEvent.Init( DWORD  exitCode )
    {
        _ASSERT( mExitCode == 0 );
        mExitCode = exitCode;
    }

    HRESULT  ThreadDestroyEvent.GetExitCode( DWORD* pdwExit )
    {
        if ( pdwExit  is  null )
            return  E_INVALIDARG;

        *pdwExit = mExitCode;
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  OutputStringEvent
//----------------------------------------------------------------------------

    void  OutputStringEvent.Init( const(wchar_t) * str )
    {
        _ASSERT( str !is  null );
        _ASSERT( mStr  is  null );
        mStr = str;
    }

    HRESULT  OutputStringEvent.GetString( BSTR* pbstrString )
    {
        if ( pbstrString  is  null )
            return  E_INVALIDARG;

        *pbstrString = SysAllocString( mStr );
        return *pbstrString !is  null ? S_OK : E_OUTOFMEMORY;
    }


//----------------------------------------------------------------------------
//  ModuleLoadEvent
//----------------------------------------------------------------------------

    this.ModuleLoadEvent()
    {   mLoad = ( false );
    }

    void  ModuleLoadEvent.Init(
       IDebugModule2*   module,
       const(wchar_t) *   debugMessage,
       bool              load )
    {
        _ASSERT( module !is  null );
        _ASSERT( mMod  is  null );
        _ASSERT( mMsg  is  null );

        mMod = module;
        mLoad = load;

        // don't worry if we can't allocate the string or if it's NULL
        mMsg.Attach( SysAllocString( debugMessage ) );
    }

    HRESULT  ModuleLoadEvent.GetModule( 
       IDebugModule2** pModule,
       BSTR*           pbstrDebugMessage,
       BOOL*           pbLoad )
    {
        _ASSERT( mMod !is  null );

        if ( pbstrDebugMessage !is  null )
        {
            *pbstrDebugMessage = SysAllocString( mMsg );
        }

        if ( pbLoad !is  null )
            *pbLoad = mLoad;

        *pModule = mMod;
        (*pModule).AddRef();

        return  S_OK;
    }


    //----------------------------------------------------------------------------
    //  SymbolSearchEvent
    //----------------------------------------------------------------------------

    this.SymbolSearchEvent()
    {   mInfoFlags = ( 0 );
    }

    void  SymbolSearchEvent.Init(
       IDebugModule3*       module,
       const(wchar_t) *       debugMessage,
       MODULE_INFO_FLAGS     infoFlags )
    {
        _ASSERT( module !is  null );
        _ASSERT( mMod  is  null );
        _ASSERT( mMsg  is  null );

        mMod = module;
        mInfoFlags = infoFlags;
        // don't worry if we can't allocate the string or if it's NULL
        mMsg.Attach( SysAllocString( debugMessage ) );
    }

    HRESULT  SymbolSearchEvent.GetSymbolSearchInfo( 
       IDebugModule3**      pModule,
       BSTR*                pbstrDebugMessage,
       MODULE_INFO_FLAGS*   pdwModuleInfoFlags )
    {
        _ASSERT( mMod !is  null );

        if ( pbstrDebugMessage !is  null )
        {
            *pbstrDebugMessage = SysAllocString( mMsg );
        }

        if ( pdwModuleInfoFlags !is  null )
            *pdwModuleInfoFlags = mInfoFlags;

        *pModule = mMod;
        (*pModule).AddRef();

        return  S_OK;
    }


//----------------------------------------------------------------------------
//  BreakpointEvent
//----------------------------------------------------------------------------

    void  BreakpointEvent.Init( 
        IEnumDebugBoundBreakpoints2* pEnum )
    {
        _ASSERT( pEnum !is  null );
        _ASSERT( mEnumBP  is  null );
        mEnumBP = pEnum;
    }

    HRESULT  BreakpointEvent.EnumBreakpoints( IEnumDebugBoundBreakpoints2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;

        _ASSERT( mEnumBP !is  null );
        *ppEnum = mEnumBP;
        (*ppEnum).AddRef();
        return  S_OK;
    }

//----------------------------------------------------------------------------
//  BreakpointBoundEvent
//----------------------------------------------------------------------------

    void  BreakpointBoundEvent.Init( 
        IEnumDebugBoundBreakpoints2* pEnum, 
        IDebugPendingBreakpoint2* pPending )
    {
        _ASSERT( pEnum !is  null );
        _ASSERT( pPending !is  null );
        _ASSERT( mEnumBoundBP  is  null );
        _ASSERT( mPendingBP  is  null );
        mEnumBoundBP = pEnum;
        mPendingBP = pPending;
    }

    HRESULT  BreakpointBoundEvent.GetPendingBreakpoint( IDebugPendingBreakpoint2** ppPendingBP )
    {
        if ( ppPendingBP  is  null )
            return  E_INVALIDARG;

        _ASSERT( mPendingBP !is  null );
        *ppPendingBP = mPendingBP;
        (*ppPendingBP).AddRef();
        return  S_OK;
    }

    HRESULT  BreakpointBoundEvent.EnumBoundBreakpoints( IEnumDebugBoundBreakpoints2** ppEnum )
    {
        if ( ppEnum  is  null )
            return  E_INVALIDARG;

        _ASSERT( mEnumBoundBP !is  null );
        *ppEnum = mEnumBoundBP;
        (*ppEnum).AddRef();
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  BreakpointErrorEvent
//----------------------------------------------------------------------------

    void  BreakpointErrorEvent.Init( 
        IDebugErrorBreakpoint2* pError )
    {
        _ASSERT( pError !is  null );
        _ASSERT( mErrorBP  is  null );
        mErrorBP = pError;
    }

    HRESULT  BreakpointErrorEvent.GetErrorBreakpoint( IDebugErrorBreakpoint2** ppErrorBP )
    {
        if ( ppErrorBP  is  null )
            return  E_INVALIDARG;

        _ASSERT( mErrorBP !is  null );
        *ppErrorBP = mErrorBP;
        (*ppErrorBP).AddRef();
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  BreakpointUnboundEvent
//----------------------------------------------------------------------------

    this.BreakpointUnboundEvent()
    {   mReason = ( BPUR_UNKNOWN );
    }

    void  BreakpointUnboundEvent.Init(
        IDebugBoundBreakpoint2* pBound, BP_UNBOUND_REASON  reason )
    {
        _ASSERT( pBound !is  null );
        _ASSERT( reason !is  null );
        _ASSERT( mBoundBP  is  null );
        mBoundBP = pBound;
        mReason = reason;
    }

    HRESULT  BreakpointUnboundEvent.GetBreakpoint( IDebugBoundBreakpoint2** ppBoundBP )
    {
        if ( ppBoundBP  is  null )
            return  E_INVALIDARG;

        _ASSERT( mBoundBP !is  null );
        *ppBoundBP = mBoundBP;
        (*ppBoundBP).AddRef();
        return  S_OK;
    }

    HRESULT  BreakpointUnboundEvent.GetReason( BP_UNBOUND_REASON* pdwUnboundReason )
    {
        if ( pdwUnboundReason  is  null )
            return  E_INVALIDARG;

        *pdwUnboundReason = mReason;
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  ExceptionEvent
//----------------------------------------------------------------------------

    this.ExceptionEvent()
    {   mCode = ( 0 );
            mState = ( EXCEPTION_NONE );
            mGuidType = ( GUID_NULL );
            mRootExceptionName = ( null );
            mSearchKey = ( Code );
    }

    void  ExceptionEvent.Init( 
        Program* prog, 
        bool  firstChance, 
        const  EXCEPTION_RECORD64* exceptRec,
        bool  canPassToDebuggee )
    {
        mProg = prog;
        mState = firstChance ? EXCEPTION_STOP_FIRST_CHANCE : EXCEPTION_STOP_SECOND_CHANCE;
        mCode = exceptRec.ExceptionCode;
        mCanPassToDebuggee = canPassToDebuggee;

        wchar_t  name[100] = ""w;
        if ( exceptRec.ExceptionCode == DExceptionCode )
        {
            mGuidType = GetDExceptionType();
            mRootExceptionName = GetRootDExceptionName();
            mSearchKey = Name;
            if ( ICoreProcess* process = prog.GetCoreProcess() )
            {
                DRuntime* druntime = prog.GetDRuntime();

                druntime.GetClassName( exceptRec.ExceptionInformation[0], &mExceptionName );
                druntime.GetExceptionInfo( exceptRec.ExceptionInformation[0], &mExceptionInfo );
            }

            if ( mExceptionName  is  null )
                mExceptionName = "D Exception"w;
        }
        else
        {
            // make it a Win32 exception
            mGuidType = GetWin32ExceptionType();
            swprintf_s( name, "%08x"w, exceptRec.ExceptionCode );
            mRootExceptionName = GetRootWin32ExceptionName();
            mSearchKey = Code;
            mExceptionName = name;
        }
    }

    HRESULT  ExceptionEvent.GetException( EXCEPTION_INFO* pExceptionInfo )
    {
        if ( pExceptionInfo  is  null )
            return  E_INVALIDARG;

        memset( pExceptionInfo, 0, ( *pExceptionInfo).sizeof );

        _ASSERT( mProg.Get() !is  null );
        mProg.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &pExceptionInfo.pProgram );
        
        mProg.GetName( &pExceptionInfo.bstrProgramName );
        
        pExceptionInfo.guidType = mGuidType;
        pExceptionInfo.dwState = mState;
        pExceptionInfo.dwCode = mCode;
        pExceptionInfo.bstrExceptionName = mExceptionName.Copy();

        return  S_OK;
    }

    HRESULT  ExceptionEvent.GetExceptionDescription( BSTR* pbstrDescription )
    {
        if ( pbstrDescription  is  null )
            return  E_INVALIDARG;

        bool     firstChance = (mState & EXCEPTION_STOP_FIRST_CHANCE) != 0;
        wchar_t  msg[256] = ""w;
        const(wchar_t) * format = null;

        if ( firstChance )
            format = GetString( IDS_FIRST_CHANCE_EXCEPTION );
        else
             format = GetString( IDS_UNHANDLED_EXCEPTION );

        if ( format !is  null )
            _swprintf_p( msg, _countof( msg ), format, mExceptionName.m_str );
        else
             wcscpy_s( msg, mExceptionName.m_str );

        if ( mExceptionInfo )
        {
            CComBSTR  bmsg = CComBSTR( msg );
            bmsg.Append( ' 'w );
            bmsg.Append( mExceptionInfo );
            *pbstrDescription = bmsg.Detach();
        }
        else
            *pbstrDescription = SysAllocString( msg );
        return  S_OK;
    }

    void  ExceptionEvent.SetExceptionName( LPCOLESTR  name )
    {
        mExceptionName = name;
    }

    HRESULT  ExceptionEvent.CanPassToDebuggee()
    {
        return  mCanPassToDebuggee ? S_OK : S_FALSE;
    }

    HRESULT  ExceptionEvent.PassToDebuggee( BOOL  fPass )
    {
        mProg.SetPassExceptionToDebuggee( fPass ? true : false );
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  EmbeddedBreakpointEvent
//----------------------------------------------------------------------------

    this.EmbeddedBreakpointEvent()
    {
    }

    void  EmbeddedBreakpointEvent.Init( Program* prog )
    {
        wchar_t  name[100] = ""w;
        CComBSTR  progName;
        const(wchar_t) * BpTriggeredStr = GetString( IDS_BP_TRIGGERED );

        if ( BpTriggeredStr !is  null )
        {
            prog.GetName( &progName );
            _swprintf_p( name, _countof( name ), BpTriggeredStr, progName.m_str );
        }

        mProg = prog;
        mExceptionName = name;
    }

    HRESULT  EmbeddedBreakpointEvent.GetException( EXCEPTION_INFO* pExceptionInfo )
    {
        if ( pExceptionInfo  is  null )
            return  E_INVALIDARG;

        memset( pExceptionInfo, 0, ( *pExceptionInfo).sizeof );

        _ASSERT( mProg.Get() !is  null );
        mProg.QueryInterface( __uuidof( IDebugProgram2 ), cast(void **) &pExceptionInfo.pProgram );
        
        mProg.GetName( &pExceptionInfo.bstrProgramName );
        
        pExceptionInfo.guidType = GUID_NULL;
        pExceptionInfo.dwState = 0;
        pExceptionInfo.dwCode = 0;
        pExceptionInfo.bstrExceptionName = mExceptionName.Copy();

        return  S_OK;
    }

    HRESULT  EmbeddedBreakpointEvent.GetExceptionDescription( BSTR* pbstrDescription )
    {
        if ( pbstrDescription  is  null )
            return  E_INVALIDARG;

        *pbstrDescription = SysAllocString( mExceptionName );
        return  S_OK;
    }

    HRESULT  EmbeddedBreakpointEvent.CanPassToDebuggee()
    {
        // no, can't pass to debuggee
        return  S_FALSE;
    }

    HRESULT  EmbeddedBreakpointEvent.PassToDebuggee( BOOL  fPass )
    {
        return  S_OK;
    }


//----------------------------------------------------------------------------
//  MessageTextEvent
//----------------------------------------------------------------------------

    this.MessageTextEvent()
    {   mMessageType = ( MT_OUTPUTSTRING );
    }

    void  MessageTextEvent.Init( 
        MESSAGETYPE  reason, const(wchar_t) * msg )
    {
        _ASSERT( msg !is  null );
        mMessageType = (reason & MT_REASON_MASK) | MT_OUTPUTSTRING;
        mMessage = msg;
    }

    HRESULT  MessageTextEvent.GetMessageW( 
            MESSAGETYPE*    pMessageType,
            BSTR*           pbstrMessage,
            DWORD*          pdwType,
            BSTR*           pbstrHelpFileName,
            DWORD*          pdwHelpId )
    {
        if ( (pMessageType  is  null)
            || (pbstrMessage  is  null)
            || (pdwType  is  null)
            || (pbstrHelpFileName  is  null)
            || (pdwHelpId  is  null) )
            return  E_INVALIDARG;

        *pbstrMessage = mMessage.Copy();
        if ( *pbstrMessage  is  null )
            return  E_OUTOFMEMORY;

        *pMessageType = mMessageType;
        *pdwType = 0;
        *pbstrHelpFileName = null;
        *pdwHelpId = 0;
        return  S_OK;
    }

    HRESULT  MessageTextEvent.SetResponse( DWORD  dwResponse )
    {
        return  S_OK;
    }
}
