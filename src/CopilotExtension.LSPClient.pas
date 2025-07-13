unit CopilotExtension.LSPClient;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows;

type
  TCopilotLSPClient = class(TObject)
  private
    function WriteToStdin(const Data: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Initialize;
    procedure Shutdown;
    procedure DidOpenDocument(const Uri, LanguageId, Text: string);
    procedure DidChangeDocument(const Uri, Text: string);
    procedure DidCloseDocument(const Uri: string);
    procedure SendMessage(const Msg: string);
  end;

implementation

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

constructor TCopilotLSPClient.Create;
begin
  inherited Create;
end;

destructor TCopilotLSPClient.Destroy;
begin
  inherited Destroy;
end;

procedure TCopilotLSPClient.SendMessage(const Msg: string);
begin
  // Basic stub: send JSON-RPC message to copilot-language-server
  WriteToStdin(Msg);
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
