#
# ParseArguments
#		Liest die Argumente ein.
#

function ParseArguments([array]$arguments)
{
	[int]$i = 0;

	while ($i -lt $arguments.length)
	{
		$argument = ([string]$arguments[$i]).ToLower();

		if ( ($argument -eq "-help") -or ($argument -eq "--help") )
		{
			[System.IO.StreamReader]$srHelp = $();
			
			# Datei im Falle eines Fehlers freigeben
			trap
			{
				if ($srHelp -ne $())
				{
					$srHelp.Dispose();
				}
			}
			
			# Leerzeile vor dem Hilfetext
			"";

			# Hilfetext laden und zeilenweise ausgeben. Zulange Zeilen werden in der nächsten Zeile mit gleichbleibender Einrückung ausgegeben.
			$srHelp = new-object "System.IO.StreamReader" "./CanonDTC-Help.txt";

			[string]$strLine = $();
			[int]$intLineLength = [System.Console]::BufferWidth - 1;

			while ( ($strLine = $srHelp.ReadLine()) -ne $() )
			{
				if ($strLine.Length -le $intLineLength)
				{
					$strLine;
					continue;
				}

				# Anzahl der Leerzeichen bestimmen
				[string]$strLeadingSpaces = "";

				for ($i = 0; $i -lt $strLine.Length; $i++)
				{
					if ($strLine[$i] -ne " ")
					{
						break;
					}

					$strLeadingSpaces += " ";
				}

				# zeilenweise Ausgabe
				[int]$intPos = $strLeadingSpaces.Length;
				[int]$intSubstringLength = $intLineLength - $strLeadingSpaces.Length;

				while ($intPos -lt $strLine.Length)
				{
					if ($intSubstringLength -gt $strLine.Length - $intPos)
					{
						$strLeadingSpaces + $strLine.Substring($intPos);
					}
					else
					{
						$strLeadingSpaces + $strLine.Substring($intPos, $intLineLength - $strLeadingSpaces.Length);
					}
					
					$intPos = $intPos + $intSubstringLength;
				}
			}

			# Datei freigeben
			$srHelp.Dispose();
			
			# Leerzeile nach dem Hilfetext
			"";

			# Script beenden
			exit;
		}
		elseif ( ($argument -eq "-source") -or ($argument -eq "--source") )
		{
			$i++;

			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i - 1] + " muss die Angabe eines Quellverzeichnisses folgen!");
			}

			if ( -not [System.IO.Directory]::Exists($arguments[$i]) )
			{
				throw ("Kein gültiges Quellverzeichnis: " + $arguments[$i]);
			}
			
			$script:strSourceFolderPath = $arguments[$i];
		}
		elseif ( ($argument -eq "-target") -or ($argument -eq "--target") )
		{
			$i++;
			
			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i - 1] + " muss die Angabe eines Zielverzeichnisses folgen!");
			}
			
			if ( -not [System.IO.Directory]::Exists($arguments[$i]) )
			{
				"Zielverzeichnis nicht vorhanden. Es wird automatisch angelegt.";
			}
			
			$script:strTargetFolderPath = $arguments[$i];
		}
		elseif( ($argument -eq "-exiftool") -or ($argument -eq "--exiftool") )
		{
			$i++;
			
			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i -1] + " muss die Angabe des Pfades zu Phil Harveys Exiftool (EXE) folgen!");
			}
			
			if ( -not [System.IO.File]::Exists($arguments[$i]) )
			{
				throw ("Keine gültige Dateiangabe: " + $arguments[$i]);
			}
			
			if ( -not $arguments[$i].ToLower().EndsWith(".exe") )
			{
				throw ("Keine ausführbare Datei: " + $arguments[$i]);
			}
			
			$script:strExiftoolPath = $arguments[$i];
		}
		elseif( ($argument -eq "-exiftemplate") -or ($argument -eq "--exiftemplate") )
		{
			$i++;
			
			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i -1] + " muss die Angabe des Pfades zur Exif-Daten-Vorlage folgen!");
			}
			
			if ( -not [System.IO.File]::Exists($arguments[$i]) )
			{
				throw ("Keine gültige Dateiangabe: " + $arguments[$i]);
			}
			
			$script:strExifTemplatePath = $arguments[$i];
		}
		elseif( ($argument -eq "-format") -or ($argument -eq "--format") )
		{
			$i++;

			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i -1] + " muss eine Formatangabe folgen!");
			}

			$arrFormat = $arguments[$i].Split("xX");

			if ( -not ( ($arrFormat.Length -eq 2) -and [Int32]::TryParse($arrFormat[0], [ref] $intWidth) -and [Int32]::TryParse($arrFormat[1], [ref] $intHeight) ) )
			{
				throw ($arguments[$i] + " ist keine gültige Formatangabe.");
			}

			if ( -not ( ($intWidth -eq 640 -and $intHeight -eq 480) -or ($intWidth -eq 1600 -and $intHeight -eq 1200) -or ($intWidth -eq 2048 -and $intHeight -eq 1536) -or ($intWidth -eq 2592 -and $intHeight -eq 1944) -or ($intWidth -eq 3072 -and $intHeight -eq 2304) ) )
			{
				throw ($arguments[$i] + " wird nicht unterstützt. Es sind nur die Modi 640x480, 1600x1200, 2048x1536, 2592x1944 und 3072x2304 möglich!");
			}
		}
		elseif ( ($argument -eq "-canvas") -or ($argument -eq "--canvas") )
		{
			$i++;
			
			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i -1] + " muss entweder eine Rahmenfarbe oder none folgen!");
			}

			if ($arguments[$i].ToLower() -eq "none")
			{
				$script:bolKeepAspectRatio = $false;
			}
			else
			{
				$bolKeepAspectRatio = $true;

				if ($arguments[$i].StartsWith("#"))
				{
					# Folgendes Schema wird vorausgesetzt: #RRGGBB

					if ($arguments[$i].Length -ne 7)
					{
						throw ("Ungültiger Farbcode: " + $arguments[$i]);
					}

					[byte]$bRot = 0;
					[byte]$bGruen = 0;
					[byte]$bBlau = 0;

					if ( -not ( [Byte]::TryParse($arguments[$i].Substring(1,2), [System.Globalization.NumberStyles]::HexNumber, $(), [ref] $bRot) -and [Byte]::TryParse($arguments[$i].Substring(3,2), [System.Globalization.NumberStyles]::HexNumber, $(), [ref] $bGruen) -and [Byte]::TryParse($arguments[$i].Substring(5,2), [System.Globalization.NumberStyles]::HexNumber, $(), [ref] $bBlau) ) )
					{
						throw ("Ungültiger Farbcode: " + $arguments[$i]);
					}
					
					$script:clrCanvasColor = [System.Drawing.Color]::FromArgb(255, $bRot, $bGruen, $bBlau);
				}
				else
				{
					$script:clrCanvasColor = [System.Drawing.Color]::FromName($arguments[$i]);
				}
			}
		}
		elseif ( ($argument -eq "-jpegquality") -or ($argument -eq "--jpegquality") )
		{
			$i++;

			if ($i -ge $arguments.length)
			{
				throw ("Dem Parameter " + $arguments[$i -1] + " muss ein numerischer Wert zwischen 1 und 100 (einschließlich) folgen.");
			}
			
			[int]$intQuality = 0;

			if ( (-not [Int32]::TryParse($arguments[$i], [ref] $intQuality)) -or ($intQuality -lt 1) -or ($intQuality -gt 100) )
			{
				throw ("Kein numerischer Wert zwischen 1 und 100 (einschließlich): " + $arguments[$i]);
			}
			
			$script:intJpegQuality = $intQuality;
		}
		elseif ( ($argument -eq "-rename") -or ($argument -eq "--rename") )
		{
			if ( ($i + 1 -ge $arguments.Length) -or (($arguments[$i + 1].Length -gt 1) -and $arguments[$i + 1].StartsWith("-")) )
			{
				$script:bolRename = $true;
			}
			else
			{
				$i++;

				if ( ($arguments[$i] -eq "0") -or ($arguments[$i] -eq "false") )
				{
					$script:bolRename = $false;
				}
				elseif ( ($arguments[$i] -eq "1") -or ($arguments[$i] -eq "true") )
				{
					$script:bolRename = $true;
				}
				else
				{
					$i--;
				}
			}
		}
		else
		{
			throw ("Nicht unterstützter Parameter: " + $arguments[$i]);
		}

		$i++;
	}
}


