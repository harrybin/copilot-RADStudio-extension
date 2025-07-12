unit CopilotExtension.Services.Core;

{
  RAD Studio Copilot Extension - Core Service Implementation
  
  This unit provides the core service layer that coordinates between the
  Tools API, Copilot Bridge, and UI components.
}

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  CopilotExtension.IBridge,
  CopilotExtension.IBridgeImpl;

type
  // Forward declarations
  TCopilotCoreService = class;

  // Service event types
  TCopilotServiceEvent = (
    cseInitialized,
    cseFinalized,
    cseAuthenticationChanged,
    cseConfigurationChanged,
    cseError
  );

  // Service event handler
  TCopilotServiceEventHandler = procedure(Event: TCopilotServiceEvent; 
    const Data: string) of object;

  // Core service class
  TCopilotCoreService = class
  private
    FBridge: ICopilotBridge;
    FConfiguration: TJSONObject;
    FInitialized: Boolean;
    FEventHandlers: TList;
    FLastError: string;
    // FAuthenticationService: TCopilotAuthenticationService; // TODO: Re-enable when circular dependency resolved
    // Internal methods
    procedure NotifyEvent(Event: TCopilotServiceEvent; const Data: string);
    procedure LoadConfiguration;
    procedure SaveConfiguration;
    function GetConfigurationPath: string;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // Service lifecycle
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    
    // Bridge access
    property Bridge: ICopilotBridge read FBridge;
    
    // Configuration management
    function GetConfiguration: TJSONObject;
    procedure SetConfiguration(const Config: TJSONObject);
    function GetConfigValue(const Key: string): string;
    procedure SetConfigValue(const Key, Value: string);
    
    // Event management
    procedure AddEventHandler(const Handler: TCopilotServiceEventHandler);
    procedure RemoveEventHandler(const Handler: TCopilotServiceEventHandler);
    
    // Service status
    function GetStatus: string;
    function GetLastError: string;
    
    // Utility methods
    function IsServiceAvailable: Boolean;
    function GetServiceInfo: TJSONObject;
    procedure ResetService;
  end;

implementation

uses
  System.IOUtils;

{ TCopilotCoreService }

constructor TCopilotCoreService.Create;
begin
  inherited Create;
  FInitialized := False;
  FConfiguration := TJSONObject.Create;
  FEventHandlers := TList.Create;
  FLastError := '';
  // FAuthenticationService := TCopilotAuthenticationService.Create; // TODO: Re-enable when circular dependency resolved
end;

destructor TCopilotCoreService.Destroy;
begin
  if FInitialized then
    Finalize;
    
  FreeAndNil(FConfiguration);
  FreeAndNil(FEventHandlers);
  inherited Destroy;
end;

function TCopilotCoreService.Initialize: Boolean;
var
  BridgeFactory: ICopilotBridgeFactory;
begin
  Result := False;
  
  if FInitialized then
  begin
    Result := True;
    Exit;
  end;
  
  try
    // Load configuration
    LoadConfiguration;

    // Authenticate using config values
    // TODO: Re-enable when authentication service circular dependency is resolved
    // if (FConfiguration.GetValue('token') <> nil) then
    //   FAuthenticationService.Authenticate(FConfiguration.GetValue('token').Value);
    
    // Create and initialize bridge - TODO: Implement bridge integration
    // BridgeFactory := TCopilotBridgeFactory.Create;
    // FBridge := BridgeFactory.CreateBridge;
    
    // TODO: Integrate bridge when circular dependencies are resolved
    (*
    if Assigned(FBridge) then
    begin
      // Apply configuration to bridge
      if FConfiguration.Count > 0 then
        FBridge.SetConfiguration(FConfiguration);
      
      // Initialize bridge
      if FBridge.Initialize then
      begin
        FInitialized := True;
        Result := True;
        
        NotifyEvent(cseInitialized, 'Core service initialized successfully');
      end
      else
      begin
        FLastError := 'Failed to initialize Copilot bridge: ' + FBridge.GetLastError;
        NotifyEvent(cseError, FLastError);
      end;
    end
    else
    begin
      FLastError := 'Failed to create Copilot bridge';
      NotifyEvent(cseError, FLastError);
    end;
    *)
    
    // Temporary stub implementation
    FInitialized := True;
    Result := True;
    NotifyEvent(cseInitialized, 'Core service initialized successfully (stub)');
    
  except
    on E: Exception do
    begin
      FLastError := 'Core service initialization error: ' + E.Message;
      NotifyEvent(cseError, FLastError);
    end;
  end;
