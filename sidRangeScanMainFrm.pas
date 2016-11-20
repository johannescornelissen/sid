unit sidRangeScanMainFrm;

interface

uses
  System.Generics.Defaults,
  system.generics.collections,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TRange = packed record
    head: Int64;
    tail: Int64;
    scanHead: Boolean;
    scanTail: Boolean;
    function size: Int64;
    function middle(aBlockSize: Int64): Int64;
  end;

  TRangeComparerOffsetLowToHigh = class(TComparer<TRange>)
  public
    function Compare(const Left, Right: TRange): Integer; override;
  end;

  TRangeComparerOffsetHighToLow = class(TComparer<TRange>)
  public
    function Compare(const Left, Right: TRange): Integer; override;
  end;

  TRangeComparerSizeLowToHigh = class(TComparer<TRange>)
  public
    function Compare(const Left, Right: TRange): Integer; override;
  end;

  TRangeComparerSizeHighToLow = class(TComparer<TRange>)
  public
    function Compare(const Left, Right: TRange): Integer; override;
  end;

  TForm1 = class(TForm)
    editFileName: TEdit;
    Label1: TLabel;
    btnBrowseFileName: TButton;
    btnScan: TButton;
    OpenDialog1: TOpenDialog;
    paintboxScan: TPaintBox;
    listboxScan: TListBox;
    btnSortLH: TButton;
    btnSave: TButton;
    btnMerge: TButton;
    SaveDialog1: TSaveDialog;
    btnScanHeadAndTail: TButton;
    btnSortHL: TButton;
    btnNOScanHeadAndTail: TButton;
    btnSortSizeLH: TButton;
    btnSortSizeHL: TButton;
    editImageSize: TEdit;
    procedure btnBrowseFileNameClick(Sender: TObject);
    procedure btnScanClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure paintboxScanPaint(Sender: TObject);
    procedure listboxScanClick(Sender: TObject);
    procedure listboxScanKeyPress(Sender: TObject; var Key: Char);
    procedure btnSortLHClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnMergeClick(Sender: TObject);
    procedure btnScanHeadAndTailClick(Sender: TObject);
    procedure btnSortHLClick(Sender: TObject);
    procedure btnNOScanHeadAndTailClick(Sender: TObject);
    procedure btnSortSizeHLClick(Sender: TObject);
    procedure btnSortSizeLHClick(Sender: TObject);
  private
    fRanges: TList<TRange>;
    procedure rangesLoad(const aFileName: string);
    procedure rangesSave(const aFileName: string);
    procedure rangesToListbox;

    procedure rangesSortOffsetLowToHigh;
    procedure rangesSortOffsetHighToLow;
    procedure rangesSortSizeLowToHigh;
    procedure rangesSortSizeHighToLow;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ bytes to string }

const
  MaxUnitIndex = 4;
  Units: array [0 .. MaxUnitIndex] of string = ('B', 'kB', 'MB', 'GB', 'TB');

// build a readable form to output a count of bytes with an extension
function BytesToStr(n: Extended): string; overload;
var
  u: Integer;
begin
  Result := '';
  u := 0;
  while (n >= 1024) and (u < MaxUnitIndex) do
  begin
    n := n / 1024;
    u := u + 1;
  end;
  if (n > 10) or (u = 0) then
  begin
    if (n > 100) or (u = 0)
    then Result := FloatToStrF(n, ffNumber, 4, 0) + ' ' + Units[u]
    else Result := FloatToStrF(n, ffNumber, 4, 1) + ' ' + Units[u];
  end
  else Result := FloatToStrF(n, ffNumber, 4, 2) + ' ' + Units[u];
end;

function BytesToStr(n: Int64): string; overload;
var
  RealSize: Extended;
begin
  RealSize := n;
  Result := BytesToStr(RealSize);
end;

function TRangeComparerOffsetLowToHigh.Compare(const Left, Right: TRange): Integer;
begin
  if Left.tail<Right.head
  then Result := -1
  else if Right.tail<Left.head
  then Result := 1
  else Result := 0;
end;

