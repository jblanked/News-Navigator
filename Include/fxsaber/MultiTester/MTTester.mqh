#property strict

#include <WinAPI\WinAPI.mqh>

#define GA_ROOT           0x00000002

#define BM_CLICK          0x000000F5

#define WM_KEYDOWN        0x0100
#define WM_CHAR           0x0102
#define WM_LBUTTONDOWN    0x0201
#define WM_CLOSE          0x0010
#define WM_COMMAND        0x0111

#define VK_RETURN         0x0D
#define VK_ESCAPE         0x1B
#define VK_HOME           0x24
#define VK_LEFT           0x25
#define VK_RIGHT          0x27
#define VK_DOWN           0x28
#define VK_DELETE         0x2E

#define DTM_SETSYSTEMTIME 0x1002

#define GW_HWNDNEXT     2
#define GW_CHILD        5

#define CB_GETLBTEXT     0x0148
#define CB_GETLBTEXTLEN  0x0149

#define GMEM_MOVEABLE   2
#define CF_UNICODETEXT  13
#define CF_TEXT         1

#define ID_EDIT_PASTE 0xE125
#define ID_EDIT_COPY  0xE122

#define PROCESS_QUERY_INFORMATION 0x0400

#define FILE_ATTRIBUTE_DIRECTORY 0x00000010
#define INVALID_FILE_ATTRIBUTES UINT_MAX

#define LVM_GETITEMCOUNT 0x1004

#import "user32.dll"
  PVOID SendMessageW( HANDLE, uint, PVOID, int &[] );
  PVOID SendMessageW( HANDLE, uint, PVOID, short &[] );
#import

#import "kernel32.dll"
  bool CopyFileW( string lpExistingFileName, string lpNewFileName, bool bFailIfExists );
  int ReadFile( HANDLE file, uchar &buffer[], uint number_of_bytes_to_read, uint &number_of_bytes_read, PVOID overlapped );
  int WriteFile( HANDLE file, const uchar &buffer[], uint number_of_bytes_to_write, uint &number_of_bytes_written, PVOID overlapped );
  string lstrcatW( HANDLE Dst, string Src );
  int    lstrcpyW( HANDLE ptrhMem, string Text );
  int QueryFullProcessImageNameW( HANDLE process, uint flags, short &Buffer[], uint &size );
#import

class MTTESTER
{
private:
  static string arrayToHex(uchar &arr[])
  {
    string res = "";
    for(int i = 0; i < ::ArraySize(arr); i++)
    {
      res += ::StringFormat("%.2X", arr[i]);
    }
    return(res);
  }

  // https://www.mql5.com/en/code/26945
  static string instance_id(const string strPath)
  {
    string strTest = strPath;
    ::StringToUpper(strTest);

    // Convert the string to widechar Unicode array (it will include a terminating 0)
    ushort arrShort[];
    const int n = ::StringToShortArray(strTest, arrShort); // n includes terminating 0, and should be dropped

    // Convert data to uchar array for hashing
    uchar widechars[];
    ::ArrayResize(widechars, (n - 1) * 2);
    for(int i = 0; i < n - 1; i++)
    {
      widechars[i * 2] = (uchar)(arrShort[i] & 0xFF);
      widechars[i * 2 + 1] = (uchar)((arrShort[i] >> 8) & 0xFF);
    }

    // Do an MD5 hash of the uchar array, containing the Unicode string
    uchar dummykey[1] = {0};
    uchar result[];
    if(::CryptEncode(CRYPT_HASH_MD5, widechars, dummykey, result) == 0)
    {
      ::Print("Error ", ::GetLastError());
      return NULL;
    }

    return arrayToHex(result);
  }

  static long GetHandle( const int &ControlID[] )
  {
    long Handle = MTTESTER::GetTerminalHandle();
    const int Size = ::ArraySize(ControlID);

    for (int i = 0; i < Size; i++)
      Handle = user32::GetDlgItem(Handle, ControlID[i]);

    return(Handle);
  }

  static int GetLastPos( const string &Str, const short Char )
  {
    int Pos = ::StringLen(Str) - 1;

    while ((Pos >= 0) && (Str[Pos] != Char))
      Pos--;

    return(Pos);
  }

  static string GetPathExe( const HANDLE Handle )
  {
    string Str = NULL;

    uint processId = 0;

    if (user32::GetWindowThreadProcessId(Handle, processId))
    {
      const HANDLE processHandle = kernel32::OpenProcess(PROCESS_QUERY_INFORMATION, false, processId);

      if (processHandle)
      {
        short Buffer[MAX_PATH] = {0};

        uint Size = ::ArraySize(Buffer);

        if (kernel32::QueryFullProcessImageNameW(processHandle, 0, Buffer, Size))
          Str = ::ShortArrayToString(Buffer, 0, Size);

        kernel32::CloseHandle(processHandle);
      }
    }

    return(Str);
  }

  static string GetClassName( const HANDLE Handle )
  {
    string Str = NULL;

    short Buffer[MAX_PATH] = {0};

    if (user32::GetClassNameW(Handle, Buffer, ::ArraySize(Buffer)))
      Str = ::ShortArrayToString(Buffer);

    return(Str);
  }

  static string StringBetween( string &Str, const string StrBegin, const string StrEnd = NULL )
  {
    string Res = NULL;
    int PosBegin = ::StringFind(Str, StrBegin);

    if ((PosBegin >= 0) || (StrBegin == NULL))
    {
      PosBegin = (PosBegin >= 0) ? PosBegin + ::StringLen(StrBegin) : 0;

      const int PosEnd = ::StringFind(Str, StrEnd, PosBegin);

      if (PosEnd != PosBegin)
        Res = ::StringSubstr(Str, PosBegin, (PosEnd >= 0) ? PosEnd - PosBegin : -1);

      Str = (PosEnd >= 0) ? ::StringSubstr(Str, PosEnd + ::StringLen(StrEnd)) : NULL;

      if (Str == "")
        Str = NULL;
    }

    return((Res == "") ? NULL : Res);
  }

