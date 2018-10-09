module micommand;

import miutils;

enum PrintLevel
{
	PRINT_NO_VALUES = 0,
	PRINT_ALL_VALUES = 1,
	PRINT_SIMPLE_VALUES = 2,
};

/// MI interface command IDs
enum MiCommandId
{
	CMD_UNKNOWN,
	CMD_GDB_EXIT, // -gdb-exit quit
	CMD_HELP, // help
	CMD_EXEC_RUN, // run -exec-run
	CMD_EXEC_CONTINUE, // continue -exec-continue
	CMD_EXEC_INTERRUPT, // interrupt -exec-interrupt
	CMD_EXEC_FINISH, // finish -exec-finish
	CMD_EXEC_NEXT, // next -exec-next
	CMD_EXEC_NEXT_INSTRUCTION, // nexti -exec-next-instruction
	CMD_EXEC_STEP, // step -exec-step
	CMD_EXEC_STEP_INSTRUCTION, // stepi -exec-step-instruction
	CMD_BREAK_INSERT, // break -break-insert
	CMD_BREAK_DELETE, // delete -break-delete
	CMD_BREAK_ENABLE, // enable -break-enable
	CMD_BREAK_DISABLE, // disable -break-disable
	CMD_BREAK_LIST, // -break-list
	CMD_LIST_THREAD_GROUPS, // info break -list-thread-groups
	CMD_THREAD_INFO, // info thread -thread-info
	CMD_THREAD_LIST_IDS, // info threads -thread-list-ids
	CMD_STACK_LIST_FRAMES, // -stack-list-frames backtrace
	CMD_STACK_INFO_DEPTH, // -stack-info-depth
	CMD_STACK_LIST_ARGUMENTS, // -stack-list-variables
	CMD_STACK_LIST_VARIABLES, // -stack-list-variables
	CMD_STACK_LIST_LOCALS, // -stack-list-locals
	CMD_VAR_CREATE, // -var-create
	CMD_VAR_UPDATE, // -var-update
	CMD_VAR_DELETE, // -var-delete
	CMD_VAR_SET_FORMAT, // -var-set-format
	CMD_LIST_FEATURES, // -list-features
	CMD_GDB_VERSION, // -gdb-version
	CMD_ENVIRONMENT_CD, // -environment-cd
	CMD_SET_INFERIOR_TTY, // set inferior-tty
	CMD_GDB_SHOW, // -gdb-show
	CMD_INTERPRETER_EXEC, // -interpreter-exec
	CMD_DATA_EVALUATE_EXPRESSION, // -data-evaluate-expression
	CMD_GDB_SET, // -gdb-set
	CMD_MAINTENANCE, // maintenance
	CMD_ENABLE_PRETTY_PRINTING, // -enable-pretty-printing
	CMD_SOURCE, // source
	CMD_FILE_EXEC_AND_SYMBOLS, // -file-exec-and-symbols
	CMD_HANDLE, // handle
}

void getCommandsHelp(ref wstring[] res, bool forMi);

struct MICommand
{
	ulong requestId = UNSPECIFIED_REQUEST_ID;
	MiCommandId commandId;
	wstring threadGroupId;
	unsigned threadId;
	unsigned frameId;
	PrintLevel printLevel; // 0=--no-values 1=--all-values 2=--simple-values
	bool skipUnavailable; //--skip-unavailable
	bool noFrameFilters; //--no-frame-filters
	/// true if command is prefixed with single -
	bool miCommand;
	/// original command text
	wstring commandText;
	/// command name string
	wstring commandName;
	/// tail after command till end of line
	wstring tail;
	/// individual parameters from tail
	wstring_vector params;
	/// named parameters - pairs (key, value)
	param_vector namedParams;
	/// parameters with values w/o names
	wstring_vector unnamedValues;

