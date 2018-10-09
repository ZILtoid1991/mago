module exec.commandfunctor;

abstract class CommandFunctor
{
    abstract void Run();
}

class ExecCommandFunctor : public CommandFunctor
{
    ref Exec Core;
    HRESULT OutHResult;

    this(ref Exec exec)
    {
        Core = (exec);
        OutHResult = (E_FAIL);
    }

private:
    ref ExecCommandFunctor operator = (ref const ExecCommandFunctor);
}

class LaunchParams : ExecCommandFunctor
{
    LaunchInfo* Settings;
    RefPtr!(IProcess) OutProcess;

    this(ref Exec exec)
    {
        super(exec);
        Settings = (null);
        OutProcess = (null);
    }

    void Run()
    {
        OutHResult = Core.Launch(Settings, OutProcess.Ref());
    }
}

class AttachParams : ExecCommandFunctor
{
    uint32_t ProcessId;
    RefPtr!(IProcess) OutProcess;

    this(ref Exec exec)
    {
        super(exec);
        ProcessId = (0);
        OutProcess = (null);
    }

    void Run()
    {
        OutHResult = Core.Attach(ProcessId, OutProcess.Ref());
    }
}

class TerminateParams : ExecCommandFunctor
{
    IProcess Process;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
    }

    void Run()
    {
        OutHResult = Core.Terminate(Process);
    }
}

class DetachParams : ExecCommandFunctor
{
    IProcess Process;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
    }

    void Run()
    {
        OutHResult = Core.Detach(Process);
    }
}

class ResumeLaunchedProcessParams : ExecCommandFunctor
{
    IProcess Process;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
    }

    void Run()
    {
        OutHResult = Core.ResumeLaunchedProcess(Process);
    }
}

class ReadMemoryParams : ExecCommandFunctor
{
    IProcess Process;
    Address Address;
    uint8_t* Buffer;
    uint32_t Length;
    uint32_t OutLengthRead;
    uint32_t OutLengthUnreadable;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        Address = (0);
        Buffer = (null);
        Length = (0);
    }

    void Run()
    {
        OutHResult = Core.ReadMemory(Process, Address, Length, OutLengthRead,
                OutLengthUnreadable, Buffer);
    }
}

class WriteMemoryParams : ExecCommandFunctor
{
    IProcess Process;
    Address Address;
    uint8_t* Buffer;
    uint32_t Length;
    uint32_t OutLengthWritten;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        Address = (0);
        Buffer = (null);
        Length = (0);
    }

    void Run()
    {
        OutHResult = Core.WriteMemory(Process, Address, Length, OutLengthWritten, Buffer);
    }
}

class SetBreakpointParams : ExecCommandFunctor
{
    IProcess Process;
    Address Address;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        Address = (0);
    }

    void Run()
    {
        OutHResult = Core.SetBreakpoint(Process, Address);
    }
}

class RemoveBreakpointParams : ExecCommandFunctor
{
    IProcess Process;
    Address Address;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        Address = (0);
    }

    void Run()
    {
        OutHResult = Core.RemoveBreakpoint(Process, Address);
    }
}

class StepOutParams : ExecCommandFunctor
{
    IProcess Process;
    Address TargetAddress;
    bool HandleException;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        TargetAddress = (0);
        HandleException = (false);
    }

    void Run()
    {
        OutHResult = Core.StepOut(Process, TargetAddress, HandleException);
    }
}

class StepInstructionParams : ExecCommandFunctor
{
    IProcess Process;
    bool StepIn;
    bool HandleException;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        StepIn = (false);
        HandleException = (false);
    }

    void Run()
    {
        OutHResult = Core.StepInstruction(Process, StepIn, HandleException);
    }
}

class StepRangeParams : ExecCommandFunctor
{
    IProcess Process;
    bool StepIn;
    AddressRange Range;
    bool HandleException;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        StepIn = (false);
        HandleException = (false);
    }

    void Run()
    {
        OutHResult = Core.StepRange(Process, StepIn, Range, HandleException);
    }
}

class ContinueParams : ExecCommandFunctor
{
    IProcess Process;
    bool HandleException;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        HandleException = (false);
    }

    void Run()
    {
        OutHResult = Core.Continue(Process, HandleException);
    }
}

class ExecuteParams : ExecCommandFunctor
{
    IProcess Process;
    bool HandleException;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
        HandleException = (false);
    }

    void Run()
    {
        OutHResult = Core.CancelStep(Process);

        if (SUCCEEDED(OutHResult))
            OutHResult = Core.Continue(Process, HandleException);
    }
}

class AsyncBreakParams : ExecCommandFunctor
{
    IProcess Process;

    this(ref Exec exec)
    {
        super(exec);
        Process = (null);
    }

    void Run()
    {
        OutHResult = Core.AsyncBreak(Process);
    }
}
