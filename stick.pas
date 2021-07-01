Program Stick;

{$mode objfpc}

Uses	crt,
		classes,
		sysutils;

Type
		AreaRec = Record
			Name	: String;
			AreaDesc: String;
			Location: String;
			Files	: LongInt;
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
			TicFile	: String;
		End;

		NodeRec = Record
			Name	: String;
			Area	: String;
		end;

		TicArray = Array of TicRec;
		NodeArray = Array of NodeRec;

Const
		Version		: String = '1.2a';
		Copyright	: String = '2014 by Spiro Dotgeek';

Var
		cfgFile		: String = 'stick.cfg';
		logFile		: String = 'stick.log';
		annFile		: String;
		announce	: Boolean = False;
		af,
		lf			: Text;
		quarDir		: String = '';
		inDir		: String = '';
		nodeDir		: String = '';
		h,i,j,f,n	: LongInt;
		nl			: LongInt = 0;
		Area		: AreaArray;
		nlSrc,
		fileInfo	: TSearchRec;
		tic			: TicRec;
		ImportFiles	: TicArray;
		NodeList	: NodeArray;
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
		c,a			: LongInt;

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

			if upcase(leftstr(tmpline,8)) = 'NODEDIR ' then begin
				nodeDir := copy(tmpline,9,length(tmpline));
				if RightStr(nodeDir,1) <> '/' then
					nodeDir := nodeDir + '/';
				if not DirectoryExists(nodeDir) then begin
					if not CreateDir(nodeDir) then begin
						writeln('Can''t create Node Directory: ' + nodeDir);
						Close(cf);
						halt(1);
					end;
				end;
			end;


			if upcase(leftstr(tmpline,9)) = 'NODELIST ' then begin
				SetLength(Nodelist,nl+1);
				for c := 10 to length(tmpline) do begin
					cc := copy(tmpline,c,1);
					if cc = ' ' then begin
						Nodelist[nl].Name := copy(tmpline,10,c-10);
						break;
					end;
				end;
				Nodelist[nl].Area := copy(tmpline,c+1,length(tmpline));
				Inc(nl);
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
		d			: LongInt = 0;
		i			: LongInt;
		