function TRangeComparerOffsetHighToLow.Compare(const Left, Right: TRange): Integer;
begin
  if Left.tail<Right.head
  then Result := 1
  else if Right.tail<Left.head
  then Result := -1
  else Result := 0;
end;

{ TRangeComparerSizeLowToHigh }

function TRangeComparerSizeLowToHigh.Compare(const Left, Right: TRange): Integer;
begin
  if Left.size<Right.size
  then Result := -1
  else if Left.size>Right.size
  then Result := 1
  else Result := 0;
end;

{ TRangeComparerSizeHighToLow }

function TRangeComparerSizeHighToLow.Compare(const Left, Right: TRange): Integer;
begin
	if Right.size<Left.size
  then Result := -1
  else if Right.size>Left.size
  then Result := 1
  else Result := 0;
end;

{ TRange }

function TRange.middle(aBlockSize: Int64): Int64;
begin
  Result := ((tail+head) div (2*aBlockSize))*aBlockSize;
end;

function TRange.size: Int64;
begin
  Result := tail-head+1;
end;

{ TForm1 }

procedure TForm1.btnBrowseFileNameClick(Sender: TObject);
begin
  OpenDialog1.FileName := editFileName.Text;
  if OpenDialog1.Execute then
  begin
    editFileName.Text := OpenDialog1.FileName;
  end;
end;

procedure TForm1.btnMergeClick(Sender: TObject);
var
  r: Integer;
  range: TRange;
begin
  rangesSortOffsetLowToHigh;
  for r := fRanges.Count-1 downto 1 do
  begin
    if fRanges[r].head=fRanges[r-1].tail+1 then
    begin
      range := fRanges[r-1];
      range.tail := fRanges[r].tail;
      range.scanTail := fRanges[r].scanTail;
      fRanges[r-1] := range;
      fRanges.Delete(r);
    end;
  end;
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.btnNOScanHeadAndTailClick(Sender: TObject);
var
  range: TRange;
  r: Integer;
begin
  for r :=0 to fRanges.Count-1 do
  begin
    range := fRanges[r];
    range.scanHead := False;
    range.scanTail := False;
    fRanges[r] := range;
  end;
  rangesToListbox;
end;

procedure TForm1.btnSaveClick(Sender: TObject);
begin
  OpenDialog1.FileName := editFileName.Text;
  if OpenDialog1.Execute then
  begin
    rangesSave(OpenDialog1.FileName);
  end;
end;

procedure TForm1.btnScanClick(Sender: TObject);
begin
  fRanges.Clear;
  rangesLoad(editFileName.Text);
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.btnScanHeadAndTailClick(Sender: TObject);
var
  range: TRange;
  r: Integer;
begin
  for r :=0 to fRanges.Count-1 do
  begin
    range := fRanges[r];
    range.scanHead := True;
    range.scanTail := True;
    fRanges[r] := range;
  end;
  rangesToListbox;
end;

procedure TForm1.btnSortHLClick(Sender: TObject);
begin
  rangesSortOffsetHighToLow;
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.btnSortLHClick(Sender: TObject);
begin
  rangesSortOffsetLowToHigh;
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.btnSortSizeHLClick(Sender: TObject);
begin
  rangesSortSizeHighToLow;
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.btnSortSizeLHClick(Sender: TObject);
begin
  rangesSortSizeLowToHigh;
  rangesToListbox;
  paintboxScan.Invalidate;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  fRanges := TList<TRange>.Create;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fRanges);
end;

procedure TForm1.listboxScanClick(Sender: TObject);
begin
  paintboxScan.Invalidate;
end;

procedure TForm1.listboxScanKeyPress(Sender: TObject; var Key: Char);
begin
  paintboxScan.Invalidate;
end;

procedure TForm1.paintboxScanPaint(Sender: TObject);
var
  range: TRange;
  w: Integer;
  first: Boolean;
  minP, maxP: Int64;
  h: Integer;
  r: TRect;
  widthP: Int64;
  i: Integer;
