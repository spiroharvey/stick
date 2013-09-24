Program Stick;

{$mode objfpc}

Uses	crt,
		classes,
		sysutils;

Type
		AreaRec = Record
			Name	: String;
			Location: String;
		End;

		AreaArray = Array of AreaRec;

		TicRec = Record
			FName	: String;
			Area	: String;
			AreaDesc: String;
			Desc	: String[80];
			LDesc	: array [0..9] of String[80];
			Size	: string;
			Replaces: String;
		End;

Const
		Version		: String = '1.1';

Var
		cfgFile		: String = 'stick.cfg';
		logFile		: String = 'stick.log';
		annFile		: String;
		announce	: Boolean = False;
		af,
		lf			: Text;
		quarDir		: String = '';
		inDir		: String = '';
		i,j			: integer;
		Area		: AreaArray;
		fileInfo	: TSearchRec;
		tic			: TicRec;
		tstr,
		SrcFile,
		DstFile		: String;
		debug		: Boolean = false;
		longdesc	: Boolean = true;
		strictdiz	: Boolean = false;
		gotfile		: Boolean = false;
		quarantine	: Boolean = false;

		dt			: double;
		dyr,dmn,ddy,
		thr,tmn,tsc,tms : word;


Procedure LoadCfg;
Var
		cf			: Text;
		cc			: string;
		tmpline		: string;
		c,a			: integer;

Begin
	a := 0;
	if FileExists(cfgFile) then begin
		Assign(cf,cfgFile);
		Reset(cf);
		while not eof(cf) do begin
			readln(cf,tmpline);
			if length(tmpline) = 0 then continue;
			if leftstr(tmpline,1) = '#' then continue;
			if leftstr(tmpline,1) = ';' then continue;

			if upcase(leftstr(tmpline,9)) = 'AREANAME ' then begin
				SetLength(Area,a+1);
				for c := 10 to length(tmpline) do begin
					cc := copy(tmpline,c,1);
					if cc = ' ' then begin
						Area[a].Name := copy(tmpline,10,c-10);
						break;
					end;
				end;
				Area[a].Location := copy(tmpline,c+1,length(tmpline));
				if RightStr(Area[a].Location,1) <> '/' then
					Area[a].Location := Area[a].Location + '/';
				Inc(a);
			end;

			if upcase(leftstr(tmpline,8)) = 'LOGFILE ' then
				logFile := copy(tmpline,9,length(tmpline));

			if upcase(leftstr(tmpline,8)) = 'INBOUND ' then begin
				inDir := copy(tmpline,9,length(tmpline));
				if RightStr(inDir,1) <> '/' then
					inDir := inDir + '/';
			end;

			if upcase(leftstr(tmpline,6)) = 'DEBUG ' then begin
				case upcase(copy(tmpline,7,length(tmpline))) of
					'1',
					'YES',
					'Y',
					'ON',
					'TRUE' : debug := true;
				end;
			end;

			if upcase(leftstr(tmpline,9)) = 'LONGDESC ' then begin
				case upcase(copy(tmpline,10,length(tmpline))) of
					'0',
					'NO',
					'N',
					'OFF',
					'FALSE' : longdesc := false;
				end;
			end;

			if upcase(leftstr(tmpline,9)) = 'ANNOUNCE ' then begin
				announce := true;
				annFile := copy(tmpline,10,length(tmpline));
				if annFile = '' then
					annFile := 'announce.txt';
			end;

			if upcase(leftstr(tmpline,10)) = 'STRICTDIZ ' then begin
				case upcase(copy(tmpline,11,length(tmpline))) of
					'1',
					'YES',
					'Y',
					'ON',
					'TRUE' : strictdiz := true;
				end;
			end;

			if upcase(leftstr(tmpline,11)) = 'QUARANTINE ' then begin
				quarantine := true;
				quarDir := copy(tmpline,12,length(tmpline));
				if RightStr(quarDir,1) <> '/' then
					quarDir := quarDir + '/';
				if not DirectoryExists(quarDir) then begin
					if not CreateDir(quarDir) then begin
						writeln('Can''t create Quarantine directory: ' + quarDir);
						Close(cf);
						halt(1);
					end;
				end;
			end;

		end;
	end else begin
		writeln('Can''t find config file: ' + cfgFile);
		halt(1);
	end;
	if inDir = '' then begin
		writeln('Error: Need an INBOUND directory.');
		Close(cf);
		halt(2);
	end;
	Close(cf);
End;


Procedure ReadTicFile(FN : String);
Var
		tf			: Text;
		tmpline		: string;
		d			: integer = 0;
		i			: integer;
		
Begin
	Assign(tf,FN);
	Reset(tf);
	for i := 0 to high(tic.LDesc) do
		tic.LDesc[i] := '';
	while not eof(tf) do begin
		readln(tf,tmpline);

		if upcase(leftstr(tmpline,5)) = 'FILE ' then
			tic.FName := copy(tmpline,6,length(tmpline));
		if upcase(leftstr(tmpline,5)) = 'AREA ' then
			tic.Area := copy(tmpline,6,length(tmpline));
		if upcase(leftstr(tmpline,9)) = 'AREADESC ' then
			tic.AreaDesc := copy(tmpline,10,length(tmpline));
		if upcase(leftstr(tmpline,5)) = 'DESC ' then
			tic.Desc := copy(tmpline,6,length(tmpline));
		if upcase(leftstr(tmpline,5)) = 'SIZE ' then
			tic.Size := copy(tmpline,6,length(tmpline));
		if upcase(leftstr(tmpline,6)) = 'LDESC ' then begin
			if strictdiz then
				tic.LDesc[d] := copy(tmpline,7,45)
			else
				tic.LDesc[d] := copy(tmpline,7,length(tmpline));
			inc(d);
		end;
	end;
	Close(tf);						
