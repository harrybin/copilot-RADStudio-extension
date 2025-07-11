unit CopilotExtension.ToolsAPI.Implementation;

{
  RAD Studio Copilot Extension - Tools API Implementation
  
  This unit implements the Tools API interfaces for RAD Studio integration,
  providing menu registration, editor services, and IDE interaction.
}

interface

uses
  ToolsAPI, Windows, SysUtils, Classes, Menus, ActnList,
  CopilotExtension.ToolsAPI.Interfaces,
  CopilotExtension.Services.Core;

type
  // Main Tools API manager class
  TCopilotToolsAPIManager = class(TInterfacedObject, ICopilotToolsAPIService, ICopilotMenuHandler)
  private
    FCoreService: TCopilotCoreService;
    FMenuItems: TList;
    FNotifierIndex: Integer;
    FEditorNotifier: ICopilotEditorNotifier;
    FProjectNotifier: ICopilotProjectNotifier;
    
    procedure CreateMenuItems;
    procedure DestroyMenuItems;
    function GetNTAServices: INTAServices;
    function GetToolsMenuItem: TMenuItem;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ICopilotToolsAPIService implementation
    function RegisterMenuItems: Boolean;
    function UnregisterMenuItems: Boolean;
    function RegisterEditorServices: Boolean;
    function UnregisterEditorServices: Boolean;
    function ShowCopilotChat: Boolean;
    function GetCurrentEditor: IOTASourceEditor;
    function GetCurrentProject: IOTAProject;
    
    // ICopilotMenuHandler implementation
    procedure OnCopilotChatExecute(Sender: TObject);
    procedure OnCopilotSettingsExecute(Sender: TObject);
    procedure OnCopilotHelpExecute(Sender: TObject);
    
    // Public methods
    procedure RegisterServices;
    procedure UnregisterServices;
    function GetCodeContext: TCopilotCodeContext;
    
    // Properties
    property CoreService: TCopilotCoreService read FCoreService write FCoreService;
  end;

  // Editor notifier implementation
  TCopilotEditorNotifier = class(TNotifierObject, ICopilotEditorNotifier)
  private
    FToolsAPIManager: TCopilotToolsAPIManager;
  public
    constructor Create(AToolsAPIManager: TCopilotToolsAPIManager);
    
    // ICopilotEditorNotifier implementation
    procedure OnEditorModified(const Editor: IOTASourceEditor);
    procedure OnCursorMoved(const Editor: IOTASourceEditor; Line, Column: Integer);
    procedure OnFileOpened(const Editor: IOTASourceEditor);
    procedure OnFileClosed(const Editor: IOTASourceEditor);
  end;

  // Project notifier implementation
  TCopilotProjectNotifier = class(TNotifierObject, ICopilotProjectNotifier)
  private
    FToolsAPIManager: TCopilotToolsAPIManager;
  public
    constructor Create(AToolsAPIManager: TCopilotToolsAPIManager);
    
    // ICopilotProjectNotifier implementation
    procedure OnProjectOpened(const Project: IOTAProject);
    procedure OnProjectClosed(const Project: IOTAProject);
    procedure OnProjectModified(const Project: IOTAProject);
  end;

implementation

uses
  CopilotExtension.UI.ChatPanel;

{ TCopilotToolsAPIManager }

constructor TCopilotToolsAPIManager.Create;
begin
  inherited Create;
  FMenuItems := TList.Create;
  FNotifierIndex := -1;
end;

destructor TCopilotToolsAPIManager.Destroy;
begin
  UnregisterServices;
  DestroyMenuItems;
  FreeAndNil(FMenuItems);
  inherited Destroy;
end;

procedure TCopilotToolsAPIManager.RegisterServices;
begin
  RegisterMenuItems;
  RegisterEditorServices;
end;

procedure TCopilotToolsAPIManager.UnregisterServices;
begin
  UnregisterEditorServices;
  UnregisterMenuItems;
