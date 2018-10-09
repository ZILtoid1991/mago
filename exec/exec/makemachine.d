module exec.makemachine;

HRESULT MakeMachine(WORD machineType, IMachine *  & machine)
{
    HRESULT hr = E_NOTIMPL;

    version(X86)
    {
        if (machineType == IMAGE_FILE_MACHINE_I386)
        {
            hr = MakeMachineX86(machine);
        }
    }
    else version(X86_64)
    {
        if (machineType == IMAGE_FILE_MACHINE_I386)
        {
            hr = MakeMachineX86(machine);
        }
        else if (machineType == IMAGE_FILE_MACHINE_AMD64)
        {
            hr = MakeMachineX64(machine);
        }
    }
    else
        static assert(false, "Mago doesn't implement a core debugger for the current architecture.");

    return hr;
}
