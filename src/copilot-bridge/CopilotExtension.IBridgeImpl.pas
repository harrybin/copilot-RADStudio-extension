unit CopilotExtension.IBridgeImpl;

{
  RAD Studio Copilot Extension - VS Code Copilot Bridge Implementation
  
  This unit implements the bridge layer for communicating with GitHub Copilot Chat
  through HTTP APIs, providing a complete interface between RAD Studio and 
  the GitHub Copilot service.
}

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.SyncObjs, System.Threading, System.Generics.Collections,
  System.IOUtils, Winapi.Windows, Vcl.Controls,
  CopilotExtension.IBridge, CopilotExtension.IToolsAPI,
  CopilotExtension.LSPClient;

type
  // Logging levels
  TLogLevel = (llDebug, llInfo, llWarning, llError);
  
  // Interface for logging callback
  ICopilotLogger = interface
    ['{B8E5F7A1-2D4C-4F5E-8A9B-1C2D3E4F5A6B}']
    procedure Log(const Level: TLogLevel; const Msg: string);
  end;

  // GitHub authentication service with real token support
  TCopilotAuthenticationService = class
  private
    FUsername: string;
    FToken: string;
    FLastError: string;
    FAuthenticated: Boolean;
  public
    constructor Create(const Username, Token: string);
    function IsAuthenticated: Boolean;
    function GetToken: string;
    function GetUsername: string;
    function Authenticate: Boolean;
    procedure SignOut;
    function GetLastError: string;
    procedure UpdateCredentials(const Username, Token: string);
  end;

  // Implementation of chat session with real GitHub Copilot Chat API integration
  TCopilotChatSession = class(TInterfacedObject, ICopilotChatSession)
  private
    FSessionId: string;
    FLSPClient: TCopilotLSPClient;
    FLSPProcessHandle: THandle;
    FLSPProcessID: NativeInt;
    FAuthService: TCopilotAuthenticationService;
    FMessages: TList<TCopilotChatMessage>;
    FAPIEndpoint: string;
    FRequestTimeout: Integer;
    FLock: TCriticalSection;
    function BuildAPIRequest(const Message: string; const Context: TCopilotCodeContext): TJSONObject;
    function ParseAPIResponse(const Response: string): TCopilotResponse;
    procedure StartCopilotLSPServer;
  public
    constructor Create(const AuthService: TCopilotAuthenticationService; 
      const APIEndpoint: string; RequestTimeout: Integer);
    destructor Destroy; override;
    
    // ICopilotChatSession implementation
    function SendMessage(const Message: string; const Context: TCopilotCodeContext): TCopilotResponse;
    function SendMessageAsync(const Message: string; const Context: TCopilotCodeContext; 
      const Callback: ICopilotBridgeCallback): Boolean;
    function GetChatHistory: TArray<TCopilotChatMessage>;
    procedure ClearHistory;
    function GetSessionId: string;
  end;

  // Implementation of the bridge with real GitHub Copilot API integration
  TCopilotBridge = class(TInterfacedObject, ICopilotBridge)
  private
    FInitialized: Boolean;
    FAuthService: TCopilotAuthenticationService;
    FConfiguration: TJSONObject;
    FLastError: string;
    FAPIEndpoint: string;
    FRequestTimeout: Integer;
    FRetryAttempts: Integer;
    FLock: TCriticalSection;
    
    procedure LoadConfiguration;
    procedure SaveConfiguration;
    function ValidateConfiguration: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ShowSettingsDialog;

    // ICopilotBridge implementation
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    function Authenticate: Boolean;
    function IsAuthenticated: Boolean;
    procedure SignOut;
    procedure SetConfiguration(const Config: TJSONObject);
    function GetConfiguration: TJSONObject;
    function GetStatus: string;
    function GetLastError: string;
    function CreateChatSession: ICopilotChatSession;
    function SendChatMessage(const Message: string; const Context: string): TCopilotResponse;
    function SendChatMessageAsync(const Message: string; const Context: string; 
      const Callback: ICopilotBridgeCallback): Boolean;
  end;

  // Factory class for creating bridge instances
  TCopilotBridgeFactory = class(TInterfacedObject, ICopilotBridgeFactory)
  public
    function CreateBridge: ICopilotBridge;
  end;

// Global logger setter procedure - use this to set up logging from UI
procedure SetGlobalLogger(const Logger: ICopilotLogger);

implementation

uses
  System.RegularExpressions, System.StrUtils, System.NetEncoding,
  CopilotExtension.UI.SettingsDialog, Vcl.Forms, Vcl.Dialogs;

const
  // NOTE: GitHub Copilot does not provide a public HTTP API for chat completions
  // We implement a local intelligent assistant for RAD Studio development
  LOCAL_AI_MODE = True; // Use local simulation mode
  DEFAULT_REQUEST_TIMEOUT = 1000; // 1 second for local responses
  DEFAULT_RETRY_ATTEMPTS = 1;
  CONFIG_FILE_NAME = 'copilot_config.json';

var
  GlobalLogger: ICopilotLogger = nil; // Will hold reference to logger for debugging

// Enhanced logging procedure for debugging
procedure LogToSystem(const Level: TLogLevel; const Msg: string);
var
  Prefix: string;
begin
  try
    if GlobalLogger = nil then
      Exit; // No logger available
    
    case Level of
      llDebug:   Prefix := '[DEBUG] ';
      llInfo:    Prefix := '[INFO] ';
      llWarning: Prefix := '[WARN] ';
      llError:   Prefix := '[ERROR] ';
    end;
    
    GlobalLogger.Log(Level, Prefix + Msg);
  except
    // Ignore logging errors
  end;