end;

function TCopilotToolsAPIManager.RegisterMenuItems: Boolean;
var
  NTAServices: INTAServices;
  ToolsMenu: TMenuItem;
  CopilotMenu: TMenuItem;
  ChatMenuItem: TMenuItem;
  SettingsMenuItem: TMenuItem;
  HelpMenuItem: TMenuItem;
  SeparatorMenuItem: TMenuItem;
begin
  Result := False;
  
  try
    NTAServices := GetNTAServices;
    if not Assigned(NTAServices) then
      Exit;
      
    ToolsMenu := GetToolsMenuItem;
    if not Assigned(ToolsMenu) then
      Exit;
    
    // Create main Copilot submenu
    CopilotMenu := TMenuItem.Create(nil);
    CopilotMenu.Caption := '&GitHub Copilot';
    CopilotMenu.Name := 'CopilotMainMenu';
    
    // Create Chat menu item
    ChatMenuItem := TMenuItem.Create(nil);
    ChatMenuItem.Caption := '&Chat...';
    ChatMenuItem.Name := 'CopilotChatMenuItem';
    ChatMenuItem.OnClick := OnCopilotChatExecute;
    ChatMenuItem.ShortCut := TextToShortCut('Ctrl+Alt+C');
    
    // Create Settings menu item
    SettingsMenuItem := TMenuItem.Create(nil);
    SettingsMenuItem.Caption := '&Settings...';
    SettingsMenuItem.Name := 'CopilotSettingsMenuItem';
    SettingsMenuItem.OnClick := OnCopilotSettingsExecute;
    
    // Create separator
    SeparatorMenuItem := TMenuItem.Create(nil);
    SeparatorMenuItem.Caption := '-';
    SeparatorMenuItem.Name := 'CopilotSeparatorMenuItem';
    
    // Create Help menu item
    HelpMenuItem := TMenuItem.Create(nil);
    HelpMenuItem.Caption := '&Help';
    HelpMenuItem.Name := 'CopilotHelpMenuItem';
    HelpMenuItem.OnClick := OnCopilotHelpExecute;
    
    // Add items to submenu
    CopilotMenu.Add(ChatMenuItem);
    CopilotMenu.Add(SettingsMenuItem);
    CopilotMenu.Add(SeparatorMenuItem);
    CopilotMenu.Add(HelpMenuItem);
    
    // Add to Tools menu
    ToolsMenu.Add(CopilotMenu);
    
    // Track menu items for cleanup
    FMenuItems.Add(CopilotMenu);
    FMenuItems.Add(ChatMenuItem);
    FMenuItems.Add(SettingsMenuItem);
    FMenuItems.Add(SeparatorMenuItem);
    FMenuItems.Add(HelpMenuItem);
    
    Result := True;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Menu Registration Error - ' + E.Message);
      end;
    end;
  end;
end;

function TCopilotToolsAPIManager.UnregisterMenuItems: Boolean;
var
  I: Integer;
  MenuItem: TMenuItem;
begin
  Result := False;
  
  try
    // Remove and free all created menu items
    for I := FMenuItems.Count - 1 downto 0 do
    begin
      MenuItem := TMenuItem(FMenuItems[I]);
      if Assigned(MenuItem.Parent) then
        MenuItem.Parent.Remove(MenuItem);
      MenuItem.Free;
    end;
    
    FMenuItems.Clear;
    Result := True;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Menu Unregistration Error - ' + E.Message);
      end;
    end;
  end;
end;

function TCopilotToolsAPIManager.RegisterEditorServices: Boolean;
var
  EditorServices: IOTAEditorServices;
