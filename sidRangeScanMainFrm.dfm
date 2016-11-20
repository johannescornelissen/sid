object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 336
  ClientWidth = 635
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    635
    336)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 79
    Height = 13
    Caption = 'ranges file name'
  end
  object paintboxScan: TPaintBox
    Left = 8
    Top = 54
    Width = 619
    Height = 19
    Anchors = [akLeft, akTop, akRight]
    OnPaint = paintboxScanPaint
  end
  object editFileName: TEdit
    Left = 8
    Top = 27
    Width = 361
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
  end
  object btnBrowseFileName: TButton
    Left = 383
    Top = 25
    Width = 27
    Height = 25
    Anchors = [akTop, akRight]
    Caption = '...'
    TabOrder = 1
    OnClick = btnBrowseFileNameClick
  end
  object btnScan: TButton
    Left = 560
    Top = 25
    Width = 67
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Scan'
    TabOrder = 2
    OnClick = btnScanClick
  end
  object listboxScan: TListBox
    Left = 8
    Top = 79
    Width = 619
    Height = 186
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 3
    OnClick = listboxScanClick
    OnKeyPress = listboxScanKeyPress
  end
  object btnSortLH: TButton
    Left = 8
    Top = 271
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Sort O LH'
    TabOrder = 4
    OnClick = btnSortLHClick
  end
  object btnSave: TButton
    Left = 552
    Top = 287
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Save'
    TabOrder = 5
    OnClick = btnSaveClick
  end
  object btnMerge: TButton
    Left = 192
    Top = 287
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Merge'
    TabOrder = 6
    OnClick = btnMergeClick
  end
  object btnScanHeadAndTail: TButton
    Left = 288
    Top = 271
    Width = 122
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Scan head and tail'
    TabOrder = 7
    OnClick = btnScanHeadAndTailClick
  end
  object btnSortHL: TButton
    Left = 8
    Top = 302
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Sort O HL'
    TabOrder = 8
    OnClick = btnSortHLClick
  end
  object btnNOScanHeadAndTail: TButton
    Left = 288
    Top = 302
    Width = 122
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'NO scan head and tail'
    TabOrder = 9
    OnClick = btnNOScanHeadAndTailClick
  end
  object btnSortSizeLH: TButton
    Left = 104
    Top = 271
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Sort S LH'
    TabOrder = 10
    OnClick = btnSortSizeLHClick
  end
  object btnSortSizeHL: TButton
    Left = 104
    Top = 302
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Sort S HL'
    TabOrder = 11
    OnClick = btnSortSizeHLClick
  end
  object editImageSize: TEdit
    Left = 432
    Top = 27
    Width = 121
    Height = 21
    Anchors = [akTop, akRight]
    TabOrder = 12
    Text = '2000398934016'
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = '.rgs'
    Filter = 'ranges|*.rgs|all|*.*'
    FilterIndex = 0
    Title = 'Select sid ranges file'
    Left = 288
    Top = 8
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = '.rgs'
    Filter = 'ranges|*.rgs|all|*.*'
    FilterIndex = 0
    Title = 'Select sid ranges file to save ranges to'
    Left = 536
    Top = 248
  end
end