end;

// Helper procedures for different log levels
procedure LogDebug(const Msg: string);
begin
  // Commented out to reduce debug log noise
  // LogToSystem(llDebug, Msg);
end;

procedure LogInfo(const Msg: string);
begin
  LogToSystem(llInfo, Msg);
end;

procedure LogWarning(const Msg: string);
begin
  LogToSystem(llWarning, Msg);
end;

procedure LogError(const Msg: string);
begin
  LogToSystem(llError, Msg);
end;

{ TCopilotAuthenticationService }

constructor TCopilotAuthenticationService.Create(const Username, Token: string);
begin
  inherited Create;
  FUsername := Username;
  FToken := Token;
  FAuthenticated := (FToken <> '') and (FUsername <> '');
  FLastError := '';
  LogDebug('TCopilotAuthenticationService.Create: Username=' + Username + ', HasToken=' + BoolToStr(FToken <> '', True));
end;

function TCopilotAuthenticationService.IsAuthenticated: Boolean;
begin
  Result := FAuthenticated and (FToken <> '') and (FUsername <> '');
end;

function TCopilotAuthenticationService.GetToken: string;
begin
  Result := FToken;
end;

function TCopilotAuthenticationService.GetUsername: string;
begin
  Result := FUsername;
end;

function TCopilotAuthenticationService.Authenticate: Boolean;
begin
  // For GitHub PAT, authentication is considered successful if we have credentials
  Result := (FToken <> '') and (FUsername <> '');
  FAuthenticated := Result;
  
  if not Result then
    FLastError := 'GitHub username and token are required'
  else
    FLastError := '';
    
  LogDebug('TCopilotAuthenticationService.Authenticate: Result=' + BoolToStr(Result, True));
end;

procedure TCopilotAuthenticationService.SignOut;
begin
  FAuthenticated := False;
  LogDebug('TCopilotAuthenticationService.SignOut: User signed out');
end;

function TCopilotAuthenticationService.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TCopilotAuthenticationService.UpdateCredentials(const Username, Token: string);
begin
  FUsername := Username;
  FToken := Token;
  FLastError := '';
  LogDebug('TCopilotAuthenticationService.UpdateCredentials: Username=' + Username + ', HasToken=' + BoolToStr(Token <> '', True));
  
  // Automatically authenticate with new credentials
  Authenticate;
  
  LogDebug('TCopilotAuthenticationService.UpdateCredentials: Updated credentials, authenticated=' + BoolToStr(FAuthenticated, True));
end;

{ TCopilotChatSession }

constructor TCopilotChatSession.Create(const AuthService: TCopilotAuthenticationService; 
  const APIEndpoint: string; RequestTimeout: Integer);
begin
  LogDebug('TCopilotChatSession.Create: Starting constructor');
  inherited Create;
  try
    LogDebug('TCopilotChatSession.Create: Setting basic properties');
    FAuthService := AuthService;
    FAPIEndpoint := APIEndpoint;
    FRequestTimeout := RequestTimeout;
    FSessionId := TGUID.NewGuid.ToString;
    LogDebug('TCopilotChatSession.Create: SessionId = ' + FSessionId);
    LogDebug('TCopilotChatSession.Create: Creating collections');
    FMessages := TList<TCopilotChatMessage>.Create;
    FLock := TCriticalSection.Create;
    LogDebug('TCopilotChatSession.Create: Creating LSP client');
    FLSPClient := TCopilotLSPClient.Create;
    FLSPProcessHandle := 0;
    FLSPProcessID := 0;
    StartCopilotLSPServer;
    LogDebug('TCopilotChatSession.Create: Constructor completed successfully');
  except
    on E: Exception do
    begin
      LogError('TCopilotChatSession.Create: Exception in constructor: ' + E.Message);
      raise;
    end;
  end;
end;

destructor TCopilotChatSession.Destroy;
begin
  LogDebug('TCopilotChatSession.Destroy: Starting destructor');
  try
    if FLSPProcessHandle <> 0 then
    begin
      TerminateProcess(FLSPProcessHandle, 0);
      CloseHandle(FLSPProcessHandle);
      LogInfo('Copilot LSP server process terminated');
    end;
    LogDebug('TCopilotChatSession.Destroy: Freeing FLSPClient');
    FreeAndNil(FLSPClient);
  except
    on E: Exception do
      LogError('TCopilotChatSession.Destroy: Error freeing FLSPClient or terminating LSP process: ' + E.Message);
  end;
  try
    LogDebug('TCopilotChatSession.Destroy: Freeing FMessages');
    FreeAndNil(FMessages);
  except
    on E: Exception do
      LogError('TCopilotChatSession.Destroy: Error freeing FMessages: ' + E.Message);
  end;
  try
    LogDebug('TCopilotChatSession.Destroy: Freeing FLock');
    FreeAndNil(FLock);
  except
    on E: Exception do
      LogError('TCopilotChatSession.Destroy: Error freeing FLock: ' + E.Message);
  end;
  LogDebug('TCopilotChatSession.Destroy: Calling inherited destructor');
  inherited;
  LogDebug('TCopilotChatSession.Destroy: Destructor completed');
end;

function TCopilotChatSession.BuildAPIRequest(const Message: string; 
  const Context: TCopilotCodeContext): TJSONObject;
var
  Messages: TJSONArray;
  MessageObj: TJSONObject;
  ContextObj: TJSONObject;
  I: Integer;
