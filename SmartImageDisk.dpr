program SmartImageDisk;

{$APPTYPE CONSOLE}

{$R *.res}

// terminal connection settings, zero size problem, always busy problem
// http://atola.com/products/insight/manual/seagate-7200.11.html
// https://sites.google.com/site/seagatefix/

// https://www.itosaka.com/WordPress/wp-content/uploads/2009/07/Seagate-Diagnostic-Command.pdf

// all codes
// http://www.hddserialcommander.com/seagate/
// https://forum.hddguru.com/viewtopic.php?t=6411

// http://www.overclock.net/t/457286/seagate-bricked-firmware-drive-fix-with-pics/40
// http://s3.eurecom.fr/~zaddach/docs/POC13_zaddach.pdf

// LED errors, new heads..
// http://forum.acelaboratory.com/viewtopic.php?t=8453

// how to connect to master/slave pins with photo
// http://elabz.com/repairning-seagate-7200-11-drive-on-a-ubuntu-success-story/

// LBA translation https://en.wikipedia.org/wiki/Cylinder-head-sector

// g-list remapping reallocation problem
// http://forum.hddguru.com/viewtopic.php?t=6411&start=60

// safe mode
// http://www.datarecoverytools.co.uk/2011/01/29/how-to-test-seagate-drives-heads-for-hdd-repair/
// antwoord op disable correction
// https://forum.hddguru.com/viewtopic.php?f=1&t=29535&start=40&mobile=mobile

// https://forum.hddguru.com/viewtopic.php?f=1&t=27413&start=20&mobile=mobile


// forum hdd tools
// http://www.hddoracle.com/viewforum.php?f=11

uses
  WinApi.Windows,
  System.Math,
  System.generics.Collections,
  System.Classes,
  System.SysUtils;

const
  BlockGrowFactor = 4;

  dtOneDay = 1;
  dtOneHour = dtOneDay/24;
  dtOneMinute = dtOneHour/60;
  dtOneSecond = dtOneMinute/60;
  dtOneMilliSecond = dtOneSecond/1000;

  MaxSaveRangesDelta = 5*dtOneMinute; // every 5 minutes

  defaultMinRange = Int64(4)*1024*1024*1024; // 200 mb

type
  TSTORAGE_PROPERTY_ID = (
    StorageDeviceProperty = 0,
    StorageAdapterProperty,
    StorageDeviceIdProperty,
    StorageDeviceUniqueIdProperty,
    StorageDeviceWriteCacheProperty,
    StorageMiniportProperty,
    StorageAccessAlignmentProperty,
    StorageDeviceSeekPenaltyProperty,
    StorageDeviceTrimProperty,
    StorageDeviceWriteAggregationProperty,
    StorageDeviceDeviceTelemetryProperty,
    StorageDeviceLBProvisioningProperty,
    StorageDevicePowerProperty,
    StorageDeviceCopyOffloadProperty,
    StorageDeviceResiliencyProperty,
    StorageDeviceMediumProductType,
    StorageDeviceIoCapabilityProperty = 48,
    StorageAdapterProtocolSpecificProperty,
    StorageDeviceProtocolSpecificProperty,
    StorageAdapterTemperatureProperty,
    StorageDeviceTemperatureProperty,
    StorageAdapterPhysicalTopologyProperty,
    StorageDevicePhysicalTopologyProperty,
    StorageDeviceAttributesProperty
	);

  TSTORAGE_QUERY_TYPE  = (
    PropertyStandardQuery    = 0,
    PropertyExistsQuery      = 1,
    PropertyMaskQuery        = 2,
    PropertyQueryMaxDefined  = 3
  );

  TSTORAGE_PROPERTY_QUERY = packed record
    PropertyId: DWORD; //TSTORAGE_PROPERTY_ID;
  	QueryType: DWORD; //TSTORAGE_QUERY_TYPE;
    AdditionalParameters: array[0..3] of byte;
  end;

  TSTORAGE_ACCESS_ALIGNMENT_DESCRIPTOR = record
    Version: DWORD;
    Size: DWORD;
    BytesPerCacheLine: DWORD;
    BytesOffsetForCacheAlignment: DWORD;
    BytesPerLogicalSector: DWORD;
    BytesPerPhysicalSector: DWORD;
    BytesOffsetForSectorAlignment: DWORD;
  end;

  TRange = packed record
    head: Int64;
    tail: Int64;
    scanHead: Boolean;
    scanTail: Boolean;
    function size: Int64;
    function middle(aBlockSize: Int64): Int64;
  end;

  TRanges = class(TList<TRange>)
    procedure LoadRanges(const aRangesFileName: string);
    procedure SaveRanges(const aRangesFileName: string);
		procedure LogRanges();

    procedure IncRangeHead(aRange: Integer; aIncrement: Integer);
		procedure DecRangeTail(aRange: Integer; aDecrement: Integer);
  	procedure SetRangeHeadScan(aRange: Integer; aScan: Boolean);
		procedure SetRangeTailScan(aRange: Integer; aScan: Boolean);
  end;

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