begin
  Result := False;
  
  try
    if not Assigned(BorlandIDEServices) then
      Exit;
      
    EditorServices := BorlandIDEServices as IOTAEditorServices;
    if not Assigned(EditorServices) then
      Exit;
    
    // Create and register notifiers
    FEditorNotifier := TCopilotEditorNotifier.Create(Self);
    FProjectNotifier := TCopilotProjectNotifier.Create(Self);
    
    // Register notifiers with IDE
    FNotifierIndex := EditorServices.AddNotifier(FEditorNotifier);
    
    Result := FNotifierIndex >= 0;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Editor Services Registration Error - ' + E.Message);
      end;
    end;
  end;
end;

function TCopilotToolsAPIManager.UnregisterEditorServices: Boolean;
var
  EditorServices: IOTAEditorServices;
begin
  Result := False;
  
  try
    if (FNotifierIndex >= 0) and Assigned(BorlandIDEServices) then
    begin
      EditorServices := BorlandIDEServices as IOTAEditorServices;
      if Assigned(EditorServices) then
      begin
        EditorServices.RemoveNotifier(FNotifierIndex);
        FNotifierIndex := -1;
      end;
    end;
    
    FEditorNotifier := nil;
    FProjectNotifier := nil;
    
    Result := True;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Editor Services Unregistration Error - ' + E.Message);
      end;
    end;
  end;
end;

function TCopilotToolsAPIManager.ShowCopilotChat: Boolean;
begin
  Result := False;
  
  try
    // TODO: Implement chat panel display
    // This will show the Copilot chat interface
    if Assigned(BorlandIDEServices) then
    begin
      (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
        'Copilot Chat: Feature will be implemented in chat panel');
    end;
    
    Result := True;
    
  except
    on E: Exception do
    begin
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Chat Display Error - ' + E.Message);
      end;
    end;
  end;
end;

function TCopilotToolsAPIManager.GetCurrentEditor: IOTASourceEditor;
var
  EditorServices: IOTAEditorServices;
begin
  Result := nil;
  
  if Assigned(BorlandIDEServices) then
  begin
    EditorServices := BorlandIDEServices as IOTAEditorServices;
    if Assigned(EditorServices) and Assigned(EditorServices.TopBuffer) then
      Result := EditorServices.TopBuffer as IOTASourceEditor;
  end;
end;

function TCopilotToolsAPIManager.GetCurrentProject: IOTAProject;
var
  ModuleServices: IOTAModuleServices;
  ProjectGroup: IOTAProjectGroup;
begin
  Result := nil;
  
  if Assigned(BorlandIDEServices) then
  begin
    ModuleServices := BorlandIDEServices as IOTAModuleServices;
    if Assigned(ModuleServices) then
    begin
      ProjectGroup := ModuleServices.MainProjectGroup;
      if Assigned(ProjectGroup) then
        Result := ProjectGroup.ActiveProject;
    end;
  end;
end;

function TCopilotToolsAPIManager.GetCodeContext: TCopilotCodeContext;
var
  Editor: IOTASourceEditor;
  Project: IOTAProject;
  EditView: IOTAEditView;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  try
    Editor := GetCurrentEditor;
    if Assigned(Editor) then
    begin
      Result.FileName := Editor.FileName;
      
      EditView := Editor.GetEditView(0);
      if Assigned(EditView) then
      begin
        Result.Line := EditView.CursorPos.Line;
        Result.Column := EditView.CursorPos.Col;
        // TODO: Get selected text, current method, current class
      end;
      
      // Determine language based on file extension
      if SameText(ExtractFileExt(Result.FileName), '.pas') or 
         SameText(ExtractFileExt(Result.FileName), '.dpr') or
         SameText(ExtractFileExt(Result.FileName), '.dpk') then
        Result.Language := 'Delphi'
      else if SameText(ExtractFileExt(Result.FileName), '.cpp') or 
              SameText(ExtractFileExt(Result.FileName), '.h') or
              SameText(ExtractFileExt(Result.FileName), '.hpp') then
        Result.Language := 'C++'
      else
        Result.Language := 'Unknown';
    end;
    
    Project := GetCurrentProject;
    if Assigned(Project) then
    begin
      Result.ProjectName := ExtractFileName(Project.FileName);
      // TODO: Determine project type
    end;
    
  except
    on E: Exception do
    begin
      // Log error but don't propagate
      if Assigned(BorlandIDEServices) then
      begin
        (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
          'Copilot Extension: Context Error - ' + E.Message);
      end;
    end;
  end;
