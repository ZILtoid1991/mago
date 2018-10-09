module Thread_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import Thread;


this.Thread( HANDLE  hThread, uint32_t  id, Address  startAddr, Address  tebBase )
{   mRefCount = ( 0 );
    mhThread = ( hThread );
    mId = ( id );
    mStartAddr = ( startAddr );
    mTebBase = ( tebBase );
    _ASSERT( hThread !is  null );
    _ASSERT( id != 0 );
}

this.~Thread()
{
    if ( mhThread !is  null )
    {
        CloseHandle( mhThread );
    }
}


void     Thread.AddRef()
{
    InterlockedIncrement( &mRefCount );
}

void     Thread.Release()
{
    LONG  newRefCount = InterlockedDecrement( &mRefCount );
    _ASSERT( newRefCount >= 0 );
    if ( newRefCount == 0 )
    {
        delete  this;
    }
}


HANDLE  Thread.GetHandle()
{
    return  mhThread;
}

uint32_t  Thread.GetId()
{
    return  mId;
}

Address    Thread.GetStartAddr()
{
    return  mStartAddr;
}

Address    Thread.GetTebBase()
{
    return  mTebBase;
}