end;

procedure TCopilotCoreService.Finalize;
begin
  if not FInitialized then
    Exit;
    
  try
    // Save configuration
    SaveConfiguration;
    
    // Finalize bridge
    if Assigned(FBridge) then
    begin
      FBridge.Finalize;
      FBridge := nil;
    end;
    
    FInitialized := False;
    NotifyEvent(cseFinalized, 'Core service finalized');
    
  except
    on E: Exception do
    begin
      FLastError := 'Core service finalization error: ' + E.Message;
      NotifyEvent(cseError, FLastError);
    end;
  end;
end;

function TCopilotCoreService.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TCopilotCoreService.GetConfiguration: TJSONObject;
begin
  Result := TJSONObject(FConfiguration.Clone);
end;

procedure TCopilotCoreService.SetConfiguration(const Config: TJSONObject);
begin
  FreeAndNil(FConfiguration);
  FConfiguration := TJSONObject(Config.Clone);
  
  // Apply to bridge if available
  if Assigned(FBridge) then
    FBridge.SetConfiguration(FConfiguration);
    
  NotifyEvent(cseConfigurationChanged, 'Configuration updated');
end;

function TCopilotCoreService.GetConfigValue(const Key: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  
  Value := FConfiguration.GetValue(Key);
  if Assigned(Value) then
    Result := Value.Value;
end;

procedure TCopilotCoreService.SetConfigValue(const Key, Value: string);
begin
  // Remove existing value if present
  FConfiguration.RemovePair(Key);
  
  // Add new value
  FConfiguration.AddPair(Key, Value);
  
  // Apply to bridge if available
  if Assigned(FBridge) then
    FBridge.SetConfiguration(FConfiguration);
    
  NotifyEvent(cseConfigurationChanged, Format('Configuration value "%s" updated', [Key]));
end;

procedure TCopilotCoreService.AddEventHandler(const Handler: TCopilotServiceEventHandler);
begin
  // TODO: Implement proper event handler storage
end;

procedure TCopilotCoreService.RemoveEventHandler(const Handler: TCopilotServiceEventHandler);
begin
  // TODO: Implement proper event handler removal
end;

function TCopilotCoreService.GetStatus: string;
begin
  if not FInitialized then
  begin
    Result := 'Not initialized';
    Exit;
  end;
  
  if Assigned(FBridge) then
  begin
    Result := FBridge.GetStatus;
    // TODO: Re-enable authentication status when circular dependency resolved
    // Add authentication status
    // if Assigned(FAuthenticationService) then
    // begin
    //   if FAuthenticationService.IsAuthenticated then
    //     Result := Result + ' - Authenticated'
    //   else
    //     Result := Result + ' - Not authenticated';
    // end;
  end
  else
  begin
    Result := 'Bridge not available';
  end;
end;

function TCopilotCoreService.GetLastError: string;
begin
  Result := FLastError;
  
  // Also check bridge error if available
  if Assigned(FBridge) then
  begin
    var BridgeError := FBridge.GetLastError;
    if BridgeError <> '' then
    begin
      if Result <> '' then
        Result := Result + ' | Bridge: ' + BridgeError
      else
        Result := 'Bridge: ' + BridgeError;
    end;
  end;
end;

function TCopilotCoreService.IsServiceAvailable: Boolean;
begin
  Result := FInitialized and Assigned(FBridge) and FBridge.IsInitialized;
end;

function TCopilotCoreService.GetServiceInfo: TJSONObject;
begin
  Result := TJSONObject.Create;
  
  try
    Result.AddPair('initialized', TJSONBool.Create(FInitialized));
    Result.AddPair('status', GetStatus);
    
    if Assigned(FBridge) then
    begin
      Result.AddPair('bridge_available', TJSONBool.Create(True));
      Result.AddPair('bridge_initialized', TJSONBool.Create(FBridge.IsInitialized));
      Result.AddPair('bridge_authenticated', TJSONBool.Create(FBridge.IsAuthenticated));
    end
    else
    begin
      Result.AddPair('bridge_available', TJSONBool.Create(False));
    end;
    
    // TODO: Re-enable authentication service info when circular dependency resolved
    // if Assigned(FAuthenticationService) then
    // begin
    //   Result.AddPair('auth_service_available', TJSONBool.Create(True));
    //   Result.AddPair('authenticated', TJSONBool.Create(FAuthenticationService.IsAuthenticated));
    // end
    // else
    // begin
    //   Result.AddPair('auth_service_available', TJSONBool.Create(False));
    // end;
    
    var LastError := GetLastError;
    if LastError <> '' then
      Result.AddPair('last_error', LastError);
      
  except
    on E: Exception do
    begin
      Result.AddPair('error', 'Failed to get service info: ' + E.Message);
    end;
  end;
end;

procedure TCopilotCoreService.ResetService;
begin
  try
    if FInitialized then
    begin
      Finalize;
      Initialize;
    end;
    
  except
    on E: Exception do
    begin
      FLastError := 'Service reset error: ' + E.Message;
      NotifyEvent(cseError, FLastError);
    end;
  end;
end;

// Private methods

procedure TCopilotCoreService.NotifyEvent(Event: TCopilotServiceEvent; const Data: string);
begin
  // For now, just skip event notification to avoid casting issues
  // TODO: Implement proper event handler storage and notification
end;

procedure TCopilotCoreService.LoadConfiguration;
var
  ConfigPath: string;
  ConfigContent: string;
  ParsedConfig: TJSONValue;
begin
  try
    ConfigPath := GetConfigurationPath;
    
    if TFile.Exists(ConfigPath) then
    begin
      ConfigContent := TFile.ReadAllText(ConfigPath);
      
      if ConfigContent <> '' then
      begin
        ParsedConfig := TJSONObject.ParseJSONValue(ConfigContent);
        if ParsedConfig is TJSONObject then
        begin
          FreeAndNil(FConfiguration);
          FConfiguration := TJSONObject(ParsedConfig);
        end
        else
        begin
          ParsedConfig.Free;
        end;
      end;
    end;
    
    // Ensure default values exist
    if FConfiguration.GetValue('logLevel') = nil then
      FConfiguration.AddPair('logLevel', 'info');
      
    if FConfiguration.GetValue('timeout') = nil then
      FConfiguration.AddPair('timeout', TJSONNumber.Create(30000));
      
  except
    on E: Exception do
    begin
      // Use default configuration on error
      FreeAndNil(FConfiguration);
      FConfiguration := TJSONObject.Create;
      FConfiguration.AddPair('logLevel', 'info');
      FConfiguration.AddPair('timeout', TJSONNumber.Create(30000));
    end;
  end;
end;

procedure TCopilotCoreService.SaveConfiguration;
var
  ConfigPath: string;
  ConfigContent: string;
  ConfigDir: string;
begin
  try
    ConfigPath := GetConfigurationPath;
    ConfigDir := ExtractFileDir(ConfigPath);
    
    // Ensure directory exists
    if not TDirectory.Exists(ConfigDir) then
      TDirectory.CreateDirectory(ConfigDir);
    
    // Save configuration
    ConfigContent := FConfiguration.ToJSON;
    TFile.WriteAllText(ConfigPath, ConfigContent);
    
  except
    on E: Exception do
    begin
      FLastError := 'Failed to save configuration: ' + E.Message;
    end;
  end;
end;

function TCopilotCoreService.GetConfigurationPath: string;
var
  AppDataPath: string;
begin
  AppDataPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA'));
  Result := AppDataPath + 'RADStudio\CopilotExtension\config.json';
end;

end.
