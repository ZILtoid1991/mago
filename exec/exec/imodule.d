module exec.imodule;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

interface IModule
{
public:
    //virtual ~IModule() { }
    void AddRef();
    void Release();
    Address GetImageBase();
    uint32_t GetDebugInfoFileOffset();
    uint32_t GetDebugInfoSize();
    uint32_t GetSize();
    uint16_t GetMachine();
    const wchar_t* GetPath();
    const wchar_t* GetSymbolSearchPath();
    Address GetPreferredImageBase();
    bool IsDeleted();
}
