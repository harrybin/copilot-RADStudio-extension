object CopilotChatPanel: TCopilotChatPanel
  Left = 0
  Top = 0
  Width = 400
  Height = 600
  TabOrder = 0
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 600
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object pnlTop: TPanel
      Left = 0
      Top = 0
      Width = 400
      Height = 41
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object pnlToolbar: TPanel
        Left = 0
        Top = 0
        Width = 400
        Height = 41
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        object btnAuth: TSpeedButton
          Left = 8
          Top = 8
          Width = 75
          Height = 25
          Caption = 'Sign In'
          OnClick = btnAuthClick
        end
        object btnSettings: TSpeedButton
          Left = 320
          Top = 8
          Width = 25
          Height = 25
          Caption = #9881
          Hint = 'Settings'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnSettingsClick
        end
        object btnHelp: TSpeedButton
          Left = 351
          Top = 8
          Width = 25
          Height = 25
          Caption = '?'
          Hint = 'Help'
          ParentShowHint = False
          ShowHint = True
          OnClick = btnHelpClick
        end
      end
    end
    object pnlBottom: TPanel
      Left = 0
      Top = 560
      Width = 400
      Height = 40
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object pnlStatus: TPanel
        Left = 0
        Top = 0
        Width = 400
        Height = 40
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        object lblStatus: TLabel
          Left = 8
          Top = 12
          Width = 86
          Height = 13
          Caption = 'Not authenticated'
        end
      end
    end
    object pnlChat: TPanel
      Left = 0
      Top = 41
      Width = 400
      Height = 519
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 2
      object splChatInput: TSplitter
        Left = 0
        Top = 439
        Width = 400
        Height = 3
        Cursor = crVSplit
        Align = alBottom
        ExplicitTop = 436
        ExplicitWidth = 185
      end
      object memChatHistory: TMemo
        Left = 0
        Top = 0
        Width = 400
        Height = 439
        Align = alClient
        PopupMenu = pmChatContext
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
        OnContextPopup = memChatHistoryContextPopup
      end
      object pnlInput: TPanel
        Left = 0
        Top = 442
        Width = 400
        Height = 77
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        object edtMessage: TEdit
          Left = 8
          Top = 8
          Width = 305
          Height = 21
          TabOrder = 0
          OnKeyPress = edtMessageKeyPress
        end
        object btnSend: TButton
          Left = 319
          Top = 6
          Width = 75
          Height = 25
          Caption = 'Send'
          Default = True
          TabOrder = 1
          OnClick = btnSendClick
        end
        object btnClear: TButton
          Left = 319
          Top = 37
          Width = 75
          Height = 25
          Caption = 'Clear'
          TabOrder = 2
          OnClick = btnClearClick
        end
      end
    end
  end
  object pmChatContext: TPopupMenu
    OnPopup = memChatHistoryContextPopup
    Left = 200
    Top = 200
    object miCopyResponse: TMenuItem
      Caption = 'Copy Response'
      OnClick = miCopyResponseClick
    end
    object miClearHistory: TMenuItem
      Caption = 'Clear History'
      OnClick = miClearHistoryClick
    end
    object miSeparator1: TMenuItem
      Caption = '-'
    end
    object miExplainCode: TMenuItem
      Caption = 'Explain Current Code'
      OnClick = miExplainCodeClick
    end
    object miReviewCode: TMenuItem
      Caption = 'Review Current Code'
      OnClick = miReviewCodeClick
    end
    object miRefactorCode: TMenuItem
      Caption = 'Suggest Refactoring'
      OnClick = miRefactorCodeClick
    end
  end
end
