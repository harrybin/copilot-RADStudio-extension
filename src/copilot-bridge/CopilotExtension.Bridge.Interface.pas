unit CopilotBridgeIntf;

interface

type
  ICopilotBridge = interface
    ['{B2C3D4E5-F6F7-8901-2345-67890ABCDEF1}']
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
  end;

implementation

end.
