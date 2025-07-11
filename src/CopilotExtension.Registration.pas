unit CopilotExtension.Registration;

{
  RAD Studio Copilot Extension - Main Registration Unit
  
  This unit handles the registration and initialization of the Copilot extension
  within the RAD Studio IDE using the Tools API.
}

interface

uses
  ToolsAPI;

procedure Register;

implementation

procedure Register;
begin
  // TODO: Initialize the Copilot extension
  // For now, just register a message to indicate the extension loaded
  if Assigned(BorlandIDEServices) then
  begin
    (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
      'RAD Studio Copilot Extension loaded successfully');
  end;
end;

initialization
  // Package initialization - register the extension
  Register;

finalization
  // Package cleanup
  if Assigned(BorlandIDEServices) then
  begin
    try
      (BorlandIDEServices as IOTAMessageServices).AddTitleMessage(
        'RAD Studio Copilot Extension unloaded');
    except
      // Ignore errors if IDE services are already released
    end;
  end;

end.
