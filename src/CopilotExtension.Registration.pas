unit CopilotExtension.Registration;

{
  RAD Studio Copilot Extension - Main Registration Unit
  
  This unit handles the registration and initialization of the Copilot extension
  within the RAD Studio IDE using the Tools API.
}

interface

uses
  System.SysUtils, ToolsAPI, Vcl.Menus, Vcl.Dialogs;

procedure Register;

implementation

var
  CopilotMenuItem: TMenuItem = nil;
  CopilotMenuHandler: TObject = nil;

// Local class for menu click handler
type
  TMenuHandler = class
    procedure OnCopilotMenuClick(Sender: TObject);
  end;

procedure TMenuHandler.OnCopilotMenuClick(Sender: TObject);
begin
  ShowMessage('Copilot Extension UI is working!');
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

finalization
  if Assigned(CopilotMenuItem) then
    CopilotMenuItem.Free;
  if Assigned(CopilotMenuHandler) then
    CopilotMenuHandler.Free;

end.
