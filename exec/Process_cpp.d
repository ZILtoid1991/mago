module Process_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Process;
import Machine;
import Thread;
import Iter;
import Module;


this.Process( CreateMethod  way, HANDLE  hProcess, uint32_t  id, const(wchar_t) * exePath )
{   mRefCount = ( 0 );
    mCreateWay = ( way );
    mhProcess = ( hProcess );
    mhSuspendedThread = ( null );
    mId = ( id );
    mExePath = ( exePath );
    mEntryPoint = ( 0 );
    mMachineType = ( 0 );
    mImageBase = ( 0 );
    mSize = ( 0 );
    mMachine = ( null );
    mReachedLoaderBp = ( false );
    mTerminating = ( false );
    mDeleted = ( false );
    mStopped = ( false );
    mStarted = ( false );
    mSuspendCount = ( 0 );
    mOSMod = ( null );
    _ASSERT( hProcess !is  null );
    _ASSERT( id != 0 );
    _ASSERT( (way == Create_Attach) || (way == Create_Launch) );
    InitializeCriticalSection( &mLock );
    memset( &mLastEvent, 0,  mLastEvent.sizeof );
}

this.~Process()
{
    DeleteCriticalSection( &mLock );

    if ( mMachine !is  null )
    {
        mMachine.OnDestroyProcess();
        mMachine.Release();
    }

    if ( mhProcess !is  null )
    {
        CloseHandle( mhProcess );
    }

    if ( mhSuspendedThread !is  null )
    {
        CloseHandle( mhSuspendedThread );
    }

    if ( mOSMod !is  null )
    {
        mOSMod.Release();
    }
}


void     Process.AddRef()
{
    InterlockedIncrement( &mRefCount );
}

void     Process.Release()
{
    LONG  newRefCount = InterlockedDecrement( &mRefCount );
    _ASSERT( newRefCount >= 0 );
    if ( newRefCount == 0 )
    {
        delete  this;
    }
}


CreateMethod  Process.GetCreateMethod()
{
    return  mCreateWay;
}

HANDLE  Process.GetHandle()
{
    return  mhProcess;
}

uint32_t  Process.GetId()
{
    return  mId;
}

const(wchar_t) *  Process.GetExePath()
{
    return  mExePath.c_str();
}

Address  Process.GetEntryPoint()
{
    return  mEntryPoint;
}

void  Process.SetEntryPoint( Address  entryPoint )
{
    mEntryPoint = entryPoint;
}

uint16_t  Process.GetMachineType()
{
    return  mMachineType;
}

void  Process.SetMachineType( uint16_t  machineType )
{
    mMachineType = machineType;
}

Address  Process.GetImageBase()
{
    return  mImageBase;
}

void  Process.SetImageBase( Address  address )
{
    mImageBase = address;
}

uint32_t  Process.GetImageSize()
{
    return  mSize;
}

void  Process.SetImageSize( uint32_t  size )
{
    mSize = size;
}

HANDLE  Process.GetLaunchedSuspendedThread()
{
    return  mhSuspendedThread;
}

void  Process.SetLaunchedSuspendedThread( HANDLE  hThread )
{
    if ( mhSuspendedThread !is  null )
        CloseHandle( mhSuspendedThread );

    mhSuspendedThread = hThread;
}


IMachine* Process.GetMachine()
{
    return  mMachine;
}

void  Process.SetMachine( IMachine* machine )
{
    if ( mMachine !is  null )
    {
        mMachine.OnDestroyProcess();
        mMachine.Release();
    }

    mMachine = machine;

    if ( machine !is  null )
    {
        machine.AddRef();
    }
}


bool  Process.IsStopped()
{
    return  mStopped;
}

void  Process.SetStopped( bool  value )
{
    mStopped = value;
}

bool  Process.IsDeleted()
{
    return  mDeleted;
}

void  Process.SetDeleted()
{
    mDeleted = true;
}

bool  Process.IsTerminating()
{
    return  mTerminating;
}