end;

procedure TCopilotToolsAPIManager.OnCopilotChatExecute(Sender: TObject);
begin
  ShowCopilotChat;
end;

procedure TCopilotToolsAPIManager.OnCopilotSettingsExecute(Sender: TObject);
begin
  // TODO: Show settings dialog
  if Assigned(BorlandIDEServices) then
  begin
    (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
      'Copilot Settings: Feature will be implemented');
  end;
end;

procedure TCopilotToolsAPIManager.OnCopilotHelpExecute(Sender: TObject);
begin
  // TODO: Show help documentation
  if Assigned(BorlandIDEServices) then
  begin
    (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
      'Copilot Help: Feature will be implemented');
  end;
end;

procedure TCopilotToolsAPIManager.CreateMenuItems;
begin
  // Menu items are created dynamically in RegisterMenuItems
end;

procedure TCopilotToolsAPIManager.DestroyMenuItems;
begin
  // Menu items are destroyed in UnregisterMenuItems
end;

function TCopilotToolsAPIManager.GetNTAServices: INTAServices;
begin
  Result := nil;
  if Assigned(BorlandIDEServices) then
    BorlandIDEServices.QueryInterface(INTAServices, Result);
end;

function TCopilotToolsAPIManager.GetToolsMenuItem: TMenuItem;
var
  NTAServices: INTAServices;
  MainMenu: TMainMenu;
  I: Integer;
begin
  Result := nil;
  
  NTAServices := GetNTAServices;
  if Assigned(NTAServices) then
  begin
    MainMenu := NTAServices.MainMenu;
    if Assigned(MainMenu) then
    begin
      for I := 0 to MainMenu.Items.Count - 1 do
      begin
        if SameText(MainMenu.Items[I].Name, 'ToolsMenu') or
           SameText(MainMenu.Items[I].Caption, '&Tools') then
        begin
          Result := MainMenu.Items[I];
          Break;
        end;
      end;
    end;
  end;
end;

{ TCopilotEditorNotifier }

constructor TCopilotEditorNotifier.Create(AToolsAPIManager: TCopilotToolsAPIManager);
begin
  inherited Create;
  FToolsAPIManager := AToolsAPIManager;
end;

procedure TCopilotEditorNotifier.OnEditorModified(const Editor: IOTASourceEditor);
begin
  // TODO: Handle editor modifications for context awareness
end;

procedure TCopilotEditorNotifier.OnCursorMoved(const Editor: IOTASourceEditor; Line, Column: Integer);
begin
  // TODO: Handle cursor movement for context updates
end;

procedure TCopilotEditorNotifier.OnFileOpened(const Editor: IOTASourceEditor);
begin
  // TODO: Handle file opening events
end;

procedure TCopilotEditorNotifier.OnFileClosed(const Editor: IOTASourceEditor);
begin
  // TODO: Handle file closing events
end;

{ TCopilotProjectNotifier }

constructor TCopilotProjectNotifier.Create(AToolsAPIManager: TCopilotToolsAPIManager);
begin
  inherited Create;
  FToolsAPIManager := AToolsAPIManager;
end;

procedure TCopilotProjectNotifier.OnProjectOpened(const Project: IOTAProject);
begin
  // TODO: Handle project opening events
end;

procedure TCopilotProjectNotifier.OnProjectClosed(const Project: IOTAProject);
begin
  // TODO: Handle project closing events
end;

procedure TCopilotProjectNotifier.OnProjectModified(const Project: IOTAProject);
begin
  // TODO: Handle project modification events
end;

end.
