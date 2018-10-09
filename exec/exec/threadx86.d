module exec.treadx86;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import exec.common;
import exec.threadX86;

enum ExpectedCode
{
    None,
    SS,
    BP,
}

enum Expect_None = ExpectedCode.None;
enum Expect_SS = ExpectedCode.SS;
enum Expect_BP = ExpectedCode.BP;

enum Motion
{
    None,
    StepIn,
    StepOver,
    RangeStepIn,
    RangeStepOver
}

enum Motion_None = Motion.None;
enum Motion_StepIn = Motion.StepIn;
enum Motion_StepOver = Motion.StepOver;
enum Motion_RangeStepIn = Motion.RangeStepIn;
enum Motion_RangeStepOver = Motion.RangeStepOver;

enum NotifyAction
{
    None,
    Run,
    StepComplete,
    Trigger,
    CheckRange,
    CheckCall,
    StepOut
}

enum NotifyNone = NotifyAction.None;
enum NotifyRun = NotifyAction.Run;
enum NotifyStepComplete = NotifyAction.StepComplete;
enum NotifyTrigger = NotifyAction.Trigger;
enum NotifyCheckRange = NotifyAction.CheckRange;
enum NotifyCheckCall = NotifyAction.CheckCall;
enum NotifyStepOut = NotifyAction.StepOut;

struct RangeStep
{
    AddressRange Range;
    AddressRange ThunkRange;
    bool InThunk;
}

struct ExpectedEvent
{
    RangeStep* Range;
    Address BPAddress;
    Address UnpatchedAddress;
    int NotifyAction;
    Motion Motion;
    ExpectedCode Code;
    bool PatchBP;
    bool ResumeThreads;
    bool ClearTF;
    bool RemoveBP;
}

class ThreadX86Base
{
    Thread mExecThread;
    ExpectedEvent mExpectedEvents[2];
    int mExpectedCount;
public:
    this(Thread execThread)
    {
        mExecThread = (execThread);
        mExpectedCount = (0);
        if (mExecThread !is null)
            mExecThread.AddRef();
    }

    ~this()
    {
        if (mExecThread !is null)
            mExecThread.Release();

        // free resources held by the events
        while (mExpectedCount > 0)
        {
            PopExpected();
        }
    }

    Thread GetExecThread()
    {
        return mExecThread;
    }

    int GetExpectedCount()
    {
        return mExpectedCount;
    }

    ExpectedEvent* GetTopExpected()
    {
        if (mExpectedCount == 0)
            return null;

        return  & mExpectedEvents[mExpectedCount - 1];
    }

    ExpectedEvent* PushExpected(ExpectedCode code, int notifier)
    {
        assert(code == Expect_SS || code == Expect_BP);
        assert(notifier != 0);
        assert(mExpectedCount < 2);

        if (mExpectedCount >= 2)
            return null;

        ExpectedEvent* event = &mExpectedEvents[mExpectedCount];
        mExpectedCount++;

        memset(event, 0, ( * event).sizeof);
        event.Code = code;
        event.NotifyAction = notifier;

        return event;
    }

    void PopExpected()
    {
        assert(mExpectedCount > 0);

        if (mExpectedCount > 0)
        {
            mExpectedCount--;

            ExpectedEvent* event = &mExpectedEvents[mExpectedCount];

            if (event.Range !is null)
            {
                delete event.Range;
                event.Range = null;
            }
        }
    }

    RangeStep* AllocRange()
    {
        RangeStep* range = new RangeStep();

        if (range is null)
            return null;

        memset(range, 0, ( * range).sizeof);
        return range;
    }

}
