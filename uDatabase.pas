unit uDatabase;

interface

uses classes, Sysutils, uCommon, uHeaderPage, uTipPage, uDataPage, uPoiner,
  uGenPage;

const
  MAX_PAGE_SIZE = 32768;
  MIN_PAGE_SIZE = 1024;

type
  TFBDatabase = class(TObject)
  private
    _NameDB: string;
    _page_size_curr: integer;
    HeaderPage: THdrPage;
    _EmptyDataPage: Boolean;
    _CurrentPageNumber: int64;
    function GetCount: integer;
    function GetNameDB: string;
    function GetCurrPageSizeDB: integer;
    procedure SetCurrPage;
  public
    constructor Create(nameDB: string);
    destructor Destroy; override;
    procedure AddValue(Value: string);
    procedure Clear;
    function DBFileSize: int64;
    function typeCurrPage(PageNum: int64): integer;
    function typePageChecksum(PageNum: int64): integer;
    function GetNextDataPage: TDataPage;
    function GetDataPage(PageNum: int64): TDataPage;
    function EmptyDataPage: Boolean;
    function GenerateNewPage(const PageType: Smallint): int64;
    function GenerateNewPagePosition(const PageType: Smallint;
      Position: int64): int64;
    function ReWritePage(typePagePrew: Shortint; PageNumber: int64;
      Checksum: integer; TipeNext: integer; typePage: integer): Boolean;
    function GetHeaderFlags: string;
    procedure SetHeaderFlags(const flags: string);
    function GetHeaderPage: THdrPage;
    property Count: integer read GetCount;
    property nameDB: string read GetNameDB;
    property Curr_page_size: integer read GetCurrPageSizeDB;
  end;

implementation

uses uPag;

{ TDatabase }

procedure TFBDatabase.AddValue(Value: string);
begin

end;

procedure TFBDatabase.Clear;
begin

end;

constructor TFBDatabase.Create(nameDB: string);
begin
  _NameDB := nameDB;
  _EmptyDataPage := false;
  _CurrentPageNumber := 0;
  SetCurrPage;
end;

function TFBDatabase.DBFileSize: int64;
begin
  result := GetFileSizeBase(_NameDB);
end;

destructor TFBDatabase.Destroy;
begin

  inherited;
end;

function TFBDatabase.EmptyDataPage: Boolean;
begin
  result := _EmptyDataPage;
end;

function TFBDatabase.GenerateNewPage(const PageType: Smallint): int64;
var
  FS: TFileStream;
  DataPage: TDataPage;
  TipPage: TTipPage;
  PointerPage: TPointer_page;
  GeneratorPage: TGenerator_page;
begin
  if PageType = 0 then
  begin
    FillChar(TipPage, SizeOf(TipPage), 0);
    try
      FS := TFileStream.Create(_NameDB, fmOpenReadWrite or fmShareDenyNone);
      FS.Position := FS.Size;
      FS.Write(TipPage, SizeOf(TipPage));
      result := round(FS.Size / _page_size_curr);
    finally
      FS.Free;
    end;
  end;
end;

function TFBDatabase.GenerateNewPagePosition(const PageType: Smallint;
  Position: int64): int64;
var
  FromFile, ToFile: TFileStream;
  Buffer: array [0 .. 8192 - 1] of byte;
  NumRead: Longint;
  FileSize, CopiedSize: int64;
  TipPage: TTipPage;
begin
  FillChar(TipPage, SizeOf(TipPage), 0);
  FileSize := GetFileSizeBase(_NameDB);
  FromFile := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
  try
    if FileExists('new_base.FDB') then
      ToFile := TFileStream.Create('new_base.FDB', fmOpenReadWrite or
        fmShareDenyWrite)
    else
      ToFile := TFileStream.Create('new_base.FDB', fmCreate);
    try
      CopiedSize := 0;
      ToFile.Size := FileSize + _page_size_curr;
      ToFile.Position := 0;
      FromFile.Position := 0;
      NumRead := FromFile.Read(Buffer[0], _page_size_curr);
      ToFile.Write(Buffer[0], _page_size_curr);
      while NumRead > 0 do
      begin
        CopiedSize := CopiedSize + NumRead;
        if CopiedSize = Position * _page_size_curr then
          ToFile.Write(TipPage, SizeOf(TipPage));
        NumRead := FromFile.Read(Buffer[0], _page_size_curr);
        ToFile.Write(TipPage, SizeOf(TipPage))
      end;
    finally
      FreeAndNil(ToFile);
    end;
  finally
    FreeAndNil(FromFile);
  end;
  DeleteFile(_NameDB);
  RenameFile('new_base.FDB', _NameDB);
  result := 1;
end;

function TFBDatabase.GetCount: integer;
begin

end;

function TFBDatabase.GetCurrPageSizeDB: integer;
begin
  result := _page_size_curr;
end;

// Get DataPage by number
function TFBDatabase.GetDataPage(PageNum: int64): TDataPage;
var
  i, db: integer;
  ResDataPage: TDataPage;
begin
  FillChar(ResDataPage, SizeOf(ResDataPage), 0);
  try
    PageNum := PageNum - 1;
    db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
    fileseek(db, 0, 0);
    fileseek(db, PageNum * _page_size_curr, 0);
    i := fileread(db, ResDataPage, _page_size_curr);
    result := ResDataPage;
  finally
    FileClose(db);
  end;
end;

function TFBDatabase.GetHeaderPage: THdrPage;
var
  FS: TFileStream;
begin
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
    FS.Read(HeaderPage, _page_size_curr);
    result := HeaderPage;
  finally
    FS.Free;
  end;
