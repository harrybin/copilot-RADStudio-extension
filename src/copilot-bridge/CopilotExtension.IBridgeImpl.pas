unit CopilotExtension.IBridgeImpl;

{
  RAD Studio Copilot Extension - VS Code Copilot Bridge Implementation
  
  This unit implements the bridge layer for communicating with GitHub Copilot Chat
  through HTTP APIs, providing a complete interface between RAD Studio and 
  the GitHub Copilot service.
}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  System.Net.URLClient, System.SyncObjs, System.Threading, System.Generics.Collections,
  System.IOUtils, Winapi.Windows, Vcl.Controls,
  CopilotExtension.IBridge, CopilotExtension.IToolsAPI;

type
  // Logging levels
  TLogLevel = (llDebug, llInfo, llWarning, llError);
  
  // Interface for logging callback
  ICopilotLogger = interface
    ['{B8E5F7A1-2D4C-4F5E-8A9B-1C2D3E4F5A6B}']
    procedure Log(const Level: TLogLevel; const Msg: string);
  end;

  // Simple authentication service stub for compilation
  TCopilotAuthenticationService = class
  public
    function IsAuthenticated: Boolean;
    function GetToken: string;
    function Authenticate: Boolean;
    procedure SignOut;
    function GetLastError: string;
  end;

  // Implementation of chat session with real GitHub Copilot Chat API integration
  TCopilotChatSession = class(TInterfacedObject, ICopilotChatSession)
  private
    FSessionId: string;
    FHttpClient: THTTPClient;
    FAuthService: TCopilotAuthenticationService;
    FMessages: TList<TCopilotChatMessage>;
    FAPIEndpoint: string;
    FRequestTimeout: Integer;
    FLock: TCriticalSection;
    
    function BuildAPIRequest(const Message: string; const Context: TCopilotCodeContext): TJSONObject;
    function ParseAPIResponse(const Response: string): TCopilotResponse;
    function SendHTTPRequest(const RequestBody: TJSONObject): string;
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
    FHttpClient: THTTPClient;
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
  GITHUB_COPILOT_API_ENDPOINT = 'https://api.githubcopilot.com/chat/completions';
  DEFAULT_REQUEST_TIMEOUT = 30000; // 30 seconds
  DEFAULT_RETRY_ATTEMPTS = 3;
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
  LogToSystem(llDebug, Msg);
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

function TCopilotAuthenticationService.IsAuthenticated: Boolean;
begin
  Result := True; // Stub - always authenticated for now
end;

function TCopilotAuthenticationService.GetToken: string;
begin
  Result := 'stub_token'; // Stub implementation
end;

function TCopilotAuthenticationService.Authenticate: Boolean;
begin
  Result := True; // Stub implementation
end;

procedure TCopilotAuthenticationService.SignOut;
begin
  // Stub implementation
end;

function TCopilotAuthenticationService.GetLastError: string;
begin
  Result := ''; // Stub implementation
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
    
    LogDebug('TCopilotChatSession.Create: Creating HTTP client');
    // Initialize HTTP client
    FHttpClient := THTTPClient.Create;
    FHttpClient.SendTimeout := FRequestTimeout;
    
    LogDebug('TCopilotChatSession.Create: Setting up request headers');
    // Set up request headers
    FHttpClient.CustomHeaders['Accept'] := 'text/event-stream';
    FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
    FHttpClient.CustomHeaders['User-Agent'] := 'RADStudio-Copilot-Extension/1.0';
    
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
    LogDebug('TCopilotChatSession.Destroy: Freeing FHttpClient');
    FreeAndNil(FHttpClient);
  except
    on E: Exception do
      LogError('TCopilotChatSession.Destroy: Error freeing FHttpClient: ' + E.Message);
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
      begin
        Result.Free;
        Result := nil;
      end;
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

function TCopilotChatSession.SendHTTPRequest(const RequestBody: TJSONObject): string;
var
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  Token: string;
begin
  if not FAuthService.IsAuthenticated then
  begin
    raise Exception.Create('Not authenticated with GitHub Copilot');
  end;
  
  Token := FAuthService.GetToken;
  if Token = '' then
  begin
    raise Exception.Create('No access token available');
  end;
  
  // Set authorization header
  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + Token;
  
  RequestStream := TStringStream.Create(RequestBody.ToString, TEncoding.UTF8);
  try
    Response := FHttpClient.Post(FAPIEndpoint, RequestStream);
    
    if Response.StatusCode = 200 then
    begin
      Result := Response.ContentAsString;
    end
    else
    begin
      raise Exception.CreateFmt('HTTP request failed with status %d: %s', 
        [Response.StatusCode, Response.StatusText]);
    end;
    
  finally
    RequestStream.Free;
  end;
end;

function TCopilotChatSession.SendMessage(const Message: string; 
  const Context: TCopilotCodeContext): TCopilotResponse;
var
  RequestBody: TJSONObject;
  ResponseContent: string;
  UserMsg, AssistantMsg: TCopilotChatMessage;
