unit CopilotExtension.Registration;

{
  RAD Studio Copilot Extension - Main Registration Unit
  
  This unit handles the registration and initialization of the Copilot extension
  within the RAD Studio IDE using the Tools API.
}

interface

uses
  System.SysUtils, ToolsAPI, Vcl.Menus, Vcl.Dialogs, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Controls,
  System.Threading, System.Classes, Winapi.Windows, Winapi.Messages;

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
    FSendButton: TButton;
    FIsProcessing: Boolean;
    
    procedure SimulateCopilotResponse(const UserMessage: string);
    procedure SetProcessingState(Processing: Boolean);
    function GetCodeContext: string;
    function GenerateResponse(const Message: string): string;
  public
    procedure OnCopilotMenuClick(Sender: TObject);
    procedure OnSendButtonClick(Sender: TObject);
    procedure OnInputKeyPress(Sender: TObject; var Key: Char);
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
    ChatMemo.Font.Name := 'Consolas';
    ChatMemo.Font.Size := 9;
    ChatMemo.Lines.Add('=== GitHub Copilot Chat for RAD Studio ===');
    ChatMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] System: Welcome to GitHub Copilot Chat!');
    ChatMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] System: I can help you with Delphi/Pascal code questions.');
    ChatMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] System: Try asking: "Help", "Explain this code", or "Review my code"');
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
    InputEdit.OnKeyPress := OnInputKeyPress;
    
    // Store references for the send button handler
    FChatMemo := ChatMemo;
    FInputEdit := InputEdit;
    FIsProcessing := False;
    
    // Create send button
    SendButton := TButton.Create(Panel);
    SendButton.Parent := Panel;
    SendButton.Left := 420;
    SendButton.Top := 13;
    SendButton.Width := 75;
    SendButton.Caption := 'Send';
    SendButton.OnClick := OnSendButtonClick;
    FSendButton := SendButton;
    
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
var
  UserMessage: string;
begin
  if FIsProcessing then Exit;
  
  if Assigned(FChatMemo) and Assigned(FInputEdit) then
  begin
    UserMessage := Trim(FInputEdit.Text);
    if UserMessage = '' then Exit;
    
    // Add user message
    FChatMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] You: ' + UserMessage);
    FChatMemo.Lines.Add('');
    FInputEdit.Clear;
    
    // Scroll to bottom
    FChatMemo.Perform(WM_VSCROLL, SB_BOTTOM, 0);
    
    // Simulate processing delay and response
    SimulateCopilotResponse(UserMessage);
  end;
end;

procedure TMenuHandler.OnInputKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and not FIsProcessing then // Enter key
  begin
    Key := #0; // Consume the key
    OnSendButtonClick(nil);
  end;
end;

procedure TMenuHandler.SetProcessingState(Processing: Boolean);
begin
  FIsProcessing := Processing;
  if Assigned(FSendButton) then
  begin
    FSendButton.Enabled := not Processing;
    if Processing then
      FSendButton.Caption := 'Processing...'
    else
      FSendButton.Caption := 'Send';
  end;
  if Assigned(FInputEdit) then
    FInputEdit.Enabled := not Processing;
end;

function TMenuHandler.GetCodeContext: string;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  FileName: string;
begin
  Result := '';
  try
    if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    begin
      Module := ModuleServices.CurrentModule;
      if Assigned(Module) and (Module.ModuleFileCount > 0) then
      begin
        FileName := Module.FileName;
        Result := Format('Current file: %s', [ExtractFileName(FileName)]);
        // Simplified approach - just show file info without detailed editor context
        Result := Result + ' [Editor context temporarily unavailable]';
      end;
    end;
  except
    on E: Exception do
      Result := 'Unable to get code context: ' + E.Message;
  end;
end;

function TMenuHandler.GenerateResponse(const Message: string): string;
var
  LowerMsg: string;
begin
  LowerMsg := LowerCase(Message);
  
  // Generate contextual responses based on message content
  if Pos('hello', LowerMsg) > 0 then
    Result := 'Hello! I''m GitHub Copilot integrated into RAD Studio. How can I help you with your Delphi/Pascal code today?'
  else if Pos('help', LowerMsg) > 0 then
    Result := 'I can help you with:' + sLineBreak +
              '• Code explanations and documentation' + sLineBreak +
              '• Code reviews and suggestions' + sLineBreak +
              '• Refactoring recommendations' + sLineBreak +
              '• Bug fixes and optimizations' + sLineBreak +
              '• Best practices for Delphi/Pascal development'
  else if (Pos('explain', LowerMsg) > 0) or (Pos('what', LowerMsg) > 0) then
    Result := 'I''d be happy to explain code for you! Please select the code you want me to explain in the editor, or paste it in your message.'
  else if Pos('review', LowerMsg) > 0 then
    Result := 'I can review your code for potential improvements. Please share the code you''d like me to review.'
  else if Pos('refactor', LowerMsg) > 0 then
    Result := 'I can suggest refactoring opportunities. Please provide the code you''d like to improve.'
  else if (Pos('bug', LowerMsg) > 0) or (Pos('error', LowerMsg) > 0) or (Pos('fix', LowerMsg) > 0) then
    Result := 'I can help debug issues! Please describe the problem or share the error message and relevant code.'
  else if Pos('delphi', LowerMsg) > 0 then
    Result := 'Great! I''m well-versed in Delphi and Object Pascal. What specific Delphi topic would you like help with?'
  else if Pos('pascal', LowerMsg) > 0 then
    Result := 'Object Pascal is a powerful language! I can help with syntax, best practices, or specific programming challenges.'
  else
    Result := 'I understand you''re asking: "' + Message + '"' + sLineBreak + sLineBreak +
              'I''m a simulated Copilot response for demonstration. In the full implementation, I would:' + sLineBreak +
              '• Connect to GitHub Copilot API' + sLineBreak +
              '• Analyze your current code context' + sLineBreak +
              '• Provide intelligent, context-aware responses' + sLineBreak + sLineBreak +
              'Current context: ' + GetCodeContext;
end;

procedure TMenuHandler.SimulateCopilotResponse(const UserMessage: string);
begin
  SetProcessingState(True);
  TThread.CreateAnonymousThread(
    procedure
    var
      Response: string;
    begin
      Sleep(1000 + Random(2000)); // 1-3 seconds
      Response := GenerateResponse(UserMessage);
      TThread.Queue(nil, 
        procedure
        begin
          if Assigned(FChatMemo) then
          begin
            FChatMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss', Now) + '] Copilot: ' + Response);
            FChatMemo.Lines.Add('');
            FChatMemo.Perform(WM_VSCROLL, SB_BOTTOM, 0);
          end;
          SetProcessingState(False);
        end
      );
    end
  ).Start;
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
  if Assigned(CopilotChatForm) then
    CopilotChatForm.Free;
  if Assigned(CopilotMenuItem) then
    CopilotMenuItem.Free;
  if Assigned(CopilotMenuHandler) then
    CopilotMenuHandler.Free;

end.
