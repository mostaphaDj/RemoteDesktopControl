unit ScreenShots_U;

interface

uses
  Classes {$IFDEF MSWINDOWS} , Windows {$ENDIF},SysUtils,Graphics,Jpeg;

type
  TThreadScreenShots = class(TThread)
  private
{MergeCursor inline}
//    FBitmapCursor:TBitmap;
    AWidth,
    AHeight:Integer;
    DC : HDC;
    procedure SetName;
    procedure SendImage;inline;
    procedure GetScreenShot;inline;// ��� ���� �� ������
    procedure MergeCursor;inline;// ����� ������
    procedure ResizeBitmap;inline;
//    procedure UnmergeChange(BitmapFirst,BitmapLast:TBitmap;var BitmapChange:TBitmap);inline;// ��� ������ ��� ������
  protected
    procedure Execute; override;
  public
    FRect : TRect;
    FJpegImg: TJpegImage;
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  end;

var
  ThreadScreenShots:TThreadScreenShots;

{$EXTERNALSYM GetCursorPos}
function GetCursorPos(var lpPoint: TPoint):BOOL;stdcall;external user32 name 'GetCursorPos';inline;
{$EXTERNALSYM GetDC}
function GetDC(hWnd: HWND): HDC; stdcall; external user32 name 'GetDC';inline;
{$EXTERNALSYM GetDeviceCaps}
function GetDeviceCaps(DC: HDC; Index: Integer): Integer; stdcall;external gdi32 name 'GetDeviceCaps';inline;
{$EXTERNALSYM BitBlt}
function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc: Integer; Rop: DWORD): BOOL; stdcall;external gdi32 name 'BitBlt';inline;
{$EXTERNALSYM GetDesktopWindow}
function GetDesktopWindow: HWND; stdcall;external user32 name 'GetDesktopWindow';inline;
{$EXTERNALSYM ReleaseDC}
function ReleaseDC(hWnd: HWND; hDC: HDC): Integer; stdcall;external user32 name 'ReleaseDC';inline;

type
  TRGB24 = packed record
    B, G, R : Byte;
  end;
  TRGB24Array = packed array[0..MaxInt div SizeOf(TRGB24)-1] of TRGB24;
  PRGB24Array = ^TRGB24Array;

implementation

uses DataConnection_U;

//  ScreenShotFirst{,ScreenShotLast}:TBitmap;

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TThreadScreenShots.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{$IFDEF MSWINDOWS}
type
  TThreadNameInfo = record
    FType: LongWord;     // must be 0x1000
    FName: PAnsiChar;    // pointer to name (in user address space)
    FThreadID: LongWord; // thread ID (-1 indicates caller thread)
    FFlags: LongWord;    // reserved for future use, must be zero
  end;
{$ENDIF}

{ TThreadScreenShots }

procedure TThreadScreenShots.SetName;
{$IFDEF MSWINDOWS}
var
  ThreadNameInfo: TThreadNameInfo;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  ThreadNameInfo.FType := $1000;
  ThreadNameInfo.FName := 'ThreadScreenShots';
  ThreadNameInfo.FThreadID := $FFFFFFFF;
  ThreadNameInfo.FFlags := 0;

  try
    RaiseException( $406D1388, 0, sizeof(ThreadNameInfo) div sizeof(LongWord), @ThreadNameInfo );
  except
  end;
{$ENDIF}
end;

procedure TThreadScreenShots.GetScreenShot;// ��� ���� �� ������
begin
  FJpegImg.Bitmap.SetSize(AWidth,AHeight);
  BitBlt(FJpegImg.Bitmap.Canvas.Handle,0,0,FJpegImg.Bitmap.Width,FJpegImg.Bitmap.Height,DC,0, 0,SRCCOPY);
end;

