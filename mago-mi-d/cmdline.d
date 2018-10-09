module cmdline;

import std.stdio;
import std.path;
import std.utf;
import std.string;
import core.sys.windows.windows;
import logger;
import miutils;

immutable wstring EMULATED_GDB_VERSION = "7.1.90"w;//#define EMULATED_GDB_VERSION L"7.1.90"
immutable wstring MAGO_MI_VERSION = "0.3.3"w; //#define MAGO_MI_VERSION L"0.3.3"
immutable wstring VERSION_STRING = "GNU gdb (mago-mi "w ~ MAGO_MI_VERSION ~ ") "w ~ EMULATED_GDB_VERSION; //#define VERSION_STRING L"GNU gdb (mago-mi " MAGO_MI_VERSION L") " EMULATED_GDB_VERSION
immutable wstring VERSION_EXPLANATION_STRING =" (Actually it's mago-mi debugger. Version shows GDB for Eclipse CDT compatibility)"w;//#define VERSION_EXPLANATION_STRING L"(Actually it's mago-mi debugger. Version shows GDB for Eclipse CDT compatibility)"

// Command line arguments parser
extern(C) void parseCommandLine(int argc, wchar_t *argv[]);

//#define MAX_PARAM_COUNT 10000
enum MAX_PARAM_COUNT = 10000;

/**
 * Note: strings are changed to D's own implementation.
 * Call setDir(getCurrentDirectory()) after declaration.
 */
struct ExecutableInfo {
	wstring exename;
	wstring[] args;
	wstring dir;
	wstring logFile;
	wstring logLevel;
	wstring tty;
	bool verbose;
	bool miMode;
	bool silent;
	bool stopOnEntry;

	/*this(){
		setDir(getCurrentDirectory());
	}*///ExecutableInfo();
	~this(){
		clear();
	}//~ExecutableInfo();
	@nogc @property int argCount() { 
		return (int)args.size(); 
	}
	void clear(){

	}
	void setExecutable(wstring exe){
		if (!exe.length) {
			exename.length = 0;
			return;
		}
		wstring tmp = fixPathDelimiters(unquoteString(exe));
		exename = asAbsolutePath(tmp);
		CRLog.info("exename is set: %s", toStringz(toUTF8(exename)));
	}
	void setDir(wstring directory){
		if (directory.empty()) {
			dir.clear();
			return;
		}
		wstring tmp = fixPathDelimiters(unquoteString(directory));
		dir = asAbsolutePath(tmp);
		info("dir is set: %s", toStringz(toUTF8(dir)));
	}
	void addArg(wstring param){
		args ~= param;
	}
	@nogc @property void setTty(wstring tty){
		this.tty = tty;
	}
	void dumpParams(){
		CRLog.info("%s", toUTF8(VERSION_STRING).c_str());
		if (!exename.empty()) {
		CRLog.info("Executable file: %s\n", toUTF8(exename).c_str());
		if (argCount()) {
			CRLog.info("Inferior arguments:");
				for (int i = 0; i < argCount(); i++) {
					CRLog.info("[%d] %s", i, toUTF8(args[i]).c_str());
				}
			}
		}
		if (!dir.empty())
			CRLog.info("Directory: %s\n", toUTF8(dir).c_str());
	}

	bool hasExecutableSpecified(){
		return exename.length != 0;
	}
}

static ExecutableInfo params;

static void fatalError(const char * msg, int errCode) {
	writef(stderr, "%s\n", msg);
	CRLog.error("%s", msg);
	exit(errCode);
}

static void fatalError(wstring msg, int errCode) {
	writef(stderr, "%s\n"w, msg);
	CRLog.error("%s", toStringz(toUTF8(msg)));
	exit(errCode);
}

enum CmdLineParamType {
	NO_PARAMS,
	STRING_PARAM,
}

struct CmdLineParamDef {
	const char * shortName;
	const char * longName;
	CmdLineParamType paramType;
	const char * description;
	const char * defValue;
	parameterHandler handler;//typedef void(*parameterHandler)(CmdLineParamDef * param, const wchar_t * value);
	@nogc bool isHelpSection() {
		return !shortName && !longName && description;
	}
	@nogc bool isLast() {
		return !shortName && !longName && !description;
	}

