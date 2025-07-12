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

implementation

uses
  System.RegularExpressions, System.StrUtils, System.NetEncoding,
  CopilotExtension.UI.SettingsDialog, Vcl.Forms;

const
  GITHUB_COPILOT_API_ENDPOINT = 'https://api.githubcopilot.com/chat/completions';
  DEFAULT_REQUEST_TIMEOUT = 30000; // 30 seconds
  DEFAULT_RETRY_ATTEMPTS = 3;
  CONFIG_FILE_NAME = 'copilot_config.json';

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
  inherited Create;
  FAuthService := AuthService;
  FAPIEndpoint := APIEndpoint;
  FRequestTimeout := RequestTimeout;
  FSessionId := TGUID.NewGuid.ToString;
  FMessages := TList<TCopilotChatMessage>.Create;
  FLock := TCriticalSection.Create;
  
  // Initialize HTTP client
  FHttpClient := THTTPClient.Create;
  FHttpClient.SendTimeout := FRequestTimeout;
  
  // Set up request headers
  FHttpClient.CustomHeaders['Accept'] := 'text/event-stream';
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
  FHttpClient.CustomHeaders['User-Agent'] := 'RADStudio-Copilot-Extension/1.0';
end;

destructor TCopilotChatSession.Destroy;
begin
  FHttpClient.Free;
  FMessages.Free;
  FLock.Free;
  inherited;
end;

function TCopilotChatSession.BuildAPIRequest(const Message: string; 
  const Context: TCopilotCodeContext): TJSONObject;
var
  Messages: TJSONArray;
  MessageObj: TJSONObject;
  ContextObj: TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  
  try
    // Build messages array
    Messages := TJSONArray.Create;
    
    // Add system message for RAD Studio context
    MessageObj := TJSONObject.Create;
    MessageObj.AddPair('role', 'system');
    MessageObj.AddPair('content', 'You are GitHub Copilot integrated into RAD Studio IDE. ' +
      'Provide helpful assistance with Delphi/Pascal code and RAD Studio development.');
    Messages.AddElement(MessageObj);
    
    // Add chat history
    FLock.Enter;
    try
      for I := 0 to FMessages.Count - 1 do
      begin
        MessageObj := TJSONObject.Create;
        MessageObj.AddPair('role', FMessages[I].Role);
        MessageObj.AddPair('content', FMessages[I].Content);
        Messages.AddElement(MessageObj);
      end;
    finally
      FLock.Leave;
    end;
    
    // Add current user message with context
    MessageObj := TJSONObject.Create;
    MessageObj.AddPair('role', 'user');
    
    // Include code context if provided
    if (Context.FileName <> '') or (Context.SelectedText <> '') then
    begin
      ContextObj := TJSONObject.Create;
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
      ContextObj.Free;
    end
    else
      MessageObj.AddPair('content', Message);
      
    Messages.AddElement(MessageObj);
    
    // Build final request
    Result.AddPair('messages', Messages);
    Result.AddPair('stream', TJSONBool.Create(False)); // For synchronous responses
    Result.AddPair('temperature', TJSONNumber.Create(0.7));
    Result.AddPair('max_tokens', TJSONNumber.Create(2048));
    
  finally
      Result.Free;
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
  FillChar(Result, SizeOf(Result), 0);
  Result.Status := crsError;
  
  try
    // Build API request
    RequestBody := BuildAPIRequest(Message, Context);
    try
      // Send HTTP request
      ResponseContent := SendHTTPRequest(RequestBody);
      
      // Parse response
      Result := ParseAPIResponse(ResponseContent);
      
      // Add messages to history if successful
      if Result.Status = crsSuccess then
      begin
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
        finally
          FLock.Leave;
        end;
      end;
      
    finally
      RequestBody.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result.Status := crsError;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TCopilotChatSession.SendMessageAsync(const Message: string; 
  const Context: TCopilotCodeContext; const Callback: ICopilotBridgeCallback): Boolean;
var
  Response: TCopilotResponse;
begin
  Result := False;
  
  if Callback = nil then
    Exit;
    
  try
    // For now, execute synchronously to avoid threading issues
    Response := SendMessage(Message, Context);
    Callback.OnResponse(Response);
    Result := True;
  except
    on E: Exception do
    begin
      // Create error response
      FillChar(Response, SizeOf(Response), 0);
      Response.Status := crsError;
      Response.ErrorMessage := 'SendMessageAsync error: ' + E.Message;
      
      try
        Callback.OnError(Response.ErrorMessage);
      except
        // Ignore callback errors to prevent cascading issues
      end;
    end;
  end;
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
  Finalize;
  FHttpClient.Free;
  FConfiguration.Free;
  FLock.Free;
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
begin
  Result := False;
  
  if Callback = nil then
    Exit;
    
  Session := CreateChatSession;
  if Session = nil then
  begin
    // Send error callback
    TTask.Run(procedure
    var
      ErrorResponse: TCopilotResponse;
    begin
      FillChar(ErrorResponse, SizeOf(ErrorResponse), 0);
      ErrorResponse.Status := crsError;
      ErrorResponse.ErrorMessage := FLastError;
      Callback.OnResponse(ErrorResponse);
    end);
    Exit;
  end;
  
  // Parse context if provided
  FillChar(CopilotContext, SizeOf(CopilotContext), 0);
  if Context <> '' then
    CopilotContext.SelectedText := Context;
    
  Result := Session.SendMessageAsync(Message, CopilotContext, Callback);
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

{ TCopilotBridgeFactory }

function TCopilotBridgeFactory.CreateBridge: ICopilotBridge;
begin
  Result := TCopilotBridge.Create;
end;

end.
