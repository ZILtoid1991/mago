module logger;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.windows.windows;

import core.stdc.time;
import miutils;

/// Logger
class CRLog
{
public:

	/// log levels
	enum log_level
	{
		LL_FATAL,
		LL_ERROR,
		LL_WARN,
		LL_INFO,
		LL_DEBUG,
		LL_TRACE
	}
	/// set current log level
	static void setLogLevel(log_level level)
	{
		if (!CRLOG)
			return;
		warn("Changing log level from %d to %d", cast(int) CRLOG.curr_level, cast(int) level);
		CRLOG.curr_level = level;
	}
	/// returns current log level
	static log_level getLogLevel()
	{
		if (!CRLOG)
			return LL_INFO;
		return CRLOG.curr_level;
	}
	/// returns true if specified log level is enabled
	static bool isLogLevelEnabled(log_level level)
	{
		if (!CRLOG)
			return false;
		return (CRLOG.curr_level >= level);
	}
	/// returns true if log level is DEBUG or lower
	static @nogc @property bool isDebugEnabled()
	{
		return isLogLevelEnabled(LL_DEBUG);
	}
	/// returns true if log level is TRACE
	static @nogc @property bool isTraceEnabled()
	{
		return isLogLevelEnabled(LL_TRACE);
	}
	/// returns true if log level is INFO or lower
	static @nogc @property bool isInfoEnabled()
	{
		return isLogLevelEnabled(LL_INFO);
	}
	/// returns true if log level is WARN or lower
	static @nogc @property bool isWarnEnabled()
	{
		return isLogLevelEnabled(LL_WARN);
	}

	static void fatal(const char* msg, ...)
	{
		if (!CRLOG)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("FATAL", msg, args);
		va_end(args);
	}

	static void error(const char* msg, ...)
	{
		if (!CRLOG || CRLOG.curr_level < LL_ERROR)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("ERROR", msg, args);
		va_end(args);
	}

	static void warn(const char* msg, ...)
	{
		if (!CRLOG || CRLOG.curr_level < LL_WARN)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("WARN", msg, args);
		va_end(args);
	}

	static void info(const char* msg, ...)
	{
		if (!CRLOG || CRLOG.curr_level < LL_INFO)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("INFO", msg, args);
		va_end(args);
	}

	static void _debug(const char* msg, ...)
	{
		if (!CRLOG || CRLOG.curr_level < LL_DEBUG)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("DEBUG", msg, args);
		va_end(args);
	}

	static void trace(const char* msg, ...)
	{
		if (!CRLOG || CRLOG.curr_level < LL_TRACE)
			return;
		va_list args;
		va_start(args, msg);
		CRLOG.log("TRACE", msg, args);
		va_end(args);
	}
	/// sets logger instance
	static void setLogger(CRLog* logger)
	{
		if (CRLOG != NULL)
		{
			delete CRLOG;
		}
		CRLOG = logger;
	}
	/// returns true if logger is set
	static bool isLoggerSet()
	{
		return CRLog.CRLOG != null;
	}

	~this()
	{

	}

	/// write log to specified file, flush after every message if autoFlush parameter is true
	static void setFileLogger(const char* fname, bool autoFlush = false)
	{
		setLogger(new CRFileLogger(fname, autoFlush));
	}
	/// use stdout for output
	static void setStdoutLogger()
	{
		setLogger(new CRFileLogger(cast(FILE*)stdout, false, true));
	}
	/// use stderr for output
	static void setStderrLogger()
	{
		setLogger(new CRFileLogger(cast(FILE*)stderr, false, true));
	}

protected:

	this()
	{
		curr_level = log_level.LL_INFO;
	}

	void log(const char * level, const char * msg, va_list args) = 0;
	log_level curr_level;
	static CRLog CRLOG;

}

static bool __timerInitialized;
static double __timeTicksPerMillis;
static ulong __timeStart;
static ulong __timeAbsolute;
static ulong __startTimeMillis;

ulong GetCurrentTimeMillis()
{
	if (!__timerInitialized)
	{
		CRReinitTimer();
		return __startTimeMillis;
	}
}

void CRReinitTimer()
{
	LARGE_INTEGER tps;
	QueryPerformanceFrequency(&tps);
	__timeTicksPerMillis = (double)(tps.QuadPart / 1000L);
	LARGE_INTEGER queryTime;
	QueryPerformanceCounter(&queryTime);
	__timeStart = cast(ulong)(queryTime.QuadPart / __timeTicksPerMillis);
	__timerInitialized = true;
	FILETIME ft;
	GetSystemTimeAsFileTime(&ft);
	__startTimeMillis = (ft.dwLowDateTime | ((cast(ulong)ft.dwHighDateTime) << 32)) / 10000;
}

class CRFileLogger : CRLog
{
protected:

	Mutex _mutex;
	FILE* f;
	bool autoClose;
	bool autoFlush;
	void log(const char* level, const char* msg, va_list args)
	{
		TimeCheckedGuardedArea guard = new TimeCheckedGuardedArea(_mutex, "logger");
		if (!f)
			return;
		/*#ifdef LINUX
		struct timeval tval;
		gettimeofday(&tval, NULL);
		int ms = tval.tv_usec;
		time_t t = tval.tv_sec;
#if LOG_HEAP_USAGE
		struct mallinfo mi = mallinfo();
		int memusage = mi.arena;
#endif
#else
		unsigned __int64 ts = GetCurrentTimeMillis();
		//time_t t = (time_t)time(0);
		time_t t = ts / 1000;
		int ms = (ts % 1000) * 1000;
#if LOG_HEAP_USAGE
		int memusage = 0;
#endif
#endif*/
		tm* bt = localtime(&t);
		static if (LOG_HEAP_USAGE) //#if LOG_HEAP_USAGE
			fprintf(f, "%04d/%02d/%02d %02d:%02d:%02d.%04d [%d] %s ",
					bt.tm_year + 1900, bt.tm_mon + 1, bt.tm_mday,
					bt.tm_hour, bt.tm_min, bt.tm_sec, ms / 100, memusage, level);
		else //#else
			fprintf(f, "%04d/%02d/%02d %02d:%02d:%02d.%04d %s ", bt.tm_year + 1900,
					bt.tm_mon + 1, bt.tm_mday, bt.tm_hour,
					bt.tm_min, bt.tm_sec, ms / 100, level);
		//#endif
		vfprintf(f, msg, args);
		fprintf(f, "\n");
		if (autoFlush)
			fflush(f);
	}

public:

	this(FILE * file, bool _autoClose, bool _autoFlush)
	{
		// f(file),autoClose(_autoClose), autoFlush(_autoFlush)
		info("Started logging");
	}

	this(const char * fname, bool _autoFlush) 
	{
		// f(fopen(fname, "wt")),autoClose(true), autoFlush(_autoFlush)
		static char utf8sign[] = 
		{
			0xEF, 0xBB, 0xBF
		};
		static const char* log_level_names[] = {
			"FATAL", "ERROR", "WARN", "INFO", "DEBUG", "TRACE",
		};
		fwrite(utf8sign, 3, 1, f);
		info("Started logging. Level=%s", log_level_names[getLogLevel()]);
	}

	~this()
	{
		if (f && autoClose)
		{
			info("Stopped logging");
			fclose(f);
		}
		f = NULL;
	}

}