	/// for normal parameter
	@nogc this(const char* shortName, const char* longName, CmdLineParamType paramType, const char* description, const char* defValue, parameterHandler handler){
		this.shortName = shortName;
		this.longName = longName;
		this.paramType = paramType;
		this.description = description;
		this.defValue = defValue;
		this.handler = handler;
	}
	/// for help section
	@nogc this(const char * description){
		this.description = description;
	}
	// for last item
	/*CmdLineParamDef()
		: shortName(NULL), longName(NULL), paramType(NO_PARAMS), description(NULL), defValue(NULL), handler(NULL) {
	}*/
}

void dumpParameterHelp(){

}

static void showHelp(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	//UNREFERENCED_PARAMETER(value);
	printf("This is Mago debugger command line interface. Usage:\n");
	printf("    mago-mi [options] [executable-file]\n");
	printf("    mago-mi [options] --args executable-file [inferior-arguments ...]\n");
	dumpParameterHelp();
	exit(0);
}

static void showVersion(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	//UNREFERENCED_PARAMETER(value);
	//if (params.miMode)
	//	printf("~\"%s\\n%s\\n\"", toUtf8(VERSION_STRING).c_str(), toUtf8(VERSION_EXPLANATION_STRING).c_str());
	//else
	printf("%s\n%s\n", toUtf8(VERSION_STRING).c_str(), toUtf8(VERSION_EXPLANATION_STRING).c_str());
	exit(0);
}

void defParamHandler(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	//UNREFERENCED_PARAMETER(value);
	// TODO
}

static void handleInterpreter(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	if (!wcscmp(value, L"mi2") || !wcscmp(value, L"mi") || !wcscmp(value, L"mi1")) {
		params.miMode = true;
		return;
	}
	if (!wcscmp(value, L"console")) {
		params.miMode = false;
		return;
	}
	fatalError("Unknown interpreter is specified", -3);
}

static bool argsFound;

static void handleArgs(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	if (params.hasExecutableSpecified()) {
		fatalError("Executable file already specified", 3);
	}
	params.setExecutable(value);
	argsFound = true;
}

static void handleExec(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	if (params.hasExecutableSpecified()) {
		fatalError("Executable file already specified", 3);
	}
	params.setExecutable(fromWStringz(value));
}

static void handleDir(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	params.setDir(value);
}

static void handleNx(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	//UNREFERENCED_PARAMETER(value);
	params.setDir(value);
}

static void handleLogFile(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	params.logFile = value;
}

static void handleLogLevel(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	params.logLevel = value;
}

static void handleVerbose(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	//UNREFERENCED_PARAMETER(value);
	params.verbose = true;
}

static void handleSilent(CmdLineParamDef * param, const wchar_t * value) {
	//UNREFERENCED_PARAMETER(param);
	/UNREFERENCED_PARAMETER(value);
	p/arams.silent = true;
}

void nonParamHandler(const wchar_t * value) {
	if (params.exename.empty()) {
		params.setExecutable(fromWStringz(value));
		return;
	}
	if (!argsFound) {
		fatalError("Use --args to provide inferior arguments", 3);
	}
	params.addArg(fromWStringz(value));
}

CmdLineParamDef[] paramDefs = [
	CmdLineParamDef("Selection of debuggee and its files"),
	CmdLineParamDef(null, "--args", CmdLineParamType.STRING_PARAM, "Arguments after executable-file are passed to inferior"
				, null, &handleArgs),
	CmdLineParamDef(null, "--exec=EXECFILE", CmdLineParamType.STRING_PARAM, "Use EXECFILE as the executable.", null,
				&handleExec),
	CmdLineParamDef("Output and user interface control"),
	CmdLineParamDef(null, "--interpreter=mi2", CmdLineParamType.STRING_PARAM, "Turn on GDB MI interface mode", null,
				&handleInterpreter),
	CmdLineParamDef("Operating modes"),
	CmdLineParamDef(null, "--help", CmdLineParamType.NO_PARAMS, "Print this message and then exit", null, &showHelp),
	CmdLineParamDef(null, "--version", CmdLineParamType.NO_PARAMS, "Print version information and then exit", null, 
				&showVersion),
	CmdLineParamDef("-v", null, CmdLineParamType.NO_PARAMS, "Verbose output", null, &handleVerbose),
	CmdLineParamDef("-q", "--silent", CmdLineParamType.NO_PARAMS, "Don't print version info on startup", null, 
				&handleSilent),
	CmdLineParamDef("Other options"),
	CmdLineParamDef(null, "--cd=DIR", CmdLineParamType.STRING_PARAM, "Change current directory to DIR.", null, &handleDir),
	CmdLineParamDef("-n", "--nx", CmdLineParamType.NO_PARAMS, "Do not execute commands found in any initializaton file", 
				null, &handleNx),
	CmdLineParamDef("-t", "--tty", CmdLineParamType.STRING_PARAM, "Run using named pipe for standard input/output", null, 
				&handleNx),
	CmdLineParamDef(null, "--log-file=FILE", CmdLineParamType.STRING_PARAM, "Set log file for debugger internal logging.", 
				null, &handleLogFile),
	CmdLineParamDef(null, "--log-level=FATAL|ERROR|WARN|INFO|DEBUG|TRACE", STRING_PARAM, 
				"Set log level for debugger internal logging.", null, &handleLogLevel),
	CmdLineParamDef()
];

