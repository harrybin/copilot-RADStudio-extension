object frmCopilotSettings: TfrmCopilotSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Copilot Settings'
  ClientHeight = 180
  ClientWidth = 340
  Position = poScreenCenter
  Font.Name = 'Segoe UI'
  Font.Size = 10
  PixelsPerInch = 96
  TextHeight = 13
  object lblApiEndpoint: TLabel
    Left = 16
    Top = 16
    Width = 80
    Height = 13
    Caption = 'API Endpoint:'
  end
  object edtApiEndpoint: TEdit
    Left = 120
    Top = 12
    Width = 200
    Height = 21
    TabOrder = 0
  end
  object lblTimeout: TLabel
    Left = 16
    Top = 52
    Width = 90
    Height = 13
    Caption = 'Request Timeout:'
  end
  object edtTimeout: TEdit
    Left = 120
    Top = 48
    Width = 80
    Height = 21
    TabOrder = 1
  end
  object lblRetry: TLabel
    Left = 16
    Top = 88
    Width = 90
    Height = 13
    Caption = 'Retry Attempts:'
  end
  object edtRetry: TEdit
    Left = 120
    Top = 84
    Width = 80
    Height = 21
    TabOrder = 2
  end
  object btnOK: TButton
    Left = 120
    Top = 128
    Width = 80
    Height = 25
    Caption = 'OK'
    TabOrder = 3
    OnClick = btnOKClick
    ModalResult = 1
  end
  object btnCancel: TButton
    Left = 240
    Top = 128
    Width = 80
    Height = 25
    Caption = 'Cancel'
    TabOrder = 4
    OnClick = btnCancelClick
    ModalResult = 2
  end
end
