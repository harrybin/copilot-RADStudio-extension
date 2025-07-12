unit CopilotExtension.UI.ChatPanel;

{
  RAD Studio Copilot Extension - Chat Panel UI
  
  This unit implements the chat interface panel that integrates into the
  RAD Studio IDE for GitHub Copilot interactions.
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, 
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Buttons, Vcl.Menus,
  CopilotExtension.IBridge,
  CopilotExtension.Services.Core,
  CopilotExtension.IBridgeImpl; // For TLogLevel and ICopilotLogger

type
  TCopilotChatPanel = class(TFrame, ICopilotBridgeCallback, ICopilotLogger)
    pnlMain: TPanel;
    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlChat: TPanel;
    memChatHistory: TMemo;
    pnlInput: TPanel;
    edtMessage: TEdit;
    btnSend: TButton;
    btnClear: TButton;
    splChatInput: TSplitter;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    pnlToolbar: TPanel;
    btnSettings: TSpeedButton;
    btnHelp: TSpeedButton;
    btnAuth: TSpeedButton;
    pmChatContext: TPopupMenu;
    miCopyResponse: TMenuItem;
    miClearHistory: TMenuItem;
    miSeparator1: TMenuItem;
    miExplainCode: TMenuItem;
    miReviewCode: TMenuItem;
    miRefactorCode: TMenuItem;
    
    procedure btnSendClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure btnAuthClick(Sender: TObject);
    procedure edtMessageKeyPress(Sender: TObject; var Key: Char);
    procedure memChatHistoryContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure miCopyResponseClick(Sender: TObject);
    procedure miClearHistoryClick(Sender: TObject);
    procedure miExplainCodeClick(Sender: TObject);
    procedure miReviewCodeClick(Sender: TObject);
    procedure miRefactorCodeClick(Sender: TObject);
    
  private
    FCopilotBridge: ICopilotBridge;
    FChatSession: ICopilotChatSession;
    FCoreService: TCopilotCoreService;
    FCurrentContext: string;
    FIsProcessing: Boolean;
    
    procedure InitializeCopilotServices;
    procedure UpdateStatusDisplay;
    procedure AddChatMessage(const Message: string; const Role: string);
    procedure SetProcessingState(Processing: Boolean);
    function GetCurrentCodeContext: string;
    procedure HandleAuthenticationResult(Success: Boolean);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    // ICopilotBridgeCallback implementation
    procedure OnResponse(const Response: TCopilotResponse);
    procedure OnError(const ErrorMessage: string);
    procedure OnStatusUpdate(const Status: string);
    
    // ICopilotLogger implementation
    procedure Log(const Level: TLogLevel; const Msg: string);
    
    // Public methods
    procedure SetCoreService(const CoreService: TCopilotCoreService);
    procedure RefreshChatHistory;
    procedure SetCodeContext(const Context: string);
    procedure SendMessage(const Message: string);
    
    // Properties
    property CopilotBridge: ICopilotBridge read FCopilotBridge;
    property ChatSession: ICopilotChatSession read FChatSession;
    property IsProcessing: Boolean read FIsProcessing;
  end;

implementation

{$R *.dfm}

uses
  ToolsAPI, CopilotExtension.IToolsAPIImpl, CopilotExtension.IToolsAPI,
  CopilotExtension.UI.SettingsDialog, System.JSON;

{ TCopilotChatPanel }

constructor TCopilotChatPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIsProcessing := False;
  
  // Set up global logging to use this chat panel
  CopilotExtension.IBridgeImpl.SetGlobalLogger(Self);
  
  InitializeCopilotServices;
  UpdateStatusDisplay;
end;

destructor TCopilotChatPanel.Destroy;
begin
  if Assigned(FChatSession) then
    FChatSession := nil;
    
  if Assigned(FCopilotBridge) then
  begin
    FCopilotBridge.Finalize;
    FCopilotBridge := nil;
  end;
  
  inherited Destroy;
end;

procedure TCopilotChatPanel.InitializeCopilotServices;
var
  BridgeFactory: ICopilotBridgeFactory;
begin
  try
    // Create bridge factory and bridge
    BridgeFactory := TCopilotBridgeFactory.Create;
    FCopilotBridge := BridgeFactory.CreateBridge;
    
    if Assigned(FCopilotBridge) then
    begin
      // Initialize the bridge
      if FCopilotBridge.Initialize then
      begin
        // Create chat session
        FChatSession := FCopilotBridge.CreateChatSession;
        AddChatMessage('Copilot bridge initialized successfully.', 'system');
      end
      else
      begin
        AddChatMessage('Failed to initialize Copilot bridge: ' + FCopilotBridge.GetLastError, 'system');
      end;
    end
    else
    begin
      AddChatMessage('Failed to create Copilot bridge.', 'system');
    end;
    
  except
    on E: Exception do
    begin
      AddChatMessage('Error initializing Copilot services: ' + E.Message, 'system');
    end;
  end;
end;

procedure TCopilotChatPanel.UpdateStatusDisplay;
begin
  if Assigned(FCopilotBridge) then
  begin
    lblStatus.Caption := FCopilotBridge.GetStatus;
    
    // Update button states based on authentication
    btnAuth.Enabled := FCopilotBridge.IsInitialized;
    btnSend.Enabled := FCopilotBridge.IsAuthenticated and not FIsProcessing;
    
    if FCopilotBridge.IsAuthenticated then
      btnAuth.Caption := 'Sign Out'
    else
      btnAuth.Caption := 'Sign In';
  end
  else
  begin
    lblStatus.Caption := 'Copilot services not available';
    btnAuth.Enabled := False;
    btnSend.Enabled := False;
  end;
end;

procedure TCopilotChatPanel.AddChatMessage(const Message: string; const Role: string);
var
  Timestamp: string;
  Prefix: string;
begin
  Timestamp := FormatDateTime('hh:nn:ss', Now);
  
  if LowerCase(Role) = 'user' then
    Prefix := Format('[%s] You: ', [Timestamp])
  else if LowerCase(Role) = 'assistant' then
    Prefix := Format('[%s] Copilot: ', [Timestamp])
  else if LowerCase(Role) = 'system' then
    Prefix := Format('[%s] System: ', [Timestamp])
  else
    Prefix := Format('[%s] %s: ', [Timestamp, Role]);
  
  memChatHistory.Lines.Add(Prefix + Message);
  memChatHistory.Lines.Add(''); // Add blank line for readability
  
  // Scroll to bottom
  Winapi.Windows.SendMessage(memChatHistory.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TCopilotChatPanel.SetProcessingState(Processing: Boolean);
begin
  FIsProcessing := Processing;
  btnSend.Enabled := not Processing and Assigned(FCopilotBridge) and FCopilotBridge.IsAuthenticated;
  edtMessage.Enabled := not Processing;
  
  if Processing then
  begin
    lblStatus.Caption := 'Processing request...';
    btnSend.Caption := 'Processing...';
  end
  else
  begin
    UpdateStatusDisplay;
    btnSend.Caption := 'Send';
  end;
  
  Application.ProcessMessages;
end;

function TCopilotChatPanel.GetCurrentCodeContext: string;
var
  ToolsAPIManager: TCopilotToolsAPIManager;
  CodeContext: TCopilotCodeContext;
begin
  Result := '';
  
  try
    if Assigned(FCoreService) then
    begin
      // Get current code context from Tools API
      // This would be injected from the main extension
      CodeContext := Default(TCopilotCodeContext);
      
      if CodeContext.FileName <> '' then
      begin
        Result := Format('Current file: %s (Line: %d, Column: %d)', 
          [ExtractFileName(CodeContext.FileName), CodeContext.Line, CodeContext.Column]);
          
        if CodeContext.Language <> '' then
          Result := Result + Format(' [%s]', [CodeContext.Language]);
          
        if CodeContext.ProjectName <> '' then
          Result := Result + Format(' Project: %s', [CodeContext.ProjectName]);
      end;
    end;
    
  except
    on E: Exception do
    begin
      Result := 'Error getting code context: ' + E.Message;
    end;
  end;
end;

procedure TCopilotChatPanel.HandleAuthenticationResult(Success: Boolean);
begin
  if Success then
  begin
    AddChatMessage('Successfully authenticated with GitHub Copilot.', 'system');
  end
  else
  begin
    AddChatMessage('Authentication failed: ' + FCopilotBridge.GetLastError, 'system');
  end;
  
  UpdateStatusDisplay;
end;

procedure TCopilotChatPanel.SetCoreService(const CoreService: TCopilotCoreService);
begin
  FCoreService := CoreService;
  if Assigned(FCoreService) then
    AddChatMessage('Debug: Core service has been set successfully.', 'system')
  else
    AddChatMessage('Debug: Core service was set to nil.', 'system');
end;

procedure TCopilotChatPanel.RefreshChatHistory;
var
  History: TArray<TCopilotChatMessage>;
  I: Integer;
begin
  memChatHistory.Clear;
  
  if Assigned(FChatSession) then
  begin
    History := FChatSession.GetChatHistory;
    for I := 0 to High(History) do
    begin
      AddChatMessage(History[I].Content, History[I].Role);
    end;
  end;
end;

procedure TCopilotChatPanel.SetCodeContext(const Context: string);
begin
  FCurrentContext := Context;
  
  if Assigned(FChatSession) then
  begin
    // Update chat session context
    // FChatSession.SetContext(...); // Would need file details
  end;
end;

procedure TCopilotChatPanel.SendMessage(const Message: string);
begin
  if not Assigned(FCopilotBridge) or not FCopilotBridge.IsAuthenticated then
  begin
    AddChatMessage('Please authenticate with GitHub Copilot first.', 'system');
    Exit;
  end;
  
  if Trim(Message) = '' then
    Exit;
    
  // Add user message to chat
  AddChatMessage(Message, 'user');
  
  // Set processing state
  SetProcessingState(True);
  
  try
    // Get current context
    var Context := GetCurrentCodeContext;
    if FCurrentContext <> '' then
      Context := Context + sLineBreak + FCurrentContext;
    
    // Send message asynchronously
    FCopilotBridge.SendChatMessageAsync(Message, Context, Self);
    
  except
    on E: Exception do
    begin
      SetProcessingState(False);
      AddChatMessage('Error sending message: ' + E.Message, 'system');
    end;
  end;
end;

// ICopilotBridgeCallback implementation

procedure TCopilotChatPanel.OnResponse(const Response: TCopilotResponse);
begin
  SetProcessingState(False);
  
  if Response.Status = crsSuccess then
  begin
    AddChatMessage(Response.Content, 'assistant');
  end
  else
  begin
    AddChatMessage('Error: ' + Response.ErrorMessage, 'system');
  end;
end;

procedure TCopilotChatPanel.OnError(const ErrorMessage: string);
begin
  SetProcessingState(False);
  AddChatMessage('Error: ' + ErrorMessage, 'system');
end;

procedure TCopilotChatPanel.OnStatusUpdate(const Status: string);
begin
  lblStatus.Caption := Status;
end;

procedure TCopilotChatPanel.Log(const Level: TLogLevel; const Msg: string);
var
  Role: string;
  FilteredMsg: string;
begin
  // Convert log level to role for chat display
  case Level of
    llDebug:   Role := 'debug';
    llInfo:    Role := 'info';
    llWarning: Role := 'warning';
    llError:   Role := 'error';
  else
    Role := 'log';
  end;
  
  // Temporarily show all messages for debugging access violations
  // Filter messages to avoid spam - only show warnings and errors by default
  // You can comment out this filter to see all debug messages
  if Level in [llDebug, llInfo, llWarning, llError] then // Show all for debugging
  begin
    FilteredMsg := Msg;
    AddChatMessage(FilteredMsg, Role);
  end;
end;

// Event handlers

procedure TCopilotChatPanel.btnSendClick(Sender: TObject);
var
  Message: string;
begin
  Message := Trim(edtMessage.Text);
  if Message <> '' then
  begin
    SendMessage(Message);
    edtMessage.Clear;
  end;
end;

procedure TCopilotChatPanel.btnClearClick(Sender: TObject);
begin
  if MessageDlg('Clear chat history?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    memChatHistory.Clear;
    if Assigned(FChatSession) then
      FChatSession.ClearHistory;
  end;
end;

procedure TCopilotChatPanel.btnSettingsClick(Sender: TObject);
var
  SettingsDialog: TfrmCopilotSettings;
  CurrentConfig: TJSONObject;
  NewConfig: TJSONObject;
  GitHubUsername: string;
  GitHubToken: string;
begin
  try
    // Debug: Check if core service is available
    if not Assigned(FCoreService) then
    begin
      AddChatMessage('Debug: Core service is not assigned to ChatPanel.', 'system');
      AddChatMessage('Unable to access settings: Core service not available.', 'system');
      Exit;
    end;
    
    AddChatMessage('Debug: Core service is available, getting configuration...', 'system');
    
    // Get current configuration from core service
    CurrentConfig := nil;
    if Assigned(FCoreService) then
      CurrentConfig := FCoreService.GetConfiguration;
    
    // Extract GitHub settings or use defaults
    GitHubUsername := '';
    GitHubToken := '';
    
    if Assigned(CurrentConfig) then
    begin
      if CurrentConfig.GetValue('github_username') <> nil then
        GitHubUsername := CurrentConfig.GetValue('github_username').Value;
      if CurrentConfig.GetValue('github_token') <> nil then
        GitHubToken := CurrentConfig.GetValue('github_token').Value;
    end;
    
    // Create and show settings dialog
    SettingsDialog := TfrmCopilotSettings.CreateSettings(Self, GitHubUsername, GitHubToken);
    try
      if SettingsDialog.ShowModal = mrOk then
      begin
        // Get new configuration from dialog
        NewConfig := SettingsDialog.GetGithubConfig;
        try
          // Update core service configuration
          if Assigned(FCoreService) then
          begin
            FCoreService.SetConfigValue('github_username', NewConfig.GetValue('username').Value);
            FCoreService.SetConfigValue('github_token', NewConfig.GetValue('token').Value);
            AddChatMessage('Settings updated successfully.', 'system');
            
            // Update display to reflect any changes
            UpdateStatusDisplay;
          end
          else
          begin
            AddChatMessage('Unable to save settings: Core service not available.', 'system');
          end;
        finally
          NewConfig.Free;
        end;
      end;
    finally
      SettingsDialog.Free;
    end;
    
  except
    on E: Exception do
    begin
      AddChatMessage('Error opening settings dialog: ' + E.Message, 'system');
    end;
  end;
end;

procedure TCopilotChatPanel.btnHelpClick(Sender: TObject);
begin
  // TODO: Show help documentation
  ShowMessage('Help documentation will be implemented');
end;

procedure TCopilotChatPanel.btnAuthClick(Sender: TObject);
begin
  if not Assigned(FCopilotBridge) then
    Exit;
    
  if FCopilotBridge.IsAuthenticated then
  begin
    // Sign out
    FCopilotBridge.SignOut;
    AddChatMessage('Signed out from GitHub Copilot.', 'system');
  end
  else
  begin
    // Sign in
    SetProcessingState(True);
    try
      var Success := FCopilotBridge.Authenticate;
      HandleAuthenticationResult(Success);
    finally
      SetProcessingState(False);
    end;
  end;
  
  UpdateStatusDisplay;
end;

procedure TCopilotChatPanel.edtMessageKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and not FIsProcessing then // Enter key
  begin
    Key := #0; // Consume the key
    btnSendClick(nil);
  end;
end;

procedure TCopilotChatPanel.memChatHistoryContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
begin
  // Enable/disable context menu items based on state
  miCopyResponse.Enabled := memChatHistory.SelLength > 0;
  miClearHistory.Enabled := memChatHistory.Lines.Count > 0;
  miExplainCode.Enabled := FCopilotBridge.IsAuthenticated;
  miReviewCode.Enabled := FCopilotBridge.IsAuthenticated;
  miRefactorCode.Enabled := FCopilotBridge.IsAuthenticated;
end;

procedure TCopilotChatPanel.miCopyResponseClick(Sender: TObject);
begin
  if memChatHistory.SelLength > 0 then
    memChatHistory.CopyToClipboard;
end;

procedure TCopilotChatPanel.miClearHistoryClick(Sender: TObject);
begin
  btnClearClick(nil);
end;

procedure TCopilotChatPanel.miExplainCodeClick(Sender: TObject);
begin
  SendMessage('Please explain the current code selection.');
end;

procedure TCopilotChatPanel.miReviewCodeClick(Sender: TObject);
begin
  SendMessage('Please review the current code and suggest improvements.');
end;

procedure TCopilotChatPanel.miRefactorCodeClick(Sender: TObject);
begin
  SendMessage('Please suggest refactoring opportunities for the current code.');
end;

end.