{ log }

var
  logFile: Text;

procedure Openlog(const aLogFileName:string='');
var
  logFileName: string;
begin
  if aLogFileName=''
  then logFileName := ChangeFileExt(ParamStr(0), '.log')
  else logFileName := aLogFileName;
  AssignFile(logFile, logFileName);
  if FileExists(logFileName)
  then Append(logFile)
  else Rewrite(logFile);
end;

procedure CloseLog;
begin
  CloseFile(logFile);
end;

procedure LogFileOnlyWriteLn(const aLine: string);
begin
  WriteLn(logFile, aLine);
  Flush(logFile);
end;

procedure LogWriteLn(const aLine: string);
begin
  // write to log
  LogFileOnlyWriteLn(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)+' '+aLine);
  // write to console
  WriteLn(aLine);
end;

procedure LogRange(aRange: TRange; const aPrefix: string='   ');
begin
  LogWriteLn(
    aPrefix+
    aRange.head.ToString()+' ('+Ord(aRange.scanHead).ToString+') - '+
    aRange.tail.ToString()+' ('+Ord(aRange.scanTail).ToString+') : '+
    BytesToStr(aRange.size));
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

{ TRanges }

procedure TRanges.DecRangeTail(aRange, aDecrement: Integer);
var
  currentRange: TRange;
begin
  currentRange := self[aRange];
  currentRange.tail := currentRange.tail-aDecrement;
  self[aRange] := currentRange;
end;

procedure TRanges.IncRangeHead(aRange, aIncrement: Integer);
var
  currentRange: TRange;
begin
  currentRange := self[aRange];
  currentRange.head := currentRange.head+aIncrement;
  self[aRange] := currentRange;
end;

procedure TRanges.LoadRanges(const aRangesFileName: string);
var
  rangesFile: File;
  currentRange: TRange;
  res: Integer;
begin
  AssignFile(rangesFile, aRangesFileName);
  Reset(rangesFile, 1);
  try
    while not EOF(rangesFile) do
    begin
      BlockRead(rangesFile, currentRange, SizeOf(currentRange), res);
      if res=SizeOf(currentRange)
      then Add(currentRange)
      else
      begin
        LogWriteLn('## Error reading progress file..');
        ReadLn;
        Halt;
      end;
    end;
  finally
    CloseFile(rangesFile);
  end;
end;

procedure TRanges.LogRanges;
var
  currentRange: TRange;
begin
  for currentRange in self
  do LogRange(currentRange);
end;

procedure TRanges.SaveRanges(const aRangesFileName: string);
var
  rangesFile: File;
  currentRange: TRange;
begin
  // store ranges
  AssignFile(rangesFile, aRangesFileName);
  Rewrite(rangesFile, 1);
  try
    for currentRange in self
    do BlockWrite(rangesFile, currentRange, SizeOf(currentRange));
  finally
    CloseFile(rangesFile);
  end;
end;

procedure TRanges.SetRangeHeadScan(aRange: Integer; aScan: Boolean);
var
  currentRange: TRange;
begin
  currentRange := self[aRange];
  currentRange.scanHead := aScan;
  self[aRange] := currentRange;
end;

procedure TRanges.SetRangeTailScan(aRange: Integer; aScan: Boolean);
var
  currentRange: TRange;
begin
  currentRange := self[aRange];
  currentRange.scanTail := aScan;
  self[aRange] := currentRange;
end;

function GetFileSizeEx(aFileHandle: THandle; var aFileSize: Int64): bool; stdcall; external kernelbase name 'GetFileSizeEx';