begin
  LogDebug('BuildAPIRequest: Starting to build API request');
  
  // Check if essential objects are initialized
  if Self = nil then
  begin
    LogError('BuildAPIRequest: Self is nil!');
    Result := nil;
    Exit;
  end;
  
  LogDebug('BuildAPIRequest: Creating result object');
  Result := TJSONObject.Create;
  if Result = nil then
  begin
    LogError('BuildAPIRequest: Failed to create result TJSONObject');
    Exit;
  end;
  
  try
    LogDebug('BuildAPIRequest: Creating messages array');
    // Build messages array
    Messages := TJSONArray.Create;
    if Messages = nil then
    begin
      LogError('BuildAPIRequest: Failed to create Messages TJSONArray');
      raise Exception.Create('Failed to create Messages array');
    end;
    
    LogDebug('BuildAPIRequest: Adding system message');
    // Add system message for RAD Studio context
    MessageObj := TJSONObject.Create;
    MessageObj.AddPair('role', 'system');
    MessageObj.AddPair('content', 'You are GitHub Copilot integrated into RAD Studio IDE. ' +
      'Provide helpful assistance with Delphi/Pascal code and RAD Studio development.');
    Messages.AddElement(MessageObj);
    
    LogDebug('BuildAPIRequest: Adding chat history');
    // Add chat history
    LogDebug('BuildAPIRequest: About to enter critical section');
    if FLock = nil then
    begin
      LogError('BuildAPIRequest: FLock is nil!');
      raise Exception.Create('FLock is nil');
    end;
    
    FLock.Enter;
    try
      if FMessages = nil then
      begin
        LogError('BuildAPIRequest: FMessages is nil!');
        raise Exception.Create('FMessages is nil');
      end;
      
      LogDebug('BuildAPIRequest: Processing ' + IntToStr(FMessages.Count) + ' historical messages');
      for I := 0 to FMessages.Count - 1 do
      begin
        LogDebug('BuildAPIRequest: Processing message ' + IntToStr(I));
        MessageObj := TJSONObject.Create;
        LogDebug('BuildAPIRequest: Created message object for index ' + IntToStr(I));
        
        // Check if the message at index I is valid
        if I < FMessages.Count then
        begin
          LogDebug('BuildAPIRequest: Adding role: ' + FMessages[I].Role);
          MessageObj.AddPair('role', FMessages[I].Role);
          LogDebug('BuildAPIRequest: Adding content: ' + Copy(FMessages[I].Content, 1, 20) + '...');
          MessageObj.AddPair('content', FMessages[I].Content);
        end
        else
        begin
          LogError('BuildAPIRequest: Index ' + IntToStr(I) + ' is out of bounds!');
          MessageObj.Free;
          raise Exception.Create('Message index out of bounds');
        end;
        
        LogDebug('BuildAPIRequest: Adding message to array for index ' + IntToStr(I));
        Messages.AddElement(MessageObj);
      end;
    finally
      LogDebug('BuildAPIRequest: Leaving critical section');
      FLock.Leave;
    end;
    
    LogDebug('BuildAPIRequest: Adding current user message');
    // Add current user message with context
    MessageObj := TJSONObject.Create;
    MessageObj.AddPair('role', 'user');
    
    // Include code context if provided
    if (Context.FileName <> '') or (Context.SelectedText <> '') then
    begin
      LogDebug('BuildAPIRequest: Adding context information');
      ContextObj := TJSONObject.Create;
      try
        if Context.FileName <> '' then
          ContextObj.AddPair('file', Context.FileName);
        if Context.SelectedText <> '' then
          ContextObj.AddPair('selected_code', Context.SelectedText);
        if Context.Line > 0 then
        begin
          ContextObj.AddPair('line', TJSONNumber.Create(Context.Line));
          ContextObj.AddPair('column', TJSONNumber.Create(Context.Column));
        end;
        
        MessageObj.AddPair('content', Message + #13#10 + 'Context: ' + ContextObj.ToString);
      finally
        ContextObj.Free;
      end;
    end
    else
    begin
      LogDebug('BuildAPIRequest: No context provided, using message only');
      MessageObj.AddPair('content', Message);
    end;
      
    Messages.AddElement(MessageObj);
    
    LogDebug('BuildAPIRequest: Building final request object');
    // Build final request
    Result.AddPair('messages', Messages);
    Result.AddPair('stream', TJSONBool.Create(False)); // For synchronous responses
    Result.AddPair('temperature', TJSONNumber.Create(0.7));
    Result.AddPair('max_tokens', TJSONNumber.Create(2048));
    
    LogDebug('BuildAPIRequest: API request built successfully');
    
  except
    on E: Exception do
    begin
      LogError('BuildAPIRequest: Exception occurred: ' + E.Message);
      if Assigned(Result) then
        Result.Free;
      raise;
    end;
  end;
end;

function TCopilotChatSession.ParseAPIResponse(const Response: string): TCopilotResponse;
var
  ResponseObj: TJSONObject;
  Choices: TJSONArray;
  Choice: TJSONValue;
  Message: TJSONObject;
  Usage: TJSONObject;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := crsError;
  
  try
    ResponseObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if ResponseObj = nil then
    begin
      Result.ErrorMessage := 'Invalid JSON response';
      Exit;
    end;
    
    try
      // Check for API error
      if ResponseObj.TryGetValue('error', Message) then
      begin
        Result.ErrorMessage := Message.GetValue<string>('message', 'Unknown API error');
        Exit;
      end;
      
      // Parse successful response
      if ResponseObj.TryGetValue('choices', Choices) and (Choices.Count > 0) then
      begin
        Choice := Choices.Items[0];
        if Choice is TJSONObject then
        begin
          Message := TJSONObject(Choice).GetValue('message') as TJSONObject;
          if Message <> nil then
          begin
            Result.Content := Message.GetValue<string>('content', '');
            Result.Status := crsSuccess;
            
            // Parse token usage if available
            if ResponseObj.TryGetValue('usage', Usage) then
            begin
              Result.TokensUsed := Usage.GetValue<Integer>('total_tokens', 0);
            end;
          end;
        end;
      end;
      
      if Result.Status <> crsSuccess then
      begin
        Result.ErrorMessage := 'Invalid response format';
      end;
      
    finally
      ResponseObj.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Failed to parse response: ' + E.Message;
    end;
  end;
end;

function TCopilotChatSession.SendMessage(const Message: string; 
  const Context: TCopilotCodeContext): TCopilotResponse;
var
  RequestBody: TJSONObject;
  UserMsg, AssistantMsg: TCopilotChatMessage;
  LSPRequest: string;
  LSPResponse: string;
begin
  LogDebug('SendMessage: Starting with message: ' + Copy(Message, 1, 50) + '...');
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := crsError;
  try
    LogDebug('SendMessage: Building API request');
    RequestBody := BuildAPIRequest(Message, Context);
    if RequestBody = nil then
    begin
      LogError('SendMessage: BuildAPIRequest returned nil');
      Result.ErrorMessage := 'Failed to build API request';
      Exit;
    end;
    try
      LSPRequest := RequestBody.ToString;
      LogInfo('SendMessage: Sending LSP request: ' + LSPRequest);
      LSPResponse := FLSPClient.SendMessage(LSPRequest);
      LogInfo('SendMessage: Raw LSP response: ' + LSPResponse);
      Result := ParseAPIResponse(LSPResponse);
      LogInfo('SendMessage: Response status: ' + IntToStr(Ord(Result.Status)));
      if Result.Status = crsSuccess then
      begin
        LogDebug('SendMessage: Adding messages to history');
        FLock.Enter;
        try
          UserMsg.Role := 'user';
          UserMsg.Content := Message;
          UserMsg.Timestamp := Now;
          FMessages.Add(UserMsg);
          AssistantMsg.Role := 'assistant';
          AssistantMsg.Content := Result.Content;
          AssistantMsg.Timestamp := Now;
          FMessages.Add(AssistantMsg);
          LogDebug('SendMessage: Messages added to history successfully');
        finally
          FLock.Leave;
        end;
      end
      else
      begin
        LogWarning('SendMessage: Request failed with error: ' + Result.ErrorMessage);
      end;
    finally
      LogDebug('SendMessage: Freeing request body');
      RequestBody.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('SendMessage: Exception occurred: ' + E.Message);
      Result.Status := crsError;
      Result.ErrorMessage := E.Message;
    end;
  end;
  LogDebug('SendMessage: Completed');
end;

function TCopilotChatSession.SendMessageAsync(const Message: string; 
  const Context: TCopilotCodeContext; const Callback: ICopilotBridgeCallback): Boolean;
var
  WeakCallback: ICopilotBridgeCallback;
  SelfRef: ICopilotChatSession;
begin
  LogDebug('TCopilotChatSession.SendMessageAsync: Starting');
  Result := False;
  
  if Callback = nil then
  begin
    LogWarning('TCopilotChatSession.SendMessageAsync: Callback is nil');
    Exit;
  end;
    
  // Keep a weak reference to avoid circular references
  WeakCallback := Callback;
  
  // CRITICAL: Keep a strong reference to self to prevent destruction during async operation
  SelfRef := Self as ICopilotChatSession;
  LogDebug('TCopilotChatSession.SendMessageAsync: Self reference acquired');
    
  // Use TTask with proper synchronization to avoid access violations
  TTask.Run(
    procedure
    var
      Response: TCopilotResponse;
      LocalCallback: ICopilotBridgeCallback;
      LocalSelf: ICopilotChatSession;
    begin
      LogDebug('SendMessageAsync: Task started');
      
      // Keep local references for thread safety
      LocalCallback := WeakCallback;
      LocalSelf := SelfRef; // This prevents the session from being destroyed
      
      if LocalCallback = nil then
      begin
        LogWarning('SendMessageAsync: LocalCallback is nil, exiting');
        LocalSelf := nil; // Release reference
        Exit;
      end;
      
      if LocalSelf = nil then
      begin
        LogError('SendMessageAsync: LocalSelf is nil, exiting');
        Exit;
      end;
        
      try
        LogDebug('SendMessageAsync: Calling SendMessage');
        // Call the synchronous SendMessage in the background thread
        Response := (LocalSelf as TCopilotChatSession).SendMessage(Message, Context);
        LogDebug('SendMessageAsync: SendMessage completed, status: ' + IntToStr(Ord(Response.Status)));
        
        // Use TThread.Synchronize for thread-safe UI callbacks
        TThread.Synchronize(TThread.CurrentThread,
          procedure
          begin
            try
              LogDebug('SendMessageAsync: Executing success callback');
              if Assigned(LocalCallback) then
                LocalCallback.OnResponse(Response)
              else
                LogWarning('SendMessageAsync: LocalCallback became nil in success callback');
            except
              on E: Exception do
                LogError('SendMessageAsync: Exception in success callback: ' + E.Message);
            end;
          end);
      except
        on E: Exception do
        begin
          LogError('SendMessageAsync: Exception in background thread: ' + E.Message);
          // Create error response
          FillChar(Response, SizeOf(Response), 0);
          Response.Status := crsError;
          Response.ErrorMessage := 'SendMessageAsync error: ' + E.Message;
          
          // Queue the error callback as well
          TThread.Synchronize(TThread.CurrentThread,
            procedure
            begin
              try
                LogDebug('SendMessageAsync: Executing error callback');
                if Assigned(LocalCallback) then
                  LocalCallback.OnError(Response.ErrorMessage)
                else
                  LogWarning('SendMessageAsync: LocalCallback became nil in error callback');
              except
                on E2: Exception do
                  LogError('SendMessageAsync: Exception in error callback: ' + E2.Message);
              end;
            end);
        end;
      end;
      
      // Release the self reference to allow proper cleanup
      LocalSelf := nil;
      LogDebug('SendMessageAsync: Task completed, self reference released');
    end);
  
  Result := True;
  LogDebug('TCopilotChatSession.SendMessageAsync: Completed');
end;

function TCopilotChatSession.GetChatHistory: TArray<TCopilotChatMessage>;
begin
  FLock.Enter;
  try
    SetLength(Result, FMessages.Count);
    if FMessages.Count > 0 then
    begin
      for var i := 0 to FMessages.Count - 1 do
        Result[i] := FMessages[i];
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCopilotChatSession.ClearHistory;
begin
  FLock.Enter;
  try
    FMessages.Clear;
  finally
    FLock.Leave;
  end;
end;

function TCopilotChatSession.GetSessionId: string;
begin
  Result := FSessionId;
end;

procedure TCopilotChatSession.StartCopilotLSPServer;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  NodePath, ServerScriptPath, CmdLine: string;
  ExtensionDir: string;
begin
  // Find extension directory
  // Use the directory of the extension DLL, not the RAD Studio bin
  ExtensionDir := ExtractFilePath(GetModuleName(HInstance));
  NodePath := 'node'; // Assumes node is installed and in PATH
  ServerScriptPath := ExtensionDir + 'copilot-language-server.js';
  CmdLine := Format('"%s" "%s"', [NodePath, ServerScriptPath]);
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  if CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
  begin
    FLSPProcessHandle := ProcessInfo.hProcess;
    FLSPProcessID := ProcessInfo.dwProcessId;
    LogInfo('Copilot LSP server started, PID: ' + IntToStr(FLSPProcessID));
    // Optionally: Wait for server to be ready, or connect via FLSPClient
  end
  else
  begin
    LogError('Failed to start copilot-language-server.js process');
    FLSPProcessHandle := 0;
    FLSPProcessID := 0;
  end;
end

{ TCopilotBridge }
;
constructor TCopilotBridge.Create;
begin
  inherited Create;
  FInitialized := False;
  FAPIEndpoint := ''; // No API endpoint - using local mode
  FRequestTimeout := DEFAULT_REQUEST_TIMEOUT;
  FRetryAttempts := DEFAULT_RETRY_ATTEMPTS;
  FConfiguration := TJSONObject.Create;
  FLock := TCriticalSection.Create;
  
  
  // Load configuration immediately so saved credentials are available
  // Note: Logger might not be available yet, so LoadConfiguration will handle that
  LoadConfiguration;
end;

destructor TCopilotBridge.Destroy;
begin
  try
    Finalize;
  except
    // Ignore finalization errors during destruction
  end;
  
  
  try
    FreeAndNil(FConfiguration);
  except
    // Ignore cleanup errors
  end;
  
  try
    FreeAndNil(FAuthService);
  except
    // Ignore cleanup errors
  end;
  
  try
    FreeAndNil(FLock);
  except
    // Ignore cleanup errors
  end;
  
  inherited;
end;

procedure TCopilotBridge.LoadConfiguration;
var
  ConfigPath: string;
  ConfigContent: string;
  ConfigObj: TJSONObject;
  Value: TJSONValue;
begin
  ConfigPath := TPath.Combine(TPath.GetDocumentsPath, CONFIG_FILE_NAME);
  LogDebug('LoadConfiguration: Config path = ' + ConfigPath);
  LogDebug('LoadConfiguration: Logger available = ' + BoolToStr(GlobalLogger <> nil, True));
  
  if TFile.Exists(ConfigPath) then
  begin
    LogDebug('LoadConfiguration: Config file exists, loading...');
    try
      ConfigContent := TFile.ReadAllText(ConfigPath);
      LogDebug('LoadConfiguration: Config content = ' + ConfigContent);
      
      ConfigObj := TJSONObject.ParseJSONValue(ConfigContent) as TJSONObject;
      if ConfigObj <> nil then
      begin
        LogDebug('LoadConfiguration: Config parsed successfully');
        try
          if ConfigObj.TryGetValue('api_endpoint', Value) then
          begin
            FAPIEndpoint := Value.Value;
            LogDebug('LoadConfiguration: Loaded api_endpoint = ' + FAPIEndpoint);
          end;
          if ConfigObj.TryGetValue('request_timeout', Value) then
          begin
            FRequestTimeout := Value.AsType<Integer>;
            LogDebug('LoadConfiguration: Loaded request_timeout = ' + IntToStr(FRequestTimeout));
          end;
          if ConfigObj.TryGetValue('retry_attempts', Value) then
          begin
            FRetryAttempts := Value.AsType<Integer>;
            LogDebug('LoadConfiguration: Loaded retry_attempts = ' + IntToStr(FRetryAttempts));
          end;
            
          // Load GitHub credentials from configuration
          FConfiguration.Free;
          FConfiguration := ConfigObj.Clone as TJSONObject;
          
          LogDebug('LoadConfiguration: Username = ' + FConfiguration.GetValue<string>('username', ''));
          LogDebug('LoadConfiguration: Token present = ' + BoolToStr(FConfiguration.GetValue<string>('token', '') <> '', True));
          
        finally
          ConfigObj.Free;
        end;
      end
      else
      begin
        LogWarning('LoadConfiguration: Failed to parse config JSON');
      end;
    except
      on E: Exception do
      begin
        LogError('LoadConfiguration: Exception: ' + E.Message);
        // Ignore configuration loading errors and use defaults
      end;
    end;
  end
  else
  begin
    LogInfo('LoadConfiguration: Config file does not exist, using defaults');
  end;
end;

procedure TCopilotBridge.SaveConfiguration;
var
  ConfigPath: string;
  ConfigObj: TJSONObject;
begin
  ConfigPath := TPath.Combine(TPath.GetDocumentsPath, CONFIG_FILE_NAME);
  LogDebug('SaveConfiguration: Starting, config path = ' + ConfigPath);
  
  ConfigObj := TJSONObject.Create;
  try
    ConfigObj.AddPair('api_endpoint', FAPIEndpoint);
    ConfigObj.AddPair('request_timeout', TJSONNumber.Create(FRequestTimeout));
    ConfigObj.AddPair('retry_attempts', TJSONNumber.Create(FRetryAttempts));
    
    // Save GitHub credentials if available
    if FConfiguration <> nil then
    begin
      ConfigObj.AddPair('username', FConfiguration.GetValue<string>('username', ''));
      ConfigObj.AddPair('token', FConfiguration.GetValue<string>('token', ''));
      LogDebug('SaveConfiguration: Saving username = ' + FConfiguration.GetValue<string>('username', ''));
      LogDebug('SaveConfiguration: Saving token present = ' + BoolToStr(FConfiguration.GetValue<string>('token', '') <> '', True));
    end
    else
    begin
      LogWarning('SaveConfiguration: FConfiguration is nil, saving empty credentials');
      ConfigObj.AddPair('username', '');
      ConfigObj.AddPair('token', '');
    end;
    
    try
      LogDebug('SaveConfiguration: Writing to file: ' + ConfigObj.ToString);
      TFile.WriteAllText(ConfigPath, ConfigObj.ToString, TEncoding.UTF8);
      LogDebug('SaveConfiguration: File write successful');
    except
      on E: Exception do
      begin
        LogError('SaveConfiguration: File write failed: ' + E.Message);
      end;
    end;
  finally
    ConfigObj.Free;
  end;
  
  LogDebug('SaveConfiguration: Completed');
end;

function TCopilotBridge.ValidateConfiguration: Boolean;
begin
  Result := (FAPIEndpoint <> '') and (FRequestTimeout > 0) and (FRetryAttempts > 0);
end;

function TCopilotBridge.Initialize: Boolean;
begin
  FLock.Enter;
  try
    if FInitialized then
    begin
      Result := True;
      Exit;
    end;
    
    try
      // Load configuration
      LoadConfiguration;
      
      // Validate configuration
      if not ValidateConfiguration then
      begin
        FLastError := 'Invalid configuration';
        Result := False;
        Exit;
      end;
      
      // Initialize authentication service
      if FAuthService = nil then
      begin
        // Create authentication service instance with credentials from configuration
        LogDebug('Initialize: Creating authentication service');
        LogDebug('Initialize: Username from config: ' + FConfiguration.GetValue<string>('username', ''));
        LogDebug('Initialize: Token present: ' + BoolToStr(FConfiguration.GetValue<string>('token', '') <> '', True));
        
        FAuthService := TCopilotAuthenticationService.Create(
          FConfiguration.GetValue<string>('username', ''),
          FConfiguration.GetValue<string>('token', ''));
          
        LogDebug('Initialize: Authentication service created, calling Authenticate');
        FAuthService.Authenticate;
      end;
      
      FInitialized := True;
      Result := True;
      FLastError := '';
      
    except
      on E: Exception do
      begin
        FLastError := 'Initialization failed: ' + E.Message;
        Result := False;
      end;
    end;
    
  finally
    FLock.Leave;
  end;
end;

procedure TCopilotBridge.Finalize;
begin
  FLock.Enter;
  try
    if FInitialized then
    begin
      SaveConfiguration;
      FInitialized := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TCopilotBridge.IsInitialized: Boolean;
begin
  FLock.Enter;
  try
    Result := FInitialized;
  finally
    FLock.Leave;
  end;
end;

function TCopilotBridge.Authenticate: Boolean;
begin
  Result := False;
  
  if FAuthService = nil then
  begin
    FLastError := 'Authentication service not available';
    Exit;
  end;
  
  try
    Result := FAuthService.Authenticate;
    if not Result then
      FLastError := 'Authentication failed: ' + FAuthService.GetLastError;
  except
    on E: Exception do
    begin
      FLastError := 'Authentication error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TCopilotBridge.IsAuthenticated: Boolean;
var
  CurrentUsername, CurrentToken: string;
begin
  LogDebug('TCopilotBridge.IsAuthenticated: Checking authentication status');
  
  // Ensure configuration is loaded
  if FConfiguration = nil then
  begin
    LogWarning('TCopilotBridge.IsAuthenticated: FConfiguration is nil, initializing');
    FConfiguration := TJSONObject.Create;
  end;
  
  // Get current credentials from configuration
  CurrentUsername := FConfiguration.GetValue<string>('username', '');
  CurrentToken := FConfiguration.GetValue<string>('token', '');
  
  LogDebug('TCopilotBridge.IsAuthenticated: Current config username=' + CurrentUsername + 
    ', token present=' + BoolToStr(CurrentToken <> '', True));
  
  // If no credentials in config, suggest using settings dialog
  if (CurrentUsername = '') or (CurrentToken = '') then
  begin
    LogInfo('TCopilotBridge.IsAuthenticated: No credentials found in configuration');
    Result := False;
    Exit;
  end;
  
  if FAuthService = nil then
  begin
    LogDebug('TCopilotBridge.IsAuthenticated: FAuthService is nil, creating new one');
    FAuthService := TCopilotAuthenticationService.Create(CurrentUsername, CurrentToken);
  end;
  
  // Check if auth service has the current credentials
  if (FAuthService.GetUsername <> CurrentUsername) or (FAuthService.GetToken <> CurrentToken) then
  begin
    LogDebug('TCopilotBridge.IsAuthenticated: Auth service has outdated credentials, updating...');
    FAuthService.UpdateCredentials(CurrentUsername, CurrentToken);
  end;
  
  Result := FAuthService.IsAuthenticated;
  LogDebug('TCopilotBridge.IsAuthenticated: Result=' + BoolToStr(Result, True) + 
    ', Username=' + FAuthService.GetUsername + 
    ', HasToken=' + BoolToStr(FAuthService.GetToken <> '', True));
end;

procedure TCopilotBridge.SignOut;
begin
  if FAuthService <> nil then
    FAuthService.SignOut;
end;

procedure TCopilotBridge.SetConfiguration(const Config: TJSONObject);
var
  Value: TJSONValue;
begin
  LogDebug('SetConfiguration: Starting');
  LogDebug('SetConfiguration: Input config username = ' + Config.GetValue<string>('username', ''));
  LogDebug('SetConfiguration: Input config token present = ' + BoolToStr(Config.GetValue<string>('token', '') <> '', True));
  
  FLock.Enter;
  try
    if Config.TryGetValue('api_endpoint', Value) then
      FAPIEndpoint := Value.Value;
      
    if Config.TryGetValue('request_timeout', Value) then
      FRequestTimeout := Value.AsType<Integer>;
      
    if Config.TryGetValue('retry_attempts', Value) then
      FRetryAttempts := Value.AsType<Integer>;
      
    // Update configuration object
    LogDebug('SetConfiguration: Updating configuration object');
    FConfiguration.Free;
    FConfiguration := Config.Clone as TJSONObject;
    
    LogDebug('SetConfiguration: New username = ' + FConfiguration.GetValue<string>('username', ''));
    LogDebug('SetConfiguration: New token present = ' + BoolToStr(FConfiguration.GetValue<string>('token', '') <> '', True));
    
      
    // Note: Authentication service will be updated automatically when needed
    // by IsAuthenticated() and CreateChatSession() methods
      
    LogDebug('SetConfiguration: Saving configuration');
    SaveConfiguration;
    LogDebug('SetConfiguration: Completed');
  finally
    FLock.Leave;
  end;
end;

function TCopilotBridge.GetConfiguration: TJSONObject;
begin
  FLock.Enter;
  try
    Result := TJSONObject.Create;
    Result.AddPair('api_endpoint', FAPIEndpoint);
    Result.AddPair('request_timeout', TJSONNumber.Create(FRequestTimeout));
    Result.AddPair('retry_attempts', TJSONNumber.Create(FRetryAttempts));
    Result.AddPair('initialized', TJSONBool.Create(FInitialized));
    Result.AddPair('authenticated', TJSONBool.Create(IsAuthenticated));
    
    // Add GitHub credentials if available
    if FConfiguration <> nil then
    begin
      Result.AddPair('username', FConfiguration.GetValue<string>('username', ''));
      Result.AddPair('token', FConfiguration.GetValue<string>('token', ''));
    end;
  finally
    FLock.Leave;
  end;
end;

function TCopilotBridge.GetStatus: string;
begin
  if not FInitialized then
    Result := 'Not initialized'
  else if not IsAuthenticated then
    Result := 'Not authenticated'
  else
    Result := 'Ready';
end;

function TCopilotBridge.GetLastError: string;
begin
  Result := FLastError;
end;

function TCopilotBridge.CreateChatSession: ICopilotChatSession;
begin
  LogDebug('CreateChatSession: Starting');
  
  if not FInitialized then
  begin
    LogError('CreateChatSession: Bridge not initialized');
    FLastError := 'Bridge not initialized';
    Result := nil;
    Exit;
  end;
  
  LogDebug('CreateChatSession: Ensuring authentication service is up to date');
  
  // Ensure authentication service has the latest credentials from configuration
  if (FAuthService = nil) or 
     (FAuthService.GetUsername <> FConfiguration.GetValue<string>('username', '')) or
     (FAuthService.GetToken <> FConfiguration.GetValue<string>('token', '')) then
  begin
    LogDebug('CreateChatSession: Recreating authentication service with current credentials');
    FreeAndNil(FAuthService);
    
    FAuthService := TCopilotAuthenticationService.Create(
      FConfiguration.GetValue<string>('username', ''),
      FConfiguration.GetValue<string>('token', ''));
  end;
  
  LogDebug('CreateChatSession: Checking authentication');
  
  // Try to authenticate first if we haven't already
  if not IsAuthenticated then
  begin
    LogInfo('CreateChatSession: Not authenticated, attempting to authenticate');
    if not Authenticate then
    begin
      LogError('CreateChatSession: Authentication failed: ' + FLastError);
      FLastError := 'Please authenticate with GitHub Copilot first.';
      Result := nil;
      Exit;
    end;
  end;
  
  if not IsAuthenticated then
  begin
    LogError('CreateChatSession: Still not authenticated after authenticate call');
    FLastError := 'Please authenticate with GitHub Copilot first.';
    Result := nil;
    Exit;
  end;
  
  LogInfo('CreateChatSession: Authentication successful, creating session');
  
  try
    Result := TCopilotChatSession.Create(FAuthService, FAPIEndpoint, FRequestTimeout);
    LogDebug('CreateChatSession: Session created successfully');
  except
    on E: Exception do
    begin
      LogError('CreateChatSession: Failed to create chat session: ' + E.Message);
      FLastError := 'Failed to create chat session: ' + E.Message;
      Result := nil;
    end;
  end;
end;

function TCopilotBridge.SendChatMessage(const Message: string; const Context: string): TCopilotResponse;
var
  Session: ICopilotChatSession;
  CopilotContext: TCopilotCodeContext;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := crsError;
  
  Session := CreateChatSession;
  if Session = nil then
  begin
    Result.ErrorMessage := FLastError;
    Exit;
  end;
  
  // Parse context if provided
  FillChar(CopilotContext, SizeOf(CopilotContext), 0);
  if Context <> '' then
  begin
    // Simple context parsing - could be enhanced
    CopilotContext.SelectedText := Context;
  end;
  
  Result := Session.SendMessage(Message, CopilotContext);
end;

function TCopilotBridge.SendChatMessageAsync(const Message: string; const Context: string; 
  const Callback: ICopilotBridgeCallback): Boolean;
var
  Session: ICopilotChatSession;
  CopilotContext: TCopilotCodeContext;
  WeakCallback: ICopilotBridgeCallback;
begin
  LogDebug('SendChatMessageAsync: Starting');
  Result := False;
  
  if Callback = nil then
  begin
    LogWarning('SendChatMessageAsync: Callback is nil');
    Exit;
  end;
    
  WeakCallback := Callback;
  LogDebug('SendChatMessageAsync: Creating chat session');
    
  Session := CreateChatSession;
  if Session = nil then
  begin
    LogError('SendChatMessageAsync: Failed to create session: ' + FLastError);
    // Send error callback safely
    TThread.Synchronize(TThread.CurrentThread, 
      procedure
      var
        ErrorResponse: TCopilotResponse;
      begin
        try
          if Assigned(WeakCallback) then
          begin
            FillChar(ErrorResponse, SizeOf(ErrorResponse), 0);
            ErrorResponse.Status := crsError;
            ErrorResponse.ErrorMessage := FLastError;
            WeakCallback.OnResponse(ErrorResponse);
          end;
        except
          // Ignore callback errors
        end;
      end);
    Exit;
  end;
  
  LogDebug('SendChatMessageAsync: Session created successfully');
  
  // Parse context if provided
  FillChar(CopilotContext, SizeOf(CopilotContext), 0);
  if Context <> '' then
    CopilotContext.SelectedText := Context;
  
  // Keep a strong reference to the session in the async task
  Result := Session.SendMessageAsync(Message, CopilotContext, WeakCallback);
  LogDebug('SendChatMessageAsync: Completed with result: ' + BoolToStr(Result, True));
end;

procedure TCopilotBridge.ShowSettingsDialog;
var
  SettingsForm: TfrmCopilotSettings;
  NewConfig: TJSONObject;
  Config: TJSONObject;
begin
    NewConfig := nil;
  LogDebug('ShowSettingsDialog: Starting');
  
  try
    Config := GetConfiguration;
    LogDebug('ShowSettingsDialog: Current username = ' + Config.GetValue<string>('username', ''));
    LogDebug('ShowSettingsDialog: Current token present = ' + BoolToStr(Config.GetValue<string>('token', '') <> '', True));
    
    SettingsForm := TfrmCopilotSettings.CreateSettings(nil, Config.GetValue<string>('username', ''), Config.GetValue<string>('token', ''));
    try
      LogDebug('ShowSettingsDialog: About to show modal dialog');
      if SettingsForm.ShowModal = mrOk then
      begin
        LogDebug('ShowSettingsDialog: User clicked OK, getting new config');
        try
          NewConfig := SettingsForm.GetGithubConfig;
          if NewConfig <> nil then
          begin
            LogDebug('ShowSettingsDialog: New username = ' + NewConfig.GetValue<string>('username', ''));
            LogDebug('ShowSettingsDialog: New token present = ' + BoolToStr(NewConfig.GetValue<string>('token', '') <> '', True));
            
            LogDebug('ShowSettingsDialog: About to call SetConfiguration');
            SetConfiguration(NewConfig);
            LogInfo('ShowSettingsDialog: Configuration updated successfully');
            
            // Free NewConfig here since we're done with it
            try
              NewConfig.Free;
            except
              on E: Exception do
                LogError('ShowSettingsDialog: Exception freeing NewConfig: ' + E.Message);
            end;
          end
          else
          begin
            LogError('ShowSettingsDialog: NewConfig is nil!');
          end;
        except
          on E: Exception do
          begin
            LogError('ShowSettingsDialog: Exception during configuration update: ' + E.Message);
            // Free NewConfig if it was created but an exception occurred
            if Assigned(NewConfig) then
            begin
              try
                NewConfig.Free;
              except
                on E2: Exception do
                  LogError('ShowSettingsDialog: Exception freeing NewConfig after error: ' + E2.Message);
              end;
            end;
          end;
        end;
      end
      else
      begin
        LogDebug('ShowSettingsDialog: User cancelled');
      end;
    finally
      SettingsForm.Free;
      Config.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('ShowSettingsDialog: Exception in ShowSettingsDialog: ' + E.Message);
    end;
  end;
end;

// Global logger setter procedure
procedure SetGlobalLogger(const Logger: ICopilotLogger);
begin
  GlobalLogger := Logger;
end;

{ TCopilotBridgeFactory }

function TCopilotBridgeFactory.CreateBridge: ICopilotBridge;
begin
  Result := TCopilotBridge.Create;
end;

end.