end;

function TFBDatabase.GetHeaderFlags: string;
var
  FS: TFileStream;
  s, resString: string;
  i: integer;
begin
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
    FS.Read(HeaderPage, _page_size_curr);
    s := IntToBin2(HeaderPage.fix_data.hdr_flags);
    resString := '';
    For i := Length(s) downto 1 do
      resString := resString + s[i];
    result := resString;
  finally
    FS.Free;
  end;
end;

function TFBDatabase.GetNameDB: string;
begin
  result := _NameDB;

end;

// get nex DataPage Iterator pattern
function TFBDatabase.GetNextDataPage: TDataPage;
var
  NumRead: integer;
  db, i, countByte: integer;
  sizeStream: int64;
  DataPage: TDataPage;
  FS: TFileStream;
begin
  FillChar(DataPage, SizeOf(DataPage), 0);
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
    FS.Seek(_CurrentPageNumber, 0);
    countByte := FS.Read(DataPage, _page_size_curr);
    sizeStream := FS.Size;
    _CurrentPageNumber := _CurrentPageNumber + _page_size_curr;
    if sizeStream = _CurrentPageNumber then
      _EmptyDataPage := True;
    result := DataPage;
  finally
    FS.Free;
  end;
end;

// rewrite database page with ne data
function TFBDatabase.ReWritePage(typePagePrew: Shortint; PageNumber: int64;
  Checksum: integer; TipeNext: integer; typePage: integer): Boolean;
var
  db, i: integer;
  DataPage: TDataPage;
  TipPage: TTipPage;
begin
  try
    // TIP
    if typePagePrew = 3 then
    begin
      FillChar(TipPage, SizeOf(TipPage), 0);
      try
        db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
        fileseek(db, 0, 0);
        fileseek(db, PageNumber * _page_size_curr, 0);
        i := fileread(db, TipPage, _page_size_curr);
      finally
        FileClose(db);
      end;
      TipPage.fix_data.tip_header.pag_type := typePage;
      TipPage.fix_data.tip_header.pag_checksum := Checksum;
      TipPage.fix_data.tip_next := TipeNext;

      try
        db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
        fileseek(db, 0, 0);
        fileseek(db, PageNumber * _page_size_curr, 0);
        i := filewrite(db, TipPage, _page_size_curr);
      finally
        FileClose(db);
      end;
      result := True;
    end;
    // data
    if typePagePrew <> 3 then
    begin
      FillChar(DataPage, SizeOf(DataPage), 0);
      try
        db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
        fileseek(db, 0, 0);
        fileseek(db, PageNumber * _page_size_curr, 0);
        i := fileread(db, DataPage, _page_size_curr);
      finally
        FileClose(db);
      end;
      DataPage.fix_data.pagHdr_Header.pag_type := typePage;
      DataPage.fix_data.pagHdr_Header.pag_checksum := Checksum;
      try
        db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
        fileseek(db, 0, 0);
        fileseek(db, PageNumber * _page_size_curr, 0);
        i := filewrite(db, DataPage, _page_size_curr);
      finally
        FileClose(db);
      end;
      result := True;
    end;
  except
    result := false;
  end;
end;

procedure TFBDatabase.SetCurrPage;
var
  FS: TFileStream;
  DPage: TDataPage;
begin
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);

    FS.Read(HeaderPage, MIN_PAGE_SIZE);
    _page_size_curr := HeaderPage.fix_data.hdr_page_size;
  finally
    FS.Free;
  end;
  FillChar(HeaderPage, SizeOf(HeaderPage), 0);
  // HeaderPage:=nil;
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
    FS.Read(HeaderPage, _page_size_curr);
    _page_size_curr := HeaderPage.fix_data.hdr_page_size;
  finally
    FS.Free;
  end;

end;

procedure TFBDatabase.SetHeaderFlags(const flags: string);
var
  FS: TFileStream;
  s, resString: string;
  i, db: integer;
begin
  FillChar(HeaderPage, SizeOf(HeaderPage), 0);
  resString := '';
  For i := Length(flags) downto 1 do
    resString := resString + flags[i];
  try
    FS := TFileStream.Create(_NameDB, fmOpenRead or fmShareDenyNone);
    FS.Read(HeaderPage, _page_size_curr);

  finally
    FS.Free;
  end;

  HeaderPage.fix_data.hdr_flags := BinToInt(resString);
  try
    db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
    fileseek(db, 0, 0);
    fileseek(db, 0 * _page_size_curr, 0);
    i := filewrite(db, HeaderPage, _page_size_curr);
  finally
    FileClose(db);
  end;
end;

function TFBDatabase.typeCurrPage(PageNum: int64): integer;
var
  db, i: integer;
  DataPage: TDataPage;
begin
  try
    PageNum := PageNum - 1;
    db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
    fileseek(db, 0, 0);
    fileseek(db, PageNum * _page_size_curr, 0);
    i := fileread(db, DataPage, _page_size_curr);
    result := DataPage.fix_data.pagHdr_Header.pag_type;
  finally
    FileClose(db);
  end;
end;

function TFBDatabase.typePageChecksum(PageNum: int64): integer;
var
  db, i: integer;
  DataPage: TDataPage;
begin
  try
    db := fileopen(_NameDB, fmOpenReadWrite + fmShareExclusive);
    fileseek(db, 0, 0);
    fileseek(db, PageNum * _page_size_curr, 0);
    i := fileread(db, DataPage, _page_size_curr);
    result := DataPage.fix_data.pagHdr_Header.pag_checksum;
  finally
    FileClose(db);
  end;
end;

end.
