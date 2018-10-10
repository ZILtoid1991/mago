module debugger;

/*
	debugger.d
	by Laszlo Szeremi
	(c) 2018
*/

import core.stdc.inttypes;

///Interfaces with the IDebugThread2 class
extern(C) struct DebugThread{
	///Thread ID
	DWORD threadID;
	///Null-terminated string
	wchar_t* threadName;
	///Points to the original IDebugThread2 class, but without the type specified
	void* original;
}

alias STEPKIND = DWORD;
alias STEPUNIT = DWORD;

//to interface with the C++ part of the debugger
extern(C++) int32 Debugger_Init();
extern(C++) void Debugger_Deinit();
extern(C++) int32 Debugger_enterCommandLoop();
/// load executable
extern(C++) bool Debugger_load(uint64_t requestId = UNSPECIFIED_REQUEST_ID, bool synchronous = true);
/// start execution
extern(C++) bool Debugger_run(uint64_t requestId = UNSPECIFIED_REQUEST_ID);
/// resume paused execution
extern(C++) bool Debugger_resume(uint64_t requestId = UNSPECIFIED_REQUEST_ID, DWORD threadId = 0);
/// break program if running
extern(C++) bool Debugger_causeBreak(uint64_t requestId = UNSPECIFIED_REQUEST_ID);
/// stop program execution
extern(C++) bool Debugger_stop(uint64_t requestId);
/// step paused program
extern(C++) bool Debugger_step(STEPKIND stepKind, STEPUNIT stepUnit, DWORD threadId = 0, uint64_t requestId = UNSPECIFIED_REQUEST_ID);
/// step paused program
extern(C++) bool stepInternal(STEPKIND stepKind, STEPUNIT stepUnit, DebugThread* pThread, uint64_t requestId = UNSPECIFIED_REQUEST_ID);
/// finds a thead by ID
extern(C++) DebugThread* Debugger_findThreadByID(DWORD threadId);

/**
 * Handles command line from 
 */