	// debug dump
	wstring dumpCommand()
	{
		WstringBuffer buf;
		buf.append("MICommand {"w);
		buf.appendStringParam("commandName"w, commandName);
		buf.append(" params=[ "w);
		for (size_t i = 0; i < params.size(); i++)
		{
			buf.append("`"w);
			buf += params[i];
			buf.append("` "w);
		}
		buf.append("] "w);
		buf.append(" namedParams={"w);
		for (size_t i = 0; i < namedParams.size(); i++)
		{
			buf.append("`"w);
			buf += namedParams[i].first;
			buf.append("`=`"w);
			buf += namedParams[i].second;
			buf.append("` "w);
		}
		buf.append("} "w);
		buf.append(" unnamedValues=[ "w);
		for (size_t i = 0; i < unnamedValues.size(); i++)
		{
			buf.append("`"w);
			buf += unnamedValues[i];
			buf.append("` "w);
		}
		buf.append("] "w);
		buf.append("}"w);
		return buf.wstr();
	}

	/// returns true if there is specified named parameter in cmd
	bool hasParam(wstring name)
	{
		for (unsigned i = 0; i < namedParams.size(); i++)
			if (namedParams[i].first == name)
				return true;
		return false;
	}
	// find parameter by name
	wstring findParam(wstring name)
	{
		for (unsigned i = 0; i < namedParams.size(); i++)
			if (namedParams[i].first == name)
				return namedParams[i].second;
		return null;
	}

	wstring unnamedValue(unsigned index = 0)
	{
		return index < unnamedValues.size() ? unnamedValues[index] :[];
	}
	// get parameter --thread-id
	uint64_t getUlongParam(wstring name, uint64_t defValue = 0)
	{
		wstring v = findParam(name);
		if (v.empty())
			return defValue;
		uint64_t tid = 0;
		if (!toUlong(v, tid))
			return defValue;
		return tid;
	}

	this(){

	}
	~this(){
		
	}
	// parse MI command, returns true if successful
	bool parse(wstring line)
	{
		requestId = UNSPECIFIED_REQUEST_ID;
		commandName.clear();
		tail.clear();
		params.clear();
		namedParams.clear();
		unnamedValues.clear();
		commandText = s;
		parseUlong(s, requestId);
		if (!parseIdentifier(s, commandName))
			return false;
		if (commandName[0] == '-' && commandName[1] != '-')
			miCommand = true;
		skipWhiteSpace(s);
		tail = s;
		splitSpaceSeparatedParams(s, params);
		// find id for command
		findCommand(*this);
		handleKnownParams();
		collapseParams(params, namedParams);
		for (size_t i; i < namedParams.size(); i++)
		{
			if (namedParams[i].first.empty() && !namedParams[i].second.empty())
				unnamedValues.push_back(namedParams[i].second);
		}
		return true;
	}

private:
	void handleKnownParams()
	{
		uint i = 0;
		uint64_t n = 0;
		bool valuesParamFound;
		for (; i < params.size();)
		{
			wstring param = params[i];
			wstring nextparam = i + 1 < params.size() ? params[i + 1] : [];
			int itemsHandled = 0;
			if (param == "--thread-id"w || param == "--thread"w)
			{
				if (toUlong(nextparam, n))
				{
					threadId = cast(uint)n;
					itemsHandled = 2;
				}
			} //--thread-group
			else if (param == "--thread-group"w)
			{
				if (!nextparam.empty())
				{
					threadGroupId = nextparam;
					itemsHandled = 2;
				}
			}
			else if (param == "--frame"w)
			{
				if (toUlong(nextparam, n))
				{
					frameId = cast(uint)n;
					itemsHandled = 2;
				}
			}
			else if (param == "--no-values"w)
			{
				printLevel = PRINT_NO_VALUES;
				itemsHandled = 1;
				valuesParamFound = true;
			}
			else if (param == "--simple-values"w)
			{
				printLevel = PRINT_SIMPLE_VALUES;
				itemsHandled = 1;
				valuesParamFound = true;
			}
			else if (param == "--all-values"w)
			{
				printLevel = PRINT_ALL_VALUES;
				itemsHandled = 1;
				valuesParamFound = true;
			}
			else if (param == "--skip-unavailable"w)
			{
				skipUnavailable;
				itemsHandled = 1;
			}
			else if (param == "--no-frame-filters"w)
			{
				skipUnavailable;
				itemsHandled = 1;
			}
			if (itemsHandled)
			{
				params.erase(params.begin() + i, params.begin() + i + itemsHandled);
			}
			else
			{
				i++;
			}
		}
		if (commandId == CMD_STACK_LIST_LOCALS || commandId == CMD_STACK_LIST_VARIABLES
				|| commandId == CMD_STACK_LIST_ARGUMENTS)
		{
			if (!valuesParamFound && params.size() > 0)
			{
				wstring param = params[0];
				params.erase(params.begin());
				if (param == "1"w)
					printLevel = PRINT_ALL_VALUES;
				else if (param == "2"w)
					printLevel = PRINT_SIMPLE_VALUES;
			}
			//CRLog::trace("print level: %d", printLevel);
		}
	}
}

