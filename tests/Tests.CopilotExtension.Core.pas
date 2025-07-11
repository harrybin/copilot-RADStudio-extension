unit Tests.CopilotExtension.Core;

{
  Unit tests for the Core Service functionality
}

interface

uses
  TestFramework,
  CopilotExtension.Services.Core,
  CopilotExtension.Services.Authentication;

type
  // Test case for Core Service
  TCoreServiceTest = class(TTestCase)
  private
    FCoreService: TCopilotCoreService;
    FAuthService: TCopilotAuthenticationService;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestServiceInitialization;
    procedure TestServiceConfiguration;
    procedure TestServiceStatus;
    procedure TestServiceEventHandling;
  end;

implementation

uses
  SysUtils, JSON;

{ TCoreServiceTest }

procedure TCoreServiceTest.SetUp;
begin
  inherited;
  FCoreService := TCopilotCoreService.Create;
  FAuthService := TCopilotAuthenticationService.Create;
  FCoreService.AuthenticationService := FAuthService;
end;

procedure TCoreServiceTest.TearDown;
begin
  FCoreService.Free;
  FAuthService.Free;
  inherited;
end;

procedure TCoreServiceTest.TestServiceInitialization;
begin
  // Test initial state
  CheckFalse(FCoreService.IsInitialized, 'Service should not be initialized initially');
  
  // Test initialization
  // Note: This may fail if Node.js is not available
  try
    var InitResult := FCoreService.Initialize;
    if InitResult then
    begin
      CheckTrue(FCoreService.IsInitialized, 'Service should be initialized after successful init');
      
      // Test finalization
      FCoreService.Finalize;
      CheckFalse(FCoreService.IsInitialized, 'Service should not be initialized after finalization');
    end
    else
    begin
      // Expected if Node.js not available
      CheckFalse(FCoreService.IsInitialized, 'Service should remain uninitialized if init fails');
      CheckNotEquals('', FCoreService.GetLastError, 'Error message should be provided on init failure');
    end;
  except
    on E: Exception do
    begin
      // Allow initialization to fail gracefully for testing
      CheckFalse(FCoreService.IsInitialized, 'Service should not be initialized after exception');
    end;
  end;
end;

procedure TCoreServiceTest.TestServiceConfiguration;
var
  Config: TJSONObject;
  TestValue: string;
begin
  // Test default configuration
  Config := FCoreService.GetConfiguration;
  try
    CheckNotNull(Config, 'Configuration should not be null');
    CheckTrue(Config.Count >= 0, 'Configuration should be valid JSON object');
  finally
    Config.Free;
  end;
  
  // Test configuration values
  FCoreService.SetConfigValue('testKey', 'testValue');
  TestValue := FCoreService.GetConfigValue('testKey');
  CheckEquals('testValue', TestValue, 'Configuration value should be set and retrieved correctly');
  
  // Test configuration object
  Config := TJSONObject.Create;
  try
    Config.AddPair('customKey', 'customValue');
    FCoreService.SetConfiguration(Config);
    
    TestValue := FCoreService.GetConfigValue('customKey');
    CheckEquals('customValue', TestValue, 'Custom configuration should be applied');
  finally
    Config.Free;
  end;
end;

procedure TCoreServiceTest.TestServiceStatus;
var
  Status: string;
begin
  // Test status when not initialized
  Status := FCoreService.GetStatus;
  CheckTrue(Pos('Not initialized', Status) > 0, 'Status should indicate not initialized');
  
  // Test service availability
  CheckFalse(FCoreService.IsServiceAvailable, 'Service should not be available when not initialized');
  
  // Test service info
  var ServiceInfo := FCoreService.GetServiceInfo;
  try
    CheckNotNull(ServiceInfo, 'Service info should not be null');
    
    var InitializedValue := ServiceInfo.GetValue('initialized');
    CheckNotNull(InitializedValue, 'Service info should contain initialized status');
    CheckFalse((InitializedValue as TJSONBool).AsBoolean, 'Service should report as not initialized');
  finally
    ServiceInfo.Free;
  end;
end;

procedure TCoreServiceTest.TestServiceEventHandling;
var
  EventReceived: Boolean;
  EventData: string;
  
  procedure EventHandler(Event: TCopilotServiceEvent; const Data: string);
  begin
    EventReceived := True;
    EventData := Data;
  end;
  
begin
  EventReceived := False;
  EventData := '';
  
  // Add event handler
  FCoreService.AddEventHandler(EventHandler);
  
  // Trigger an event by changing configuration
  FCoreService.SetConfigValue('eventTest', 'eventValue');
  
  // Check if event was received
  CheckTrue(EventReceived, 'Event handler should have been called');
  CheckTrue(Pos('Configuration', EventData) > 0, 'Event data should contain configuration information');
  
  // Remove event handler
  FCoreService.RemoveEventHandler(EventHandler);
  
  // Reset and test that handler is no longer called
  EventReceived := False;
  FCoreService.SetConfigValue('eventTest2', 'eventValue2');
  CheckFalse(EventReceived, 'Event handler should not be called after removal');
end;

initialization
  RegisterTest('CopilotExtension.Services', TCoreServiceTest.Suite);

end.
