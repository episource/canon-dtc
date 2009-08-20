#
#	ParseBooleanArgumentValue
#		Liest den boolschen Wert eines Arguments ein. Lieft den entsprechenden Wert und den neuen Index im $arguments-Array.
#		!!! Nicht gerade elegant programmiert !!!
#

function ParseBooleanArgumentValue()
{
	[bool]$bolReturnValue = $false;

	if ( ($i + 1 -ge $arguments.Length) -or (($arguments[$i + 1].Length -gt 1) -and $arguments[$i + 1].StartsWith("-")) )
	{
		$bolReturnValue = $true;
	}
	else
	{
		$i++;

		if ( ($arguments[$i] -eq "0") -or ($arguments[$i] -eq "false") )
		{
			$bolReturnValue = $false;
		}
		elseif ( ($arguments[$i] -eq "1") -or ($arguments[$i] -eq "true") )
		{
			$bolReturnValue = $true;
		}
		else
		{
			$i--;
		}
	}
	
	return $($bolReturnValue, $i);
}

#
# ParseArguments
#		Liest die Argumente ein.
#

function ParseArguments([array]$arguments)
{
	[int]$:i = 0;

	while ($i -lt $arguments.length)
	{
		$argument = ([string]$arguments[$i]).ToLower().TrimStart("-");

		switch ($argument)
		{
			"help"
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
				$srHelp = new-object "System.IO.StreamReader" $( $strBaseDir + "/CanonDTC-Help.txt" );

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
			
			"source"
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

			"target"
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
			
			"exiftool"
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
			
			"exiftemplate"
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
			
			"size"
			{
				$i++;

				if ($i -ge $arguments.length)
				{
					throw ("Dem Parameter " + $arguments[$i -1] + " muss eine Formatangabe folgen!");
				}

				$intWidth = 0;
				$intHeight = 0;

				$szSize = [System.Drawing.Size]::Empty;

				$arrSize = $arguments[$i].Split("xX");

				if ( -not ( ($arrSize.Length -eq 2) -and [Int32]::TryParse($arrSize[0], [ref] $intWidth) -and [Int32]::TryParse($arrSize[1], [ref] $intHeight) ) )
				{
					throw ($arguments[$i] + " ist keine gültige Formatangabe.");
				}
				
				if ( ($intWidth -gt 0) -and ($intHeight -gt 0) )
				{
					$szSize = new-object "System.Drawing.Size" $($intWidth, $intHeight);
				}

				if ( [System.Array]::IndexOf($arrSupportedSizes, $szSize) -eq -1 )
				{
					$bolFirst = $true;
					$strSupportedSizes = "";

					foreach($szSize in $arrSupportedSizes)
					{
						if (-not $bolFirst)
						{
							$strSupportedSizes += ", ";
						}
						else
						{
							$bolFirst = $false;
						}
					
						$strSupportedSizes += $szSize.Width.ToString() + "x" + $szSize.Height.ToString();
					}

					throw ($arguments[$i] + " wird nicht unterstützt. Es sind nur die Modi " + $strSupportedSizes + "  möglich!");
				}
			}
			
			"autosize"
			{
				[array]$arrValue = ParseBooleanArgumentValue;
				
				$script:bolAutoSize = $arrValue[0];
				$i = $arrValue[1];
			}

			"canvas"
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
			
			"jpegquality"
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
			
			"rename"
			{
				[array]$arrValue = ParseBooleanArgumentValue;

				$script:bolRename = $arrValue[0];
				$i = $arrValue[1];
			}
			
			"autorotate"
			{
				[array]$arrValue = ParseBooleanArgumentValue;

				$script:bolAutoRotate = $arrValue[0];
				$i = $arrValue[1];
			}
	
			default
			{
				throw ("Nicht unterstützter Parameter: " + $arguments[$i]);
			}
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
#	GetNewSize
#		Bestimmt das zu verwendende Zielformat. Wenn der Befehlszeilenschlater -autosize (--autosize)
#		angegeben wurde, wird das Format automatisch bestimmt. Die mit dem Argument -size (--size) angegebenen
#		Abmessungen bestimmen in diesem Fall das größte zu verwendende Bildformat. Bei Angabe von -noupscale (--noupscale)
#		werden Bilder nur heraufskaliert, wenn sie die kleinstmöglichen Bildabmessungen unterschreiten. Wenn -autosize
#		(--autosize) nicht angegeben wurde, verliert -noupscale (--noupscale) seine Wirkung und das mit -size
#		(--size) angegebene Format wird erzwungen.
#

function GetNewSize([System.Drawing.Image]$imgImage)
{
	[System.Drawing.Size]$szNewSize = [System.Drawing.Size]::Empty;

	if ( -not $bolAutoSize )
	{
		return $szTargetSize;
	}

	$intImgWidth = $imgImage.Width;
	$intImgHeight = $imgImage.Height;

	if ($bolAutoRotate -and ($imgImage.Height -gt $imgImage.Width))
	{
		$intImgWidth = $imgImage.Height;
		$intImgHeight = $imgImage.Width;
	}

	$intLowestDiffIndex = -1;
	$intHighestNegativeDiffIndex = -1;
	$intLowestDiff = [System.Int32]::MaxValue;
	$intHighestNegativeDiff = [System.Int32]::MaxValue;

	for($i = 0; $i -lt $arrSupportedSizes.Length; $i++)
	{
  	$szSupportedSize = $arrSupportedSizes[$i];
  	
  	if ( ($szSupportedSize.Width -gt $szTargetSize.Width) -or ($szSupportedSize.Height -gt $szTargetSize.Height) )
  	{
  		continue;
  	}

		if ( $( $imgImage.Width - $szSupportedSize.Width ) -ge $( $imgImage.Height - $szSupportedSize.Height ) )
		{
			$intFirstValue = $imgImage.Width;
			$intSecondValue = $szSupportedSize.Width;
		}
		else
		{
			$intFirstValue = $imgImage.Height;
			$intSecondValue = $szSupportedSize.Height;
		}

		$intDiff = $intFirstValue - $intSecondValue;
		$intAbsDiff = [System.Math]::Abs($intDiff);

		if ($intAbsDiff -lt $intLowestDiff)
		{
			if ( ($intDiff -lt 0) -and $bolNoUpscale )
			{
				if ($intAbsDiff -lt $intHighestNegativeDiff)
				{
					$intHighestNegativeDiff = $intAbsDiff;
					$intHighestNegativeDiffIndex = $i;
				}
			}
			else
			{
				$intLowestDiff = $intAbsDiff;
				$intLowestDiffIndex = $i;
			}
		}
	}
	
	$intIndex = $intLowestDiffIndex;
	
	if ($intIndex -lt 0)
	{
		$intIndex = $intHighestNegativeDiffIndex;
	}
	
	return $arrSupportedSizes[$intIndex];
}

#
#	Scale
#		Skaliert eine gegebene Image-Instanz entsprechend den gewünschten Werten.
#		Gibt ein [System.Drawing.Image]-Objekt zurück. Wenn das Bild höher als breit ist, wird es um 90°
#		im Uhrzeigersinn gedreht um das Zielformat optimal auszunutzen. Die Variable $bolRotate wird
#		entsprechend gesetzt.
#

function Scale()
{
	Param ( [System.Drawing.Image]$imgImage, [System.Drawing.Size]$szNewSize = [System.Drawing.Size]::Empty, [int]$intDpi = 0 );

	if ( $szNewSize -eq [System.Drawing.Size]::Empty )
	{
		$szNewSize = GetNewSize $imgImage;
	}

	# Bild bei Bedarf drehen
	if ($bolAutoRotate -and ($imgImage.Height -gt $imgImage.Width))
	{
		$imgImage.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone);
		$script:bolRotated = $true;
	}

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
		$intScaleWidth = $szNewSize.Width;
		$intScaleHeight = $szNewSize.Height;
	}
	elseif ($( $imgImage.Width - $szNewSize.Width ) -ge $( $imgImage.Height - $szNewSize.Height ))
	{
		$intScaleWidth = $szNewSize.Width;
		$intScaleHeight = [Math]::Round( $intScaleWidth * ( $imgImage.Height / $imgImage.Width ) , 0 );

		# Bild füllt die Breite vollständig aus, muss aber vertikal zentriert werden
		$intX = 0;
		$intY = [Math]::Ceiling( ( $szNewSize.Height - $intScaleHeight ) / 2 );
	}
	else
	{
		$intScaleHeight = $szNewSize.Height;
		$intScaleWidth = [Math]::Round( $intScaleHeight * ( $imgImage.Width / $imgImage.Height ) , 0 );

		# Bild füllt die Höhe vollständig aus, muss aber horizontal zentriert werden
		$intY = 0;
		$intX = [Math]::Ceiling( ( $szNewSize.Width - $intScaleWidth ) / 2 );
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
	$bmpBaseImage = new-object "System.Drawing.Bitmap" $($szNewSize.Width, $szNewSize.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb);
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
	$imgThumbnail = Scale $imgImage $(new-object "System.Drawing.Size" $(160, 120)) 180;

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

	# AutoRotate-Funktion der Kamera bei Bedarf aktivieren (Drehung um 270° im Uhrzeigersinn)
	if ($bolRotated)
	{
		& $strExiftoolPath -overwrite_original "-IFD0:Orientation=Rotate 270 CW" "$strFullTargetPath" | out-null;
	}
}