#
# ValidatePaths
#		Überprüft die Pfadangaben
#

function ValidatePaths()
{
	if ( -not [System.IO.Directory]::Exists($strSourceFolderPath) )
	{
		throw ("Quellverzeichnis " + $strSourceFolderPath + " nicht vorhanden!");
	}
	
	if ( -not [System.IO.Directory]::Exists($strTargetFolderPath) )
	{
		throw ("Zielverzeichnis " + $strTargetFolderPath + "nicht vorhanden!");
	}

	if ( -not [System.IO.File]::Exists($strExiftoolPath) )
	{
		throw ("Kann Exiftool nicht finden. die Pfadangabe ist falsch: " + $strExiftoolPath);
	}
}

#
#	Scale
#		Skaliert eine gegebene Image-Instanz entsprechend den gewünschten Werten.
#		Gibt ein [System.Drawing.Image]-Objekt zurück.
#

function Scale()
{
	Param ( [System.Drawing.Image]$imgImage, [int]$intNewWidth = $intWidth, [int]$intNewHeight = $intHeight, [int]$intDpi = 0 );



	# Auflösung des Bildes festlegen

	[int]$intHDpi = $intDpi;
	[int]$intVDpi = $intDpi;

	if ($intDpi -le 0)
	{
		$intHDpi = $imgImage.HorizontalResolution;
		$intVDpi = $imgImage.VerticalResolution;
	}
	
	if ( ($intHDpi -le 0) -or ($intVDpi -le 0) )
	{
		$intHDpi = 96;
		$intVDpi = 96;
	}


	# Format bestimmen, dass entweder in Breite oder Höhe mit dem Zielformat übereinstimmt. Wenn $bolKeepAspectRatio false ist, stimmen
	# beide Werte überein. Da das Bild zentriert werden soll, müssen noch die Werte $intX und $intY bestimmt werden

	[int]$intScaleWidth = 0;
	[int]$intScaleHeight = 0;
	[int]$intX = 0;
	[int]$intY = 0;

	if ($bolKeepAspectRatio -eq $false)
	{
		$intScaleWidth = $intNewWidth;
		$intScaleHeight = $intNewHeight;
	}
	elseif ($( $imgImage.Width - $intNewWidth ) -ge $( $imgImage.Height - $intNewHeight ))
	{
		$intScaleWidth = $intNewWidth;
		$intScaleHeight = [Math]::Round( $intScaleWidth * ( $imgImage.Height / $imgImage.Width ) , 0 );

		# Bild füllt die Breite vollständig aus, muss aber vertikal zentriert werden
		$intX = 0;
		$intY = [Math]::Ceiling( ( $intNewHeight - $intScaleHeight ) / 2 );
	}
	else
	{
		$intScaleHeight = $intNewHeight
		$intScaleWidth = [Math]::Round( $intScaleHeight * ( $imgImage.Width / $imgImage.Height ) , 0 );

		# Bild füllt die Höhe vollständig aus, muss aber horizontal zentriert werden
		$intY = 0;
		$intX = [Math]::Ceiling( ( $intNewWidth - $intScaleWidth ) / 2 );
	}


	# Ressourcen im Falle eines Fehlers freigeben
	[System.Drawing.Bitmap]$bmpBaseImage = $();
	[System.Drawing.Graphics]$grImage = $();

	trap
	{
		if ($grImage -ne $())
		{
			$grImage.Dispose();
		}
		
		if ($bmpBaseImage -ne $())
		{
			$bmpBaseImage.Dispose();
		}

		break;
	}

	# Erzeuge Graphics-Objekt auf Basis eines Bitmaps
	$bmpBaseImage = new-object "System.Drawing.Bitmap" $($intNewWidth, $intNewheight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb);
	$bmpBaseImage.SetResolution($intHDpi, $intVDpi);

	$grImage = [System.Drawing.Graphics]::FromImage($bmpBaseImage);

	# Bestimmt die Rahmenfarbe (falls vorhanden)
	$grImage.Clear($clrCanvasColor);

	# Bikubische Interpolation für gute Ergebnisse
	$grImage.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;

	# $imgImage skalieren
	$grImage.DrawImage($imgImage, $(new-object "System.Drawing.Rectangle" $($intX, $intY, $intScaleWidth, $intScaleHeight)), $(new-object "System.Drawing.Rectangle" $(0, 0, $imgImage.Width, $imgImage.Height)), [System.Drawing.GraphicsUnit]::Pixel);


	# Aufräumen
	$grImage.Dispose();

	return $bmpBaseImage;
}


