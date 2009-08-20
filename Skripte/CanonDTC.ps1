# Variabeln m�ssen initialisiert werden
set-psdebug -strict


# Assemblies laden (das Casten nach void unterdr�ckt die Ausgabe des R�ckgabewertes)

[void][System.Reflection.Assembly]::Load("System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a");


# Verwendete Variabeln

[string]$script:strBaseDir = "";						# Basisverzeichnis des Skripts (darin liegen die Skriptdateien)

[System.Drawing.Size[]]$script:arrSupportedSizes = $();	# Unterst�tzte Bildformate

[string]$script:strTempFolderPath = "";			# tempor�res Verzeichnis; wird automatisch angelegt und gel�scht

[bool]$script:bolRotated = $false;					# Gibt an, ob das Bild beim letzten Skalierungsvorgang gedreht wurde (siehe Scale-Methode). In diesem Fall muss die AutoRotate-Funktion der Kamera aktiviert werden.


# Verwendete Parameter-Variabeln

[System.Drawing.Size]$script:szTargetSize = [System.Drawing.Size]::Empty;	# gew�nschtes Bildformat

[string]$script:strSourceFolderPath = "";		# Quellverzeichnis
[string]$script:strTargetFolderPath = "";		# Zielverzeichnis

[bool]$script:bolRename = $false;						# Dateien nach dem Schema img_#### umbennen
[int]$script:intFirstImageNumber = 1;				# Wenn die Ausgabedateien nach dem Schema img_#### benannt werden, gibt dieser wert die Nummer des ersten Bildes an

[string]$script:strExiftoolPath = "";				# Pfad zu ExifTool von Phil Harvey (EXE)

[string]$script:strExifTemplatePath = "";		# Pfad zu der Exif-Daten-Vorlage

[bool]$script:bolAutoSize = $false;					# Bestimmt, ob das Zielformat automatisch bestimmt werden soll. Siehe auch GetNewSize([...]).
[bool]$script:bolNoUpscale = $false;					# Bestimmt, ob Bilder auch hochskaliert werden d�rfen.
[bool]$script:bolAutoRotate = $false;				# Bestimmt ob die AutoRotate-Funktion der Kamera zum Darstellen von Hochformatbildern genutzt werden soll
[bool]$script:bolKeepAspectRatio = $false;	# Legt fest, ob das Seitenverh�ltnis des urspr�nglichen Bildes beibehalten wird. Auftretende R�nder werden mit der Farbe CanvasColor gef�llt. Die Farbangabe erfolgt entweder als Name aus der KnownColors Enumeration oder nach dem Schema #RRGGBB.
[System.Drawing.Color]$Script:clrCanvasColor = [System.Drawing.Color]::Empty; # siehe KeepAspectRatio

[int]$script:intJpegQuality = 0;						# Bestimmt die Qualit�t und Gr��e des Ausgabebildes. Werte von 1 bis 100 (einschlie�lich) erlaubt.


# Voreinstellungen

$strBaseDir = $(split-path -parent $MyInvocation.MyCommand.Path);

$arrSupportedSizes = $(new-object "System.Drawing.Size" $(640, 480)), $(new-object "System.Drawing.Size" $(1600, 1200)), $(new-object "System.Drawing.Size" $(2048, 1536)), $(new-object "System.Drawing.Size" $(2592, 1944)), $(new-object "System.Drawing.Size" $(3072, 2304));

$szTargetSize = new-object "System.Drawing.Size" $(1600, 1200);

$strSourceFolderPath = $strBaseDir + "/../Source/";
$strTargetFolderPath = $strBaseDir + "/../Target/";

$bolRename = $false;
$intFirstImageNumber = 1;

$strExiftoolPath = $strBaseDir + "/../Tools/exiftool.exe";

$strExifTemplatePath = $strBaseDir + "/../Vorlagen/canon.jpg";

$bolAutoSize = $false;
$bolNoUpscale = $true;
$bolAutoRotate = $true;
$bolKeepAspectRatio = $true;
$clrCanvasColor = [System.Drawing.Color]::Black;

$intJpegQuality = 85;


# Methoden einbinden

. ($strBaseDir + "/CanonDTC-Methods.ps1");


