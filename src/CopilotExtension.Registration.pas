unit CopilotExtension.Registration;

{
  RAD Studio Copilot Extension - Main Registration Unit
  
  This unit handles the registration and initialization of the Copilot extension
  within the RAD Studio IDE using the Tools API.
}

interface

uses
  System.SysUtils, ToolsAPI, Vcl.Menus, Vcl.Dialogs, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Controls;

procedure Register;

implementation

var
  CopilotMenuItem: TMenuItem = nil;
  CopilotMenuHandler: TObject = nil;
  CopilotChatForm: TForm = nil;

// Local class for menu click handler
type
  TMenuHandler = class
  private
    FChatMemo: TMemo;
    FInputEdit: TEdit;
  public
    procedure OnCopilotMenuClick(Sender: TObject);
    procedure OnSendButtonClick(Sender: TObject);
  end;

procedure TMenuHandler.OnCopilotMenuClick(Sender: TObject);
var
  ChatMemo: TMemo;
  InputEdit: TEdit;
  SendButton: TButton;
  Panel: TPanel;
begin
  // Check if chat form already exists
  if Assigned(CopilotChatForm) then
  begin
    // Bring existing form to front
    CopilotChatForm.Show;
    CopilotChatForm.BringToFront;
    Exit;
  end;
  
  // Create new chat form
  CopilotChatForm := TForm.Create(Application);
  try
    CopilotChatForm.Caption := 'GitHub Copilot Chat';
    CopilotChatForm.Width := 600;
    CopilotChatForm.Height := 500;
    CopilotChatForm.Position := poScreenCenter;
    
    // Create chat memo
    ChatMemo := TMemo.Create(CopilotChatForm);
    ChatMemo.Parent := CopilotChatForm;
    ChatMemo.Align := alClient;
    ChatMemo.ReadOnly := True;
    ChatMemo.ScrollBars := ssVertical;
    ChatMemo.Lines.Add('GitHub Copilot Chat Panel');
    ChatMemo.Lines.Add('This is a basic chat interface.');
    ChatMemo.Lines.Add('Full Copilot integration will be implemented next.');
    ChatMemo.Lines.Add('');
    
    // Create input panel
    Panel := TPanel.Create(CopilotChatForm);
    Panel.Parent := CopilotChatForm;
    Panel.Align := alBottom;
    Panel.Height := 60;
    Panel.BevelOuter := bvNone;
    
    // Create input edit
    InputEdit := TEdit.Create(Panel);
    InputEdit.Parent := Panel;
    InputEdit.Left := 8;
    InputEdit.Top := 15;
    InputEdit.Width := 400;
    InputEdit.Text := 'Type your message here...';
    
    // Store references for the send button handler
    FChatMemo := ChatMemo;
    FInputEdit := InputEdit;
    
    // Create send button
    SendButton := TButton.Create(Panel);
    SendButton.Parent := Panel;
    SendButton.Left := 420;
    SendButton.Top := 13;
    SendButton.Width := 75;
    SendButton.Caption := 'Send';
    SendButton.OnClick := OnSendButtonClick;
    
    // Show the form
    CopilotChatForm.Show;
    
  except
    on E: Exception do
    begin
      if Assigned(CopilotChatForm) then
        CopilotChatForm.Free;
      CopilotChatForm := nil;
      ShowMessage('Error creating Copilot Chat panel: ' + E.Message);
    end;
  end;
end;

procedure TMenuHandler.OnSendButtonClick(Sender: TObject);
begin
  if Assigned(FChatMemo) and Assigned(FInputEdit) then
  begin
    FChatMemo.Lines.Add('You: ' + FInputEdit.Text);
    FChatMemo.Lines.Add('Copilot: Feature not yet implemented.');
    FChatMemo.Lines.Add('');
    FInputEdit.Clear;
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

finalization
  if Assigned(CopilotChatForm) then
    CopilotChatForm.Free;
  if Assigned(CopilotMenuItem) then
    CopilotMenuItem.Free;
  if Assigned(CopilotMenuHandler) then
    CopilotMenuHandler.Free;

end.