//procedure TThreadScreenShots.UnmergeChange(BitmapFirst,BitmapLast:TBitmap;var BitmapChange:TBitmap);// ��� ������ ��� ������
//var
//  x,y  : Integer;
//  LineFirst,LineLast,LineResult : PRGB24Array;
//begin
//  if BitmapFirst.Handle=0 then
//  begin
//    BitmapChange:=BitmapLast;
//    Exit;
//  end;
//  BitmapChange.SetSize(BitmapLast.Width,BitmapLast.Height);
////  BitmapChange.PixelFormat := pf24bit;
////  BitmapFirst.PixelFormat := pf24bit;
////  BitmapLast.PixelFormat := pf24bit;
//
//  for y := 0 to BitmapFirst.Height - 1 do
//  begin
//    LineFirst := BitmapFirst.Scanline[y];
//    LineLast := BitmapLast.Scanline[y];
//    LineResult := BitmapChange.Scanline[y];
//    for x := 0 to BitmapFirst.Width - 1 do
//    begin
//      if (LineLast[x].B = LineFirst[x].B)And(LineLast[x].G = LineFirst[x].G)And(LineLast[x].R = LineFirst[x].R) then
//      begin
//        LineResult[x].B:=0;
//        LineResult[x].G:=0;
//        LineResult[x].R:=0;
//      end
//      else
//      begin
//        LineResult[x].B:=LineLast[x].B;
//        LineResult[x].G:=LineLast[x].G;
//        LineResult[x].R:=LineLast[x].R;
//      end;
//    end;
//  end;
//end;

procedure TThreadScreenShots.SendImage;
const
  MaxBufSize = $FFE3;
var
  Count: Int64;
  BufSize, N: Integer;
  Buffer: TBytes;
begin
  Count := FJpegImg.Image.Size;
  FJpegImg.Image.Position := 0;
  if Count > MaxBufSize then BufSize := MaxBufSize else BufSize := Count;
  SetLength(Buffer,BufSize);
  try
    while Count <> 0 do
    begin
      if Count > BufSize then
       N := BufSize
      else
      begin
        N := Count;
        SetLength(Buffer,Count)
      end;
      FJpegImg.Image.ReadBuffer(Pointer(Buffer)^, N);
      DataConnection.IdUDPClientScreenShots.SendBuffer(Buffer);
      Dec(Count, N);
    end;
  finally
    //SetLength(Buffer,0);
  end;
end;

procedure TThreadScreenShots.MergeCursor;// ����� ������
  function GetCursorInfo2: TCursorInfo;inline;
  var
   hWindow: HWND;
   pt: TPoint;
   pIconInfo: TIconInfo;
   dwThreadID, dwCurrentThreadID: DWORD;
  begin
   Result.hCursor := 0;
   ZeroMemory(@Result, SizeOf(Result));
   // Find out which window owns the cursor
   if GetCursorPos(pt) then
   begin
     Result.ptScreenPos := pt;
     hWindow := WindowFromPoint(pt);
     if IsWindow(hWindow) then
     begin
       // Get the thread ID for the cursor owner.
       dwThreadID := GetWindowThreadProcessId(hWindow, nil);

       // Get the thread ID for the current thread
       dwCurrentThreadID := GetCurrentThreadId;

       // If the cursor owner is not us then we must attach to
       // the other thread in so that we can use GetCursor() to
       // return the correct hCursor
       if (dwCurrentThreadID <> dwThreadID) then
       begin
         if AttachThreadInput(dwCurrentThreadID, dwThreadID, True) then
         begin
           // Get the handle to the cursor
           Result.hCursor := GetCursor;
           AttachThreadInput(dwCurrentThreadID, dwThreadID, False);
         end;
       end
       else
       begin
         Result.hCursor := GetCursor;
       end;
     end;
   end;
  end;
var
//  LineMain,LineCursor : PRGB24Array;
//  X,Y:Integer;
//  var
////  ScreenShotPermutation:TBitmap;
//  CursorPos:TPoint;
 MyCursor: TIcon;
 CursorInfo: TCursorInfo;
 IconInfo: TIconInfo;
begin
//  GetCursorPos(CursorPos);
//  for Y := 0 to FBitmapCursor.Height - 1 do
//  begin
//    if CursorPos.Y+Y>FJpegImg.Bitmap.Height-1 then Break ;
//    LineMain := FJpegImg.Bitmap.Scanline[CursorPos.Y+Y];
//    LineCursor := FBitmapCursor.Scanline[Y];
//    for X := 0 to FBitmapCursor.Width - 1 do
//    begin
//      if CursorPos.X+X>FJpegImg.Bitmap.Width-1 then Break ;
//      if not((LineCursor[X].B=0) and (LineCursor[X].G=0) and (LineCursor[X].R=0)) then
//      begin
//        LineMain[CursorPos.X+X].B := LineCursor[X].B;
//        LineMain[CursorPos.X+X].G := LineCursor[X].G;
//        LineMain[CursorPos.X+X].R := LineCursor[X].R;
//      end;
//    end;
//  end;
   MyCursor := TIcon.Create;
   try
     // Retrieve Cursor info
     CursorInfo := GetCursorInfo2;
     if CursorInfo.hCursor <> 0 then
     begin
       MyCursor.Handle := CursorInfo.hCursor;
       // Get Hotspot information
       GetIconInfo(CursorInfo.hCursor, IconInfo);
       // Draw the Cursor on our bitmap
       FJpegImg.Bitmap.Canvas.Draw(CursorInfo.ptScreenPos.X - IconInfo.xHotspot,
                           CursorInfo.ptScreenPos.Y - IconInfo.yHotspot, MyCursor);
     end;
   finally
     // Clean up
     MyCursor.ReleaseHandle;
     MyCursor.Free;
   end;
