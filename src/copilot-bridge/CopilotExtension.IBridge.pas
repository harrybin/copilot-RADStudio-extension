unit CopilotExtension.IBridge;

{
  RAD Studio Copilot Extension - Bridge Interface
  
  This unit defines the interfaces for communicating with GitHub Copilot
  services from within the RAD Studio IDE.
}

interface

uses
  System.Classes, System.SysUtils, System.JSON, CopilotExtension.IToolsAPI;

type
  // Response status enumeration
  TCopilotResponseStatus = (crsSuccess, crsError, crsPending, crsTimeout);

  // Bridge event types
  TCopilotBridgeEvent = (
    cbeInitialized,
    cbeFinalized,
    cbeAuthenticated,
    cbeSignedOut,
    cbeError,
    cbeStatusChanged
  );

  // Bridge event handler
  TCopilotBridgeEventHandler = procedure(Event: TCopilotBridgeEvent; const Data: string) of object;

  // Chat message structure
  TCopilotChatMessage = record
    Role: string;        // 'user', 'assistant', 'system'
    Content: string;     // Message content
    Timestamp: TDateTime; // When the message was created
  end;

  // Response structure
  TCopilotResponse = record
    Status: TCopilotResponseStatus;
    Content: string;
    ErrorMessage: string;
    RequestId: string;
    TokensUsed: Integer;
  end;



  // Forward declarations
  ICopilotBridge = interface;
  ICopilotChatSession = interface;

  // Callback interface for async responses
  ICopilotBridgeCallback = interface
    ['{A1B2C3D4-E5F6-7890-1234-56789ABCDEF0}']
    procedure OnResponse(const Response: TCopilotResponse);
    procedure OnError(const ErrorMessage: string);
    procedure OnStatusUpdate(const Status: string);
  end;

  // Chat session interface
  ICopilotChatSession = interface
    ['{C1D2E3F4-A5B6-7890-1234-56789ABCDEF1}']
    function SendMessage(const Message: string; const Context: TCopilotCodeContext): TCopilotResponse;
    function SendMessageAsync(const Message: string; const Context: TCopilotCodeContext; 
      const Callback: ICopilotBridgeCallback): Boolean;
    function GetChatHistory: TArray<TCopilotChatMessage>;
    procedure ClearHistory;
    function GetSessionId: string;
  end;

  // Main bridge interface
  ICopilotBridge = interface
    ['{B2C3D4E5-F6F7-8901-2345-67890ABCDEF1}']
    // Initialization
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    
    // Authentication
    function Authenticate: Boolean;
    function IsAuthenticated: Boolean;
    procedure SignOut;
    
    // Configuration
    procedure SetConfiguration(const Config: TJSONObject);
    function GetConfiguration: TJSONObject;
    
    // Status and error handling
    function GetStatus: string;
    function GetLastError: string;
    
    // Chat functionality
    function CreateChatSession: ICopilotChatSession;
    function SendChatMessage(const Message: string; const Context: string): TCopilotResponse;
    function SendChatMessageAsync(const Message: string; const Context: string; 
      const Callback: ICopilotBridgeCallback): Boolean;
  end;

  // Factory interface for creating bridge instances
  ICopilotBridgeFactory = interface
    ['{D3E4F5A6-B7C8-9012-3456-789ABCDEF012}']
    function CreateBridge: ICopilotBridge;
  end;

implementation

end.