void dumpParameterHelp() {
	for (int i = 0; !paramDefs[i].isLast(); i++) {
		if (paramDefs[i].isHelpSection()) {
			writef("\n%s:\n\n", paramDefs[i].description);
		} else {
			if (paramDefs[i].longName)
				writef("  %-16s %s\n", paramDefs[i].longName, paramDefs[i].description);
			if (paramDefs[i].shortName)
				writef("  %-16s %s\n", paramDefs[i].shortName, paramDefs[i].description);
		}
	}
}

CmdLineParamDef* findParam(const wchar_t * &name) {
	if (name[0] == '-' && name[1] != '-') {
		for (int i = 0; !paramDefs[i].isLast(); i++) {
			if (paramDefs[i].isHelpSection())
				continue;
			if (!paramDefs[i].shortName)
				continue;
			if (paramDefs[i].shortName[1] == name[1]) {
				name += 2;
				return &paramDefs[i];
			}
		}
	} else if (name[0] == '-' && name[1] == '-') {
		for (int i = 0; !paramDefs[i].isLast(); i++) {
			if (paramDefs[i].isHelpSection())
				continue;
			if (!paramDefs[i].longName)
				continue;
			int j = 0;
			for (; name[j] && paramDefs[i].longName[j] && (paramDefs[i].longName[j] != '=') && name[j] == paramDefs[i].longName[j]; j++)
				;
			if ((!paramDefs[i].longName[j] || paramDefs[i].longName[j] == '=') && (!name[j] || name[j] == '=')) {
				name += j;
				if (name[0] == '=')
					name++;
				return &paramDefs[i];
			}
		}
	}
	return NULL;
}

void parseCommandLine(int argc, wchar_t *argv[]) {
	for (int i = 1; i < argc; i++) {
		wchar_t * v = argv[i];
		if (v[0] == '-') {
			const wchar_t * value = v;
			CmdLineParamDef* param = findParam(value);
			if (!param) {
				fatalError("Unknown command line parameter "w ~ v, 1);
			}
			if (param.paramType != NO_PARAMS) {
				if (!value[0]) {
					if (i == argc - 1) {
						fatalError("Value not specified for parameter "w ~ v, 1);
					}
					i++;
					value = argv[i];
				}
			}
			else {
				if (value[0]) {
					fatalError("Value not allowed for parameter "w ~ v, 1);
				}
			}
			if (param.handler) {
				param.handler(param, value);
			} else {
				defParamHandler(param, value);
			}
		}else {
			nonParamHandler(v);
		}
	}
	// handle logging
	if (!params.logFile.empty()) {
		CRLog.log_level level = CRLog.LL_INFO;
		if (params.logLevel == "FATAL"w)
			level = CRLog.LL_FATAL;
		else if (params.logLevel == "ERROR"w)
			level = CRLog.LL_ERROR;
		else if (params.logLevel == "DEBUG"w)
			level = CRLog.LL_DEBUG;
		else if (params.logLevel == "TRACE"w)
			level = CRLog.LL_TRACE;
		CRLog.setFileLogger(toUtf8(params.logFile).c_str(), true);
		CRLog.setLogLevel(level);
	}
	params.dumpParams();
}