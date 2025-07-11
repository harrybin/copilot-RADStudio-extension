unit CopilotExtension.ToolsAPI.Interfaces;

{
  RAD Studio Copilot Extension - Tools API Interface Definitions
  
  This unit defines the interfaces for interacting with RAD Studio's Tools API,
  including OTA (Open Tools API) and NTA (Native Tools API) interfaces.
}

interface

uses
  ToolsAPI, System.SysUtils;

type
  // Forward declarations
  ICopilotMenuHandler = interface;
  ICopilotEditorNotifier = interface;
  ICopilotProjectNotifier = interface;

  // Main Copilot service interface
  ICopilotToolsAPIService = interface
    ['{B8E7F0C1-2E4A-4D5B-9F3C-1A8E7F0C1234}']
    function RegisterMenuItems: Boolean;
    function UnregisterMenuItems: Boolean;
    function RegisterEditorServices: Boolean;
    function UnregisterEditorServices: Boolean;
    function ShowCopilotChat: Boolean;
    function GetCurrentEditor: IOTASourceEditor;
    function GetCurrentProject: IOTAProject;
  end;

  // Menu handler interface
  ICopilotMenuHandler = interface
    ['{C9F8E1D2-3F5B-4E6C-AF4D-2B9F8E1D2345}']
    procedure OnCopilotChatExecute(Sender: TObject);
    procedure OnCopilotSettingsExecute(Sender: TObject);
    procedure OnCopilotHelpExecute(Sender: TObject);
  end;

  // Editor notifier interface for code context
  ICopilotEditorNotifier = interface(IOTANotifier)
    ['{DAE9F2E3-4F6C-5F7D-BF5E-3CAE9F2E3456}']
    procedure OnEditorModified(const Editor: IOTASourceEditor);
    procedure OnCursorMoved(const Editor: IOTASourceEditor; Line, Column: Integer);
    procedure OnFileOpened(const Editor: IOTASourceEditor);
    procedure OnFileClosed(const Editor: IOTASourceEditor);
  end;

  // Project notifier interface for project context
  ICopilotProjectNotifier = interface(IOTANotifier)
    ['{EBF0A3F4-5F7D-6F8E-CF6F-4DBF0A3F4567}']
    procedure OnProjectOpened(const Project: IOTAProject);
    procedure OnProjectClosed(const Project: IOTAProject);
    procedure OnProjectModified(const Project: IOTAProject);
  end;

  // Code context information
  TCopilotCodeContext = record
    FileName: string;
    Line: Integer;
    Column: Integer;
    SelectedText: string;
    CurrentMethod: string;
    CurrentClass: string;
    ProjectName: string;
    ProjectType: string;
    Language: string; // 'Delphi' or 'C++'
  end;

  // Copilot message types
  TCopilotMessageType = (cmtInfo, cmtWarning, cmtError, cmtSuccess);

  // Message service interface
  ICopilotMessageService = interface
    ['{FCE1B4F5-6F8E-7F9F-DF7F-5ECE1B4F5678}']
    procedure ShowMessage(const Message: string; MessageType: TCopilotMessageType);
    procedure ShowInMessageWindow(const Message: string);
    procedure LogError(const ErrorMessage: string; const Exception: Exception = nil);
  end;

implementation

end.
