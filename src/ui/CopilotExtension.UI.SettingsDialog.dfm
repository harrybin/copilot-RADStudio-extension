object frmCopilotSettings: TfrmCopilotSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'GitHub Copilot Settings'
  ClientHeight = 160
  ClientWidth = 360
  Position = poScreenCenter
  Font.Name = 'Segoe UI'
  Font.Size = 10
  PixelsPerInch = 96
  TextHeight = 13
  object lblGithubUsername: TLabel
    Left = 16
    Top = 16
    Width = 95
    Height = 13
    Caption = 'GitHub Username:'
  end
  object edtGithubUsername: TEdit
    Left = 120
    Top = 12
    Width = 220
    Height = 21
    TabOrder = 0
  end
  object lblGithubToken: TLabel
    Left = 16
    Top = 52
    Width = 85
    Height = 13
    Caption = 'GitHub Token:'
  end
  object edtGithubToken: TEdit
    Left = 120
    Top = 48
    Width = 220
    Height = 21
    TabOrder = 1
    PasswordChar = '*'
  end
  object btnOK: TButton
    Left = 160
    Top = 100
    Width = 80
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 2
    OnClick = btnOKClick
    ModalResult = 1
  end
  object btnCancel: TButton
    Left = 260
    Top = 100
    Width = 80
    Height = 25
    Caption = 'Cancel'
    Cancel = True
    TabOrder = 3
    OnClick = btnCancelClick
    ModalResult = 2
  end
end
