unit CopilotExtension.Services.Authentication;

{
  RAD Studio Copilot Extension - Authentication Service
  
  This unit handles GitHub Copilot authentication, token management,
  and integration with GitHub's authentication systems.
}

interface

uses
  System.SysUtils, System.Classes, System.JSON, Winapi.Windows, System.Win.Registry;

type
  // Authentication status
  TCopilotAuthStatus = (
    casNotAuthenticated,
    casAuthenticated,
    casExpired,
    casError
  );

  // Authentication method
  TCopilotAuthMethod = (
    camGitHubOAuth,
    camPersonalAccessToken,
    camDeviceFlow
  );

  // Authentication info record
  TCopilotAuthInfo = record
    Status: TCopilotAuthStatus;
    Method: TCopilotAuthMethod;
    Username: string;
    Email: string;
    ExpiresAt: TDateTime;
    Scopes: TStringList;
  end;

  // Authentication event handler
  TCopilotAuthEventHandler = procedure(Success: Boolean; const ErrorMessage: string) of object;

  // Authentication service class
  TCopilotAuthenticationService = class
  private
    FAuthenticated: Boolean;
    FAuthInfo: TCopilotAuthInfo;
    FToken: string;
    FTokenExpiry: TDateTime;
    FLastError: string;
    FEventHandlers: TList;
    
    // Internal methods
    function LoadStoredCredentials: Boolean;
    procedure SaveCredentials;
    procedure ClearStoredCredentials;
    function ValidateToken(const Token: string): Boolean;
    function RefreshToken: Boolean;
    procedure NotifyAuthResult(Success: Boolean; const ErrorMessage: string);
    function GetRegistryPath: string;
    function EncryptToken(const Token: string): string;
    function DecryptToken(const EncryptedToken: string): string;
    
    // GitHub API methods
    function AuthenticateWithGitHub(const Token: string): Boolean;
    function GetUserInfo(const Token: string): TJSONObject;
    function CheckCopilotSubscription(const Token: string): Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // Authentication methods
    function Authenticate(const Token: string = ''): Boolean;
    function AuthenticateWithOAuth: Boolean;
    function AuthenticateWithDeviceFlow: Boolean;
    procedure SignOut;
    
    // Status methods
    function IsAuthenticated: Boolean;
    function GetAuthStatus: TCopilotAuthStatus;
    function GetAuthInfo: TCopilotAuthInfo;
    function IsTokenExpired: Boolean;
    
    // Token management
    function GetToken: string;
    procedure SetToken(const Token: string);
    function ValidateCurrentToken: Boolean;
    
    // Event management
    procedure AddEventHandler(const Handler: TCopilotAuthEventHandler);
    procedure RemoveEventHandler(const Handler: TCopilotAuthEventHandler);
    
    // Utility methods
    function GetLastError: string;
    procedure ClearError;
    function GetAuthStatusText: string;
  end;

implementation

uses
  Winapi.WinInet, Winapi.ShellAPI, System.IOUtils, System.DateUtils;

{ TCopilotAuthenticationService }

constructor TCopilotAuthenticationService.Create;
begin
  inherited Create;
  FAuthenticated := False;
  FToken := '';
  FTokenExpiry := 0;
  FLastError := '';
  FEventHandlers := TList.Create;
  
  // Initialize auth info
  FillChar(FAuthInfo, SizeOf(FAuthInfo), 0);
  FAuthInfo.Status := casNotAuthenticated;
  FAuthInfo.Scopes := TStringList.Create;
  
  // Try to load stored credentials
  LoadStoredCredentials;
end;

destructor TCopilotAuthenticationService.Destroy;
begin
  FreeAndNil(FAuthInfo.Scopes);
  FreeAndNil(FEventHandlers);
  inherited Destroy;
end;

function TCopilotAuthenticationService.Authenticate(const Token: string): Boolean;
begin
  Result := False;
  ClearError;
  
  try
    if Token <> '' then
    begin
      // Authenticate with provided token
      Result := AuthenticateWithGitHub(Token);
    end
    else if FToken <> '' then
    begin
      // Try with stored token
      if IsTokenExpired then
      begin
        // Try to refresh token
        Result := RefreshToken;
      end
      else
      begin
        // Validate current token
        Result := ValidateCurrentToken;
      end;
    end
    else
    begin
      // No token available, try OAuth flow
      Result := AuthenticateWithOAuth;
    end;
    
    NotifyAuthResult(Result, FLastError);
    
  except
    on E: Exception do
    begin
      FLastError := 'Authentication error: ' + E.Message;
      Result := False;
      NotifyAuthResult(False, FLastError);
    end;
  end;
end;

function TCopilotAuthenticationService.AuthenticateWithOAuth: Boolean;
begin
  Result := False;
  
  // TODO: Implement OAuth flow
  // This would involve:
  // 1. Opening browser to GitHub OAuth URL
  // 2. Handling callback
  // 3. Exchanging code for token
  
  FLastError := 'OAuth authentication not yet implemented. Please use a Personal Access Token.';
end;