#
# Logik
#

# Arbeitsverzeichnis festlegen
[System.IO.Directory]::SetCurrentDirectory( $(get-location) );

# Parameter einlesen
ParseArguments $args;

# Pfade �berpr�fen
ValidatePaths;

# tempor�res Verzeichnis mit zuf�lligem Namen erzeugen
$strTempFolderPath = $strBaseDir + "/tmp-" + $(new-object "System.Random").Next(1000,10000);
[void] [System.IO.Directory]::CreateDirectory($strTempFolderPath);

#Einstellungen ausgeben:
"";

$strSupportedSizes = "Unterst�tzte Zielformate:     ";
$bolFirst = $true;

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

"";
$strSupportedSizes;
"Zielformat                    " + $szTargetSize.Width + "x" + $szTargetSize.Height;
"Format automatisch bestimmen: " + $bolAutoSize;
"Bilder nicht hochskalieren:   " + $bolNoUpscale;
"Seitenverh�ltnis beibehalten: " + $bolKeepAspectRatio;
"Autorotate verwenden:         " + $bolAutoRotate;
"Randfarbe:                    " + $clrCanvasColor;
"";
"Jpeg-Qualit�t:                " + $intJpegQuality;
"";
"Quellverzeichnis:             " + $strSourceFolderPath.Replace("\", "/");
"Zielverzeichnis:              " + $strTargetFolderPath.Replace("\", "/");
"Tempor�res Verzeichnis:       " + $strTempFolderPath.Replace("\", "/");
"";
"Dateinamen anpassen:          " + $bolRename;
"Nummer des ersten Bildes:     " + $intFirstImageNumber;
"";
"Exiftool:                     " + $strExiftoolPath.Replace("\", "/");
"";
"Exif-Daten-Vorlage:           " + $strExifTemplatePath.Replace("\", "/");
"";
"";
"";

# Alle Dateien im Quellverzeichnis mit Endung .jpg durchgehen
[array]$arrFiles = [System.IO.Directory]::GetFiles($strSourceFolderPath);

if ($arrFiles.Length -eq 0)
{
	"Keine Dateien bearbeitet: Das Quellverzeichnis ist leer!";
}
else
{
	for ([int]$i = 0; $i -lt $arrFiles.Length; $i++)
	{
		write-host -noNewLine $([System.IO.Path]::GetFileName($arrFiles[$i]));
		
		[string]$strFilePath = $arrFiles[$i];
		[string]$strNewFileName = [System.IO.Path]::GetFileName($strFilePath);

		if ($bolRename -eq $true)
		{
			$strNewFileName = "img_" + ($i + $intFirstImageNumber).ToString("D4");

			write-host -noNewLine $(" -> " + $strNewFileName + ".jpg");
		}
		elseif ($strNewFileName.EndsWith(".jpg"))
		{
			$strNewFileName = $strNewFileName.Remove($strNewFileName.Length - 4);
		}

		write-host -noNewLine "... ";

		# GDI+ wirft eine OutOfMemoryException wenn das Bildformat nicht unterst�tzt wird (schon verr�ckt...)
		[bool]$bolImageSupported = $true;

		trap [System.OutOfMemoryException]
		{
			$script:bolImageSupported = $false;

			continue;
		}

		CreateThumbnail $strFilePath $strNewFileName;

		# CreateThumbnail und CreateScaledImage werfen im Falle eines nicht unterst�tzten Bildformats eine OutOfMemoryException (liegt an
		# GDI+). Diese wird im vorangehenden trap-Block gefangen, allerdings existiert dann nur noch die M�glichkeit den aktuellen Scope
		# und somit das Skript zur verlassen (break) oder fortzufahren (continue). Daher das eigenartige Konstrukt mit $bolImageSupported.
		if ($bolImageSupported)
		{
			CreateScaledImage $strFilePath $strNewFileName;

			UpdateExifData $([System.IO.Path]::Combine($strTempFolderPath, $strNewFileName + ".jpg"));

			"OK";
		}
		else
		{
			"Bildformat unbekannt";
		}
	}
}

"";

# Tempor�re Daten l�schen
remove-item -path $strTempFolderPath -recurse