unit CopilotExtension.LSPClient;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows;

type
  TCopilotLSPClient = class(TObject)
  private
    FProcessHandle: THandle;
    FStdInWrite: THandle;
    FStdOutRead: THandle;
    FStdInRead: THandle;
    FStdOutWrite: THandle;
    function WriteToStdin(const Data: string): Boolean;
    function ReadFromStdout: string;
    procedure StartNodeProcess;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    procedure Shutdown;
    procedure DidOpenDocument(const Uri, LanguageId, Text: string);
    procedure DidChangeDocument(const Uri, Text: string);
    procedure DidCloseDocument(const Uri: string);
    function SendMessage(const Msg: string): string;
  end;

implementation
constructor TCopilotLSPClient.Create;
begin
  inherited Create;
  FProcessHandle := 0;
  FStdInWrite := 0;
  FStdOutRead := 0;
  FStdInRead := 0;
  FStdOutWrite := 0;
  OutputDebugString('TCopilotLSPClient.Create: Starting Node.js process');
  StartNodeProcess;
  OutputDebugString('TCopilotLSPClient.Create: Node.js process started, waiting for server to be ready');
  Sleep(2000); // Wait 2 seconds for Node.js server startup
end;

destructor TCopilotLSPClient.Destroy;
begin
  OutputDebugString('TCopilotLSPClient.Destroy: Cleaning up Node.js process and handles');
  if FProcessHandle <> 0 then
  begin
    TerminateProcess(FProcessHandle, 0);
    OutputDebugString('TCopilotLSPClient.Destroy: Node.js process terminated');
  end;
  if FStdInWrite <> 0 then begin CloseHandle(FStdInWrite); OutputDebugString('TCopilotLSPClient.Destroy: Closed FStdInWrite'); end;
  if FStdOutRead <> 0 then begin CloseHandle(FStdOutRead); OutputDebugString('TCopilotLSPClient.Destroy: Closed FStdOutRead'); end;
  if FStdInRead <> 0 then begin CloseHandle(FStdInRead); OutputDebugString('TCopilotLSPClient.Destroy: Closed FStdInRead'); end;
  if FStdOutWrite <> 0 then begin CloseHandle(FStdOutWrite); OutputDebugString('TCopilotLSPClient.Destroy: Closed FStdOutWrite'); end;
  inherited Destroy;
end;
function TCopilotLSPClient.SendMessage(const Msg: string): string;
var
  Attempt: Integer;
begin
  Result := '';
  for Attempt := 1 to 3 do
  begin
    OutputDebugString(PChar('CopilotLSPClient.SendMessage: Sending to stdin: ' + Msg));
    if not WriteToStdin(Msg + #10) then
      Exit('');
    Result := ReadFromStdout;
    if Result <> '' then Exit;
    Sleep(500); // Wait before retry
  end;
  // If still empty after retries, return empty string
end;

procedure TCopilotLSPClient.DidOpenDocument(const Uri, LanguageId, Text: string);
begin
  // Stub implementation
end;

procedure TCopilotLSPClient.DidChangeDocument(const Uri, Text: string);
begin
  // Stub implementation
end;
procedure TCopilotLSPClient.StartNodeProcess;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Security: TSecurityAttributes;
  NodePath, ScriptPath, CmdLine: string;
  ExtensionDir: string;
var
  Success: Boolean;
begin
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  Security.lpSecurityDescriptor := nil;

  OutputDebugString('TCopilotLSPClient.StartNodeProcess: Creating stdin pipe');
  Success := CreatePipe(FStdInRead, FStdInWrite, @Security, 0);
  if not Success then
  begin
    OutputDebugString('TCopilotLSPClient.StartNodeProcess: Failed to create stdin pipe');
    raise Exception.Create('Failed to create stdin pipe');
  end;
  OutputDebugString('TCopilotLSPClient.StartNodeProcess: stdin pipe created');

  OutputDebugString('TCopilotLSPClient.StartNodeProcess: Creating stdout pipe');
  Success := CreatePipe(FStdOutRead, FStdOutWrite, @Security, 0);
  if not Success then
  begin
    OutputDebugString('TCopilotLSPClient.StartNodeProcess: Failed to create stdout pipe');
    raise Exception.Create('Failed to create stdout pipe');
  end;
  OutputDebugString('TCopilotLSPClient.StartNodeProcess: stdout pipe created');

  ExtensionDir := ExtractFilePath(GetModuleName(HInstance));
  NodePath := 'node';
  ScriptPath := ExtensionDir + 'copilot-language-server.js';
  CmdLine := Format('"%s" "%s"', [NodePath, ScriptPath]);
  OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: CmdLine = ' + CmdLine));
  OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: ExtensionDir = ' + ExtensionDir));
  OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: ScriptPath = ' + ScriptPath));

  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;
  StartupInfo.hStdInput := FStdInRead;
  StartupInfo.hStdOutput := FStdOutWrite;
  StartupInfo.hStdError := FStdOutWrite;

  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  Success := CreateProcess(nil, PChar(CmdLine), nil, nil, True, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo);
  if not Success then
  begin
    OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: Failed to start process.'));
    OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: GetLastError = ' + IntToStr(GetLastError())));
    raise Exception.Create('Failed to start copilot-language-server.js process: ' + CmdLine);
  end;
  OutputDebugString(PChar('TCopilotLSPClient.StartNodeProcess: Node.js process started, PID = ' + IntToStr(ProcessInfo.dwProcessId)));
  FProcessHandle := ProcessInfo.hProcess;
end;

procedure TCopilotLSPClient.Initialize;
begin
  // Initialization logic here
end;

procedure TCopilotLSPClient.Shutdown;
begin
  // Cleanup logic here
end;

function TCopilotLSPClient.WriteToStdin(const Data: string): Boolean;
var
  BytesWritten: DWORD;
  DataAnsi: AnsiString;
begin
  Result := False;
  if FStdInWrite = 0 then Exit;
  DataAnsi := AnsiString(Data);
  if not WriteFile(FStdInWrite, Pointer(DataAnsi)^, Length(DataAnsi), BytesWritten, nil) then
    Exit;
  Result := BytesWritten = Length(DataAnsi);
end;

function TCopilotLSPClient.ReadFromStdout: string;
var
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  S: string;
  StartTime: Cardinal;
  IsJSON: Boolean;
begin
  Result := '';
  if FStdOutRead = 0 then Exit;
  StartTime := GetTickCount;
  repeat
    S := '';
    if ReadFile(FStdOutRead, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) then
      SetString(S, Buffer, BytesRead);
    S := Trim(S);
    // Check if S looks like JSON (starts with '{' or '[')
    IsJSON := (S <> '') and ((S[1] = '{') or (S[1] = '['));
    if IsJSON then
    begin
      Result := S;
      Exit;
    end;
    // If not JSON, ignore and keep reading until timeout (5 seconds)
    if (GetTickCount - StartTime) > 5000 then
      Exit('');
    Sleep(100);
  until False;
end;

procedure TCopilotLSPClient.DidCloseDocument(const Uri: string);
var
  Msg: string;
begin
  Msg := '{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":"' + Uri + '"}}}';
  SendMessage(Msg);
end;

end.