End;

Procedure CopyFl(src,dst:String);
var
		s,d	: TFileStream;
Begin
	s := TFileStream.Create(src,fmOpenRead);
	d := TFileStream.Create(dst,fmCreate);
	d.copyfrom(s,s.size);
	s.free;
	d.free;
End;

Procedure CheckArgs;
Var
	a : integer;
Begin
	for a := 1 to ParamCount do begin
		Case ParamStr(a) of
			'-c' : cfgFile := ParamStr(a+1);
			'-d' : debug := True;
			'--help',
			'-h' : begin
					writeln();
					writeln('stick v' + Version + ' - (c) 2013 by Spiro Dotgeek');
					writeln('  Usage:');
					writeln('          stick [-c configfile]');
					writeln('                [-d] to set debug mode');
					writeln();
					writeln('  configfile consists of:');
					writeln('          INBOUND    <inbound path>');
					writeln('          AREANAME   <echoname> <file directory>');
					writeln('          DEBUG      on/off');
					writeln('          LONGDESC   on/off');
					writeln('          ANNOUNCE   <filename>');
					writeln('          QUARANTINE <idirectory>');
					writeln();
					halt(0);
					end;
		End;
	End;
End;


Begin
	dt := Now;
	CheckArgs;
	LoadCfg;

    if Debug then
	    for i := 0 to high(area) do
		    writeln('area #' + intToStr(i) + ':' + Area[i].Name + ':' + Area[i].Location + ':');

	DecodeDate(dt,dyr,dmn,ddy);
	DecodeTime(dt,thr,tmn,tsc,tms);

	// Open Log File
	Assign(lf,logFile);
	if FileExists(logFile) then
		Append(lf)
	else
		Rewrite(lf);


	// Open Announcement File
	if announce then begin
		Assign(af,annFile);
		if FileExists(annFile) then
			Append(af)
		else
			Rewrite(af);
	end;

	{$I+}
	Try
	if FindFirst (inDir+'*.tic',faAnyFile,fileInfo) = 0 then begin
		write(lf,'Started at: ' + Format('%.4d',[dyr]) + '/' + Format('%.2d',[dmn]) + '/' + Format('%.2d',[ddy]));
		writeln(lf, ' : ' + Format('%.2d',[thr]) + ':' + Format('%.2d',[tmn]) + ':' + Format('%.2d',[tsc]));
		writeln(lf,'Checking for TIC files in: ' + inDir);
		Repeat
			ReadTicFile(inDir+fileInfo.Name);
			writeln(lf,'Processing TIC file : ' + fileInfo.Name);
			SrcFile := inDir+tic.FName;
			if debug then
				writeln(lf,'Source File: ' + SrcFile);
			for i := 0 to high(Area) do begin
				if UpCase(Area[i].Name) = UpCase(tic.Area) then begin
					DstFile := Area[i].Location+tic.FName;
					if announce then begin
		 				writeln(af,'>Area: ' + upcase(tic.Area) + ' // ' + tic.AreaDesc);
						writeln(af,' ' + StringOfChar('-',78));
						write(af,Format('  %0:-15s ',[tic.FName]));
						write(af,Format(' %0:12s  ',[tic.Size]));
						writeln(af,tic.Desc);
						if longdesc then begin
							for j := 0 to high(tic.LDesc) do begin
								if tic.LDesc[j] <> '' then
									writeln(af,StringOfChar(' ',33) + tic.LDesc[j]);
							end;
						end;
						writeln(af,'');
					end;
					writeln(lf,'Moving file: "' + tic.FName + '" to area ' + Area[i].Name);
					if debug then
						writeln(lf,'Destination File: ' + DstFile);
					CopyFl(SrcFile,DstFile);
					if FileExists(DstFile) then begin
						if quarantine then begin
						//	CopyFl(SrcFile,				quarDir+tic.FName);
							CopyFl(inDir+fileInfo.Name,	quarDir+fileInfo.Name);
						end;
						DeleteFile(SrcFile);
						if debug then writeln(lf,'Move successful.');
						DeleteFile(inDir+fileInfo.Name);
						if debug then writeln(lf,'Deleted ' + fileInfo.Name);
						gotfile := true;
					end;
				end;
			end;
		Until FindNext(fileInfo) <> 0;
		writeln(lf,'');
	end;
	FindClose(fileInfo);
	Except
	on E: EInOutError do begin
		writeln('Can''t find ' + inDir+'*.tic');
		end;
	End;
	Close(lf);

	if announce and gotfile then begin
		writeln(af,' ' + StringOfChar('-',78));
		writeln(af,'');
		tstr := 'Files processed by Stick v' + Version + ' (c) 2013 by SDG';
		writeln(af,StringOfChar(' ',78-length(tstr)) + tstr);
		tstr := '(spiro@oldschool.geek.nz)';
		writeln(af,StringOfChar(' ',78-length(tstr)) + tstr);
		writeln(af,'');
	end;

	Close(af);

	if gotfile then
		halt(2);

End.
