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
  StartNodeProcess;
end;

destructor TCopilotLSPClient.Destroy;
begin
  if FProcessHandle <> 0 then
    TerminateProcess(FProcessHandle, 0);
  if FStdInWrite <> 0 then CloseHandle(FStdInWrite);
  if FStdOutRead <> 0 then CloseHandle(FStdOutRead);
  if FStdInRead <> 0 then CloseHandle(FStdInRead);
  if FStdOutWrite <> 0 then CloseHandle(FStdOutWrite);
  inherited Destroy;
end;
procedure TCopilotLSPClient.StartNodeProcess;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Security: TSecurityAttributes;
  NodePath, ScriptPath, CmdLine: string;
  ExtensionDir: string;
begin
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  Security.lpSecurityDescriptor := nil;

  // Create pipes for stdin/stdout
  if not CreatePipe(FStdInRead, FStdInWrite, @Security, 0) then
    raise Exception.Create('Failed to create stdin pipe');
  if not CreatePipe(FStdOutRead, FStdOutWrite, @Security, 0) then
    raise Exception.Create('Failed to create stdout pipe');

  // Use the directory of the extension DLL, not the RAD Studio bin
  ExtensionDir := ExtractFilePath(GetModuleName(HInstance));
  NodePath := 'node';
  ScriptPath := ExtensionDir + 'copilot-language-server.js';
  CmdLine := Format('"%s" "%s"', [NodePath, ScriptPath]);

  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;
  StartupInfo.hStdInput := FStdInRead;
  StartupInfo.hStdOutput := FStdOutWrite;
  StartupInfo.hStdError := FStdOutWrite;

  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  if not CreateProcess(nil, PChar(CmdLine), nil, nil, True, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
    raise Exception.Create('Failed to start copilot-language-server.js process');

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
begin
  Result := '';
  if FStdOutRead = 0 then Exit;
  S := '';
  if ReadFile(FStdOutRead, Buffer, SizeOf(Buffer), BytesRead, nil) and (BytesRead > 0) then
    SetString(S, Buffer, BytesRead);
  Result := Trim(S);
end;

function TCopilotLSPClient.SendMessage(const Msg: string): string;
begin
  if not WriteToStdin(Msg + #10) then
    Exit('');
  Result := ReadFromStdout;
end;

procedure TCopilotLSPClient.DidOpenDocument(const Uri, LanguageId, Text: string);
var
  Msg: string;
begin
  Msg := '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"' + Uri + '","languageId":"' + LanguageId + '","version":1,"text":"' + Text + '"}}}';
  SendMessage(Msg);
end;

procedure TCopilotLSPClient.DidChangeDocument(const Uri, Text: string);
var
  Msg: string;
begin
  Msg := '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"' + Uri + '","version":2},"contentChanges":[{"text":"' + Text + '"}]}}';
  SendMessage(Msg);
end;

procedure TCopilotLSPClient.DidCloseDocument(const Uri: string);
var
  Msg: string;
begin
  Msg := '{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":"' + Uri + '"}}}';
  SendMessage(Msg);
end;

end.
  if not WriteToStdin(Msg + #10) then
    Exit('');
  Result := ReadFromStdout;
end;

function TCopilotLSPClient.WriteToStdin(const Data: string): Boolean;
begin
  // TODO: Implement writing to stdin pipe
  Result := True;
end;


procedure TCopilotLSPClient.Initialize;
var
  OutputDir, NodeModulesPath, PackagePath: string;
begin
  // Determine output directory (where DLL and JS are located)
  OutputDir := ExtractFilePath(ParamStr(0));
  NodeModulesPath := OutputDir + 'node_modules';
  PackagePath := NodeModulesPath + '\@githubnext\copilot-language-server';

  // Check if copilot-language-server package is installed
  if not DirectoryExists(PackagePath) then
  begin
    // Run npm install @githubnext/copilot-language-server in output dir
    WinExec(PAnsiChar('cmd /c npm install @githubnext/copilot-language-server'), SW_HIDE);
    // Optionally: Wait for install to complete (could poll for directory)
  end;
  // ...existing code...
end;

procedure TCopilotLSPClient.Shutdown;
begin
  // TODO: Implement cleanup
end;

end.