function TCopilotAuthenticationService.AuthenticateWithDeviceFlow: Boolean;
begin
  Result := False;
  
  // TODO: Implement device flow
  // This would involve:
  // 1. Getting device code from GitHub
  // 2. Showing user code to user
  // 3. Polling for token
  
  FLastError := 'Device flow authentication not yet implemented. Please use a Personal Access Token.';
end;

procedure TCopilotAuthenticationService.SignOut;
begin
  try
    FAuthenticated := False;
    FToken := '';
    FTokenExpiry := 0;
    
    FAuthInfo.Status := casNotAuthenticated;
    FAuthInfo.Method := camPersonalAccessToken;
    FAuthInfo.Username := '';
    FAuthInfo.Email := '';
    FAuthInfo.ExpiresAt := 0;
    FAuthInfo.Scopes.Clear;
    
    ClearStoredCredentials;
    NotifyAuthResult(False, 'Signed out successfully');
    
  except
    on E: Exception do
    begin
      FLastError := 'Sign out error: ' + E.Message;
    end;
  end;
end;

function TCopilotAuthenticationService.IsAuthenticated: Boolean;
begin
  Result := FAuthenticated and (FToken <> '') and not IsTokenExpired;
end;

function TCopilotAuthenticationService.GetAuthStatus: TCopilotAuthStatus;
begin
  if FAuthenticated and (FToken <> '') then
  begin
    if IsTokenExpired then
      Result := casExpired
    else
      Result := casAuthenticated;
  end
  else if FLastError <> '' then
    Result := casError
  else
    Result := casNotAuthenticated;
end;

function TCopilotAuthenticationService.GetAuthInfo: TCopilotAuthInfo;
begin
  Result := FAuthInfo;
  Result.Status := GetAuthStatus;
end;

function TCopilotAuthenticationService.IsTokenExpired: Boolean;
begin
  Result := (FTokenExpiry > 0) and (Now >= FTokenExpiry);
end;

function TCopilotAuthenticationService.GetToken: string;
begin
  if IsAuthenticated then
    Result := FToken
  else
    Result := '';
end;

procedure TCopilotAuthenticationService.SetToken(const Token: string);
begin
  FToken := Token;
  
  if Token <> '' then
  begin
    // Validate and authenticate with new token
    Authenticate(Token);
  end
  else
  begin
    // Clear authentication
    SignOut;
  end;
end;

function TCopilotAuthenticationService.ValidateCurrentToken: Boolean;
begin
  Result := False;
  
  if FToken = '' then
    Exit;
    
  try
    Result := ValidateToken(FToken);
    
    if Result then
    begin
      FAuthenticated := True;
      FAuthInfo.Status := casAuthenticated;
    end
    else
    begin
      FAuthenticated := False;
      FAuthInfo.Status := casError;
      FLastError := 'Token validation failed';
    end;
    
  except
    on E: Exception do
    begin
      FLastError := 'Token validation error: ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure TCopilotAuthenticationService.AddEventHandler(const Handler: TCopilotAuthEventHandler);
begin
  // TODO: Implement proper event handler storage
end;

procedure TCopilotAuthenticationService.RemoveEventHandler(const Handler: TCopilotAuthEventHandler);
begin
  // TODO: Implement proper event handler removal
end;

function TCopilotAuthenticationService.GetLastError: string;
begin
  Result := FLastError;
end;

procedure TCopilotAuthenticationService.ClearError;
begin
  FLastError := '';
end;

function TCopilotAuthenticationService.GetAuthStatusText: string;
begin
  case GetAuthStatus of
    casNotAuthenticated: Result := 'Not authenticated';
    casAuthenticated: Result := 'Authenticated';
    casExpired: Result := 'Token expired';
    casError: Result := 'Authentication error';
  else
    Result := 'Unknown status';
  end;
end;

// Private methods

function TCopilotAuthenticationService.LoadStoredCredentials: Boolean;
var
  Registry: TRegistry;
  EncryptedToken: string;
  ExpiryStr: string;
begin
  Result := False;
  
  Registry := TRegistry.Create(KEY_READ);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    
    if Registry.OpenKey(GetRegistryPath, False) then
    begin
      try
        if Registry.ValueExists('Token') then
        begin
          EncryptedToken := Registry.ReadString('Token');
          FToken := DecryptToken(EncryptedToken);
        end;
        
        if Registry.ValueExists('TokenExpiry') then
        begin
          ExpiryStr := Registry.ReadString('TokenExpiry');
          if ExpiryStr <> '' then
            FTokenExpiry := StrToDateTimeDef(ExpiryStr, 0);
        end;
        
        if Registry.ValueExists('Username') then
          FAuthInfo.Username := Registry.ReadString('Username');
          
        if Registry.ValueExists('Email') then
          FAuthInfo.Email := Registry.ReadString('Email');
        
        // If we have a token, validate it
        if FToken <> '' then
        begin
          Result := ValidateCurrentToken;
        end;
        
      finally
        Registry.CloseKey;
      end;
    end;
    
  finally
    Registry.Free;
  end;
end;

