module mago_mi_d;

import std.stdio;

import cmdline;
import debugger;
import miutils;

int main(wstring[] args)
{
    wstring logFileName = "mago-mi-debug.log"w;//std::wstring logFileName = L"mago-mi-debug.log";
	wstring exename = args[0];//std::wstring exename = argv[0];
	wstring dirname = getDirName(exename);//std::wstring dirname = getDirName(exename);
	if (!dirname.empty())
		logFileName = dirname + "\\"w + logFileName;
//#ifdef FORCE_LOG_FILE_IN_RELEASE_MODE
	static if(FORCE_LOG_FILE_IN_RELEASE_MODE){
		CRLog.setFileLogger(toUtf8(logFileName).c_str(), true);
//#ifdef _DEBUG
		debug{
			CRLog.setLogLevel(CRLog.LL_TRACE);
		}
		else//#else{
			CRLog.setLogLevel(CRLog.LL_DEBUG);
		}
//#endif
		for (int i = 0; i < argc; i++)
			CRLog._debug("args[%d]: `%s`", i, toUtf8(args[i]).c_str());
//#endif
	}
	parseCommandLine(args);

//#ifdef _DEBUG
	debug{
		if (!CRLog.isLoggerSet()) {
			CRLog.setFileLogger(toUtf8(logFileName).c_str(), true);
			CRLog.setLogLevel(CRLog.LL_TRACE);
		}
//#else
//#ifdef FORCE_LOG_FILE_IN_RELEASE_MODE
	}else{
		static if(FORCE_LOG_FILE_IN_RELEASE_MODE){
			if (!CRLog.isLoggerSet()) {
				CRLog.setFileLogger(toUtf8(logFileName).c_str(), true);
				CRLog.setLogLevel(CRLog.LL_DEBUG);
			}
		}
	}
//#endif
//#endif

	//testEngine();
	
	//Debugger debugger;
	//int res = debugger.enterCommandLoop();
	int res = Debugger_Init();
	if(!res){
		Debugger_enterCommandLoop();
	}

	params.clear();
	return res;
	//CRLog.trace("mago-mi leaving main(), exit code: %d", res);
	
}
