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
  CopilotExtension.UI.DockableWindow;

procedure RegisterCopilotSettingsMenu;

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

procedure RegisterCopilotSettingsMenu;
var
  Svc: INTAServices;
  MainMenu: TMainMenu;
  ToolsMenu: TMenuItem;
  I: Integer;
  MenuItem: TMenuItem;
  SettingsMenuHandler: TSettingsMenuHandler;
begin
  if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, INTAServices, Svc) then
  begin
    MainMenu := Svc.MainMenu;
    ToolsMenu := nil;
    for I := 0 to MainMenu.Items.Count - 1 do
      if SameText(MainMenu.Items[I].Name, 'ToolsMenu') then
        ToolsMenu := MainMenu.Items[I];
    if Assigned(ToolsMenu) then
    begin
      MenuItem := TMenuItem.Create(nil);
      MenuItem.Caption := 'Copilot Settings...';
      SettingsMenuHandler := TSettingsMenuHandler.Create;
      MenuItem.OnClick := SettingsMenuHandler.OnCopilotSettingsClick;
      ToolsMenu.Add(MenuItem);
    end;
  end;
end;

var
  CopilotMenuItem: TMenuItem = nil;
  CopilotMenuHandler: TObject = nil;
  CopilotDockableForm: TCopilotDockableForm = nil;

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
    // Since we simplified the dockable form, let's just use standalone window for now
    if not Assigned(CopilotDockableForm) then
    begin
      try
        // Create the dockable form manager
        CopilotDockableForm := TCopilotDockableForm.Create;
        
        // Show the window
        CopilotDockableForm.ShowWindow;
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
  RegisterCopilotSettingsMenu;
  // Package initialization happens through Register procedure
  Randomize; // Initialize random number generator for simulated responses

finalization
  if Assigned(CopilotDockableForm) then
    CopilotDockableForm.Free;
  if Assigned(CopilotMenuItem) then
    CopilotMenuItem.Free;
  if Assigned(CopilotMenuHandler) then
    CopilotMenuHandler.Free;

end.