begin
  // paint ranges
  w := paintboxScan.ClientWidth;
  h := paintboxScan.ClientHeight;
  if editImageSize.Text='' then
  begin
    minP := 0;
    maxP := 0;
    first := true;
    for range in fRanges do
    begin
      if first then
      begin
        minP := range.head;
        maxP := range.tail;
        first := False;
      end
      else
      begin
        if minP>range.head
        then minP := range.head;
        if maxP<range.tail
        then maxP := range.tail;
      end;
    end;
  end
  else
  begin
    minP := 0;
    maxP := StrToInt64Def(editImageSize.Text, 0);
  end;
  widthP := maxP-minP+1;

  // clear background
	paintboxScan.Canvas.Brush.Color := clWhite;
  paintboxScan.Canvas.FillRect(paintboxScan.Canvas.ClipRect);

  i := 0;
  for range in fRanges do
  begin
    if i=listboxScan.ItemIndex
    then paintboxScan.Canvas.Brush.Color := clBlack
    else
    begin
      case i mod 10 of
        0: paintboxScan.Canvas.Brush.Color := clYellow;
        1: paintboxScan.Canvas.Brush.Color := clOlive;
        2: paintboxScan.Canvas.Brush.Color := clRed;
        3: paintboxScan.Canvas.Brush.Color := clPurple;
        4: paintboxScan.Canvas.Brush.Color := clGreen;
        5: paintboxScan.Canvas.Brush.Color := clDkGray;
        6: paintboxScan.Canvas.Brush.Color := clTeal;
        7: paintboxScan.Canvas.Brush.Color := clLime;
        8: paintboxScan.Canvas.Brush.Color := clFuchsia;
      else
           paintboxScan.Canvas.Brush.Color := clBlue;
      end;
    end;

    r.Top := 0;
    r.Height := h;
    r.Left := round(w*((range.head-minP)/widthP));
    r.Right := round(w*((range.tail-minP)/widthP));
    paintboxScan.Canvas.FillRect(r);
    i := i+1;
  end;
end;

procedure TForm1.rangesLoad(const aFileName: string);
var
  F: File;
  range: TRange;
begin
  AssignFile(F, aFilename);
  Reset(F, 1);
  try
    while not eof(F) do
    begin
      BlockRead(F, range, sizeof(range));
      fRanges.Add(range);
    end;
  finally
    CloseFile(F);
  end;
end;

procedure TForm1.rangesSave(const aFileName: string);
var
  F: File;
  range: TRange;
begin
  AssignFile(F, aFileName);
  Rewrite(F, 1);
  try
    for range in fRanges
    do BloCkWrite(F, range, sizeof(range));
  finally
    CloseFile(F);
  end;
end;

procedure TForm1.rangesSortOffsetHighToLow;
var
  cmp: TRangeComparerOffsetHighToLow;
begin
  cmp := TRangeComparerOffsetHighToLow.Create;
  try
    fRanges.Sort(cmp);
  finally
    cmp.Free;
  end;
end;

procedure TForm1.rangesSortOffsetLowToHigh;
var
  cmp: TRangeComparerOffsetLowToHigh;
begin
  cmp := TRangeComparerOffsetLowToHigh.Create;
  try
    fRanges.Sort(cmp);
  finally
    cmp.Free;
  end;
end;

procedure TForm1.rangesSortSizeHighToLow;
var
  cmp: TRangeComparerSizeHighToLow;
begin
  cmp := TRangeComparerSizeHighToLow.Create;
  try
    fRanges.Sort(cmp);
  finally
    cmp.Free;
  end;
end;

procedure TForm1.rangesSortSizeLowToHigh;
var
  cmp: TRangeComparerSizeLowToHigh;
begin
  cmp := TRangeComparerSizeLowToHigh.Create;
  try
    fRanges.Sort(cmp);
  finally
    cmp.Free;
  end;
end;

procedure TForm1.rangesToListbox;
var
  range: TRange;
begin
  listboxScan.Items.BeginUpdate;
  try
    listboxScan.Items.Clear;
    for range in fRanges
    do listboxScan.Items.Add(
     	   range.head.ToString+' ('+ord(range.scanHead).ToString+') - '+
         range.tail.ToString+' ('+ord(range.scanTail).ToString+'): '+
         BytesToStr(range.size));
  finally
    listboxScan.Items.EndUpdate;
  end;
end;

end.
