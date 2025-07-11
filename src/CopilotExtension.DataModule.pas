unit CopilotExtension.DataModule;

{
  RAD Studio Copilot Extension - Main Data Module
  
  This data module serves as the main lifecycle manager for the Copilot extension,
  handling initialization, cleanup, and service registration.
}

interface

uses
  SysUtils, Classes, ToolsAPI,
  CopilotExtension.Services.Core,
  CopilotExtension.Services.Authentication,
  CopilotExtension.ToolsAPI.Implementation;

type
  TCopilotExtensionDM = class(TDataModule)
  private
    FCoreService: TCopilotCoreService;
    FAuthService: TCopilotAuthenticationService;
    FToolsAPIManager: TCopilotToolsAPIManager;
    FServicesRegistered: Boolean;
    
    procedure InitializeServices;
    procedure CleanupServices;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RegisterIDEServices;
    procedure UnregisterIDEServices;
    
    property CoreService: TCopilotCoreService read FCoreService;
    property AuthService: TCopilotAuthenticationService read FAuthService;
    property ToolsAPIManager: TCopilotToolsAPIManager read FToolsAPIManager;
  end;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TCopilotExtensionDM }

constructor TCopilotExtensionDM.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FServicesRegistered := False;
  InitializeServices;
end;

destructor TCopilotExtensionDM.Destroy;
begin
  CleanupServices;
  inherited Destroy;
end;

procedure TCopilotExtensionDM.InitializeServices;
begin
  try
    // Initialize core services
    FCoreService := TCopilotCoreService.Create;
    FAuthService := TCopilotAuthenticationService.Create;
    FToolsAPIManager := TCopilotToolsAPIManager.Create;
    
    // Set up service dependencies
    FCoreService.AuthenticationService := FAuthService;
    FToolsAPIManager.CoreService := FCoreService;
    
  except
    on E: Exception do
    begin
      // Log initialization error
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Initialization Error - ' + E.Message);
      end;
    end;
  end;
end;

procedure TCopilotExtensionDM.CleanupServices;
begin
  try
    if FServicesRegistered then
      UnregisterIDEServices;
      
    FreeAndNil(FToolsAPIManager);
    FreeAndNil(FAuthService);
    FreeAndNil(FCoreService);
  except
    on E: Exception do
    begin
      // Log cleanup error
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Cleanup Error - ' + E.Message);
      end;
    end;
  end;
end;

procedure TCopilotExtensionDM.RegisterIDEServices;
begin
  if FServicesRegistered or not Assigned(FToolsAPIManager) then
    Exit;
    
  try
    // Register menu items, toolbars, and IDE services
    FToolsAPIManager.RegisterServices;
    FServicesRegistered := True;
    
    // Show successful registration message
    if Assigned(BorlandIDEServices) then
    begin
      (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
        'Copilot Extension: Successfully registered IDE services');
    end;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Registration Error - ' + E.Message);
      end;
    end;
  end;
end;

procedure TCopilotExtensionDM.UnregisterIDEServices;
begin
  if not FServicesRegistered or not Assigned(FToolsAPIManager) then
    Exit;
    
  try
    FToolsAPIManager.UnregisterServices;
    FServicesRegistered := False;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Unregistration Error - ' + E.Message);
      end;
    end;
  end;
end;

end.
