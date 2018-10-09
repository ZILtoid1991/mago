module ThreadX86_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import ThreadX86;
import Thread;


this.ThreadX86Base( Thread* execThread )
{   mExecThread = ( execThread );
    mExpectedCount = ( 0 );
    if ( mExecThread !is  null )
        mExecThread.AddRef();
}

this.~ThreadX86Base()
{
    if ( mExecThread !is  null )
        mExecThread.Release();

    // free resources held by the events
    while ( mExpectedCount > 0 )
    {
        PopExpected();
    }
}

Thread*     ThreadX86Base.GetExecThread()
{
    return  mExecThread;
}

int  ThreadX86Base.GetExpectedCount()
{
    return  mExpectedCount;
}

ExpectedEvent* ThreadX86Base.GetTopExpected()
{
    if ( mExpectedCount == 0 )
        return  null;

    return &mExpectedEvents[mExpectedCount - 1];
}

ExpectedEvent* ThreadX86Base.PushExpected( ExpectedCode  code, int  notifier )
{
    _ASSERT( code == Expect_SS || code == Expect_BP );
    _ASSERT( notifier != 0 );
    _ASSERT( mExpectedCount < 2 );

    if ( mExpectedCount >= 2 )
        return  null;

    ExpectedEvent* event = &mExpectedEvents[mExpectedCount];
    mExpectedCount++;

    memset( event, 0, ( *event).sizeof );
    event.Code = code;
    event.NotifyAction = notifier;

    return  event;
}

void  ThreadX86Base.PopExpected()
{
    _ASSERT( mExpectedCount > 0 );

    if ( mExpectedCount > 0 )
    {
        mExpectedCount--;

        ExpectedEvent* event = &mExpectedEvents[mExpectedCount];

        if ( event.Range !is  null )
        {
            delete  event.Range;
            event.Range = null;
        }
    }
}

RangeStep* ThreadX86Base.AllocRange()
{
    RangeStep* range = new  RangeStep();

    if ( range  is  null )
        return  null;

    memset( range, 0, ( *range).sizeof );
    return  range;
}