function SizeOfFile(const aFilename: string): Int64;
var
  h: THandle;
begin
  h := CreateFile(PChar(aFilename), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  try
    if not GetFileSizeEx(h, Result)
    then Result := -1;
  finally
    CloseHandle(h);
  end;
end;

function CreateEmptyFile(const aFilename: string; aFileSize: Int64; aBufferSize: Integer=64*1024*1024; aFillChar: Integer=$E5): Boolean;
var
  buffer: array of byte;
  F: File;
  c: int64;
  res: Integer;
  p: Char;
begin
  setLength(buffer, aBufferSize);
  FillChar(Buffer[0], aBufferSize, aFillChar);
  AssignFile(F, aFileName);
  Rewrite(F, 1);
  try
    Result := True;
  	c := 0;
    p := '-';
    while Result and (aFileSize>c) do
    begin
      BlockWrite(F, buffer[0], min(Length(buffer), aFileSize-c), res);
      if res>0 then
      begin
        c := c+res;
        if p='-'
        then p := '\'
        else if p='\'
        then p := '|'
        else if p='|'
        then p := '/'
        else p := '-';
        // log status to console only
        Write(Round((100.0*c/aFileSize)).ToString()+'% '+p+#13);
      end
      else Result := False;
    end;
    WriteLn; // to skip progress line
  finally
    CloseFile(F);
  end;
end;

function CreateOutputFile(const aFileName: string; aFileSize: Int64): Boolean;
begin
  LogWriteLn('Creating output file '+aFileName);
  Result := CreateEmptyFile(aFileName, aFileSize);
  if Result
  then LogWriteLn('Created output file '+aFileName+' of '+aFileSize.ToString()+' bytes')
  else LogWriteLn('## Could not create output file '+aFileName+' of '+aFileSize.ToString()+' bytes');
end;

function GetDiskSize(aDiskHandle: THandle): Int64;
var
  rsize: DWORD;
begin
  if not DeviceIoControl(aDiskHandle, IOCTL_DISK_GET_LENGTH_INFO, nil, 0, @Result, sizeof(Result), rsize, nil)
  then Result := -1;
end;

function MySysErrorMessage(var aError: DWORD): string;
begin
  aError := GetLastError;
  Result := aError.tostring+': '+SysErrorMessage(aError);
end;

function GetDiskSectorSize(aDiskHandle: THandle): Integer;
var
  storageQuery: TSTORAGE_PROPERTY_QUERY;
  diskAlignment: TSTORAGE_ACCESS_ALIGNMENT_DESCRIPTOR;
  rsize: DWORD;
begin
  FillChar(storageQuery, SizeOf(storageQuery), 0);
  storageQuery.PropertyId := Ord(StorageAccessAlignmentProperty);
  storageQuery.QueryType := Ord(PropertyStandardQuery);
  FillChar(diskAlignment, SizeOf(diskAlignment), 0);
  rSize := 0;
  if DeviceIoControl(aDiskHandle, IOCTL_STORAGE_QUERY_PROPERTY, @storageQuery, sizeOf(storageQuery), @diskAlignment, sizeof(diskAlignment), rsize, nil)
  then Result := diskAlignment.BytesPerPhysicalSector
  else Result := -1;
end;

function CopyBlock(aDiskHandle, aOutputFile: THandle; {aOutputFile: TFileStream; }aPosition: Int64; aBlockSize: DWORD; var aBuffer; var aErrorCode: DWORD): Boolean;
var
  res: DWORD;
begin
  // todo: switch to direct sector reading?
  // http://www.codeproject.com/Articles/28314/Reading-and-Writing-to-Raw-Disk-Sectors

  if SetFilePointerEx(aDiskHandle, aPosition, nil, FILE_BEGIN) and ReadFile(aDiskHandle, aBuffer, aBlockSize, res, nil) then
  begin
    Result :=
      SetFilePointerEx(aOutputFile, aPosition, nil, FILE_BEGIN) and
      WriteFile(aOutputFile, aBuffer, aBlockSize, res, nil);
	end
  else
  begin
    LogWriteLn('## CopyBlock @ '+aPosition.ToString+' - '+BytesToStr(aBlockSize)+' : '+MySysErrorMessage(aErrorCode));
    Result := False;
  end;
end;

procedure ShowStatus(aDiskSize: Int64; aRanges: TRanges; aCurrentRange: Integer; aMinRangeSize: Int64; aBlockSize: Int64);
var
  r: TRange;
  toProcess: Int64;
  belowMinRangeCount: Integer;
begin
  toProcess := 0;
  belowMinRangeCount := 0;
  for r in aRanges do
  begin
    toProcess := toProcess+r.size;
    if r.size<aMinRangeSize
    then belowMinRangeCount := belowMinRangeCount+1;
  end;
  // status to console only
  Write(
    aRanges[aCurrentRange].head.ToString+'/'+aRanges[aCurrentRange].tail.ToString+'/'+BytesToStr(aRanges[aCurrentRange].size)+' - '+BytesToStr(aBlockSize)+' - '+
    BytesToStr(toProcess)+' ('+Round(100*toProcess/aDiskSize).ToString+'%) - '+
    belowMinRangeCount.ToString+'/'+aRanges.Count.ToString+'        '+
    #13);
end;

var
  ranges: TRanges;
  rangesFileName: string;
  outputFile: THandle;
  done: Boolean;

procedure FlushAll;
begin
  done := True;
  FlushFileBuffers(outputFile);
  ranges.SaveRanges(rangesFileName);
end;

function ConsoleCtrlHandler(dwCtrlType: DWORD): Boolean; stdcall;
begin
  Result := False; // execute default handler
  case dwCtrlType of
    CTRL_CLOSE_EVENT:
      begin
        FlushAll;
        WriteLn;
        LogWriteLn('Done on close event');
      end;
    CTRL_LOGOFF_EVENT:
      begin
        FlushAll;
        WriteLn;
        LogWriteLn('Done on logoff event');
      end;
    CTRL_SHUTDOWN_EVENT:
      begin
        FlushAll;
        WriteLn;
        LogWriteLn('Done on shutdown event');
      end;
    CTRL_C_EVENT:
      begin
        FlushAll;
        WriteLn;
        LogWriteLn('Done on ctrl-c event');
      end;
    CTRL_BREAK_EVENT:
      begin
        FlushAll;
        WriteLn;
        LogWriteLn('Done on ctrl-break event');
      end;
  end;
end;

procedure CloseScanDisk(var aDiskhandle: THandle);
begin
  if aDiskHandle<>INVALID_HANDLE_VALUE then
  begin
    CloseHandle(aDiskhandle);
    aDiskHandle := INVALID_HANDLE_VALUE;
  end;
end;

function OpenScanDisk(const aDiskPath: string; var aDiskHandle: THandle): Boolean;
begin
  aDiskHandle := CreateFile(
    PChar(aDiskPath), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_NO_BUFFERING,
    0);
  Result := aDiskHandle<>INVALID_HANDLE_VALUE;
end;

procedure WaitToReopenDisk(const aDiskPath: string; var aDiskHandle: THandle);
var
  p: Char;
begin
  CloseScanDisk(aDiskHandle);
  LogWriteLn('Closed scan disk');
  p := '-';
  while not OpenScanDisk(aDiskPath, aDiskHandle) do
  begin
    if p='-' then p := '\' else if p='\' then p := '|' else if p='|' then p := '/' else p := '-';
    // log status to console only
    Write('Waiting for scan disk '+p+#13);
    Sleep(5*1000);
  end;
  WriteLn; // to skip progress line
  Sleep(10000); // extra sleep to make stopping code possible..
  LogWriteLn('Re-opened scan disk');
end;

procedure CopyDiskToImage(const aDiskPath, aOutputFileName, aProgressFileName: string; aMinRangeSize: Int64);
var
  diskHandle: THandle;
  diskSize: Int64;
  outputFileOK: Boolean;
  outputFileSize: Int64;
  sectorSize: Integer;
  r: Integer;
  lowRange: TRange;
  highRange: TRange;
  blockSize: Int64;
  maxBlockSizeForward: Integer;
  maxBlockSizeBackward: Integer;
  buffer: RawByteString;
  currentRange: TRange;
  lastSavedRanges: TDateTime;
  errorCode: DWORD;
begin
  // open disk as file
  if OpenScanDisk(aDiskPath, diskHandle) then
  begin
    try
      // get size of disk
      diskSize := GetDiskSize(diskHandle);
      if diskSize>=0 then
      begin
        LogWriteLn('Found disk size: '+BytesToStr(diskSize));
        sectorSize := GetDiskSectorSize(diskHandle);
        if sectorSize>0 then
        begin
          LogWriteLn('Found sector size: '+BytesToStr(sectorSize));
          // create output file
          if not FileExists(aOutputFileName)
          then outputFileOK := CreateOutputFile(aOutputFileName, diskSize)
          else
          begin
            outputFileSize := SizeOfFile(aOutputFileName);
            if outputFileSize<>diskSize then
            begin
              LogWriteLn('>> Output file size mismatch: '+diskSize.ToString+' <> '+outputFileSize.ToString());
              LogWriteLn('Press return to re-create output file '+aOutputFileName);
              ReadLn;
              outputFileOK := CreateOutputFile(aOutputFileName, diskSize)
            end
            else outputFileOK := true;
          end;
          if outputFileOK then
          begin
            ranges := TRanges.Create;
            try
              // check progress file
              if FileExists(aProgressFileName) then
              begin
                // read progress file and start from there
                ranges.LoadRanges(aProgressFileName);
                LogWriteLn('Read '+ranges.Count.ToString()+' ranges to process');
                ranges.LogRanges();
              end
              else
              begin
                // start fresh with a scan for the first range
                currentRange.head := 0;
                currentRange.tail := diskSize-1;
                currentRange.scanHead := True;
                currentRange.scanTail := True;
                ranges.Add(currentRange);
                LogWriteLn('Added whole disk as first range');
              end;

              outputFile := CreateFile(
    					  PChar(aOutputFileName), GENERIC_WRITE,
                FILE_SHARE_READ or FILE_SHARE_WRITE,
                nil,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL{ or FILE_FLAG_NO_BUFFERING},
                0);
              try
                // prepare buffer
                maxBlockSizeForward := 64*1024; // 256*sectorSize; //*1024; // 256*4kB sectors or 2048*512B sectors
                maxBlockSizeBackward := 64*1024; // sectorSize;
                setLength(buffer, max(maxBlockSizeForward, maxBlockSizeBackward));
                // process defined ranges
                done := False;
                lastSavedRanges := 0; // never saved ranges
                rangesFileName := aProgressFileName;
                // make sure that if console window is closed or ctrl-break or ctrl-c is pressed we exit nicely
        				SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);
                try
                  while (ranges.Count>0) and not done do
                  begin
                    // find first range to process
                    r := 0;
                    while (r<ranges.Count) and (ranges[r].size<aMinRangeSize)
                    do r := r+1;
                    if r<ranges.Count then
                    begin
                      // process range
                      LogRange(ranges[r], '   Processing: ');
                      // try to advance head
                      blockSize := sectorSize;
                      while (ranges[r].size>0) and ranges[r].scanHead and not done do
                      begin
                        blockSize := min(min(blockSize, ranges[r].size), maxBlockSizeForward);
                        ShowStatus(diskSize, ranges, r, aMinRangeSize, blockSize);
                        errorCode := 0;
                        if CopyBlock(diskHandle, outputFile, ranges[r].head, blockSize, buffer[1], errorCode) then
                        begin
                          ranges.IncRangeHead(r, blockSize); // go forward
                          blockSize := blockSize*BlockGrowFactor;
                        end
                        else
                        begin
                          if (errorCode<>483) and (errorCode<>1117) and (errorCode<>2) then
                          begin
                            if blockSize>sectorSize
                            then blockSize := sectorSize // reset block size
                            else ranges.SetRangeHeadScan(r, False); //  signal we are ready
                          end
                          else
                          begin
                            blockSize := sectorSize;
                            ranges.SetRangeHeadScan(r, False); //  signal we are ready
//                            WaitToReopenDisk(aDiskPath, diskHandle); // wait until we can re-open drive
                            done := True; // most of the time the best decision
                          end;
                        end;
                      end;
                      // try to decrease tail
                      blockSize := sectorSize;
                      while (ranges[r].size>0) and ranges[r].scanTail and not done do
                      begin
                        blockSize := min(min(blockSize, ranges[r].size), maxBlockSizeBackward);
                        ShowStatus(diskSize, ranges, r, aMinRangeSize, blockSize);
                        errorCode := 0;
                        if CopyBlock(diskHandle, outputFile, ranges[r].tail-blockSize+1, blockSize, buffer[1], errorCode) then
                        begin
                          ranges.DecRangeTail(r, blockSize); // go backward
                          blockSize := blockSize*BlockGrowFactor;
                        end
                        else
                        begin
                          if (errorCode<>483) and (errorCode<>1117) and (errorCode<>2) then
                          begin
                            if blockSize>sectorSize
                            then blockSize := sectorSize // reset block size
                            else ranges.SetRangeTailScan(r, False); //  signal we are ready
                          end
                          else
                          begin
                            blockSize := sectorSize;
                            ranges.SetRangeTailScan(r, False); //  signal we are ready
//                            WaitToReopenDisk(aDiskPath, diskHandle); // wait until we can re-open drive
                            done := True; // most of the time the best decision
                          end;
                        end;
                      end;

                      // range is minimized now
                      if ranges[r].size>0 then
                      begin
                        // split up range
                        lowRange.head := ranges[r].head;
                        lowRange.scanHead := ranges[r].scanHead;
                        lowRange.tail := ranges[r].middle(sectorSize)-1;
                        lowRange.scanTail := True;
                        highRange.head := ranges[r].middle(sectorSize);
                        highRange.scanHead := True;
                        highRange.tail := ranges[r].tail;
                        highRange.scanTail := ranges[r].scanTail;
                        // add split entries to end of queue
                        LogRange(lowRange, '   New low: ');
                        LogRange(highRange, '   New high: ');
                        ranges.Add(lowRange);
                        ranges.Add(highRange);
                      end;
                      // remove this entry
                      LogRange(ranges[r], '   Removed: ');
                      ranges.Delete(r);
                    end
                    else done := True;

                    // save progress
                    if lastSavedRanges<=Now-MaxSaveRangesDelta then
                    begin
                      ranges.SaveRanges(aProgressFileName);
                      lastSavedRanges := Now;
                    end;

                  end; // end of main scan loop

                finally
                  SetConsoleCtrlHandler(@ConsoleCtrlHandler, False);
                end;

              finally
                CloseHandle(outputFile);
              end;

              WriteLn; // to skip progress line

              ranges.SaveRanges(aProgressFileName);

              LogWriteLn('Saved '+ranges.Count.ToString()+' ranges');

              for currentRange in ranges
              do LogFileOnlyWriteLn(currentRange.head.ToString+#9+Ord(currentRange.scanHead).ToString+#9+currentRange.tail.ToString+#9+Ord(currentRange.scanTail).ToString+#9+BytesToStr(currentRange.size));

            finally
              ranges.Free;
            end;
          end;
        end
        else LogWriteLn('## Could not get disk sector size: '+MySysErrorMessage(errorCode));
      end
      else LogWriteLn('## Could not get disk length: '+MySysErrorMessage(errorCode));
    finally
      CloseScanDisk(diskHandle);
    end;
  end
  else LogWriteLn('## Could not open disk '+aDiskPath+': '+MySysErrorMessage(errorCode));
end;

var
  diskPath: string;
  imageFileName: string;
  minRange: Int64;
begin
  try
    if ParamCount=0 then
    begin
      WriteLn('Use: '+ChangeFileExt(ExtractFileName(ParamStr(0)), '')+' "<disk-path>" ["<output-image-file>" [<minimum-scan-range(bytes, default='+defaultMinRange.tostring+')>]]');
    end
    else
    begin
      // read parameters
      diskPath := ParamStr(1);
      if ParamCount>1
      then imageFileName := ParamStr(2)
      else imageFileName := ChangeFileExt(ParamStr(0), '.dsk');
      if ParamCount>2
      then minRange := StrToInt64Def(ParamStr(3), defaultMinRange)
      else minRange := defaultMinRange;

      OpenLog(ChangeFileExt(imageFileName, '.log'));
      try
        LogWriteLn('disk-path: '+diskPath);
      	LogWriteLn('output-image-file: '+imageFileName);
        LogWriteLn('minimum-scan-range: '+minRange.toString);
        // start the copy
        CopyDiskToImage(diskPath, imageFileName, ChangeFileExt(imageFileName, '.rgs'), minRange);
      finally
        CloseLog;
      end;

      WriteLn('Finished, press return to quit..');
      ReadLn;
    end;
  except
    on E: Exception do
      LogWriteln('## '+E.ClassName+': '+E.Message);
  end;
end.
