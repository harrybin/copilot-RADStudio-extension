unit CopilotExtension.Registration;

{
  RAD Studio Copilot Extension - Main Registration Unit
  
  This unit handles the registration and initialization of the Copilot extension
  within the RAD Studio IDE using the Tools API.
}

interface
uses
  System.SysUtils, ToolsAPI, Vcl.Menus, Vcl.Dialogs, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Controls,
  System.Threading, System.Classes, Winapi.Windows, Winapi.Messages,
  CopilotExtension.UI.DockableWindow, CopilotExtension.Services.Core;

procedure Register;

implementation

uses
  CopilotExtension.IBridgeImpl;

type
// Local class for settings menu click handler
  TSettingsMenuHandler = class
  public
    procedure OnCopilotSettingsClick(Sender: TObject);
  end;

procedure TSettingsMenuHandler.OnCopilotSettingsClick(Sender: TObject);
var
  Bridge: TCopilotBridge;
begin
  Bridge := TCopilotBridge.Create;
  try
    Bridge.Initialize;
    Bridge.ShowSettingsDialog;
  finally
    Bridge.Free;
  end;
end;

var
  CopilotMenuItem: TMenuItem = nil;
  CopilotMenuHandler: TObject = nil;
  CopilotDockableForm: TCopilotDockableForm = nil;
  CopilotCoreService: TCopilotCoreService = nil;

// Local class for menu click handler
type
  TMenuHandler = class
  public
    procedure OnCopilotMenuClick(Sender: TObject);
  end;

procedure TMenuHandler.OnCopilotMenuClick(Sender: TObject);
var
  StandaloneWindow: TCopilotDockableWindow;
begin
  try
    // Ensure we have a Core service instance
    if not Assigned(CopilotCoreService) then
    begin
      CopilotCoreService := TCopilotCoreService.Create;
      CopilotCoreService.Initialize;
    end;
    
    // Since we simplified the dockable form, let's just use standalone window for now
    if not Assigned(CopilotDockableForm) then
    begin
      try
        // Create the dockable form manager
        CopilotDockableForm := TCopilotDockableForm.Create;
        
        // Show the window first to create the ChatPanel
        CopilotDockableForm.ShowWindow;
        
        // Then inject the Core service
        CopilotDockableForm.SetCoreService(CopilotCoreService);
        
        Exit;
      except
        on E: Exception do
        begin
          // If creation fails, clean up
          if Assigned(CopilotDockableForm) then
          begin
            CopilotDockableForm.Free;
            CopilotDockableForm := nil;
          end;
        end;
      end;
    end
    else
    begin
      // Show existing window
      CopilotDockableForm.ShowWindow;
      Exit;
    end;

    // Fallback: Create standalone window
    StandaloneWindow := TCopilotDockableWindow.Create(nil);
    StandaloneWindow.FormStyle := fsNormal;
    StandaloneWindow.Show;
    
  except
    on E: Exception do
      ShowMessage('Error opening Copilot Chat: ' + E.Message);
  end;
end;

procedure Register;
var
  ToolsMenu: TMenuItem;
  MainMenu: TMainMenu;
  I: Integer;
  Svc: INTAServices;
begin
  if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, INTAServices, Svc) then
  begin
    (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
      'Copilot Extension for RAD Studio by harrybin loaded successfully');
    MainMenu := Svc.MainMenu;
    ToolsMenu := nil;
    for I := 0 to MainMenu.Items.Count - 1 do
      if SameText(MainMenu.Items[I].Name, 'ToolsMenu') then
        ToolsMenu := MainMenu.Items[I];
    if Assigned(ToolsMenu) then
    begin
      CopilotMenuItem := TMenuItem.Create(nil);
      CopilotMenuItem.Caption := 'Copilot Chat';
      CopilotMenuHandler := TMenuHandler.Create;
      CopilotMenuItem.OnClick := TMenuHandler(CopilotMenuHandler).OnCopilotMenuClick;
      ToolsMenu.Add(CopilotMenuItem);
    end;
  end;
end;

initialization
  // Package initialization happens through Register procedure
  Randomize; // Initialize random number generator for simulated responses

finalization
  if Assigned(CopilotDockableForm) then
    CopilotDockableForm.Free;
  if Assigned(CopilotCoreService) then
  begin
    CopilotCoreService.Finalize;
    CopilotCoreService.Free;
  end;
  if Assigned(CopilotMenuItem) then
    CopilotMenuItem.Free;
  if Assigned(CopilotMenuHandler) then
    CopilotMenuHandler.Free;

end.
