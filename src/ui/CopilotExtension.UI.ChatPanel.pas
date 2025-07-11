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
  CopilotExtension.Bridge.Interface, CopilotExtension.Services.Core;

type
  TCopilotChatPanel = class(TFrame, ICopilotBridgeCallback)
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
  ToolsAPI, CopilotExtension.Bridge.Implementation, CopilotExtension.ToolsAPI.Implementation;

{ TCopilotChatPanel }

constructor TCopilotChatPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIsProcessing := False;
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
  
  case LowerCase(Role) of
    'user': Prefix := Format('[%s] You: ', [Timestamp]);
    'assistant': Prefix := Format('[%s] Copilot: ', [Timestamp]);
    'system': Prefix := Format('[%s] System: ', [Timestamp]);
  else
    Prefix := Format('[%s] %s: ', [Timestamp, Role]);
  end;
  
  memChatHistory.Lines.Add(Prefix + Message);
  memChatHistory.Lines.Add(''); // Add blank line for readability
  
  // Scroll to bottom
  SendMessage(memChatHistory.Handle, WM_VSCROLL, SB_BOTTOM, 0);
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
begin
  // TODO: Show settings dialog
  ShowMessage('Settings dialog will be implemented');
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
