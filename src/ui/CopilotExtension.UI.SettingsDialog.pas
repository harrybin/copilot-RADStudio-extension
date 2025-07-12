unit CopilotExtension.UI.SettingsDialog;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, System.JSON, Winapi.Windows;

type
  TfrmCopilotSettings = class(TForm)
  published
    lblGithubUsername: TLabel;
    edtGithubUsername: TEdit;
    lblGithubToken: TLabel;
    edtGithubToken: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FGithubUsername: string;
    FGithubToken: string;
  public
    constructor CreateSettings(AOwner: TComponent; const AGithubUsername, AGithubToken: string); reintroduce;
    function GetGithubConfig: TJSONObject;
  end;

implementation

{$R CopilotExtension.UI.SettingsDialog.dfm}

constructor TfrmCopilotSettings.CreateSettings(AOwner: TComponent; const AGithubUsername, AGithubToken: string);
begin
  inherited Create(AOwner);
  FGithubUsername := AGithubUsername;
  FGithubToken := AGithubToken;
  edtGithubUsername.Text := FGithubUsername;
  edtGithubToken.Text := FGithubToken;
end;

function TfrmCopilotSettings.GetGithubConfig: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('username', edtGithubUsername.Text);
  Result.AddPair('token', edtGithubToken.Text);
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