  static bool GetClipboard( string &Str, const int Attempts = 3 )
  {
    bool Res = false;
    Str = NULL;

    for (int j = 0; (j < Attempts) && !Res/* && !::IsStopped()*/; j++) // Глобальному деструктору может понадобиться
      if (user32::OpenClipboard(0))
      {
        const HANDLE hglb = user32::GetClipboardData(CF_TEXT);

        if (hglb)
        {
          const HANDLE lptstr = kernel32::GlobalLock(hglb);

          if (lptstr)
          {
            kernel32::GlobalUnlock(hglb);

            short Array[];
            const int Size = ::StringToShortArray(kernel32::lstrcatW(lptstr, ""), Array) - 1;

            //Str = ::CharArrayToString(_R(Array).Bytes); // TypeToBytes.mqh

            if ((Size > 0) && ::StringReserve(Str, Size << 1))
              for (int i = 0; i < Size; i++)
              {
                const uchar Char1 = (uchar)Array[i];

                if (Char1)
                  Str += ::CharToString(Char1);
                else
                  break;

                const uchar Char2 = uchar(Array[i] >> 8);

                if (Char2)
                  Str += ::CharToString(Char2);
                else
                  break;
              }

            Res = true;
          }
        }

        user32::CloseClipboard();
      }
      else
        ::Sleep(10);

    return(Res);
  }

  static bool SetClipboard( const string Str, const int Attempts = 3 )
  {
    bool Res = false;

    for (int j = 0; (j < Attempts) && !Res/* && !::IsStopped()*/; j++) // Глобальному деструктору может понадобиться
      if (user32::OpenClipboard(0))
      {
        if (user32::EmptyClipboard())
        {
          const HANDLE hMem = kernel32::GlobalAlloc(GMEM_MOVEABLE, (::StringLen(Str) + 1) << 1);

          if (hMem)
          {
            const HANDLE ptrMem = kernel32::GlobalLock(hMem);

            if (ptrMem)
            {
              kernel32::lstrcpyW(ptrMem, Str);
              kernel32::GlobalUnlock(hMem);

              Res = user32::SetClipboardData(CF_UNICODETEXT, hMem);
            }

            if (!ptrMem || !Res)
              kernel32::GlobalFree(hMem);
          }
        }

        user32::CloseClipboard();
      }
      else
        ::Sleep(10);

    return (Res);
  }

  static string GetFreshFileName( const string Path, const string Mask )
  {
    string Str = NULL;

    FIND_DATAW FindData;
    const HANDLE handle = kernel32::FindFirstFileW(Path + Mask, FindData);

    if (handle != INVALID_HANDLE)
    {
      ulong MaxTime = 0;
//      ulong Size = 0;

      do
      {
        const ulong TempTime = ((ulong)FindData.ftLastWriteTime.dwHighDateTime << 32) + FindData.ftLastWriteTime.dwLowDateTime;

        if (TempTime > MaxTime)
        {
          MaxTime = TempTime;

          Str = ::ShortArrayToString(FindData.cFileName);
//          Size = ((ulong)FindData.nFileSizeHigh << 32) + FindData.nFileSizeLow;;
        }
      }
      while (kernel32::FindNextFileW(handle, FindData));

      kernel32::FindClose(handle);
    }

    return((Str == NULL) ? NULL : Path + Str);
  }