begin
  LogDebug('SendMessage: Starting with message: ' + Copy(Message, 1, 50) + '...');
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := crsError;
  
  try
    LogDebug('SendMessage: Building API request');
    // Build API request
    RequestBody := BuildAPIRequest(Message, Context);
    if RequestBody = nil then
    begin
      LogError('SendMessage: BuildAPIRequest returned nil');
      Result.ErrorMessage := 'Failed to build API request';
      Exit;
    end;
    
    try
      LogDebug('SendMessage: Sending HTTP request');
      // Send HTTP request
      ResponseContent := SendHTTPRequest(RequestBody);
      LogDebug('SendMessage: HTTP request completed, response length: ' + IntToStr(Length(ResponseContent)));
      
      LogDebug('SendMessage: Parsing API response');
      // Parse response
      Result := ParseAPIResponse(ResponseContent);
      LogInfo('SendMessage: Response status: ' + IntToStr(Ord(Result.Status)));
      
      // Add messages to history if successful
      if Result.Status = crsSuccess then
      begin
        LogDebug('SendMessage: Adding messages to history');
        FLock.Enter;
        try
          // Add user message
          UserMsg.Role := 'user';
          UserMsg.Content := Message;
          UserMsg.Timestamp := Now;
          FMessages.Add(UserMsg);
          
          // Add assistant response
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
        
        // Use TThread.Queue instead of Synchronize for better performance
        TThread.Queue(nil,
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
          TThread.Queue(nil,
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

{ TCopilotBridge }

constructor TCopilotBridge.Create;
begin
  inherited Create;
  FInitialized := False;
  FAPIEndpoint := GITHUB_COPILOT_API_ENDPOINT;
  FRequestTimeout := DEFAULT_REQUEST_TIMEOUT;
  FRetryAttempts := DEFAULT_RETRY_ATTEMPTS;
  FConfiguration := TJSONObject.Create;
  FLock := TCriticalSection.Create;
  
  // Initialize HTTP client
  FHttpClient := THTTPClient.Create;
  FHttpClient.SendTimeout := FRequestTimeout;
end;

destructor TCopilotBridge.Destroy;
begin
  try
    Finalize;
  except
    // Ignore finalization errors during destruction
  end;
  
  try
    FreeAndNil(FHttpClient);
  except
    // Ignore cleanup errors
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
  
  if TFile.Exists(ConfigPath) then
  begin
    try
      ConfigContent := TFile.ReadAllText(ConfigPath);
      ConfigObj := TJSONObject.ParseJSONValue(ConfigContent) as TJSONObject;
      if ConfigObj <> nil then
      begin
        try
          if ConfigObj.TryGetValue('api_endpoint', Value) then
            FAPIEndpoint := Value.Value;
          if ConfigObj.TryGetValue('request_timeout', Value) then
            FRequestTimeout := Value.AsType<Integer>;
          if ConfigObj.TryGetValue('retry_attempts', Value) then
            FRetryAttempts := Value.AsType<Integer>;
        finally
          ConfigObj.Free;
        end;
      end;
    except
      // Ignore configuration loading errors and use defaults
    end;
  end;
end;

procedure TCopilotBridge.SaveConfiguration;
var
  ConfigPath: string;
  ConfigObj: TJSONObject;
begin
  ConfigPath := TPath.Combine(TPath.GetDocumentsPath, CONFIG_FILE_NAME);
  
  ConfigObj := TJSONObject.Create;
  try
    ConfigObj.AddPair('api_endpoint', FAPIEndpoint);
    ConfigObj.AddPair('request_timeout', TJSONNumber.Create(FRequestTimeout));
    ConfigObj.AddPair('retry_attempts', TJSONNumber.Create(FRetryAttempts));
    
    try
      TFile.WriteAllText(ConfigPath, ConfigObj.ToString, TEncoding.UTF8);
    except
      // Ignore save errors
    end;
  finally
    ConfigObj.Free;
  end;
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
        // Create authentication service instance
        FAuthService := TCopilotAuthenticationService.Create;
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
begin
  Result := (FAuthService <> nil) and FAuthService.IsAuthenticated;
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
  FLock.Enter;
  try
    if Config.TryGetValue('api_endpoint', Value) then
      FAPIEndpoint := Value.Value;
      
    if Config.TryGetValue('request_timeout', Value) then
      FRequestTimeout := Value.AsType<Integer>;
      
    if Config.TryGetValue('retry_attempts', Value) then
      FRetryAttempts := Value.AsType<Integer>;
      
    // Update HTTP client timeout
    if FHttpClient <> nil then
      FHttpClient.SendTimeout := FRequestTimeout;
      
    SaveConfiguration;
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
  if not FInitialized then
  begin
    FLastError := 'Bridge not initialized';
    Result := nil;
    Exit;
  end;
  
  if not IsAuthenticated then
  begin
    FLastError := 'Not authenticated';
    Result := nil;
    Exit;
  end;
  
  try
    Result := TCopilotChatSession.Create(FAuthService, FAPIEndpoint, FRequestTimeout);
  except
    on E: Exception do
    begin
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
    TThread.Queue(nil, 
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
  Config := GetConfiguration;
  SettingsForm := TfrmCopilotSettings.CreateSettings(nil, Config.GetValue<string>('username', ''), Config.GetValue<string>('token', ''));
  try
    if SettingsForm.ShowModal = mrOk then
    begin
      NewConfig := SettingsForm.GetGithubConfig;
      try
        SetConfiguration(NewConfig);
      finally
        NewConfig.Free;
      end;
    end;
  finally
    SettingsForm.Free;
    Config.Free;
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
