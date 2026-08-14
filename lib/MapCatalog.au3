#include-once

; Map catalog built from LocationsIDS naming ($Title_Map / $Title_Outpost).

Global Const $GC_I_MAPCATALOG_MAX = 256
Global $g_as_MapTitles[$GC_I_MAPCATALOG_MAX]
Global $g_i_MapTitleCount = 0

; Titles that appear in the Ascalon caravan (LocationsIDS style).
Global Const $GC_AS_ASCALON_CARAVAN_TITLES = "TheBlackCurtain|CursedLands|NeboTerrace|NorthKrytaProvince|ScoundrelsRise|GriffonsMouth|DeldrimorBowl|AnvilRock|IronHorseMine|TravelersVale|AscalonFoothills|DiessaLowlands|FlameTempleCorridor|DragonsGullet|TheBreach|OldAscalon|RegentValley|PockmarkFlats|EasternFrontier"

Global Const $GC_AS_MAPCATALOG_EXTRA = "WatchtowerCoast|TwinSerpentLakes|KessexPeak|MajestysRest|TalmarkWilderness|TearsoftheFallen|StingrayStrand|SageLands|MamnoonLagoon|Silverwood|EttinsBack|ReedBog|TheFalls|DryTop|TangleRoot"

Func MapCatalog_Init()
	_Vanquisher_InitAscalonCaravanPlan()
	$g_i_MapTitleCount = 0

	MapCatalog_AddTitlesFromPipe($GC_AS_ASCALON_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_MAPCATALOG_EXTRA)
EndFunc

Func MapCatalog_AddTitlesFromPipe($a_s_PipeList)
	Local $l_a_Parts = StringSplit($a_s_PipeList, "|")
	If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then Return
	Local $i
	For $i = 1 To $l_a_Parts[0]
		MapCatalog_AddTitle(StringStripWS($l_a_Parts[$i], 3))
	Next
EndFunc

Func MapCatalog_AddTitle($a_s_Title)
	If $a_s_Title = "" Then Return
	If MapCatalog_GetMapID($a_s_Title) <= 0 Then Return

	Local $i
	For $i = 0 To $g_i_MapTitleCount - 1
		If $g_as_MapTitles[$i] = $a_s_Title Then Return
	Next

	If $g_i_MapTitleCount >= $GC_I_MAPCATALOG_MAX Then Return
	$g_as_MapTitles[$g_i_MapTitleCount] = $a_s_Title
	$g_i_MapTitleCount += 1
EndFunc

Func MapCatalog_GetComboString()
	Local $l_s = "Current Map|(Sequence) TOA Ascalon Caravan"
	Local $i
	For $i = 0 To $g_i_MapTitleCount - 1
		$l_s &= "|" & $g_as_MapTitles[$i]
	Next
	Return $l_s
EndFunc

Func MapCatalog_GetMapID($a_s_Title)
	If $a_s_Title = "" Then Return 0

	Local $l_s_Name = $a_s_Title & "_Map"
	If IsDeclared($l_s_Name) <> 0 Then Return Number(Eval($l_s_Name))

	_Vanquisher_InitAscalonCaravanPlan()
	Local $i
	For $i = 0 To $GC_I_ASCALON_CARAVAN_MAP_COUNT - 1
		If String($g_a_AscalonCaravanPlan[$i][8]) = $a_s_Title Then Return Number($g_a_AscalonCaravanPlan[$i][0])
	Next
	Return 0
EndFunc

Func MapCatalog_GetOutpostID($a_s_Title)
	If $a_s_Title = "" Then Return 0

	Local $l_s_Name = $a_s_Title & "_Outpost"
	If IsDeclared($l_s_Name) <> 0 Then Return Number(Eval($l_s_Name))

	_Vanquisher_InitAscalonCaravanPlan()
	Local $i
	For $i = 0 To $GC_I_ASCALON_CARAVAN_MAP_COUNT - 1
		If String($g_a_AscalonCaravanPlan[$i][8]) = $a_s_Title Then Return Number($g_a_AscalonCaravanPlan[$i][1])
	Next
	Return 0
EndFunc

Func MapCatalog_GetCaravanStage($a_s_Title)
	_Vanquisher_InitAscalonCaravanPlan()
	Local $i
	For $i = 0 To $GC_I_ASCALON_CARAVAN_MAP_COUNT - 1
		If String($g_a_AscalonCaravanPlan[$i][8]) = $a_s_Title Then Return $i
	Next
	Return -1
EndFunc

Func MapCatalog_IsSequenceSelection($a_s_Selection)
	Return StringInStr($a_s_Selection, "TOA Ascalon Caravan") > 0
EndFunc

Func MapCatalog_IsCurrentMapSelection($a_s_Selection)
	Return $a_s_Selection = "" Or $a_s_Selection = "Current Map"
EndFunc
