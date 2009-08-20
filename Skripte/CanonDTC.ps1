# Variabeln müssen initialisiert werden
set-psdebug -strict


# Assemblies laden (das Casten nach void unterdrückt die Ausgabe des Rückgabewertes)

[void][System.Reflection.Assembly]::Load("System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a");


# Verwendete Variabeln

[string]$script:strTempFolderPath = "";			# temporäres Verzeichnis; wird automatisch angelegt und gelöscht

[bool]$script:bolRotated = $false;					# Gibt an, ob das Bild beim letzten Skalierungsvorgang gedreht wurde (siehe Scale-Methode). In diesem Fall muss die AutoRotate-Funktion der Kamera aktiviert werden.


# Verwendete Parameter-Variabeln

[int]$script:intWidth = 0;									# gewünschte Breite
[int]$script:intHeight = 0;									# gewünschte Höhe

[string]$script:strSourceFolderPath = "";		# Quellverzeichnis
[string]$script:strTargetFolderPath = "";		# Zielverzeichnis

[bool]$script:bolRename = $false;						# Dateien nach dem Schema img_#### umbennen

[string]$script:strExiftoolPath = "";				# Pfad zu ExifTool von Phil Harvey (EXE)

[string]$script:strExifTemplatePath = "";		# Pfad zu der Exif-Daten-Vorlage

[bool]$script:bolAutoRotate = $true					# Bestimmt ob die AutoRotate-Funktion der Kamera zum Darstellen von Hochformatbildern genutzt werden soll
[bool]$script:bolKeepAspectRatio = $false;	# Legt fest, ob das Seitenverhältnis des ursprünglichen Bildes beibehalten wird. Auftretende Ränder werden mit der Farbe CanvasColor gefüllt. Die Farbangabe erfolgt entweder als Name aus der KnownColors Enumeration oder nach dem Schema #RRGGBB.
[System.Drawing.Color]$Script:clrCanvasColor = [System.Drawing.Color]::Empty; # siehe KeepAspectRatio

[int]$script:intJpegQuality = 0;						# Bestimmt die Qualität und Größe des Ausgabebildes. Werte von 1 bis 100 (einschließlich) erlaubt.


# Voreinstellungen

$intWidth = 1600;
$intHeight = 1200;

$strSourceFolderPath = "../Source/";
$strTargetFolderPath = "../Target/";

$bolRename = $false;

$strExiftoolPath = "../Tools/exiftool.exe";

$strExifTemplatePath = "../Vorlagen/canon.jpg";

$bolAutoRotate = $true;
$bolKeepAspectRatio = $true;
$clrCanvasColor = [System.Drawing.Color]::Black;

$intJpegQuality = 85;


# Methoden einbinden

. ./CanonDTC-Methods.ps1


#
# Logik
#

# Arbeitsverzeichnis festlegen
[System.IO.Directory]::SetCurrentDirectory( $(get-location) );

# Parameter einlesen
ParseArguments $args;

# Pfade überprüfen
ValidatePaths;

# temporäres Verzeichnis mit zufälligem Namen erzeugen
$strTempFolderPath = "./tmp-" + $(new-object "System.Random").Next(1000,10000);
[void] [System.IO.Directory]::CreateDirectory($strTempFolderPath);

#Einstellungen ausgeben:
"";
"Breite:                       " + $intWidth;
"Höhe:                         " + $intHeight;
"Seitenverhältnis beibehalten: " + $bolKeepAspectRatio;
"Autorotate verwenden:         " + $bolAutoRotate;
"Randfarbe:                    " + $clrCanvasColor;
"";
"Jpeg-Qualität:                " + $intJpegQuality;
"";
"Quellverzeichnis:             " + $strSourceFolderPath.Replace("\", "/");
"Zielverzeichnis:              " + $strTargetFolderPath.Replace("\", "/");
"Temporäres Verzeichnis:       " + $strTempFolderPath.Replace("\", "/");
"";
"Dateinamen anpassen:          " + $bolRename;
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
			$strNewFileName = "img_" + ($i + 1).ToString("D4");

			write-host -noNewLine $(" -> " + $strNewFileName + ".jpg");
		}
		elseif ($strNewFileName.EndsWith(".jpg"))
		{
			$strNewFileName = $strNewFileName.Remove($strNewFileName.Length - 4);
		}

		write-host -noNewLine "... ";

		# GDI+ wirft eine OutOfMemoryException wenn das Bildformat nicht unterstützt wird (schon verrückt...)
		[bool]$bolImageSupported = $true;

		trap [System.OutOfMemoryException]
		{
			$script:bolImageSupported = $false;

			continue;
		}

		CreateThumbnail $strFilePath $strNewFileName;

		# CreateThumbnail und CreateScaledImage werfen im Falle eines nicht unterstützten Bildformats eine OutOfMemoryException (liegt an
		# GDI+). Diese wird im vorangehenden trap-Block gefangen, allerdings existiert dann nur noch die Möglichkeit den aktuellen Scope
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

# Temporäre Daten löschen
remove-item -path $strTempFolderPath -recurse