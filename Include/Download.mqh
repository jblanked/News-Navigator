//+------------------------------------------------------------------+
//|                                                     Download.mqh |
//|                                          Copyright 2024,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict
// Import ShellExecuteW from shell32.dll for file operations
#import "shell32.dll"
int ShellExecuteW(int hWnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
int ShellExecuteA(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

// Import Wininet for downloading
#import "Wininet.dll"
int InternetOpenW(string name, int config, string, string, int);
int InternetOpenUrlW(int, string, string, int, int, int);
bool InternetReadFile(int, uchar &sBuffer[], int, int &OneInt);
bool InternetCloseHandle(int);
bool HttpSendRequestW(int hRequest, string lpszHeaders, int dwHeadersLength, char &lpOptional[], int dwOptionalLength);
#import

#import "kernel32.dll"
bool CopyFileW(string lpExistingFileName, string lpNewFileName, bool bFailIfExists);
#import


#define SW_HIDE             0    // hide command window

#include <Zip\Zip.mqh>  // include file to unzip files
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CDownload {

 public:
   // creates files with uchar content
   void              create(const string fileName, uchar & fileContent[]) {
      this.filehandle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_BIN | FILE_COMMON);
      FileWriteArray(this.filehandle, fileContent);
      FileClose(this.filehandle);
   }

   // path to the current common/files folder
   string            commonFilesFolder(void) {
      return TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\" + "Files" + "\\";
   }

   // downloads the file and saves to common folder
   bool              download(const string downloadLink, const string filenameToSave) {
      bytesRead = 0;
      headers = "Content-Type: application/json";
      // Initialize WinHTTP
      hInternet = InternetOpenW("MyApp", 1, NULL, NULL, 0);
      if(!hInternet) {
         Print("Failed to initialize WinHTTP");
         return false;
      } else {
         // Open a URL
         hUrl = InternetOpenUrlW(hInternet, downloadLink, NULL, 0, 0, 0);
         if(!hUrl) {
            Print("Failed to open " + downloadLink);
            return false;
         } else {
            // Send the request headers
            if(HttpSendRequestW(hUrl, headers, StringLen(headers), buffer, 0)) {
               // delete file if exists
               this.fileDelete(this.commonFilesFolder() + filenameToSave);
               Sleep(2000);
               fileHandle = FileOpen(filenameToSave, FILE_WRITE | FILE_BIN | FILE_COMMON); // Open the file in binary write mode
               if(fileHandle != INVALID_HANDLE) {
                  // Read the response and write directly to file
                  while(InternetReadFile(hUrl, buffer, ArraySize(buffer), bytesRead) && bytesRead > 0) {
                     FileWriteArray(fileHandle, buffer, 0, bytesRead); // Write the data to the file
                  }

                  FileClose(fileHandle); // Close the file
               } else {
                  Print("Error opening file for writing.");
                  return false;
               }
            }
            InternetCloseHandle(hUrl); // Close the request handle
         }
         InternetCloseHandle(hInternet); // Close the WinHTTP handle
      }
      return true;
   }

   // downloads a zip file, optionally extracts it, then saves it to the Experts folder
   bool              downloadAndExtract(const string downloadLink, const string filenameToSave, bool zipFile = true) {

      if(!this.download(downloadLink, filenameToSave)) {
         return false;
      }

      // Corrected definitions for paths
      eaNameLength = StringLen(MQLInfoString(MQL_PROGRAM_NAME)) + 4;
      fullpathLength = StringLen(MQLInfoString(MQL_PROGRAM_PATH));
      Expertsfolder = StringSubstr(MQLInfoString(MQL_PROGRAM_PATH), 0, (fullpathLength - eaNameLength));
      downloadedFileLocation = this.commonFilesFolder() + filenameToSave;
      targetFileLocation = Expertsfolder + "\\" +  filenameToSave;

      Sleep(2000); // maybe not needed

      if(!zipFile) {
         // Move the file experts folder
         this.fileMove(downloadedFileLocation, targetFileLocation);
         return true;
      }

      // unzip file
      Print("Unzipping " + downloadedFileLocation);
      if(!this.unzip(filenameToSave)) {
         ::Print("Failed to unzip " + downloadedFileLocation);
         return false;
      }
      Print("Unzipped!");
      Sleep(2000);

      for(int i = 0; i < ArraySize(this.fileNames); i++) {
         // Move the file to the Experts folder
         Print("Moving " + fileNames[i]);
         this.fileMove(this.commonFilesFolder() + fileNames[i], Expertsfolder + "\\" + fileNames[i]);
         Sleep(1000);
      }

      // delete the zip file
      Print("Deleting " + downloadedFileLocation);
      this.fileDelete(downloadedFileLocation);

      Sleep(2000);

#ifdef __MQL5__
      editedName = Expertsfolder + "\\" + StringSubstr(filenameToSave, 0, StringLen(filenameToSave) - 4) + ".ex4";
#else
      editedName = Expertsfolder + "\\" + StringSubstr(filenameToSave, 0, StringLen(filenameToSave) - 4) + ".ex5";
#endif
      // delete the ex4 file if in MT5, otherwise delete the ex5 file
      Print("Deleting " + editedName);
      this.fileDelete(editedName);

      ::Alert(filenameToSave + " successfully downloaded! Restart your terminal.");

      return true;

   }

   // delete files
   void              fileDelete(const string filePath) {
      // ShellExecuteW to call cmd.exe to delete the file
      deleteCmdParameters = "/C if exist \"" + filePath + "\" del \"" + filePath + "\"";

      // Execute the file delete command
      ShellExecuteW(0, "open", "cmd.exe", deleteCmdParameters, NULL, SW_HIDE);
   }

   void              fileDuplicate(const string filePath, const string newFilePath) {
      cmdParameters = "/C copy /Y \"" + filePath + "\" \"" + newFilePath + "\"";
      ShellExecuteW(0, "open", "cmd.exe", cmdParameters, NULL, SW_HIDE);
   }


   // move files
   void              fileMove(const string currentFilePath, const string destinationPathAndName) {
      // Move the file using ShellExecuteW to call cmd.exe with move command
      cmdParameters = "/C move \"" + currentFilePath + "\" \"" + destinationPathAndName + "\"";
      ShellExecuteW(0, "open", "cmd.exe", cmdParameters, NULL, SW_HIDE);
   }

   // rename files
   void              fileRename(const string currentFilePath, const string newNameOnly) {
      // Command to rename the file
      renameCommand = "/C rename \"" + currentFilePath + "\" \"" + newNameOnly + "\"";

      // Execute the renaming command
      ShellExecuteW(0, "open", "cmd.exe", renameCommand, NULL, SW_HIDE);
   }

   // meesage box/pop up alert
   bool              messageBox(const string message, const string title = "Alert") {
      return ::MessageBox(message, title, MB_YESNO | MB_ICONQUESTION) == 6 ? true : false;
   }

   // unzip file that in the common/files folder
   bool              unzip(const string filenameOnly) {
      // Load the ZIP file
      if(!::FileIsExist(filenameOnly, FILE_COMMON) || !Zip.LoadZipFromFile(filenameOnly, FILE_COMMON)) {
         ::Print("Failed to load " + this.commonFilesFolder() + filenameOnly);
         return false;
      }

      // unzip the file
      ArrayResize(this.fileNames, Zip.TotalElements());
      for(int i = 0; i < Zip.TotalElements(); i++) {
         uchar file_content[];                     // local var to hold file contents
         CZipFile* content = Zip.ElementAt(i);     // set CZipFileContent

         if(content == NULL) {
            ::Print("Failed to set ZipFileContent");
            return false;
         }

         content.GetUnpackFile(file_content);      // unzip file contents into array
         fileNames[i] = Zip.ElementAt(i).Name();   // name of file
         delete content;                           // delete pointer after use

         binName = fileNames[i] + ".bin";          // name of file + .bin extension (safely download ANY file type)

         this.create(binName, file_content);       // create file with file_content

         // delete the intended file if exists
         this.fileDelete(this.commonFilesFolder() + fileNames[i]);

         Sleep(1000); // wait one sec to ensure the file is deleted

         // Execute the renaming command from +.bin to regular file
         this.fileRename(this.commonFilesFolder() + binName, fileNames[i]);

         Sleep(1000); // wait one sec to ensure the file is renamed
      }

      return true;
   }

 private:
   string            commonDataPath;
   string            savePath;
   string            curlCommand, psCommand;
   int               result;
   string            cmdParameters;
   string            deleteCmdParameters;
   int               eaNameLength;
   int               fullpathLength;
   string            Expertsfolder;
   string            downloadedFileLocation;
   string            targetFileLocation;
   string            command;
   int               fileHandle, hInternet, hUrl, fileHand;
   int               bytesRead;
   string            headers;
   uchar             buffer[1024];
   int               filehandle;
   string            strCurrentFile;
   string            strNewName;
   string            renameCommand;
   string            binName;
   string            cname;
   string            editedName;
   string            fileNames[];
   CZip              Zip;

   void              createBatchFile(void) {
      ::Print("The create batch file is not working currently: ", __LINE__, __FILE__);

      const string batfile =
         "@echo off\n"
         "rem RestartTerminal.bat\n"
         "set /a initialCount=0\n"
         "for /f \"usebackq delims==\" %%F in (`tasklist ^| findstr \"terminal.exe\"`) do (\n"
         "    set/a initialCount+=1\n"
         ")\n"
         ":loop\n"
         "    ping -n 6 localhost >nul& rem Sleep 5 seconds\n"
         "    set /a newCount=0\n"
         "    for /f \"usebackq delims==\" %%F in (`tasklist ^| findstr \"terminal.exe\"`) do (\n"
         "        set/a newCount+=1\n"
         "    )\n"
         "    if %newCount% == %initialCount% goto loop\n"
         "start \"terminal\" \"%~dp0terminal.exe\"";

      if(::FileIsExist("RestartTerminal.txt", FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_TXT)) {
         ::FileDelete("RestartTerminal.txt", FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_TXT | FILE_IS_BINARY);
      }

      this.fileHand = FileOpen("RestartTerminal.txt", FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_TXT);
      if(this.fileHand == INVALID_HANDLE) {
         ::Print("file handle is invalid");
      } else {

         ::FileWriteString(this.fileHand, batfile);
         ::FileClose(this.fileHand);

         // Get the path to the common data directory
         commonDataPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\";

         if(!FileIsExist("RestartTerminal.txt", FILE_COMMON)) {
            Print("RestartTerminal.txt does not exist in ", commonDataPath);
            return;
         }

         // Command to rename the file

         // works
         // this.fileRename(commonDataPath + "RestartTerminal.txt", "newtest.txt");

         // doesnt work
         this.fileRename(commonDataPath + "RestartTerminal.txt", "RestartTerminal.bat");
      }

   }


   void              restartTerminal(void) {
      ::Print("The restarting terminal function is not working currently: ", __LINE__, __FILE__);
      // Execute the batch file

      // ShellExecuteW(NULL,"open","c:\\users\\route206\\desktop\\test.bat",NULL,NULL,1);
      //ShellExecuteW(0, "open", "/C " + TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\RestartTerminal.bat", "", "", 1);

      //ShellExecuteA(0, "open", "/C " + TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\RestartTerminal.bat", "", "", SW_HIDE);
      //ShellExecuteW(0, "open", "cmd.exe", "/C " + TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\RestartTerminal.bat", NULL, 0);
   }

};
//+------------------------------------------------------------------+