Begin
	Assign(tf,FN);
	Reset(tf);
	for i := 0 to high(tic.LDesc) do
		tic.LDesc[i] := '';
	while not eof(tf) do begin
		readln(tf,tmpline);

		if upcase(leftstr(tmpline,5)) = 'FILE ' then begin
			tic.FName := copy(tmpline,6,length(tmpline));
			if debug then
				writeln(lf, ' ** got file: ' + tic.FName);
		end;
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
					writeln('stick v' + Version + ' - (c) ' + Copyright);
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
					writeln('          QUARANTINE <directory>');
					writeln('          NODEDIR    <directory>');
					writeln('          NODELIST   <filename> <filearea>');
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

	DecodeDate(dt,dyr,dmn,ddy);
	DecodeTime(dt,thr,tmn,tsc,tms);

	// Open Log File
	Assign(lf,logFile);
	if FileExists(logFile) then
		Append(lf)
	else
		Rewrite(lf);


	{$I+}
	Try
	if FindFirst (inDir+'*.tic',faAnyFile,fileInfo) = 0 then begin
		writeln(lf,StringofChar('-',79));
		write(lf,'Started at: ' + Format('%.4d',[dyr]) + '/' + Format('%.2d',[dmn]) + '/' + Format('%.2d',[ddy]));
		writeln(lf, ' : ' + Format('%.2d',[thr]) + ':' + Format('%.2d',[tmn]) + ':' + Format('%.2d',[tsc]));
		writeln(lf,'Checking for TIC files in: ' + inDir);
		f := 0;
		gotfile := true;
		Repeat
			ReadTicFile(inDir+fileInfo.Name);
			writeln(lf,'Processing TIC file : ' + fileInfo.Name);
			SetLength(ImportFiles,f+1);
			ImportFiles[f] := tic;
			ImportFiles[f].TicFile := fileInfo.Name;
			for h := 0 to high(Area) do begin
				if upcase(ImportFiles[f].Area) = upcase(Area[h].Name) then begin
					Area[h].AreaDesc := ImportFiles[f].AreaDesc;
					Inc(Area[h].Files);
				end;
			end;
			Inc(f);
		Until FindNext(fileInfo) <> 0;
		writeln(lf,'');
	end;
	FindClose(fileInfo);
	Except
	on E: EInOutError do begin
		writeln('Can''t find ' + inDir+'*.tic');
		end;
	End;


	if gotfile and announce then begin
		Assign(af,annFile);
		if FileExists(annFile) then
			Append(af)
		else
			Rewrite(af);

		for i := 0 to high(Area) do begin
			if Area[i].Files > 0 then begin
				if announce then begin
					writeln(af,'>Area: ' + upcase(Area[i].Name) + ' // ' + Area[i].AreaDesc);
					writeln(af,' ' + StringOfChar('-',78));
				end;
				if debug then begin
					writeln(lf,'');
					writeln(lf,'Area: ' + Area[i].Name);
				end;
				for f := 0 to high(ImportFiles) do begin
					for n := 0 to high(nodelist) do begin
						if (nodelist[n].Name = leftstr(ImportFiles[f].FName,length(nodelist[n].Name))) and (UpCase(nodelist[n].Area) = UpCase(ImportFiles[f].Area)) and (upcase(nodelist[n].Area) = UpCase(Area[i].Name)) then begin
							CopyFl(inDir+ImportFiles[f].FName,nodeDir+ImportFiles[f].FName);
							writeln(lf,'Copied nodelist: ' + ImportFiles[f].FName);
							if debug then 
								writeln(lf,'Source Nodelist: ' + inDir + ImportFiles[f].FName + ' -> ' + nodeDir);
						end;
					end;
					if UpCase(Area[i].Name) = UpCase(ImportFiles[f].Area) then begin
						SrcFile := inDir+ImportFiles[f].FName;
						if debug then
							writeln(lf,'Source File: ' + SrcFile);
						DstFile := Area[i].Location+ImportFiles[f].FName;
						if announce then begin
							write(af,Format('  %0:-15s ',[ImportFiles[f].FName]));
							write(af,Format(' %0:12s  ',[ImportFiles[f].Size]));
							writeln(af,ImportFiles[f].Desc);
							if longdesc then begin
								for j := 0 to high(ImportFiles[f].LDesc) do begin
									if ImportFiles[f].LDesc[j] <> '' then
										writeln(af,StringOfChar(' ',33) + ImportFiles[f].LDesc[j]);
								end;
							end;
							writeln(af,'');
						end;
						writeln(lf,'Moving file: "' + ImportFiles[f].FName + '" to area ' + Area[i].Name);
						if debug then
							writeln(lf,'Destination File: ' + DstFile);
						{$I+}
						Try
						CopyFl(SrcFile,DstFile);
						Except
						on E: EFOpenError do begin
							writeln(lf, 'ERROR: Source File ' + SrcFile + ' doesn''t exist');
							continue;
							end;
						End;

						
						if FileExists(DstFile) then begin
							if quarantine then
								CopyFl(inDir+ImportFiles[f].TicFile,	quarDir+ImportFiles[f].TicFile);
							{$I+}
							Try
							DeleteFile(SrcFile);
							Except
							on E: EFOpenError do begin
								writeln(lf, 'ERROR: Source File ' + SrcFile + ' doesn''t exist. Can''t delete.');
								continue;
								end;
							End;
							if debug then writeln(lf,'Move successful.');
							DeleteFile(inDir+ImportFiles[f].TicFile);
							if debug then writeln(lf,'Deleted ' + ImportFiles[f].TicFile);
						end;
					end;
				end;
			end;
		end;
	end;
	Close(lf);

	if announce and gotfile then begin
		writeln(af,' ' + StringOfChar('-',78));
		writeln(af,'');
		tstr := 'Files processed by Stick v' + Version + ' (c) ' + Copyright;
		writeln(af,StringOfChar(' ',78-length(tstr)) + tstr);
		tstr := '(spiro@oldschool.geek.nz)';
		writeln(af,StringOfChar(' ',78-length(tstr)) + tstr);
		writeln(af,'');
	end;

	if gotfile and announce then 
		Close(af);

	if gotfile then
		halt(2);

End.
