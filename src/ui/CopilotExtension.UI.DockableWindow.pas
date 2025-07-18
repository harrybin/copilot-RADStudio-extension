unit CopilotExtension.UI.DockableWindow;

{
  RAD Studio Copilot Extension - Dockable Window Implementation
  
  This unit implements a dockable window that can be integrated into the
  RAD Studio IDE's docking system.
}

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, ToolsAPI,
  Vcl.ActnList, Vcl.ImgList, Vcl.Menus, Vcl.ComCtrls, System.IniFiles,
  CopilotExtension.UI.ChatPanel, CopilotExtension.Services.Core;

type
  // Type aliases for missing ToolsAPI types
  TEditState = set of (esCanUndo, esCanRedo, esCanCut, esCanCopy, esCanPaste, esCanSelectAll);
  TEditAction = (eaCut, eaCopy, eaPaste, eaSelectAll, eaUndo, eaRedo);

  // Simple dockable form implementation
  TCopilotDockableWindow = class(TForm)
  private
    FChatPanel: TCopilotChatPanel;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property ChatPanel: TCopilotChatPanel read FChatPanel;
  end;

  // Dockable form manager - simplified for now
  TCopilotDockableForm = class(TInterfacedObject)
  private
    FForm: TCopilotDockableWindow;
    FChatPanel: TCopilotChatPanel;
    FCoreService: TCopilotCoreService; // Store the core service
  public
    constructor Create;
    destructor Destroy; override;
    
    // Basic methods
    function GetCaption: string;
    function GetIdentifier: string;
    procedure ShowWindow;
    procedure HideWindow;
    procedure SetCoreService(const CoreService: TCopilotCoreService);
    
    // Properties
    property ChatPanel: TCopilotChatPanel read FChatPanel;
  end;

implementation

{ TCopilotDockableWindow }

constructor TCopilotDockableWindow.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // Use CreateNew to avoid loading form resource
  
  // Set up the form properties
  Caption := 'GitHub Copilot Chat';
  Width := 400;
  Height := 600;
  BorderStyle := bsSizeToolWin;
  FormStyle := fsNormal; // Changed from fsStayOnTop to fsNormal
  Position := poScreenCenter;
  
  // Create the chat panel
  FChatPanel := TCopilotChatPanel.Create(Self);
  FChatPanel.Parent := Self;
  FChatPanel.Align := alClient;
end;

destructor TCopilotDockableWindow.Destroy;
begin
  if Assigned(FChatPanel) then
    FChatPanel.Free;
  inherited Destroy;
end;

{ TCopilotDockableForm }

constructor TCopilotDockableForm.Create;
begin
  inherited Create;
  FForm := nil;
  FChatPanel := nil;
  FCoreService := nil;
end;

destructor TCopilotDockableForm.Destroy;
begin
  if Assigned(FForm) then
    FForm.Free;
  inherited Destroy;
end;

function TCopilotDockableForm.GetCaption: string;
begin
  Result := 'GitHub Copilot Chat';
end;

function TCopilotDockableForm.GetIdentifier: string;
begin
  Result := 'CopilotExtension.ChatWindow';
end;

procedure TCopilotDockableForm.ShowWindow;
begin
  if not Assigned(FForm) then
  begin
    FForm := TCopilotDockableWindow.Create(nil);
    FChatPanel := FForm.ChatPanel;
    
    // Now that we have the ChatPanel, inject the Core service if available
    if Assigned(FCoreService) and Assigned(FChatPanel) then
      FChatPanel.SetCoreService(FCoreService);
  end;
  FForm.Show;
end;

procedure TCopilotDockableForm.HideWindow;
begin
  if Assigned(FForm) then
    FForm.Hide;
end;

procedure TCopilotDockableForm.SetCoreService(const CoreService: TCopilotCoreService);
begin
  FCoreService := CoreService;
  
  // If the ChatPanel is already created, inject the service immediately
  if Assigned(FChatPanel) then
  begin
    FChatPanel.SetCoreService(CoreService);
    // Add debug message to verify injection
    if Assigned(CoreService) then
      // Note: We can't easily add chat message here since it would be circular
      // The debug message will be added by the ChatPanel's SetCoreService method
    else
      // Same here - ChatPanel will handle the debug message
  end;
end;

end.