end;

procedure TThreadScreenShots.ResizeBitmap;
begin
  FJpegImg.Bitmap.Canvas.StretchDraw(FRect,FJpegImg.Bitmap) ;
  FJpegImg.Bitmap.SetSize(FRect.Right,FRect.Bottom);
end;

//procedure SimulateKeyDown(Key : byte);
//begin
//   try
//     keybd_event(Key, 0, 0, 0);
//   except
//     exit;
//   end;
//end;
//
//procedure SimulateKeyUp(Key : byte);
//begin
//   try
//     Keybd_event(Key, 0, KEYEVENTF_KEYUP, 0);
//   except
//     exit
//   end
//end;
//
//procedure SimulateKeystroke(Key : byte; extra : DWORD);
//begin
//   try
//     keybd_event(Key,extra,0,0);
//     keybd_event(Key,extra,KEYEVENTF_KEYUP,0);
//   except
//     exit;
//   end;
//end;
//
//procedure SendKeys(s : string);
//var
//   i : integer;
//   flag : bool;
//   w : word;
//begin
//   try
//     flag := not GetKeyState(VK_CAPITAL) and 1 = 0;
//     if flag then SimulateKeystroke(VK_CAPITAL, 0);
//     for i := 1 to Length(s) do
//        begin
//           w := VkKeyScan(s[i]);
//           if ((HiByte(w) <> $FF) and (LoByte(w) <> $FF)) then
//                   begin
//                      if HiByte(w) and 1 = 1 then SimulateKeyDown(VK_SHIFT);
//                        SimulateKeystroke(LoByte(w), 0);
//                      if HiByte(w) and 1 = 1 then SimulateKeyUp(VK_SHIFT);
//                   end;
//        end;
//     if flag then SimulateKeystroke(VK_CAPITAL, 0);
//   except
//     exit;
//   end;
//end;

constructor TThreadScreenShots.Create(CreateSuspended: Boolean);
begin
  inherited;
  FJpegImg := TJpegImage.Create;
  FJpegImg.Bitmap.PixelFormat := pf24bit;
//  FBitmapCursor:=TBitmap.Create;
//  FBitmapCursor.LoadFromFile('Cursor.bmp');
//  FBitmapCursor.PixelFormat := pf24bit;
//-------------  GetScreenShot // ��� ���� �� ������ --------
  DC := GetDC (GetDesktopWindow);
  AWidth:=GetDeviceCaps (DC, HORZRES);
  AHeight:=GetDeviceCaps (DC, VERTRES);
//-----------------------------------------------------------------------------
  FRect.Left := 0;
  FRect.Top := 0;
end;

destructor TThreadScreenShots.Destroy;
begin
  FJpegImg.Free;
//  FBitmapCursor.Free;
  ReleaseDC(GetDesktopWindow, DC);
  inherited;
end;

procedure TThreadScreenShots.Execute;
//  ScreenShotPermutation:TBitmap;
begin
  SetName;
  { Place thread code here }
  while True do
  begin
    GetScreenShot;
    MergeCursor;
    ResizeBitmap;
    try
      //UnmergeChange(ScreenShotFirst,ScreenShotLast,ScreenShotPermutation);
      FJpegImg.Compress;
      SendImage;
    finally
      // ����� ����������
//      ScreenShotPermutation:=ScreenShotFirst;
//      ScreenShotFirst:=ScreenShotLast;
//      ScreenShotLast:=ScreenShotPermutation;
    end;
    Sleep(QualityPerformanceOptions.Sleep1);
  end;
end;

end.