void  Process.SetTerminating()
{
    mTerminating = true;
}

bool  Process.ReachedLoaderBp()
{
    return  mReachedLoaderBp;
}

void  Process.SetReachedLoaderBp()
{
    mReachedLoaderBp = true;
}

bool  Process.IsStarted()
{
    return  mStarted;
}

void  Process.SetStarted()
{
    mStarted = true;
}


size_t   Process.GetThreadCount()
{
    return  mThreads.size();
}

HRESULT  Process.EnumThreads( ref Enumerator!( Thread* )*  enumerator )
{
    ProcessGuard  guard = ProcessGuard( this );

    _RefReleasePtr< ArrayRefEnum<Thread* /* SYNTAX ERROR: (242): expression expected, not > */ > >.type  en( new  ArrayRefEnum<Thread*>() );

    if ( en.Get() is  null )
        return  E_OUTOFMEMORY;

    if ( !en.Init( mThreads.begin(), mThreads.end(), cast(int) mThreads.size() ) )
        return  E_OUTOFMEMORY;

    enumerator = en.Detach();

    return  S_OK;
}

void     Process.AddThread( Thread* thread )
{
    _ASSERT( FindThread( thread.GetId() ) is  null );

    mThreads.push_back( thread );
}

void     Process.DeleteThread( uint32_t  threadId )
{
    for ( std.list< RefPtr<Thread>  /* SYNTAX ERROR: (264): expression expected, not > */ >.iterator  it = mThreads.begin();
        it != mThreads.end();
        it++ )
    {
        if ( threadId == (*it).GetId() )
        {
            mThreads.erase( it );
            break;
        }
    }
}

Thread* Process.FindThread( uint32_t  id )
{
    for ( std.list< RefPtr<Thread>  /* SYNTAX ERROR: (278): expression expected, not > */ >.iterator  it = mThreads.begin();
        it != mThreads.end();
        it++ )
    {
        if ( id == (*it).GetId() )
            return  it.Get();
    }

    return  null;
}

bool     Process.FindThread( uint32_t  id, ref Thread*  thread )
{
    ProcessGuard  guard = ProcessGuard( this );

    Thread* t = FindThread( id );

    if ( t  is  null )
        return  false;

    thread = t;
    thread.AddRef();

    return  true;
}

Process.ThreadIterator  Process.ThreadsBegin()
{
    return  mThreads.begin();
}

Process.ThreadIterator  Process.ThreadsEnd()
{
    return  mThreads.end();
}

int32_t  Process.GetSuspendCount()
{
    return  mSuspendCount;
}

void     Process.SetSuspendCount( int32_t  count )
{
    mSuspendCount = count;
}


ShortDebugEvent  Process.GetLastEvent()
{
    ShortDebugEvent  event;

    event.EventCode = mLastEvent.EventCode;
    event.ThreadId = mLastEvent.ThreadId;
    event.ExceptionCode = mLastEvent.ExceptionCode;

    return  event;
}

void     Process.SetLastEvent( ref const  DEBUG_EVENT  debugEvent )
{
    mLastEvent.EventCode        = debugEvent.dwDebugEventCode;
    mLastEvent.ThreadId         = debugEvent.dwThreadId;
    mLastEvent.ExceptionCode    = debugEvent.u.Exception.ExceptionRecord.ExceptionCode;
}

void     Process.ClearLastEvent()
{
    memset( &mLastEvent, 0,  mLastEvent.sizeof );
}

Module* Process.GetOSModule()
{
    return  mOSMod;
}

void     Process.SetOSModule( Module* osModule )
{
    if ( mOSMod !is  null )
    {
        mOSMod.Release();
    }

    mOSMod = osModule;

    if ( mOSMod !is  null )
    {
        mOSMod.AddRef();
    }
}

void     Process.Lock()
{
    EnterCriticalSection( &mLock );
}

void     Process.Unlock()
{
    LeaveCriticalSection( &mLock );
}