  static int DeleteFolder( const string FolderName )
  {
    int Res = 0;

    FIND_DATAW FindData;
    const HANDLE handle = kernel32::FindFirstFileW(FolderName + "\\*", FindData);

    if (handle != INVALID_HANDLE)
    {
      do
      {
        if (FindData.cFileName[0] != '.')
        {
          const string Name = FolderName + "\\" + ::ShortArrayToString(FindData.cFileName);

          Res += (bool)(FindData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? MTTESTER::DeleteFolder(Name) : kernel32::DeleteFileW(Name);

        }
      }
      while (kernel32::FindNextFileW(handle, FindData));

      kernel32::FindClose(handle);

      Res += kernel32::RemoveDirectoryW(FolderName);
    }

    return(Res);
  }

  static int GetFileNames( const string Path, const string Mask, string &FileNames[] )
  {
    ::ArrayFree(FileNames);
    ulong Times[];

    FIND_DATAW FindData;
    const HANDLE handle = kernel32::FindFirstFileW(Path + Mask, FindData);

    if (handle != INVALID_HANDLE)
    {
      do
      {
        FileNames[::ArrayResize(FileNames, ::ArraySize(FileNames) + 1) - 1] = ::ShortArrayToString(FindData.cFileName);
        Times[::ArrayResize(Times, ::ArraySize(Times) + 1) - 1] = ((ulong)FindData.ftLastWriteTime.dwHighDateTime << 32) + FindData.ftLastWriteTime.dwLowDateTime;
      }
      while (kernel32::FindNextFileW(handle, FindData));

      kernel32::FindClose(handle);
    }

    ulong Pos[][2];
    const int Size = ::ArrayResize(Pos, ::ArraySize(FileNames));

    for (int i = 0; i < Size; i++)
    {
      Pos[i][0] = Times[i];
      Pos[i][1] = i;
    }

    ::ArraySort(Pos);

    string Array[];

    for (int i = ::ArrayResize(Array, Size) - 1; i >= 0; i--)
      Array[i] = FileNames[(int)Pos[i][1]];

    ::ArraySwap(Array, FileNames);

    return(Size);
  }

  static string GetLastTstCacheFileName2( void )
  {
    return(MTTESTER::GetFreshFileName(::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\", "*.tst"));
  }

  static string GetLastOptCacheFileName2( void )
  {
    return(MTTESTER::GetFreshFileName(::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\", "*.opt"));
  }

  static string GetLastConfigFileName( void )
  {
    return(MTTESTER::GetFreshFileName(::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\MQL5\\Profiles\\Tester\\", "*.ini"));
  }

  static bool IsChart( const long Handle )
  {
/*
    bool Res = false;

    for (long Chart = ::ChartFirst(), handle = user32::GetDlgItem(Handle, 0xE900);
         (Chart != -1) && !(Res = (::ChartGetInteger(Chart, CHART_WINDOW_HANDLE) == handle));
         Chart = ::ChartNext(Chart))
      ;

    return(Res);
*/
    return((bool)user32::GetDlgItem(user32::GetDlgItem(Handle, 0xE900), 0x27CE));
  }

  static bool SetTime( const long Handle, const datetime time )
  {
    const bool Res = time && MTTESTER::IsReady();

    if (Res)
    {
      MqlDateTime TimeStruct;
      ::TimeToStruct(time, TimeStruct);

      int SysTime[2];

      SysTime[0] = (TimeStruct.mon << 16) | TimeStruct.year;
      SysTime[1] = (TimeStruct.day << 16) | TimeStruct.day_of_week;

      user32::SendMessageW(Handle, DTM_SETSYSTEMTIME, 0, SysTime);
    }

    return(Res || !time);
  }

  static string GetComboBoxString( const long Handle )
  {
    short Buf[];

    // https://www.mql5.com/ru/forum/318305/page20#comment_17747389
    ::ArrayResize(Buf, (int)user32::SendMessageW(Handle, CB_GETLBTEXTLEN, 0, 0 ) + 1);
    user32::SendMessageW(Handle, CB_GETLBTEXT, 0, Buf);

    return(::ShortArrayToString(Buf));
  }

  static void Sleep2( const uint Pause )
  {
    const uint StartTime = ::GetTickCount();

    while (!::IsStopped() && (::GetTickCount() - StartTime) < Pause)
      ::Sleep(0);

    return;
  }

  static bool StartTester( void )
  {
    string Str;

    return(MTTESTER::GetSettings2(Str));
  }

  static bool IsReady2( void )
  {
    static bool bInit = MTTESTER::StartTester();

    static const int ControlID[] = {0xE81E, 0x804E, 0x2712, 0x4196};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    ushort Str[6];

    if (!::IsStopped()) // Иначе зависание при снятии советника.
      user32::GetWindowTextW(Handle, Str, sizeof(Str) / sizeof(ushort));

    const string Name = ::ShortArrayToString(Str);
    bool Res = (Name == "Старт") || (Name == "Start");

    static int Count = 0;

    if (!Res && (Name == "") && (Count < 10))
    {
      MTTESTER::StartTester();
      Count++;

      Res = MTTESTER::IsReady2();
    }

    Count = 0;

    return(Res);
  }

  static string GetStatusString( void )
  {
    static const int ControlID[] = {0xE81E, 0x804E, 0x2791};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    ushort Str[64];

    if (!::IsStopped()) // Иначе зависание при снятии советника.
      user32::GetWindowTextW(Handle, Str, sizeof(Str) / sizeof(ushort));

    return(::ShortArrayToString(Str));
  }

  static int GetAgentNames( string &AgentNames[] )
  {
    return(MTTESTER::GetFileNames(::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\", "Agent*.*", AgentNames));
  }

  static string GetBeginFileName( void )
  {
    string Res = NULL;
    string Str;

    if (MTTESTER::GetSettings2(Str))
    {
      string ExpertName = MTTESTER::GetValue(Str, "Expert");
      const int Pos = MTTESTER::GetLastPos(ExpertName, '\\') + 1;

      ExpertName = ::StringSubstr(ExpertName, Pos, ::StringLen(ExpertName) - Pos - 4);

      Res = ExpertName + "." + MTTESTER::GetValue(Str, "Symbol") + "." + MTTESTER::GetValue(Str, "Period");

      string FromDate = MTTESTER::GetValue(Str, "FromDate");
      ::StringReplace(FromDate, ".", NULL);

      string ToDate = MTTESTER::GetValue(Str, "ToDate");
      ::StringReplace(ToDate, ".", NULL);

      Res += "." + FromDate + "_" + ToDate + "." + MTTESTER::GetValue(Str, "Model");
    }

    return(Res);
  }

  static int GetJournalItemCount( void )
  {
    static const int ControlID[] = {0xE81E, 0x804E, 0x28ED};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    return((int)user32::SendMessageW(Handle, LVM_GETITEMCOUNT, 0, 0));
  }

#define GENERIC_READ  0x80000000
#define GENERIC_WRITE 0x40000000
#define SHARE_READ    1
#define OPEN_EXISTING 3
#define OPEN_ALWAYS   4
#define CREATE_ALWAYS 2

  static bool IsLibraryOrService( const string FileName )
  {
      bool Res = true;
      const HANDLE handle = kernel32::CreateFileW(FileName, GENERIC_READ, SHARE_READ, 0, OPEN_EXISTING, 0, 0);

      if (handle != INVALID_HANDLE)
      {
        uchar Buffer[4];
        uint Read;

        kernel32::ReadFile(handle, Buffer, sizeof(Buffer), Read, 0);
        Res = (Read < sizeof(Buffer)) || ((Buffer[3] == 3) || (Buffer[3] == 5)); // 1 - Script, 2 - Expert, 3 - Library, 4 - Indicator, 5 - Service.

        kernel32::CloseHandle(handle);
      }

    return(Res);
  }

  static int GetEX5FileNames( const string FolderName, string &FileNames[] )
  {
    int Res = 0;

    FIND_DATAW FindData;
    const HANDLE handle = kernel32::FindFirstFileW(FolderName + "\\*", FindData);

    if (handle != INVALID_HANDLE)
    {
      do
      {
        if (FindData.cFileName[0] != '.')
        {
          string Name = FolderName + "\\" + ::ShortArrayToString(FindData.cFileName);

          if ((bool)(FindData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
            Res += MTTESTER::GetEX5FileNames(Name, FileNames);
          else if (::StringToLower(Name) && ::StringSubstr(Name, ::StringLen(Name) - 4) == ".ex5" && !MTTESTER::IsLibraryOrService(Name))
          {
            FileNames[::ArrayResize(FileNames, ::ArraySize(FileNames) + 1) - 1] = Name;
            Res++;
          }
        }
      }
      while (kernel32::FindNextFileW(handle, FindData));

      kernel32::FindClose(handle);
    }

    return(Res);
  }

  static string GetTerminalPath( const HANDLE Handle )
  {
    string Path = MTTESTER::GetPathExe(Handle);

    return(::StringSubstr(Path, 0, MTTESTER::GetLastPos(Path, '\\')));
  }

  static void RefreshNumbersEX5( const HANDLE TerminalHandle )
  {
    const uint MT5InternalMsg = user32::RegisterWindowMessageW("MetaTrader5_Internal_Message");

    static const uchar Codes[] = {0x01, 0x02, 0x03, 0x1A};

    user32::SendMessageW(TerminalHandle, WM_COMMAND, 0X8288, 0);

    for (int i = 0; i < sizeof(Codes); i++)
      user32::SendMessageW(TerminalHandle, MT5InternalMsg, Codes[i], 0);

    return;
  }

  static int GetNumberEX5( const HANDLE TerminalHandle, string FileName )
  {
    int Res = -1;

    const string Path = MTTESTER::GetTerminalPath(TerminalHandle);

    if (Path != "")
    {
      MTTESTER::RefreshNumbersEX5(TerminalHandle);

      string FileNames[];

      MTTESTER::GetEX5FileNames(Path + "\\MQL5\\Experts", FileNames);
      MTTESTER::GetEX5FileNames(Path + "\\MQL5\\Indicators", FileNames);
      MTTESTER::GetEX5FileNames(Path + "\\MQL5\\Scripts", FileNames);

      ::StringToLower(FileName);
      const int Len = ::StringLen(Path + "\\MQL5\\");

      for (Res = ::ArraySize(FileNames) - 1; (Res >= 0) && (::StringSubstr(FileNames[Res], Len) != FileName); Res--)
        ;
    }

    return(Res);
  }

  static HANDLE GetChartHandle( const HANDLE TerminalHandle, const uchar ChartNumber = 0 )
  {
    const HANDLE Handle = user32::GetDlgItem(TerminalHandle, 0xE900);

    HANDLE Chart = 0;
    uchar Pos = 0;
    uchar Amount = 0;

    for (Chart = user32::GetDlgItem(Handle, 0xFF00); Chart; Chart = user32::GetDlgItem(Handle, 0xFF00 + ++Pos))
      if (MTTESTER::IsChart(Chart) && (ChartNumber == Amount++))
      {
        Chart = user32::GetDlgItem(Chart, 0xE900);

        break;
      }

    return(Chart);
  }

  template <typename T>
  static int Sort( const T &Array[], int &Indexes[] )
  {
    const int Size = ::ArrayResize(Indexes, ::ArraySize(Array));

    for (int i = 0; i < Size - 1; i++)
    {
      int Pos = i;

      for (int j = i + 1; j < Size; j++)
        if (Array[Pos] > Array[j])
          Pos = j;

      Indexes[i] = Pos;
    }

    return(Size);
  }

  static void SortByPath( HANDLE &Handles[] )
  {
    string Path[];

    for (int i = ::ArrayResize(Path, ::ArraySize(Handles)) - 1; i >= 0; i--)
      Path[i] = MTTESTER::GetPathExe(Handles[i]);

    HANDLE NewHandles[];
    int Indexes[];

    for (int i = ::ArrayResize(NewHandles, MTTESTER::Sort(Path, Indexes)) - 1; i >= 0; i--)
      NewHandles[i] = Handles[Indexes[i]];

    ::ArraySwap(Handles, NewHandles);

    return;
  }

public:
  static HANDLE GetTerminalHandle( void )
  {
    static HANDLE Handle = 0;

    if (!Handle)
    {
      if (::MQLInfoInteger(MQL_TESTER) || (::MQLInfoInteger(MQL_PROGRAM_TYPE) == PROGRAM_SERVICE))
      {
       const string TerminalPath = ::TerminalInfoString(TERMINAL_PATH);

       for (Handle = user32::GetTopWindow(NULL); Handle; Handle = user32::GetWindow(Handle, GW_HWNDNEXT))
         if (MTTESTER::GetClassName(Handle) == "MetaQuotes::MetaTrader::5.00")
         {
          const string ExePath = MTTESTER::GetPathExe(Handle);

          if (::StringSubstr(ExePath, 0, MTTESTER::GetLastPos(ExePath, '\\')) == TerminalPath)
            break;
         }
      }
      else
        Handle = user32::GetAncestor(::ChartGetInteger(0, CHART_WINDOW_HANDLE), GA_ROOT);
    }

    return(Handle);
  }

  static string GetTerminalCaption( void )
  {
    ushort Str[128];

    if (!::IsStopped()) // Иначе зависание при снятии советника.
      user32::GetWindowTextW(MTTESTER::GetTerminalHandle(), Str, sizeof(Str) / sizeof(ushort));

    return(::ShortArrayToString(Str));

  }

  static int GetPassesDone( void )
  {
    string Status = MTTESTER::GetStatusString();

    return((int)MTTESTER::StringBetween(Status, ": ", " /"));
  }

  static bool GetSettings( string &Str, const int Attempts = 10 )
  {
    bool Res = false;

    Str = NULL;

    if (/*!::IsStopped() &&*/ (::StringFind(Str, "[Tester]") || MTTESTER::SetClipboard("", Attempts))) // Глобальному деструктору может понадобиться
    {
      const uint MT5InternalMsg = user32::RegisterWindowMessageW("MetaTrader5_Internal_Message");
      const HANDLE HandleRoot = MTTESTER::GetTerminalHandle();

      static const int ControlID[] = {0xE81E, 0x804E};
      static const long Handle = MTTESTER::GetHandle(ControlID);

      for (int j = 0; (j < Attempts) && !Res/* && !::IsStopped()*/; j++) // Глобальному деструктору может понадобиться
      {
        user32::SendMessageW(HandleRoot, MT5InternalMsg, 9, INT_MAX);

//        SetFocus(Handle);

        // MT4build2209+ - не актуально.
//        user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, 0x17007C); // Выбор вкладки "Настройки"
        user32::SendMessageW(Handle, WM_COMMAND, ID_EDIT_COPY, 0);

        ::Sleep(10);

        Res = MTTESTER::GetClipboard(Str, Attempts) && !::StringFind(Str, "[Tester]");
      }
    }

    return(Res);
  }

  static bool SetSettings( const string Str )
  {
    const bool Res = MTTESTER::SetClipboard(Str);

    if (Res)
    {
      const uint MT5InternalMsg = user32::RegisterWindowMessageW("MetaTrader5_Internal_Message");
      user32::SendMessageW(MTTESTER::GetTerminalHandle(), MT5InternalMsg, 9, INT_MAX);

      static const int ControlID[] = {0xE81E, 0x804E};
      static const long Handle = MTTESTER::GetHandle(ControlID);

    // MT4build2209+ - не актуально.
      //user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, 0x17007C); // Выбор вкладки "Настройки"
      user32::SendMessageW(Handle, WM_COMMAND, ID_EDIT_PASTE, 0);

    // MT4build2209+ - не актуально.
//      user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, 0x1200EF); // https://www.mql5.com/ru/forum/321656/page25#comment_13873612 - Параметры
//      user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, 0x17007C); // Выбор вкладки "Настройки"

      ::Sleep(100);
    }

    return(Res);
  }

  static bool SetSettings2( string Str, const int Attempts = 5 )
  {
    bool Res = false;

    if (MTTESTER::LockWaiting())
    {
      for (int j = 0; (j < Attempts) && !Res; j++)
      {
        string Str1;
        string Str2;
        string Str3;

        Res = MTTESTER::SetSettings(Str) && MTTESTER::GetSettings(Str1) &&
              MTTESTER::SetSettings(Str) && MTTESTER::GetSettings(Str2) &&
              MTTESTER::SetSettings(Str) && MTTESTER::GetSettings(Str3) &&
              (Str1 == Str2) && (Str1 == Str3);
      }

      MTTESTER::Lock(false);
    }

    return(Res);
  }

  static bool GetSettings2( string &Str, const int Attempts = 10 )
  {
    bool Res = false;

    if (MTTESTER::LockWaiting())
    {
      Res = MTTESTER::GetSettings(Str, Attempts);

      MTTESTER::Lock(false);
    }

    return(Res);
  }

  static bool SetSettingsPart( string Str, string StrPrev, const int Attempts = 5 )
  {
    return(MTTESTER::SetSettings2(MTTESTER::StringBetween(Str, NULL, "[TesterInputs]") + "[TesterInputs]" +
                                  MTTESTER::StringBetween(StrPrev, "[TesterInputs]") + Str, Attempts));
  }


  // Если входные параметры советника заданы не все, то их значения берутся с предыдущего советника.
  static bool SetSettingsPart( string Str, const int Attempts = 5 )
  {
    string StrPrev;
/*
    string StrTmp = Str;

    StrTmp = MTTESTER::GetValue(MTTESTER::StringBetween(StrTmp, NULL, "[TesterInputs]"), "Expert");

    return(((StrTmp == NULL) || MTTESTER::GetSettings2(StrPrev)) && MTTESTER::SetSettings2(Str, Attempts) &&
           ((StrTmp == NULL) || (MTTESTER::GetValue(MTTESTER::StringBetween(StrPrev, NULL, "[TesterInputs]"), "Expert") ==
             MTTESTER::GetValue(MTTESTER::StringBetween(Str, NULL, "[TesterInputs]"), "Expert")) ||
             (MTTESTER::SetSettings2("[TesterInputs]" + StrPrev, Attempts) &&
              MTTESTER::SetSettings2("[TesterInputs]" + Str, Attempts))));
*/
    return(MTTESTER::GetSettings2(StrPrev) && MTTESTER::SetSettingsPart(Str, StrPrev, Attempts));
  }

  static int GetLastOptCache( uchar &Bytes[] )
  {
    const string FileName = MTTESTER::GetLastOptCacheFileName2();

    return((FileName != NULL) ? MTTESTER::FileLoad(FileName, Bytes) : -1);
  }

  static int GetLastTstCache( uchar &Bytes[], const bool FromSettings = false )
  {
    int Count = 0;

    string FileName = NULL;

    const string BeginFileName = FromSettings ? MTTESTER::GetBeginFileName() : NULL;

    while (!::IsStopped() && (Count++ < 10) && (FileName == NULL))
    {
      FileName = MTTESTER::GetLastTstCacheFileName2();

      if (FileName == NULL || (FromSettings && (::StringFind(FileName, BeginFileName) == -1)))
      {
        FileName = NULL;

        ::Sleep(500);
      }
    }

    return((FileName != NULL) ? MTTESTER::FileLoad(FileName, Bytes) : -1);
  }

  static string GetExpertName( void )
  {
    static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x28F5};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    return(MTTESTER::GetComboBoxString(Handle));
  }

  static string GetSymbolName( void )
  {
    string Str;;

    return(MTTESTER::GetSettings(Str) ? MTTESTER::StringBetween(Str, "Symbol=", "\r\n") : NULL);
  }

  static bool SetExpertName( const string ExpertName = NULL )
  {
    bool Res = (ExpertName == NULL);

    if (!Res)
    {
      const string PrevExpertName = MTTESTER::GetExpertName();

      if (!(Res = (PrevExpertName == ExpertName)))
      {
        static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x28F5};
        static const long Handle = MTTESTER::GetHandle(ControlID);

        user32::SendMessageW(Handle, WM_LBUTTONDOWN, 0, 0);

        const long Handle2 = user32::GetLastActivePopup(MTTESTER::GetTerminalHandle());

        user32::SendMessageW(Handle2, WM_KEYDOWN, VK_LEFT, 0);
        user32::SendMessageW(Handle2, WM_KEYDOWN, VK_LEFT, 0);

        // Нужно для инициализации.
        for (int i = 0; i < 3; i++)
          user32::SendMessageW(Handle2, WM_CHAR, ':', 0);

        user32::SendMessageW(Handle2, WM_KEYDOWN, VK_HOME, 0);

        const int Size = ::StringLen(ExpertName);

        for (int i = 0; i < Size; i++)
          if (ExpertName[i] == '\\')
          {
            user32::SendMessageW(Handle2, WM_KEYDOWN, VK_RIGHT, 0);
            user32::SendMessageW(Handle2, WM_KEYDOWN, VK_RIGHT, 0);
            user32::SendMessageW(Handle2, WM_KEYDOWN, VK_LEFT, 0);
          }
          else
            user32::SendMessageW(Handle2, WM_CHAR, ExpertName[i], 0);

        user32::SendMessageW(Handle2, WM_KEYDOWN, VK_RETURN, 0);
        user32::SendMessageW(Handle2, WM_KEYDOWN, VK_ESCAPE, 0);

        const string NewExpertName = MTTESTER::GetExpertName();

        Res = (NewExpertName == ExpertName);

        if (!Res && (NewExpertName != PrevExpertName))
          MTTESTER::SetExpertName(PrevExpertName);
      }
    }

    return(Res);
  }

  static bool CloseNotChart( void )
  {
    static const int ControlID[] = {0xE900};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    bool Res = false;

    for (long handle = user32::GetWindow(Handle, GW_CHILD); handle; handle = user32::GetWindow(handle, GW_HWNDNEXT))
      if (!MTTESTER::IsChart(handle))
      {
        user32::SendMessageW(handle, WM_CLOSE, 0, 0);
        Res = true;

        break;
      }

    return(Res);
  }

  static bool IsReady( const uint Pause = 100 )
  {
    if (MTTESTER::IsReady2())
      MTTESTER::Sleep2(Pause);

    return(MTTESTER::IsReady2());
  }

  static bool ClickStart( const bool Check = true, const int Attempts = 50 )
  {
//      static const int ControlID[] = {0xE81E, 0x804E, 0x2712, 0x4196}; // Start Button
    static const int ControlID[] = {0xE81E, 0x804E};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    bool Res = !Check || MTTESTER::IsReady2();

    if (Res)
    {
      if (Check)
      {
//        MTTESTER::StartTester();

//        user32::ShowWindow(user32::GetDlgItem(Handle, 0x28ED), 1); // Journal

        for (int i = 0; (i < Attempts)/* && !::IsStopped() */; i++) // Глобальному деструктору может понадобиться
        {
          // https://www.mql5.com/ru/forum/1111/page3471#comment_51964006
          for (int X = 300; (X <= 1000) && !MTTESTER::GetJournalItemCount(); X += 50)
            user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, X); // lparam - X

          ::Sleep(20);

          if (MTTESTER::GetJournalItemCount())
            break;
        }

        for (int i = 0; (i < Attempts)/* && !::IsStopped() */; i++) // Глобальному деструктору может понадобиться
        {
          // https://www.mql5.com/ru/forum/1111/page3471#comment_51964006
          for (int X = 300; (X <= 1000)/* && MTTESTER::GetJournalItemCount()*/; X += 50)
          {
            user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, X); // lparam - X
            user32::SendMessageW(MTTESTER::GetTerminalHandle(), WM_COMMAND, 0X8176, 0);
          }

          ::Sleep(30);

          if (!MTTESTER::GetJournalItemCount())
            break;
        }
      }

      const int PrevCount = Check ? MTTESTER::GetJournalItemCount() : 0;

//      user32::SendMessageW(Handle, BM_CLICK, 0, 0); // Start Button
      user32::SendMessageW(Handle, user32::RegisterWindowMessageW("MetaTrader5_Internal_Message"), 0X31, 0);

      if (Check)
        for (int i = 0; (i < Attempts) && !(Res = !MTTESTER::IsReady2()); i++) // Дать успеть после нажатия на Start переключиться на Stop.
          ::Sleep(1);

      if (!Res) // После нажатия на Start переключение на Stop осталось незамеченным.
      {
        ::Alert(__FILE__ + ": Start->Stop - is not detected!");

        for (int i = 0; (i < Attempts)/* && !::IsStopped() */; i++) // Глобальному деструктору может понадобиться
        {
          // https://www.mql5.com/ru/forum/1111/page3471#comment_51964006
          for (int X = 300; (X <= 1000)/* && (MTTESTER::GetJournalItemCount() == PrevCount)*/; X += 50)
            user32::SendMessageW(user32::GetDlgItem(Handle, 0x2712), WM_LBUTTONDOWN, 1, X); // lparam - X

          ::Sleep(100); // Меньшее значение может не дать успеть обновиться журналу.

          if (Res = (MTTESTER::GetJournalItemCount() - PrevCount > 1))
            break;
        }

        if (!Res || !(Res = (MTTESTER::GetJournalItemCount() - PrevCount > 1)))
          ::Alert(__FILE__ + ": problem with Start-button!");
      }

//      if (Check)
//        user32::ShowWindow(user32::GetDlgItem(Handle, 0x28ED), 0); // Journal
    }

    return(Res);
  }

  static bool SetTimeFrame( ENUM_TIMEFRAMES period )
  {
    const bool Res = MTTESTER::IsReady();

    if (Res)
    {
      static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x28F7};
      static const long Handle = MTTESTER::GetHandle(ControlID);

      user32::SendMessageW(Handle, WM_KEYDOWN, VK_HOME, 0);

      static const ENUM_TIMEFRAMES Periods[] = {PERIOD_M1, PERIOD_M2, PERIOD_M3, PERIOD_M4, PERIOD_M5, PERIOD_M6, PERIOD_M10,
                                                PERIOD_M12, PERIOD_M15, PERIOD_M20, PERIOD_M30, PERIOD_H1, PERIOD_H2, PERIOD_H3,
                                                PERIOD_H4, PERIOD_H6, PERIOD_H8, PERIOD_H12, PERIOD_D1, PERIOD_W1, PERIOD_MN1};

      if (period == PERIOD_CURRENT)
        period = ::_Period;

      for (int i = 0; (i < sizeof(Periods) / sizeof(ENUM_TIMEFRAMES)) && (period != Periods[i]); i++)
        user32::SendMessageW(Handle, WM_KEYDOWN, VK_DOWN, 0);
    }

    return(Res);
  }

  static bool SetSymbol( const string SymbName = NULL )
  {
    const bool Res = (SymbName == NULL) || (::SymbolInfoInteger(SymbName, SYMBOL_VISIBLE) && MTTESTER::IsReady());
    const int Size = ::StringLen(SymbName);

    if (Res && Size && (SymbName != MTTESTER::GetSymbolName()))
    {
      static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x28F6, 0x2855};
      static const long Handle = MTTESTER::GetHandle(ControlID);

      user32::SendMessageW(Handle, WM_LBUTTONDOWN, 0, 0);
      user32::SendMessageW(Handle, WM_KEYDOWN, VK_DELETE, 0);

      for (int i = 0; i < Size; i++)
        user32::SendMessageW(Handle, WM_CHAR, SymbName[i], 0);

      user32::SendMessageW(Handle, WM_KEYDOWN, VK_RETURN, 0);
    }

    return(Res);
  }

  static bool SetBeginTime( const datetime time )
  {
    static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x2936};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    return(MTTESTER::SetTime(Handle, time));
  }

  static bool SetEndTime( const datetime time )
  {
    static const int ControlID[] = {0xE81E, 0x804E, 0x28EC, 0x2937};
    static const long Handle = MTTESTER::GetHandle(ControlID);

    return(MTTESTER::SetTime(Handle, time));
  }

  static bool Run( const string ExpertName = NULL,
                   const string Symb = NULL,
                   const ENUM_TIMEFRAMES period = PERIOD_CURRENT,
                   const datetime iBeginTime = 0,
                   const datetime iEndTime = 0 )
  {
    string Str = "[Tester]\n";

    Str += (ExpertName != NULL) ? "Expert=" + ExpertName + "\n" : NULL;
    Str += (Symb != NULL) ? "Symbol=" + Symb + "\n" : NULL;
    Str += iBeginTime ? "FromDate=" + ::TimeToString(iBeginTime, TIME_DATE) + "\n" : NULL;
    Str += iEndTime ? "ToDate=" + ::TimeToString(iEndTime, TIME_DATE) + "\n" : NULL;

    return(MTTESTER::SetSettings2(Str) &&
           MTTESTER::SetTimeFrame(period) && MTTESTER::ClickStart());

/*
    return(MTTESTER::SetExpertName(ExpertName) &&
           MTTESTER::SetSymbol(Symb) &&
           MTTESTER::SetBeginTime(iBeginTime) && MTTESTER::SetEndTime(iEndTime) &&
           MTTESTER::SetTimeFrame(period) && MTTESTER::ClickStart());
*/
  }
  static string GetValue( string Settings, const string Name )
  {
    const string Str = (Name == "") ? NULL : MTTESTER::StringBetween(Settings, Name + "=", "\n");
    const int Len = ::StringLen(Str);

    return((Len && (Str[Len - 1] == '\r')) ? ::StringSubstr(Str, 0, Len - 1) : Str);
  }

  static string SetValue( string &Settings, const string Name, const string Value = NULL )
  {
    const string PrevValue = MTTESTER::GetValue(Settings, Name);

    if (PrevValue == NULL)
      Settings += "\n" + Name + "=" + Value;
    else
      ::StringReplace(Settings, Name + "=" + PrevValue, (Value == NULL) ? NULL : Name + "=" + Value); // NULL - delete.

    return(Settings);
  }

  static int GetOptCacheFileNames( string &Path, string &FileNames[] )
  {
    Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\";

    return(MTTESTER::GetFileNames(Path, "*.opt", FileNames));
  }

  template <typename T>
  static int FileLoad( const string FileName, T &Buffer[] )
  {
    int Res = -1;
    const HANDLE handle = kernel32::CreateFileW(FileName, GENERIC_READ, SHARE_READ, 0, OPEN_EXISTING, 0, 0);

    if (handle != INVALID_HANDLE)
    {
      long Size;
      kernel32::GetFileSizeEx(handle, Size);

      uint Read;

      ::ArrayResize(Buffer, (int)Size / sizeof(T));

      kernel32::ReadFile(handle, Buffer, (uint)Size / sizeof(T), Read, 0);
      Res = ::ArrayResize(Buffer, Read);

      kernel32::CloseHandle(handle);
    }

    return(Res);
  }

  static bool FileCopy( const string FileNameIn, const string FileNameOut, const bool Overwrite = false )
  {
    string Path = FileNameOut;
    string Directory = NULL;

    // Можно гораздо экономнее находить пути подпапок.
    while (::StringFind(Path, "\\") > 0)
      kernel32::CreateDirectoryW(Directory += MTTESTER::StringBetween(Path, NULL, "\\") + "\\", 0);

    return(kernel32::CopyFileW(FileNameIn, FileNameOut, !Overwrite));
  }

  template <typename T>
  static int FileSave( const string FileName, const T &Buffer[] )
  {
    string Path = FileName;
    string Directory = NULL;

    // Можно гораздо экономнее находить пути подпапок.
    while (::StringFind(Path, "\\") > 0)
      kernel32::CreateDirectoryW(Directory += MTTESTER::StringBetween(Path, NULL, "\\") + "\\", 0);

    uint Read = 0;
    const HANDLE handle = kernel32::CreateFileW(FileName, GENERIC_WRITE, SHARE_READ, 0, CREATE_ALWAYS, 0, 0);

    if (handle != INVALID_HANDLE)
    {
      kernel32::WriteFile(handle, Buffer, (uint)::ArraySize(Buffer) * sizeof(T), Read, 0);

      kernel32::CloseHandle(handle);
    }

    return((int)Read / sizeof(T));
  }

  static string GetLastOptCacheFileName( void )
  {
    const string Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\";

    return(::StringSubstr(MTTESTER::GetFreshFileName(Path, "*.opt"), ::StringLen(Path)));
  }

  static string GetLastTstCacheFileName( void )
  {
    const string Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\";

    return(::StringSubstr(MTTESTER::GetFreshFileName(Path, "*.tst"), ::StringLen(Path)));
  }

  static bool DeleteLastINI( void )
  {
    const string Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\MQL5\\Profiles\\Tester\\";
    string FileNames[];

    const int Size = MTTESTER::GetFileNames(Path, "*.ini", FileNames);

    return(Size && kernel32::DeleteFileW(Path + FileNames[Size - 1]));
  }

  static bool DeleteLastTST( void )
  {
    const string Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\cache\\";
    string FileNames[];

    const int Size = MTTESTER::GetFileNames(Path, "*.tst", FileNames);

    return(Size && kernel32::DeleteFileW(Path + FileNames[Size - 1]));
  }

  static bool IsFolderON( const string Name, const bool Log = false )
  {
    const uint FileAttribute = kernel32::GetFileAttributesW(Name);

    const bool Res = (FileAttribute == INVALID_FILE_ATTRIBUTES) || (bool)(FileAttribute & FILE_ATTRIBUTE_DIRECTORY);

    if (Log)
      ::Print(Name + " - " + (Res ? "ON." : "OFF"));

    return(Res);
  }

  static bool FolderOFF( const string Name, const bool Log = false  )
  {
    MTTESTER::DeleteFolder(Name);

    const HANDLE handle = kernel32::CreateFileW(Name, GENERIC_WRITE, SHARE_READ, 0, CREATE_ALWAYS, 0, 0);

    if (handle != INVALID_HANDLE)
      kernel32::CloseHandle(handle);

    return(!MTTESTER::IsFolderON(Name, Log));
  }

  static bool FolderON( const string Name, const bool Log = false  )
  {
    kernel32::DeleteFileW(Name);

    return(!MTTESTER::IsFolderON(Name, Log));
  }

#define TERMINAL_UPDATE(A)                                                                                     \
  static const string Name = ::StringSubstr(::TerminalInfoString(TERMINAL_COMMONDATA_PATH), 0,                 \
                                            ::StringLen(::TerminalInfoString(TERMINAL_COMMONDATA_PATH)) - 6) + \
                             MTTESTER::instance_id(::TerminalInfoString(TERMINAL_PATH));                       \
                                                                                                               \
  return(MTTESTER::##A(Name, Log));

  static bool IsTerminalLiveUpdate( const bool Log = false )
  {
    TERMINAL_UPDATE(IsFolderON);
  }

  static bool TerminalLiveUpdateOFF( const bool Log = false )
  {
    TERMINAL_UPDATE(FolderOFF);
  }

  static bool TerminalLiveUpdateON( const bool Log = false )
  {
    TERMINAL_UPDATE(FolderON);
  }
#undef TERMINAL_UPDATE

#define TESTER_LOG(A)                                                                \
  static const string Path = ::TerminalInfoString(TERMINAL_DATA_PATH)+ "\\Tester\\"; \
                                                                                     \
  bool Res = MTTESTER::##A(Path + "logs", Log);                                      \
                                                                                     \
  string AgentNames[];                                                               \
                                                                                     \
  for (int i = MTTESTER::GetAgentNames(AgentNames) - 1; i >= 0; i--)                 \
    Res &= MTTESTER::##A(Path + AgentNames[i] + "\\logs", Log);

  static bool IsTesterLogON( const bool Log = false )
  {
    TESTER_LOG(IsFolderON)

    return(Res);
  }

  static bool TesterLogOFF( const bool Log = false )
  {
    TESTER_LOG(FolderOFF)

    return(!MTTESTER::IsTesterLogON());
  }

  static bool TesterLogON( const bool Log = false )
  {
    TESTER_LOG(FolderON)

    return(MTTESTER::IsTesterLogON());
  }
#undef TESTER_LOG

  static bool Lock( const bool Flag = true )
  {
    static int handle = INVALID_HANDLE;

    if (handle != INVALID_HANDLE)
    {
      ::FileClose(handle);

      handle = INVALID_HANDLE;
    }

    return(Flag && ((handle = ::FileOpen(__FILE__, FILE_WRITE | FILE_COMMON)) != INVALID_HANDLE));
  }

  static bool LockWaiting( const int Attempts = 10 )
  {
    bool Res = MTTESTER::Lock();

    for (int i = 0; (i < Attempts) && !Res && !::IsStopped(); i++)
    {
      ::Sleep(500);

      Res = MTTESTER::Lock();
    }

    return(Res);
  }

  static int GetTerminalHandles( HANDLE &Handles[], const bool SortPath = false )
  {
    ::ArrayFree(Handles);

    for (HANDLE Handle = user32::GetTopWindow(NULL); Handle; Handle = user32::GetWindow(Handle, GW_HWNDNEXT))
      if (MTTESTER::GetClassName(Handle) == "MetaQuotes::MetaTrader::5.00")
        Handles[::ArrayResize(Handles, ::ArraySize(Handles) + 1) - 1] = Handle;

    if (SortPath)
      MTTESTER::SortByPath(Handles);

    return(::ArraySize(Handles));
  }

#define FORCE_PATH "Scripts\\" + __FILE__ + "\\"

  static bool RunEX5( string FileName, HANDLE TerminalHandle = 0, const bool Force = false, const uchar ChartNumber = 0 )
  {
    bool Res = false;

    if (!TerminalHandle)
      TerminalHandle = MTTESTER::GetTerminalHandle();

    const HANDLE MyChartHandle = ::ChartGetInteger(0, CHART_WINDOW_HANDLE);
    HANDLE ChartHandle = MTTESTER::GetChartHandle(TerminalHandle, ChartNumber);

    if ((ChartHandle && (ChartHandle != MyChartHandle)) ||
        (Force && (bool)(ChartHandle = (ChartHandle || ChartNumber) ? MTTESTER::GetChartHandle(TerminalHandle, (uchar)(!ChartNumber)) : 0)))
    {
      if (Force && (TerminalHandle != MTTESTER::GetTerminalHandle()) &&
         (MTTESTER::FileCopy(MTTESTER::GetTerminalPath(MTTESTER::GetTerminalHandle()) + "\\MQL5\\" + FileName,
                             MTTESTER::GetTerminalPath(TerminalHandle) + "\\MQL5\\" + FORCE_PATH + FileName, true)))
        FileName = FORCE_PATH + FileName;

      const int NumberEX5 = MTTESTER::GetNumberEX5(TerminalHandle, FileName);

      Res = (NumberEX5 >= 0) && !user32::SendMessageW(ChartHandle, user32::RegisterWindowMessageW("MetaTrader5_Internal_Message"), 0x1D, NumberEX5);
    }

    return(Res);
  }

  static bool IsForceScript( void )
  {
    return(::StringFind(::MQLInfoString(MQL_PROGRAM_PATH), "\\MQL5\\" + FORCE_PATH) > 0);
  }

#undef FORCE_PATH
};