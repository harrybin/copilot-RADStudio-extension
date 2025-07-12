unit CopilotExtension.UI.SettingsDialog;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, System.JSON, Winapi.Windows;

type
  TfrmCopilotSettings = class(TForm)
    lblApiEndpoint: TLabel;
    edtApiEndpoint: TEdit;
    lblTimeout: TLabel;
    edtTimeout: TEdit;
    lblRetry: TLabel;
    edtRetry: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FConfig: TJSONObject;
  public
    constructor CreateSettings(AOwner: TComponent; Config: TJSONObject); reintroduce;
    function GetConfig: TJSONObject;
  end;

implementation

{$R CopilotExtension.UI.SettingsDialog.dfm}

constructor TfrmCopilotSettings.CreateSettings(AOwner: TComponent; Config: TJSONObject);
begin
  inherited Create(AOwner);
  FConfig := Config;
  if FConfig <> nil then
  begin
    edtApiEndpoint.Text := FConfig.GetValue<string>('api_endpoint', '');
    edtTimeout.Text := FConfig.GetValue<string>('request_timeout', '30000');
    edtRetry.Text := FConfig.GetValue<string>('retry_attempts', '3');
  end;
end;

function TfrmCopilotSettings.GetConfig: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('api_endpoint', edtApiEndpoint.Text);
  Result.AddPair('request_timeout', TJSONNumber.Create(StrToIntDef(edtTimeout.Text, 30000)));
  Result.AddPair('retry_attempts', TJSONNumber.Create(StrToIntDef(edtRetry.Text, 3)));
end;

procedure TfrmCopilotSettings.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TfrmCopilotSettings.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
