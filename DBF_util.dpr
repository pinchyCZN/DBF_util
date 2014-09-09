program DBF_UTIL;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  StrUtils,
  Classes,
  DBTables,
  BDE,
  ApCommon,
  ApoDSet,
  ApoQSet,
  inifiles,
  L_String
  ;

function GetCh(): Char;
var
rec:INPUT_RECORD;
count:Cardinal;
state:Cardinal;
stdin:Cardinal;
begin
result:=#0;
stdin:=GetStdHandle(STD_INPUT_HANDLE);
Getconsolemode(stdin,state);
SetConsoleMode(stdin,0);
while(True)do
begin
  count:=0;
  ReadConsoleInput(stdin, rec, 1, count);
  if(count=0)then
    Break;
  if(rec.EventType=KEY_EVENT) and (rec.Event.KeyEvent.bKeyDown) then
  begin
    result:=rec.Event.KeyEvent.AsciiChar;
    Exit;
  end;
end;
SetConsoleMode(stdin,state);
end;

function bde_reindex(tname:string; dbname:string; pack,zap:boolean):boolean;
var table:TTable;
begin
  result:=False;
  table:=TTable.Create(nil);
  try
  try
    table.TableName:=tname;
    table.TableType:=ttFoxPro;
    table.DatabaseName:=dbname;
    table.Exclusive:=True;
    try
      table.Open;
      if(zap)then
        table.EmptyTable;
      if(pack)then
        DBiPackTable(table.DBHandle,Table.Handle,nil,nil,TRUE);
      Check(DbiRegenIndexes(table.Handle));
      Check(DbiSaveChanges(table.Handle));
      result:=True;
    finally
      table.Close;
    end;
  finally
    table.Free;
  end;
  except on e:Exception do
    Writeln(e.message);
  end;
end;
function apollo_reindex(tname:string; dbname:string; pack:Boolean; zap:boolean):Boolean;
var table:TApolloTable;
begin
    result:=False;

    table:=TApolloTable.Create(nil);
    try
      table.TableName:=tname;
      table.TableType:=ttSXFOX;
      table.DatabaseName:=dbname;
      table.Exclusive:=True;
      try
        table.Open;
        if(zap)then
          table.Zap;
        if(pack)then
          table.Pack;
        table.Reindex;
      finally
        table.Close;
      end;
      result:=True;
    except on e:Exception do
    begin
      Writeln(e.message);
      if(table<>nil)then
        table.Close;
    end;
    end;

    if(table<>nil)then
    begin
      try
        table.Close;
      except on e:Exception do
        Writeln(e.message);
      end;
      try
        table.Free;
      except on e:Exception do
        Writeln(e.message);
      end;
    end;
end;
function get_list_files(wild:string;var list:TStringList):integer;
var sr: TSearchRec;
  dir:string;
  full:string;
begin
  dir:=ExtractFilePath(wild);
  if FindFirst(wild, faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Attr and faAnyFile)<>0 then
      begin
        if(dir<>'')then
          full:=IncludeTrailingBackslash(dir)+sr.Name
        else
          full:=sr.Name;
        list.Add(full);
      end;
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  result:=list.count;
end;

function process_files(fname:string;pack:Boolean;zap:Boolean;usebde:Boolean):Boolean;
var flist:TStringList;
i:integer;
dir:string;
table:string;
s,tf:string;
index:integer;
begin
  flist:=TStringList.Create;
  index:=AnsiPos(';',fname);
  if(index>0)then
  begin
    s:=fname;
    while(TRUE)do
    begin
      index:=AnsiPos(';',s);
      if(index<=0)then
        tf:=s
      else
        tf:=AnsiLeftStr(s,index-1);
      if(AnsiPos('*',tf) <> 0)then
      begin
        get_list_files(tf,flist);
      end
      else
        flist.Add(tf);
      index:=AnsiPos(';',s);
      if(index<=0)then
        break;
      s:=AnsiMidStr(s,index+1,Length(s));
    end;
  end
  else
  begin
    if(AnsiPos('*',fname) <> 0)then
    begin
      get_list_files(fname,flist);
    end
    else
      flist.Add(fname);
  end;
  for i:=0 to flist.Count-1 do
  begin
     if(usebde)then
     begin
       s:=flist.Strings[i];
       dir:=ExtractFilePath(s);
       if(dir='')then
        dir:=GetCurrentDir;
       table:=ExtractFileName(s);
       Writeln(ExpandFileName(s));
       if(not bde_reindex(table,dir,pack,zap))then
        Writeln(' failed!');
     end
     else
     begin
       s:=flist.Strings[i];
       dir:=ExtractFilePath(s);
       if(dir='')then
        dir:=GetCurrentDir;
       table:=ExtractFileName(s);
       Writeln(ExpandFileName(s));
       if(not apollo_reindex(table,dir,pack,zap))then
        Writeln(' failed!');
     end;
  end;
  FreeAndnil(flist);
end;


var
  pack,zap,usebde:Boolean;
  i:Integer;
  s:string;
  fname:string;
  nocmd:Boolean;
  gotparams:Boolean;
begin
  pack:=false;
  zap:=false;
  usebde:=false;

  for i := 1 to ParamCount do
  begin
//     Writeln('Parameter '+IntToStr(i)+' = '+ParamStr(i));
      s:=ParamStr(i);
      if(s[1]='-')then
      begin
        if(AnsiCompareText(s,'-pack')=0)then
          pack:=True;
        if(AnsiCompareText(s,'-zap')=0)then
          zap:=True;
        if(AnsiCompareText(s,'-bde')=0)then
          usebde:=True;
        if(AnsiCompareText(s,'-usebde')=0)then
          usebde:=True;
        if(AnsiCompareText(s,'-apollo')=0)then
          usebde:=FALSE;
        if(AnsiCompareText(s,'-useapollo')=0)then
          usebde:=FALSE;
      end
      else
        fname:=ParamStr(i);
  end;
  s:=GetEnvironmentVariable('PROMPT');
  if(Length(s)>0)then
    nocmd:=FALSE
  else
    nocmd:=True;

  if(fname<>'')then
    gotparams:=True
  else
    gotparams:=FALSE;

  if(not gotparams)then
  begin
    Writeln(ExtractFileName(ParamStr(0))+' [-pack] [-zap] [[-bde] | [-usebde]] [-apollo] fname');
    Writeln('* wildcards accepted in fname');
    if(nocmd)then
    begin
      Writeln('press any key');
      Getch();
    end;
    Exit;
  end;

  Writeln('');
  s:='';
  if(pack)then
    s:=s+'pack,';
  if(zap)then
    s:=s+'zap,';
  if(usebde)then
    s:=s+'bde'
  else
    s:=s+'using apollo';
  Writeln('current params:'+s);

  process_files(fname,pack,zap,usebde);
  if(nocmd)then
  begin
    Writeln('press any key');
    GetCh();
  end;
end.

