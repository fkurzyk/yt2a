param(
	[string]$link,
	[string]$tracklist="none",
	[bool]$cleanup=$True
)

# dependencies
$youtubedl = ".\dependencies\youtube-dl\youtube-dl.exe"
$ffmpeg = ".\dependencies\ffmpeg-3.4-win32-static\bin\"
$mp3splt = ".\dependencies\mp3splt_2.6.2_i386\mp3splt.exe"

$outputdir = "output"
$workdir = "tmp-"+[string][int](get-date).TimeOfDay.TotalMilliseconds
mkdir ".\$workdir" | out-null

& $youtubedl --ffmpeg-location $ffmpeg --console-title --write-description --extract-audio --audio-format mp3 --audio-quality 320K -o "$workdir\%(title)s-%(id)s.%(ext)s" "$link"

$videoname = $(ls $workdir\*.description).BaseName
if ($tracklist -eq "none") {
	$descriptionfile = $(ls $workdir\*.description)
} else {
	$descriptionfile = $tracklist
}
$mp3file = $(ls $workdir\*.mp3)

$filecontent = get-content -Encoding UTF8 -LiteralPath $descriptionfile

$splitpoints = @( )
$tags = ""
foreach ($line in $filecontent) {
	if ($line -match "((\d){1,2}:)?(\d){1,2}:\d\d") {
		write-output $line
		$time = $matches[0]
		[int]$hours = $time.split(':')[-3]
		[int]$minutes = $time.split(':')[-2]
		[int]$seconds = $time.split(':')[-1]
		$splitpoint = [string]($hours*60+$minutes)+"."+[string]$seconds
		$splitpoints = $splitpoints += $splitpoint
		
		$line = $($line -replace "((\d){1,2}:)?(\d){1,2}:\d\d")
		$line = $line -replace '[\[\]]',''
		if ( $line -match " - " ) {
			$artist = $line.split("-")[0]
			$title = $line.split("-")[1]
		} else {
			$artist = $videoname -replace '[\[\]]',''
			$title = $line
		}
		$artist = $artist.trim() -replace '["]',''
		$title = $title.trim() -replace '["]',''
		$tags += "[@a=$artist,@t=$title,@b=$videoname]"
	
		write-output "splitpoint: $splitpoint artist: $artist title: $title"
	}
}

$splitpoints += "EOF"

write-output "SPLITPOINTS"
write-output $splitpoints
write-output "TAGS"
write-output $tags

& $mp3splt "-o" "@n @a - @t" "-d" ".\$outputdir\$videoname" "-T" "12" "-g" "$tags" $mp3file $splitpoints

if ( $cleanup ) {
	rm -Recurse $workdir
}