procedure TCopilotAuthenticationService.SaveCredentials;
var
  Registry: TRegistry;
  EncryptedToken: string;
begin
  if FToken = '' then
    Exit;
    
  Registry := TRegistry.Create(KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    
    if Registry.OpenKey(GetRegistryPath, True) then
    begin
      try
        EncryptedToken := EncryptToken(FToken);
        Registry.WriteString('Token', EncryptedToken);
        
        if FTokenExpiry > 0 then
          Registry.WriteString('TokenExpiry', DateTimeToStr(FTokenExpiry));
          
        Registry.WriteString('Username', FAuthInfo.Username);
        Registry.WriteString('Email', FAuthInfo.Email);
        
      finally
        Registry.CloseKey;
      end;
    end;
    
  finally
    Registry.Free;
  end;
end;

procedure TCopilotAuthenticationService.ClearStoredCredentials;
var
  Registry: TRegistry;
begin
  Registry := TRegistry.Create(KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    
    if Registry.OpenKey(GetRegistryPath, False) then
    begin
      try
        Registry.DeleteValue('Token');
        Registry.DeleteValue('TokenExpiry');
        Registry.DeleteValue('Username');
        Registry.DeleteValue('Email');
      finally
        Registry.CloseKey;
      end;
    end;
    
  finally
    Registry.Free;
  end;
end;

function TCopilotAuthenticationService.ValidateToken(const Token: string): Boolean;
var
  UserInfo: TJSONObject;
begin
  Result := False;
  
  try
    // Get user info to validate token
    UserInfo := GetUserInfo(Token);
    if Assigned(UserInfo) then
    try
      // Token is valid if we can get user info
      Result := True;
      
      // Extract user information
      var LoginValue := UserInfo.GetValue('login');
      if Assigned(LoginValue) then
        FAuthInfo.Username := LoginValue.Value;
        
      var EmailValue := UserInfo.GetValue('email');
      if Assigned(EmailValue) and not EmailValue.Null then
        FAuthInfo.Email := EmailValue.Value;
      
      // Check Copilot subscription
      if not CheckCopilotSubscription(Token) then
      begin
        FLastError := 'GitHub Copilot subscription not found';
        Result := False;
      end;
      
    finally
      UserInfo.Free;
    end
    else
    begin
      FLastError := 'Failed to validate token with GitHub API';
    end;
    
  except
    on E: Exception do
    begin
      FLastError := 'Token validation error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TCopilotAuthenticationService.RefreshToken: Boolean;
begin
  Result := False;
  
  // TODO: Implement token refresh
  // For personal access tokens, this would require re-authentication
  FLastError := 'Token refresh not implemented. Please re-authenticate.';
end;

procedure TCopilotAuthenticationService.NotifyAuthResult(Success: Boolean; const ErrorMessage: string);
begin
  // For now, just skip event notification to avoid casting issues
  // TODO: Implement proper event handler storage and notification
end;

function TCopilotAuthenticationService.GetRegistryPath: string;
begin
  Result := 'Software\RADStudio\CopilotExtension';
end;

function TCopilotAuthenticationService.EncryptToken(const Token: string): string;
begin
  // TODO: Implement proper encryption using Windows DPAPI
  // For now, use simple base64 encoding (not secure!)
  Result := Token; // Placeholder - should implement proper encryption
end;

function TCopilotAuthenticationService.DecryptToken(const EncryptedToken: string): string;
begin
  // TODO: Implement proper decryption using Windows DPAPI
  // For now, assume no encryption was used
  Result := EncryptedToken; // Placeholder - should implement proper decryption
end;

function TCopilotAuthenticationService.AuthenticateWithGitHub(const Token: string): Boolean;
begin
  Result := False;
  
  try
    if ValidateToken(Token) then
    begin
      FToken := Token;
      FAuthenticated := True;
      FAuthInfo.Status := casAuthenticated;
      FAuthInfo.Method := camPersonalAccessToken;
      
      // Save credentials
      SaveCredentials;
      
      Result := True;
    end;
    
  except
    on E: Exception do
    begin
      FLastError := 'GitHub authentication error: ' + E.Message;
    end;
  end;
end;

function TCopilotAuthenticationService.GetUserInfo(const Token: string): TJSONObject;
begin
  Result := nil;
  
  // TODO: Implement actual GitHub API call
  // This is a placeholder implementation
  try
    // Would use WinInet or similar to make HTTP request to:
    // https://api.github.com/user
    // with Authorization: token <token>
    
    // For now, return a placeholder
    Result := TJSONObject.Create;
    Result.AddPair('login', 'placeholder_user');
    Result.AddPair('email', 'user@example.com');
    
  except
    on E: Exception do
    begin
      FLastError := 'Failed to get user info: ' + E.Message;
      FreeAndNil(Result);
    end;
  end;
end;

function TCopilotAuthenticationService.CheckCopilotSubscription(const Token: string): Boolean;
begin
  // TODO: Implement actual Copilot subscription check
  // This would call GitHub API to verify Copilot access
  Result := True; // Placeholder - assume subscription exists
end;

end.
