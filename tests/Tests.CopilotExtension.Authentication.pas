unit Tests.CopilotExtension.Authentication;

{
  Unit tests for the Authentication Service functionality
}

interface

uses
  TestFramework,
  CopilotExtension.Services.Authentication;

type
  // Test case for Authentication Service
  TAuthenticationServiceTest = class(TTestCase)
  private
    FAuthService: TCopilotAuthenticationService;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestInitialState;
    procedure TestTokenManagement;
    procedure TestAuthenticationStatus;
    procedure TestEventHandling;
  end;

implementation

uses
  SysUtils;

{ TAuthenticationServiceTest }

procedure TAuthenticationServiceTest.SetUp;
begin
  inherited;
  FAuthService := TCopilotAuthenticationService.Create;
end;

procedure TAuthenticationServiceTest.TearDown;
begin
  FAuthService.Free;
  inherited;
end;

procedure TAuthenticationServiceTest.TestInitialState;
begin
  // Test initial authentication state
  CheckFalse(FAuthService.IsAuthenticated, 'Service should not be authenticated initially');
  CheckEquals(Ord(casNotAuthenticated), Ord(FAuthService.GetAuthStatus), 'Initial status should be not authenticated');
  CheckEquals('', FAuthService.GetToken, 'Initial token should be empty');
  CheckEquals('Not authenticated', FAuthService.GetAuthStatusText, 'Status text should indicate not authenticated');
end;

procedure TAuthenticationServiceTest.TestTokenManagement;
var
  TestToken: string;
begin
  TestToken := 'test_token_123';
  
  // Test setting token
  FAuthService.SetToken(TestToken);
  
  // Note: Token validation may fail since this is a test token
  // The service should handle this gracefully
  
  // Test clearing token
  FAuthService.SetToken('');
  CheckFalse(FAuthService.IsAuthenticated, 'Authentication should be cleared when token is empty');
  CheckEquals('', FAuthService.GetToken, 'Token should be empty after clearing');
end;

procedure TAuthenticationServiceTest.TestAuthenticationStatus;
var
  AuthInfo: TCopilotAuthInfo;
begin
  // Test getting authentication info
  AuthInfo := FAuthService.GetAuthInfo;
  CheckEquals(Ord(casNotAuthenticated), Ord(AuthInfo.Status), 'Auth info should show not authenticated');
  CheckEquals('', AuthInfo.Username, 'Username should be empty initially');
  CheckEquals('', AuthInfo.Email, 'Email should be empty initially');
  
  // Test token expiry
  CheckFalse(FAuthService.IsTokenExpired, 'Token should not be expired when no token is set');
end;

procedure TAuthenticationServiceTest.TestEventHandling;
var
  EventReceived: Boolean;
  EventSuccess: Boolean;
  EventMessage: string;
  
  procedure AuthEventHandler(Success: Boolean; const ErrorMessage: string);
  begin
    EventReceived := True;
    EventSuccess := Success;
    EventMessage := ErrorMessage;
  end;
  
begin
  EventReceived := False;
  EventSuccess := False;
  EventMessage := '';
  
  // Add event handler
  FAuthService.AddEventHandler(AuthEventHandler);
  
  // Trigger authentication event (will likely fail with test token)
  FAuthService.Authenticate('invalid_test_token');
  
  // Check if event was received
  CheckTrue(EventReceived, 'Authentication event handler should have been called');
  // Success will likely be false due to invalid token, but that's expected
  
  // Remove event handler
  FAuthService.RemoveEventHandler(AuthEventHandler);
  
  // Reset and test that handler is no longer called
  EventReceived := False;
  FAuthService.SignOut;
  CheckFalse(EventReceived, 'Event handler should not be called after removal');
end;

initialization
  RegisterTest('CopilotExtension.Services', TAuthenticationServiceTest.Suite);

end.
