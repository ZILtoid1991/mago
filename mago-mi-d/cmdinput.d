module cmdinput;

import core.sys.windows.windows;
import miutils;
import std.format;
import std.string;
import std.utf;

/// input callback interface
interface CmdInputCallback
{

	/// called on new input line
	void onInputLine(ref wstring s);
	/// called when ctrl+c or ctrl+break is called
	void onCtrlBreak();
};

/// console or redirected stdin input
/// Supports readline editor for windows console
class CmdInput
{
private:
	CmdInputCallback _callback;
	bool _inConsole;
	bool _closed;
	bool _enabled;
	StringBuffer _buf;
	void lineCompleted()
	{
		_buf.trimEol();
		wstring res = _buf.wstr();
		_buf.reset();
		string s = toUtf8(res);
		CRLog._debug("STDIN: %s", s.c_str());
		_readlinePromptShown = false;
		if (_callback)
		{
			_callback.onInputLine(res);
		}
	}

public:
	this()
	{
	}

	~this()
	{
	}

	void enable(bool enabled)
	{
		_enabled = enabled;
		showPrompt();
	}

	void showPrompt()
	{
		if (_inConsole)
			return;
		TimeCheckedGuardedArea area = new TimeCheckedGuardedArea(_consoleGuard, "stdin poll");
		if (_enabled && !_readlinePromptShown)
		{
			HANDLE h_out = GetStdHandle(STD_OUTPUT_HANDLE);
			DWORD bytesWritten = 0;
			//debug("STDOUT: (gdb) "w);
			if (!WriteFile(h_out, "(gdb) \r\n", 8, &bytesWritten, NULL))
			{
				DWORD err = GetLastError();
				CRLog.error("ReadFile error %d", err);
				_closed = true;
			}
			_readlinePromptShown = true;
		}
	}

	bool inConsole()
	{
		return _inConsole;
	}
	/// sets input callback
	void setCallback(CmdInputCallback* callback)
	{
		_callback = callback;
	}

	/// returns true if stdin/stdout is closed
	bool isClosed()
	{
		if (_closed)
			return true;
		if (_inConsole)
			return false;
		// check status
		TimeCheckedGuardedArea area = new TimeCheckedGuardedArea(_consoleGuard, "isClosed");
		HANDLE h_in = GetStdHandle(STD_INPUT_HANDLE);
		if (h_in && h_in != INVALID_HANDLE_VALUE)
		{
			DWORD res = WaitForSingleObject(h_in, 10);
			if (res != WAIT_FAILED)
			{
				return false;
			}
		}
		_closed = true;
		return _closed;
	}
	/// poll input, return false if stdin is closed or eof
	bool poll()
	{
		if (_closed)
			return false;
		if (_inConsole)
		{
			//
			wchar_t* line = NULL;
			int res = READLINE_ERROR;
			{
				TimeCheckedGuardedArea area = new TimeCheckedGuardedArea(_consoleGuard, "readline_poll");
				res = readline_poll("(gdb) ", &line);
				if (res == READLINE_IN_PROGRESS)
					_readlineEditActive = true;
			}
			if (res == READLINE_READY)
			{
				//wprintf(L"Line: %s\n", line);
				if (line)
				{
					wstring s = line;
					string histLine = toUTF8(s);
					add_history(cast(char * ) histLine.c_str());
					free(line);
					_buf = histLine;
					lineCompleted();
				}
			}
			else if (res == READLINE_CTRL_C)
			{
				//wprintf(L"Ctrl+C is pressed\n");
				if (_callback)
				{
					_callback.onCtrlBreak();
				}
			}
			else if (res == READLINE_ERROR)
			{
				_closed = true;
				return false;
			}
			return true;
		}
		else
		{
			{
				HANDLE h_in = GetStdHandle(STD_INPUT_HANDLE);

				if (h_in && h_in != INVALID_HANDLE_VALUE)
				{
					{
						showPrompt();
					}
					for (;;)
					{
						//CRLog::debug("Waiting for STDIN input");
						//DWORD res = WaitForSingleObject(h_in, 100);
						//CRLog::debug("Wait result: %x", res);

						DWORD bytesAvailable = 0;
						if (!PeekNamedPipe(h_in, NULL, 0, NULL, &bytesAvailable, NULL))
						{
							DWORD err = GetLastError();
							CRLog.error("PeekNamedPipe error %d", err);
							_closed = true;
							break;
						}
						//CRLog::debug("PeekNamedPipe result: %x", bytesAvailable);

						if (bytesAvailable)
						{ //res == WAIT_OBJECT_0) {
							char ch = 0;
							DWORD bytesRead = 0;
							//CRLog::trace("Reading character from stdin");
							if (ReadFile(h_in, &ch, 1, &bytesRead, NULL))
							{
								// byte is read from stdin
								if (bytesRead == 1)
								{
									//printf("Character read: %c (%d)", ch, ch);
									if (ch != '\r') // ignore \r in \r\n
										_buf.append(ch);
									if (ch == '\n')
										break; // full line is entered
								}
							}
							else
							{
								//ERROR_OPERATION_ABORTED;
								DWORD err = GetLastError();
								CRLog.error("ReadFile error %d", err);
								if (err == ERROR_BROKEN_PIPE)
								{
									_closed = true;
								}
								//printf("Reading failed, ch = %d, bytesRead = %d, lastError=%d\n", ch, bytesRead, GetLastError());
								break;
							}
						}
						else
						{
							//CRLog::trace("no data in stdin, sleeping");
							Sleep(100);
							break;
						} //if (res == WAIT_TIMEOUT) {
						//	CRLog::trace("stdin polling timeout");
						//	break;
						//}
						//} else if (res == WAIT_FAILED) {
						//	_closed = true;
						//	break;
						//}
					}
				}
			}
			if (_buf.endsWith('\n'))
			{
				lineCompleted();
			}
		}
		if (isClosed())
		{
		CRLog.trace("input is closed");
		}
		return !isClosed();
	}
}