class CmdLineHandler : CmdInputCallback{
	this(){
		
	}
	/// Moved from Debugger
	void showHelp() {
		wstring[] res;
		getCommandsHelp(res, params.miMode);
		for (unsigned i = 0; i < res.size(); i++)
			writeDebuggerMessage(res[i]);
	}
	/// called on new input line
	void onInputLine(ref wstring s){
		CRLog.trace("Input line: %s", toUtf8(s).c_str());
		if (s.empty())
			return;

		//if (_entryPointContinuePending) {
		//	_entryPointContinuePending = false;
		//	resume();
		//}

		MICommand cmd;
		if (!cmd.parse(s)) {
			writeErrorMessage(cmd.requestId, "invalid command syntax: "w + s, "undefined-command"w);
			return;
		}
		switch (cmd.commandId) {
		case CMD_UNKNOWN:
		default:
			if (cmd.miCommand)
				writeErrorMessage(cmd.requestId, "Undefined MI command: "w + s, "undefined-command"w);
			else
				writeErrorMessage(cmd.requestId, "unknown command: "w + s, "undefined-command"w);
			break;
		case CMD_GDB_EXIT:
			CRLog.info("quit requested");
			_quitRequested = true;
			if (params.miMode) {
				writeStdout("^exit"w);
				Sleep(10);
			}
			break;
		case CMD_HELP:
			showHelp();
			break;
		case CMD_EXEC_RUN:
			if (cmd.hasParam(wstring("--start"w)))
				params.stopOnEntry = true;
			run(cmd.requestId);
			break;
		case CMD_EXEC_CONTINUE:
			resume(cmd.requestId);
			break;
		case CMD_EXEC_INTERRUPT:
			causeBreak(cmd.requestId);
			break;
		case CMD_EXEC_FINISH:
			step(STEP_OUT, STEP_LINE, cmd.threadId, cmd.requestId);
			break;
		case CMD_EXEC_NEXT:
			step(STEP_OVER, STEP_LINE, cmd.threadId, cmd.requestId);
			break;
		case CMD_EXEC_NEXT_INSTRUCTION:
			step(STEP_OVER, STEP_INSTRUCTION, cmd.threadId, cmd.requestId);
			break;
		case CMD_EXEC_STEP:
			step(STEP_INTO, STEP_LINE, cmd.threadId, cmd.requestId);
			break;
		case CMD_EXEC_STEP_INSTRUCTION:
			step(STEP_INTO, STEP_INSTRUCTION, cmd.threadId, cmd.requestId);
			break;
		case CMD_BREAK_INSERT:
			handleBreakpointInsertCommand(cmd);
			break;
		case CMD_BREAK_DELETE:
			handleBreakpointDeleteCommand(cmd);
			break;
		case CMD_BREAK_ENABLE:
			handleBreakpointEnableCommand(cmd, true);
			break;
		case CMD_BREAK_DISABLE:
			handleBreakpointEnableCommand(cmd, false);
			break;
		case CMD_LIST_THREAD_GROUPS:
			{
				if (!_paused && (cmd.unnamedValue(0) == "i1"w || cmd.hasParam("--available"w))) {
					writeErrorMessage(cmd.requestId, "Can not fetch data now.\n"w);
					return;
				}
				if (cmd.unnamedValue(0) == "i1"w) {
					handleThreadInfoCommand(cmd, false);
					return;
				}
				WstringBuffer buf;
				buf.appendUlongIfNonEmpty(cmd.requestId);
				buf.append("^done"w);
				buf.append(",groups=[{"w);
				buf.appendStringParam("id"w, "i1"w);
				buf.appendStringParam("type"w, "process"w);
				buf.appendStringParam("pid"w, "123"w); // todo: add real PID
				buf.appendStringParamIfNonEmpty("executable"w, params.exename);
				buf.append("}]"w);
				writeStdout(buf.wstr());
			}
			break;
		case CMD_BREAK_LIST:
			handleBreakpointListCommand(cmd);
			break;
		case CMD_THREAD_INFO:
			handleThreadInfoCommand(cmd, false);
			break;
		case CMD_THREAD_LIST_IDS:
			handleThreadInfoCommand(cmd, true);
			break;
		case CMD_STACK_LIST_FRAMES:
			handleStackListFramesCommand(cmd, false);
			break;
		case CMD_STACK_INFO_DEPTH:
			handleStackListFramesCommand(cmd, true);
			break;
		//case CMD_STACK_LIST_ARGUMENTS:
		//	handleStackListVariablesCommand(cmd, false, true);
		//	break;
		case CMD_STACK_LIST_VARIABLES:
			handleStackListVariablesCommand(cmd, false, false);
			break;
		case CMD_STACK_LIST_LOCALS:
			handleStackListVariablesCommand(cmd, true, false);
			break;
		case CMD_VAR_CREATE:
		case CMD_VAR_UPDATE:
		case CMD_VAR_DELETE:
			handleVariableCommand(cmd);
			break;
		case CMD_VAR_SET_FORMAT:
			handleVariableCommand(cmd);
			break;
		case CMD_LIST_FEATURES:
			{
				WstringBuffer buf;
				buf.appendUlongIfNonEmpty(cmd.requestId);
				buf.append("^done,features=[\"frozen - varobjs\",\"pending - breakpoints\",\"thread-info\"]"w);
				//,\"breakpoint-notifications\",\"undefined-command-error-code\",\"exec-run-start-option\"
				writeStdout(buf.wstr());
			}
			break;
		case CMD_GDB_VERSION:
			writeStdout("~\""w ~ VERSION_STRING ~ "\\n\""w);
			writeStdout("~\""w ~ VERSION_EXPLANATION_STRING ~ "\\n\""w);
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_SET_INFERIOR_TTY:
			if (cmd.unnamedValues.size() != 1) {
				writeErrorMessage(cmd.requestId, "tty device name is required"w);
				return;
			}
			{
				wstring device = unquoteString(cmd.unnamedValues[0]);
				params.setTty(device);
				writeResultMessage(cmd.requestId, "done"w);
			}
			break;
		case CMD_ENVIRONMENT_CD:
			{
				if (cmd.unnamedValues.size() != 1) {
					writeErrorMessage(cmd.requestId, "directory name parameter required"w);
					return;
				}
				wstring dir = unquoteString(cmd.unnamedValues[0]);
				params.setDir(dir);
				CRLog.info("Changing current directory to %s", toUtf8z(params.dir));
				if (SetCurrentDirectoryW(dir.c_str()) != TRUE)
					CRLog.error("Cannot change current directory to %s", toUtf8z(params.dir));
				writeResultMessage(cmd.requestId, "done"w);
			}
			break;
		case CMD_GDB_SHOW:
			if (cmd.unnamedValue(0) == "language"w) {
				writeResultMessageRaw(cmd.requestId, "done"w, "value=\"auto\""w);
				return;
			}
			CRLog.warn("command -gdb-show is not implemented");
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_INTERPRETER_EXEC:
			if (cmd.unnamedValue(0) == "console"w) {
				if (unquoteString(cmd.unnamedValue(1)) == "show endian"w) {
					writeDebuggerMessage("The target endianness is set automatically (currently little endian)\n"w);
					writeResultMessage(cmd.requestId, "done"w);
					return;
				}
				else if (unquoteString(cmd.unnamedValue(1)) == "p/x (char)-1"w) {
					writeDebuggerMessage("$1 = 0xff\n"w);
					writeResultMessage(cmd.requestId, "done"w);
					return;
				}
				else if (unquoteString(cmd.unnamedValue(1)) == L"kill"w) {
					stop(cmd.requestId);
					return;
				}
			}
			CRLog.warn("command -interpreter-exec is not implemented");
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_DATA_EVALUATE_EXPRESSION:
			handleDataEvaluateExpressionCommand(cmd);
			break;
		case CMD_GDB_SET:
			CRLog.warn("command -gdb-set is not implemented");
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_MAINTENANCE:
			CRLog.warn("command maintenance is not implemented");
			writeStdout("&\"%s\\n\""w, cmd.commandText.c_str());
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_ENABLE_PRETTY_PRINTING:
			CRLog.warn("command -enable-pretty-printing is not implemented");
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_HANDLE:
			// ignore, reply done
			writeResultMessage(cmd.requestId, "done"w);
			break;
		case CMD_SOURCE:
			CRLog.warn("command source is not implemented");
			writeStdout("&\"source.gdbinit\\n\""w);
			writeStdout("&\".gdbinit: No such file or directory.\\n\""w);
			writeErrorMessage(cmd.requestId, ".gdbinit: No such file or directory."w);
			break;
		case CMD_FILE_EXEC_AND_SYMBOLS:
			{
				if (cmd.unnamedValues.size() != 1) {
					writeErrorMessage(cmd.requestId, "directory name parameter required"w);
					return;
				}
				wstring fn = unquoteString(cmd.unnamedValues[0]);
				params.setExecutable(fn);
				load(cmd.requestId, true);
				writeResultMessage(cmd.requestId, "done"w);
	
			}
			break;
		}
	}
	/// called when ctrl+c or ctrl+break is called
	void onCtrlBreak(){
	
	}
	void writeOutput(wstring msg) {//moved to CmdLineHandler
		writeStdout(msg);
	}

	void writeOutput(string msg) {//moved to CmdLineHandler
		writeStdout(toUFT16(msg));
	}

	void writeOutput(const char * msg) {//moved to CmdLineHandler
		//writeStdout(toUtf16(std::string(msg)));
		writeStdout(toUTF16(fromStringz(msg)));
	}

	void writeOutput(const wchar_t * msg) {//moved to CmdLineHandler
		//writeStdout(std::wstring(msg));
	}
}