/// compare name (till \0 or space) with s (till \0)
static bool cmpCommand(const char* name, const wchar_t* s)
{
	if (!name || !name[0])
		return false;
	if (!s || !s[0])
		return false;
	int i = 0;
	for (; name[i] && name[i] != ' ' && s[i]; i++)
		if (name[i] != s[i])
			break;
	if (s[i])
		return false;
	return !name[i] || name[i] == ' ';
}

/// skip till beginning of next word
static bool nextWord(ref char* s)
{
	while (*s && s[0] != ' ')
		s++;
	while (s[0] == ' ')
		s++;
	return s[0] != 0;
}

struct MiCommandInfo
{
	MiCommandId id = MICommand.CMD_UNKNOWN;
	const char* name;
	const char* nonMiName;
	const char* description;
	this()
	{
	} // : id(CMD_UNKNOWN), name(NULL), nonMiName(NULL), description(NULL) {}
	this(MiCommandId _id, const char* _name, const char* _nonMiName, const char* _description) //: id(_id), name(_name), nonMiName(_nonMiName), description(_description)
	{
	}

	bool compare(ref MICommand v)
	{
		if (cmpCommand(name, v.commandName.c_str()))
		{
			v.commandId = id;
			return true;
		}

		if (cmpCommand(nonMiName, v.commandName.c_str()))
		{
			const char * cmdName = nonMiName;
			unsigned i = 0;
			while (nextWord(cmdName))
			{
				if (i + 1 >= v.params.size())
					return false;
				wstring param = v.params[i];
				if (!cmpCommand(cmdName, param.c_str()))
					return false;
				i++;
			}
			if (i > 0)
			{
				// remove matched additional words for command
				v.params.erase(v.params.begin(), v.params.begin() + i);
			}
			v.commandId = id;
			return true;
		}
		return false;
	}
}