#
# SaveAsJpeg
#		Speichert das Bild als Jpeg mit frei festlegbarer Qualität (Werte: 1-100).
#

function SaveAsJpeg([System.Drawing.Image]$imgImage, [string]$strFileName)
{
		# Jpeg
		[System.Drawing.Imaging.ImageCodecInfo]$script:iciJpegCodec = $();

		if ($script:iciJpegCodec -eq $())
		{
			[array]$arrCodecs = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders();

			foreach ($iciCodec in $arrCodecs)
			{
				if ($iciCodec.MimeType -eq "image/jpeg")
				{
					$script:iciJpegCodec = $iciCodec;
					
					break;
				}
			}
		}
		
		if ($script:iciJpegCodec -eq $())
		{
			throw ("Es wurde kein Jpeg-Codec gefunden!");
		}

		# Qualität festlegen
		[System.Drawing.Imaging.EncoderParameters]$epsParameters = new-object "System.Drawing.Imaging.EncoderParameters" 1;
		$epsParameters.Param[0] = new-object "System.Drawing.Imaging.EncoderParameter" $([System.Drawing.Imaging.Encoder]::Quality, [long]$intJpegQuality);

		# Speichern
		$imgImage.Save($strFileName + ".jpg", $iciJpegCodec, $epsParameters);
}