/// global cmd input object
static CmdInput _cmdinput;

/// write line to stdout, returns false if writing is failed
bool writeStdout(wstring s)
{
	TimeCheckedGuardedArea area = new TimeCheckedGuardedArea(_consoleGuard, "writeStdout");
	HANDLE h_out = GetStdHandle(STD_OUTPUT_HANDLE);
	WstringBuffer buf;
	std.string lineNoEol = toUtf8(s);
	CRLog._debug("STDOUT: %s", lineNoEol.c_str());
	buf = s;
	buf += "\r\n"w;
	if (_cmdinput.inConsole())
	{
		if (_readlineEditActive)
		{
			readline_interrupt();
			_readlineEditActive = false;
		}
	}
	if (_cmdinput.inConsole())
	{
		// erase current edit line
		DWORD charsWritten = 0;
		SetConsoleMode(h_out, ENABLE_PROCESSED_OUTPUT | ENABLE_WRAP_AT_EOL_OUTPUT);
		//WriteConsoleW(h_out, buf.ptr(), buf.length(), &charsWritten, NULL);
		return (WriteConsoleW(h_out, buf.ptr(), buf.length(), &charsWritten, NULL) != 0);
	}
	else
	{
		string line = toUtf8(buf.wstr());
		DWORD bytesWritten = 0;
		//printf("line to write: %s", line.c_str());
		bool res = WriteFile(h_out, line.c_str(), line.length(), &bytesWritten, NULL) != 0;
		if (res)
		{
			FlushFileBuffers(h_out);
			WriteFile(h_out, line.c_str(), 0, &bytesWritten, NULL);
		}
		//res = WriteFile(h_out, "\n", 1, &bytesWritten, NULL) != 0;
		return res;
	}
}
/// write line to stderr, returns false if writing is failed
bool writeStderr(wstring s)
{
	TimeCheckedGuardedArea area = new TimeCheckedGuardedArea(_consoleGuard, "writeStderr");
	HANDLE h_out = GetStdHandle(STD_ERROR_HANDLE);
	WstringBuffer buf;
	buf = s;
	buf += "\r\n"w;
	string line = toUtf8(buf.wstr());
	if (_cmdinput.inConsole())
	{
		// erase current edit line
		readline_interrupt();
	}
	DWORD bytesWritten = 0;
	CRLog._debug("STDERR: %s", line.c_str());
	bool res = WriteFile(h_out, line.c_str(), line.length(), &bytesWritten, NULL) != 0;
	if (res)
	{
		FlushFileBuffers(h_out);
		WriteFile(h_out, line.c_str(), 0, &bytesWritten, NULL);
	}
	return res;
}

enum OUT_BUFFER_SIZE = 16384;

/// formatted output to debugger stdout
bool writeStdout(const char* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	static char[OUT_BUFFER_SIZE] buffer;
	vsnprintf_s(buffer, OUT_BUFFER_SIZE - 1, fmt, args);
	va_end(args);
	string s = fromStringz(fmt);
	wstring ws = toUTF16(s);
	return writeStdout(ws);
}
/// formatted output to debugger stdout
bool writeStdout(const wchar_t* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	static char buffer[OUT_BUFFER_SIZE];
	vsnprintf_s(buffer, OUT_BUFFER_SIZE - 1, fmt, args);
	va_end(args);
	string s = fromStringz(buffer);
	wstring ws = toUTF16(s);
	return writeStderr(ws);
}
/// formatted output to debugger stderr
bool writeStderr(const char* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	static wchar_t[OUT_BUFFER_SIZE] buffer;
	_vsnwprintf_s(buffer, OUT_BUFFER_SIZE - 1, fmt, args);
	va_end(args);
	wstring ws = fromWStringz(buffer);
	return writeStdout(ws);
}
/// formatted output to debugger stderr
bool writeStderr(const wchar_t* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	static wchar_t[OUT_BUFFER_SIZE] buffer;
	_vsnwprintf_s(buffer, OUT_BUFFER_SIZE - 1, fmt, args);
	va_end(args);
	wstring ws = fromWStringz(buffer);
	return writeStderr(ws);
}