static MiCommandInfo[] MI_COMMANDS = 
[
	MiCommandInfo(CMD_GDB_EXIT, "-gdb-exit", "quit", "quit debugger"), MiCommandInfo(CMD_HELP,
			NULL, "help", ""), MiCommandInfo(CMD_EXEC_RUN, "-exec-run", "run",
			"start program execution"), MiCommandInfo(CMD_EXEC_CONTINUE,
			"-exec-continue", "continue", "continue program execution"),
		MiCommandInfo(CMD_EXEC_INTERRUPT, "-exec-interrupt",
				"interrupt", "interrupt program which is being running"), MiCommandInfo(
				CMD_EXEC_FINISH, "-exec-finish", "finish", "step out from function"), MiCommandInfo(
				CMD_EXEC_NEXT, "-exec-next", "next", "step over"),
		MiCommandInfo(CMD_EXEC_NEXT_INSTRUCTION, "-exec-next-instruction",
				"nexti", "step over by instruction"), MiCommandInfo(
				CMD_EXEC_STEP, "-exec-step", "step", "step into"), MiCommandInfo(
				CMD_EXEC_STEP_INSTRUCTION, "-exec-step-instruction", "stepi",
				"step into by instruction"), MiCommandInfo(CMD_BREAK_INSERT,
				"-break-insert", "break", "add breakpoint"),
		MiCommandInfo(CMD_BREAK_DELETE, "-break-delete",
				"delete", "remove breakpoint"), MiCommandInfo(CMD_BREAK_ENABLE,
				"-break-enable", "enable", "enable breakpoint"), MiCommandInfo(
				CMD_BREAK_DISABLE, "-break-disable", "disable",
				"disable breakpoint"), MiCommandInfo(CMD_BREAK_LIST,
				"-break-list", "info break", "list breakpoints"), MiCommandInfo(
				CMD_LIST_THREAD_GROUPS, "-list-thread-groups", NULL, "list processes"),
		MiCommandInfo(CMD_THREAD_INFO, "-thread-info", "info thread",
				"reports information about threads"), MiCommandInfo(CMD_THREAD_LIST_IDS,
				"-thread-list-ids", "info threads", "show thread id list and number of threads"), MiCommandInfo(
				CMD_STACK_LIST_FRAMES, "-stack-list-frames", "backtrace", "list stack frames"),
		MiCommandInfo(CMD_STACK_INFO_DEPTH, "-stack-info-depth",
				NULL, "returns depth of stack"), MiCommandInfo(
				CMD_STACK_LIST_VARIABLES, "-stack-list-variables",
				NULL, "show stack frame variables"), MiCommandInfo(
				CMD_STACK_LIST_LOCALS, "-stack-list-locals", NULL,
				"show stack frame local variables"), MiCommandInfo(
				CMD_STACK_LIST_ARGUMENTS, "-stack-list-arguments", NULL,
				"show stack frame function arguments"), MiCommandInfo(
				CMD_VAR_CREATE, "-var-create", NULL, "create variable"), MiCommandInfo(
				CMD_VAR_UPDATE, "-var-update", NULL, "update variable"),
		MiCommandInfo(CMD_VAR_DELETE, "-var-delete",
				NULL, "delete variable"), MiCommandInfo(CMD_VAR_SET_FORMAT,
				"-var-set-format", NULL, ""), MiCommandInfo(
				CMD_LIST_FEATURES, "-list-features", NULL, "show list of supported features"),
		MiCommandInfo(CMD_GDB_VERSION, "-gdb-version", NULL,
				"show version of debugger"), MiCommandInfo(CMD_ENVIRONMENT_CD,
				"-environment-cd", NULL, "set current directory"), MiCommandInfo(
				CMD_SET_INFERIOR_TTY, "-inferior-tty-set", "set inferior-tty",
				"Set the tty for the program being debugged"), MiCommandInfo(CMD_GDB_SHOW,
				"-gdb-show", "show", ""), MiCommandInfo(CMD_INTERPRETER_EXEC,
				"-interpreter-exec", NULL, ""), MiCommandInfo(CMD_DATA_EVALUATE_EXPRESSION,
				"-data-evaluate-expression", NULL, ""), MiCommandInfo(CMD_GDB_SET,
				"-gdb-set", NULL, ""), MiCommandInfo(CMD_ENABLE_PRETTY_PRINTING,
				"-enable-pretty-printing", NULL, ""), MiCommandInfo(CMD_MAINTENANCE,
				NULL, "maintenance", ""), MiCommandInfo(CMD_SOURCE,
				NULL, "source", "execute commands from file"), MiCommandInfo(
				CMD_FILE_EXEC_AND_SYMBOLS, "-file-exec-and-symbols", NULL,
				"set executable to debug"), MiCommandInfo(CMD_HANDLE, NULL,
				"handle", ""), MiCommandInfo()
];