#
# CreateThumbnail
#		Erzeugt im temporären Verzeich ein Übersichtsbild mit den Abmessungen 160x120 und der Auflösung 180dpi
#

function CreateThumbnail([string]$strSourceImagePath, [string]$strNewFileName)
{
	# Ressourcen im Falle eines Fehlers freigeben
	[System.Drawing.Image]$imgImage = $();
	[System.Drawing.Image]$imgThumbnail = $();

	trap
	{
		if ($imgImage -ne $())
		{
			$imgImage.Dispose();
		}

		if ($imgThumbnail -ne $())
		{
			$imgThumbnail.Dispose();
		}

		break;
	}

	$imgImage = [System.Drawing.Image]::FromFile($strSourceImagePath);
	$imgThumbnail = Scale $imgImage 160 120 180;

	SaveAsJpeg $imgThumbnail $([System.IO.Path]::Combine($strTempFolderPath, $strNewFileName + "-thumb"));

	# Dateien freigeben und aufräumen
	$imgImage.Dispose();
	$imgThumbnail.Dispose();
}


#
# CreateScaledImage
#		Erzeugt im Zielverzeichnis das skalierte Bild mit den gewünschten Abmessungen und ursprünglicher Auflösung.
#

function CreateScaledImage([string]$strSourceImagePath, [string]$strNewFileName)
{
	# Ressourcen im Falle eines Fehlers freigeben
	[System.Drawing.Image]$imgImage = $();
	[System.Drawing.Image]$imgTargetImage = $();

	trap
	{
		if ($imgImage -ne $())
		{
			$imgImage.Dispose();
		}

		if ($imgTargetImage -ne $())
		{
			$imgTargetImage.Dispose();
		}
	
		break;
	}

	$imgImage = [System.Drawing.Image]::FromFile($strSourceImagePath);
	$imgTargetImage = Scale $imgImage;

	SaveAsJpeg $imgTargetImage $([System.IO.Path]::Combine($strTargetFolderPath, $strNewFileName));

	# Dateien freigeben und aufräumen
	$imgImage.Dispose();
	$imgTargetImage.Dispose();
}


#
# UpdateExifData
#		Passt die Exif-Daten so an, dass die Bilder von Canon-Kameras akzeptiert werden.
#

function UpdateExifData([string]$strSourceImagePath)
{
	[string]$strFullTargetPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($strTargetFolderPath, [System.IO.Path]::GetFileName($strSourceImagePath)));

	# Exif-Daten-Vorlage anwenden
	& $strExiftoolPath -overwrite_original -TagsFromFile "$([System.IO.Path]::GetFullPath($strExifTemplatePath))" "-all:all" "$strFullTargetPath" | out-null;

	# Thumbnail hinzufügen
	[string]$strFullThumbnailPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($strTempFolderPath, [System.IO.Path]::GetFileNameWithoutExtension($strSourceImagePath) + "-thumb.jpg"));
	& $strExiftoolPath -overwrite_original "-ThumbnailImage<=$strFullThumbnailPath" "$strFullTargetPath" | out-null;
	
	#
}