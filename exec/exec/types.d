module exec.types;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import exec.common;

alias Address = uintptr_t;

struct AddressRange
{
    Address     Begin;
    Address     End;
}

enum RunMode
{
    RunMode_Run,
    RunMode_Break,
    RunMode_Wait,
}

enum ProbeRunMode
{
    ProbeRunMode_Run,
    ProbeRunMode_Break,
    ProbeRunMode_Wait,
    ProbeRunMode_WalkThunk,
}