void getCommandsHelp(ref wstring_vector res, bool forMi)
{
	res.push_back("mago-mi: GDB and GDB-MI compatible interfaces for MAGO debugger."w);
	res.push_back(""w);
	unsigned maxCommandLength = 10;
	for (int i = 0; MI_COMMANDS[i].id != CMD_UNKNOWN; i++)
	{
		if (forMi)
		{
			if (MI_COMMANDS[i].name && maxCommandLength < strlen(MI_COMMANDS[i].name))
				maxCommandLength = strlen(MI_COMMANDS[i].name);
		}
		else
		{
			if (MI_COMMANDS[i].nonMiName && maxCommandLength < strlen(MI_COMMANDS[i].nonMiName))
				maxCommandLength = strlen(MI_COMMANDS[i].nonMiName);
		}
	}
	WstringBuffer buf;
	for (int i = 0; MI_COMMANDS[i].id != CMD_UNKNOWN; i++)
	{
		if (!MI_COMMANDS[i].description || !MI_COMMANDS[i].description[0])
			continue; // no help
		const char* name = forMi ? MI_COMMANDS[i].name : MI_COMMANDS[i].nonMiName;
		if (name)
		{
			buf.reset();
			buf.appendUtf8(name);
			buf.pad(' ', maxCommandLength + 2);
			buf.append(" - "w);
			buf.appendUtf8(MI_COMMANDS[i].description);
		}
		res.push_back(buf.wstr());
	}
	res.push_back(""w);
	res.push_back("Type quit to exit."w);
}

/// find command by name and set its id, returns false for unknown command
bool findCommand(ref MICommand v)
{
	for (int i = 0; MI_COMMANDS[i].id != CMD_UNKNOWN; i++)
	{
		if (MI_COMMANDS[i].compare(v))
			return true;
	}
	return false;
}

/*MICommand::MICommand()
	: requestId(UNSPECIFIED_REQUEST_ID)
	, commandId(CMD_UNKNOWN)
	, threadId(0)
	, frameId(0)
	, printLevel(PRINT_NO_VALUES)
	, skipUnavailable(false)
	, noFrameFilters(false)
	, miCommand(false)
{

}
MICommand::~MICommand() {

}*/

// return true if value is required
bool doesParameterRequireValue(wstring p)
{
	static const wchar_t * KNOWN_PARAMS_WITH_VALUES_LIST[] = 
	{
		"--thread-group"w, "--thread"w, "--frame"w, null
	};
	for (int i = 0; KNOWN_PARAMS_WITH_VALUES_LIST[i]; i++)
		if (p == KNOWN_PARAMS_WITH_VALUES_LIST[i])
			return true;
	return false;
}

// returns true if embedded value is found
bool splitParamAndValue(ref wstring s, ref wstring name, ref wstring value)
{
	if (isShortParamName(s))
	{
		if (s.length() == 2)
		{
			// -c
			name = s;
			value.clear();
			return false;
		}
		else
		{
			// -cvalue
			name = s.substr(0, 2);
			value = s.substr(2, s.length() - 2);
			return true;
		}
	}
	else if (isLongParamName(s))
	{
		// --paramname or --paramname=value
		return splitByChar(s, '=', name, value);
	}
	else
	{
		// not a parameter - put into value
		name.clear();
		value = s;
		return false;
	}
}

void collapseParams(ref wstring[] items, ref wstring[2][] namedParams)
{
	for (size_t i = 0; i < items.size(); i++)
	{
		wstring item = items[i];
		wstring next = i + 1 < items.size() ? items[i + 1] : "";
		wstring name;
		wstring value;
		if (isParamName(item))
		{
			// --param or -p
			if (splitParamAndValue(item, name, value))
			{
				// has both name and value: --param=value or -pvalue
				wstring_pair pair;
				pair.first = name;
				pair.second = value;
				namedParams.push_back(pair);
			}
			else
			{
				// separate values for params not supported
				if (!doesParameterRequireValue(item))
				{
					// no value
					wstring_pair pair;
					pair.first = name;
					namedParams.push_back(pair);
				}
				else
				{
					if (isParamName(next) || next.empty())
					{ // short params cannot have separate values
						// no value
						wstring_pair pair;
						pair.first = name;
						namedParams.push_back(pair);
					}
					else
					{
						// next item is value for this param
						wstring_pair pair;
						pair.first = name;
						pair.second = next;
						namedParams.push_back(pair);
						// skip one item - it's already used as value
						i++;
					}
				}
			}

		}
		else
		{
			wstring_pair pair;
			pair.second = item;
			namedParams.push_back(pair);
		}

	}
}
