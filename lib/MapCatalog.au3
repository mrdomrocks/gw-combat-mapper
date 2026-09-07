#include-once

; Map catalog built from LocationsIDS naming ($Title_Map / $Title_Outpost).
; Combo: Current Map, Ascalon/Maguuma caravans, then one entry per Vanquish
; folder (Proph_Ascalon and Proph_Maguuma are omitted — those maps live on
; the caravan lists). Selecting a region fills the Map List.

Global Const $GC_I_MAPCATALOG_MAX = 256
Global $g_as_MapTitles[$GC_I_MAPCATALOG_MAX]
Global $g_i_MapTitleCount = 0

Global Const $GC_AS_ASCALON_CARAVAN_TITLES = "TheBlackCurtain|CursedLands|NeboTerrace|NorthKrytaProvince|ScoundrelsRise|GriffonsMouth|DeldrimorBowl|AnvilRock|IronHorseMine|TravelersVale|AscalonFoothills|DiessaLowlands|FlameTempleCorridor|DragonsGullet|TheBreach|OldAscalon|RegentValley|PockmarkFlats|EasternFrontier"

Global Const $GC_AS_MAGUUMA_CARAVAN_TITLES = "TheBlackCurtain|TalmarkWilderness|MajestysRest|SageLands|MamnoonLagoon|Silverwood|EttinsBack|ReedBog|TheFalls|DryTop|TangleRoot"

Global Const $GC_AS_PROPH_NORTHERN_SHIVERPEAKS = "AnvilRock|DeldrimorBowl|GriffonsMouth|IronHorseMine|TravelersVale"
Global Const $GC_AS_PROPH_KRYTA = "CursedLands|KessexPeak|MajestysRest|NeboTerrace|NorthKrytaProvince|ScoundrelsRise|StingrayStrand|TalmarkWilderness|TearsoftheFallen|TheBlackCurtain|TwinSerpentLakes|WatchtowerCoast"
Global Const $GC_AS_PROPH_CRYSTAL_DESERT = "DivinersAscent|ProphetsPath|SaltFlats|SkywardReach|TheAridSea|TheScar|VultureDrifts"
Global Const $GC_AS_PROPH_SOUTHERN_SHIVERPEAKS = "TalusChute|SnakeDance|DreadnoughtsDrift|LornarsPass|IceDome|FrozenForest|IceFloe|GrenthsFootprint|SpearheadPeak|MineralSprings|TascasDemise|WitmansFolly"
Global Const $GC_AS_PROPH_RING_OF_FIRE = "PerditionRock"

Global Const $GC_AS_FACTIONS_SHING_JEA = "HaijuLagoon|JayaBluffs|KinyaProvince|MinisterChosEstate|PanjiangPeninsula|SaoshangTrail|SunquaVale|ZenDaijun"
Global Const $GC_AS_FACTIONS_KAINENG = "BukdekByway|NahpuiQuarter|PongmeiValley|RaisuPalace|ShadowsPassage|ShenzunTunnels|SunjiangDistrict|TahnnakiTemple|WajjunBazaar|XaquangSkyway"
Global Const $GC_AS_FACTIONS_ECHOVALD = "Arborstone|DrazachThicket|Ferndale|MelandrusHope|MorostavTrail|MourningVeilFalls|TheEternalGrove"
Global Const $GC_AS_FACTIONS_JADE_SEA = "Archipelagos|BoreasSeabed|GyalaHatchery|MaishangHills|MountQinkai|RheasCrater|SilentSurf|UnwakingWaters"

Global Const $GC_AS_NF_ISTAN = "IssnurIsles|LahtendaBog|MehtaniKeys|PlainsofJarin|ZehlonReach"
Global Const $GC_AS_NF_KOURNA = "ArkjokWard|BahdokCaverns|BarbarousShore|DejarinEstate|JahaiBluffs|MargaCoast|SunwardMarches|TheFloodplainOfMahnkelon|TuraisProcession"
Global Const $GC_AS_NF_VABBI = "ForumHighlands|GardenOfSeborhin|HoldingsOfChokhin|ResplendentMakuun|TheHiddenCityOfAhdashim|TheMirrorOfLyss|VehjinMines|VehtendiValley|WildernessOfBahdza|YatendiCanyons"
Global Const $GC_AS_NF_DESOLATION = "JokosDomain|PoisonedOutcrops|TheAlkaliPan|TheRupturedHeart|TheShatteredRavines|TheSulfurousWastes"

Global Const $GC_AS_EOTN_FAR_SHIVERPEAKS = "BjoraMarches|DrakkarLake|JagaMoraine|NorrhartDomains|VarajarFells"
Global Const $GC_AS_EOTN_CHARR_HOMELANDS = "DaladaUplands|GrothmarWardowns|SacnothValley"
Global Const $GC_AS_EOTN_TARNISHED_COAST = "AlcaziaTangle|ArborBay|MagusStones|RivenEarth|SparkflySwamp|VerdantCascades"

Func MapCatalog_Init()
	_Vanquisher_InitAscalonCaravanPlan()
	_Vanquisher_InitMaguumaCaravanPlan()
	_Vanquisher_InitEOTNCaravanPlan()
	_Vanquisher_InitFactionsCaravanPlan()
	_Vanquisher_InitNightfallCaravanPlan()
	$g_i_MapTitleCount = 0

	MapCatalog_AddTitlesFromPipe($GC_AS_ASCALON_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_MAGUUMA_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_EOTN_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_FACTIONS_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_NIGHTFALL_CARAVAN_TITLES)
	MapCatalog_AddTitlesFromPipe($GC_AS_PROPH_NORTHERN_SHIVERPEAKS)
	MapCatalog_AddTitlesFromPipe($GC_AS_PROPH_KRYTA)
	MapCatalog_AddTitlesFromPipe($GC_AS_PROPH_CRYSTAL_DESERT)
	MapCatalog_AddTitlesFromPipe($GC_AS_PROPH_SOUTHERN_SHIVERPEAKS)
	MapCatalog_AddTitlesFromPipe($GC_AS_PROPH_RING_OF_FIRE)
	MapCatalog_AddTitlesFromPipe($GC_AS_FACTIONS_SHING_JEA)
	MapCatalog_AddTitlesFromPipe($GC_AS_FACTIONS_KAINENG)
	MapCatalog_AddTitlesFromPipe($GC_AS_FACTIONS_ECHOVALD)
	MapCatalog_AddTitlesFromPipe($GC_AS_FACTIONS_JADE_SEA)
	MapCatalog_AddTitlesFromPipe($GC_AS_NF_ISTAN)
	MapCatalog_AddTitlesFromPipe($GC_AS_NF_KOURNA)
	MapCatalog_AddTitlesFromPipe($GC_AS_NF_VABBI)
	MapCatalog_AddTitlesFromPipe($GC_AS_NF_DESOLATION)
	MapCatalog_AddTitlesFromPipe($GC_AS_EOTN_FAR_SHIVERPEAKS)
	MapCatalog_AddTitlesFromPipe($GC_AS_EOTN_CHARR_HOMELANDS)
	MapCatalog_AddTitlesFromPipe($GC_AS_EOTN_TARNISHED_COAST)
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

Func MapCatalog_FilterValidPipe($a_s_PipeList)
	Local $l_a_Parts = StringSplit($a_s_PipeList, "|")
	If Not IsArray($l_a_Parts) Or $l_a_Parts[0] < 1 Then Return ""
	Local $i, $l_s = ""
	For $i = 1 To $l_a_Parts[0]
		Local $l_s_Title = StringStripWS($l_a_Parts[$i], 3)
		If $l_s_Title = "" Then ContinueLoop
		If MapCatalog_GetMapID($l_s_Title) <= 0 Then ContinueLoop
		If $l_s <> "" Then $l_s &= "|"
		$l_s &= $l_s_Title
	Next
	Return $l_s
EndFunc

Func MapCatalog_GetComboString()
	Return "Current Map|(Sequence) Ascalon Caravan|(Sequence) Maguuma Caravan|" & _
		"Prophecies Kryta|Prophecies Northern Shiverpeaks|Prophecies Crystal Desert|" & _
		"Prophecies Southern Shiverpeaks|Prophecies Ring of Fire|" & _
		"Factions Shing Jea Island|Factions Kaineng City|Factions Echovald Forest|Factions The Jade Sea|" & _
		"Nightfall Istan|Nightfall Kourna|Nightfall Vabbi|Nightfall The Desolation|" & _
		"EOTN The Far Shiverpeaks|EOTN The Charr Homelands|EOTN The Tarnished Coast"
EndFunc

Func MapCatalog_GetLongestComboName()
	Local $l_s_Best = "Current Map"
	Local $l_a_Parts = StringSplit(MapCatalog_GetComboString(), "|")
	Local $i
	If IsArray($l_a_Parts) Then
		For $i = 1 To $l_a_Parts[0]
			If StringLen($l_a_Parts[$i]) > StringLen($l_s_Best) Then $l_s_Best = $l_a_Parts[$i]
		Next
	EndIf
	Return $l_s_Best
EndFunc

Func MapCatalog_GetLongestMapTitle()
	Local $l_s_Best = ""
	Local $i
	For $i = 0 To $g_i_MapTitleCount - 1
		If StringLen($g_as_MapTitles[$i]) > StringLen($l_s_Best) Then $l_s_Best = $g_as_MapTitles[$i]
	Next
	Return $l_s_Best
EndFunc

Func MapCatalog_LocationsPrefix($a_s_Title)
	Switch $a_s_Title
		Case "IceDome"
			Return "Icedome"
	EndSwitch
	Return $a_s_Title
EndFunc

Func MapCatalog_GetMapID($a_s_Title)
	If $a_s_Title = "" Then Return 0
	If MapCatalog_IsRegionSelection($a_s_Title) Then Return 0
	If MapCatalog_IsSequenceSelection($a_s_Title) Then Return 0
	If MapCatalog_IsCurrentMapSelection($a_s_Title) Then Return 0

	Local $l_s_Prefix = MapCatalog_LocationsPrefix($a_s_Title)
	Local $l_s_Name = $l_s_Prefix & "_Map"
	If IsDeclared($l_s_Name) <> 0 Then Return Number(Eval($l_s_Name))

	Local $l_i_Map = 0, $l_i_Out = 0, $l_i_Stage = -1
	If CaravanPlan_LookupTitle($a_s_Title, $l_i_Map, $l_i_Out, $l_i_Stage) Then Return $l_i_Map
	Return 0
EndFunc

Func MapCatalog_GetOutpostID($a_s_Title)
	If $a_s_Title = "" Then Return 0
	If MapCatalog_IsRegionSelection($a_s_Title) Then Return 0
	If MapCatalog_IsSequenceSelection($a_s_Title) Then Return 0
	If MapCatalog_IsCurrentMapSelection($a_s_Title) Then Return 0

	Local $l_s_Prefix = MapCatalog_LocationsPrefix($a_s_Title)
	Local $l_s_Name = $l_s_Prefix & "_Outpost"
	If IsDeclared($l_s_Name) <> 0 Then Return Number(Eval($l_s_Name))

	Local $l_i_Map = 0, $l_i_Out = 0, $l_i_Stage = -1
	If CaravanPlan_LookupTitle($a_s_Title, $l_i_Map, $l_i_Out, $l_i_Stage) Then Return $l_i_Out
	Return 0
EndFunc

Func MapCatalog_GetCaravanStage($a_s_Title)
	Local $l_i_Map = 0, $l_i_Out = 0, $l_i_Stage = -1
	If CaravanPlan_LookupTitle($a_s_Title, $l_i_Map, $l_i_Out, $l_i_Stage) Then Return $l_i_Stage
	Return -1
EndFunc

Func MapCatalog_GetSequenceKind($a_s_Selection)
	Switch $a_s_Selection
		Case "(Sequence) Maguuma Caravan"
			Return "Maguuma"
		Case "(Sequence) Ascalon Caravan"
			Return "Ascalon"
	EndSwitch
	Return ""
EndFunc

Func MapCatalog_GetRegionKey($a_s_Selection)
	Switch $a_s_Selection
		Case "Prophecies Kryta"
			Return "Proph_Kryta"
		Case "Prophecies Northern Shiverpeaks"
			Return "Proph_NorthernShiverpeaks"
		Case "Prophecies Crystal Desert"
			Return "Proph_CrystalDesert"
		Case "Prophecies Southern Shiverpeaks"
			Return "Proph_SouthernShiverpeaks"
		Case "Prophecies Ring of Fire"
			Return "Proph_RingOfFireIsland"
		Case "Factions Shing Jea Island"
			Return "Factions_ShingJeaIsland"
		Case "Factions Kaineng City"
			Return "Factions_KainengCity"
		Case "Factions Echovald Forest"
			Return "Factions_EchovaldForest"
		Case "Factions The Jade Sea"
			Return "Factions_TheJadeSea"
		Case "Nightfall Istan"
			Return "NF_Istan"
		Case "Nightfall Kourna"
			Return "NF_Kourna"
		Case "Nightfall Vabbi"
			Return "NF_Vabbi"
		Case "Nightfall The Desolation"
			Return "NF_TheDesolation"
		Case "EOTN The Far Shiverpeaks"
			Return "EOTN_FarShiverpeaks"
		Case "EOTN The Charr Homelands"
			Return "EOTN_CharrHomelands"
		Case "EOTN The Tarnished Coast"
			Return "EOTN_TarnishedCoast"
	EndSwitch
	Return ""
EndFunc

Func MapCatalog_GetRegionTitles($a_s_Selection)
	Switch $a_s_Selection
		Case "Prophecies Kryta"
			Return MapCatalog_FilterValidPipe($GC_AS_PROPH_KRYTA)
		Case "Prophecies Northern Shiverpeaks"
			Return MapCatalog_FilterValidPipe($GC_AS_PROPH_NORTHERN_SHIVERPEAKS)
		Case "Prophecies Crystal Desert"
			Return MapCatalog_FilterValidPipe($GC_AS_PROPH_CRYSTAL_DESERT)
		Case "Prophecies Southern Shiverpeaks"
			Return MapCatalog_FilterValidPipe($GC_AS_PROPH_SOUTHERN_SHIVERPEAKS)
		Case "Prophecies Ring of Fire"
			Return MapCatalog_FilterValidPipe($GC_AS_PROPH_RING_OF_FIRE)
		Case "Factions Shing Jea Island"
			Return MapCatalog_FilterValidPipe($GC_AS_FACTIONS_SHING_JEA)
		Case "Factions Kaineng City"
			Return MapCatalog_FilterValidPipe($GC_AS_FACTIONS_KAINENG)
		Case "Factions Echovald Forest"
			Return MapCatalog_FilterValidPipe($GC_AS_FACTIONS_ECHOVALD)
		Case "Factions The Jade Sea"
			Return MapCatalog_FilterValidPipe($GC_AS_FACTIONS_JADE_SEA)
		Case "Nightfall Istan"
			Return MapCatalog_FilterValidPipe($GC_AS_NF_ISTAN)
		Case "Nightfall Kourna"
			Return MapCatalog_FilterValidPipe($GC_AS_NF_KOURNA)
		Case "Nightfall Vabbi"
			Return MapCatalog_FilterValidPipe($GC_AS_NF_VABBI)
		Case "Nightfall The Desolation"
			Return MapCatalog_FilterValidPipe($GC_AS_NF_DESOLATION)
		Case "EOTN The Far Shiverpeaks"
			Return MapCatalog_FilterValidPipe($GC_AS_EOTN_FAR_SHIVERPEAKS)
		Case "EOTN The Charr Homelands"
			Return MapCatalog_FilterValidPipe($GC_AS_EOTN_CHARR_HOMELANDS)
		Case "EOTN The Tarnished Coast"
			Return MapCatalog_FilterValidPipe($GC_AS_EOTN_TARNISHED_COAST)
	EndSwitch
	Return ""
EndFunc

Func MapCatalog_IsSequenceSelection($a_s_Selection)
	Return MapCatalog_GetSequenceKind($a_s_Selection) <> ""
EndFunc

Func MapCatalog_IsRegionSelection($a_s_Selection)
	Return MapCatalog_GetRegionKey($a_s_Selection) <> ""
EndFunc

Func MapCatalog_IsMapListSelection($a_s_Selection)
	Return MapCatalog_IsSequenceSelection($a_s_Selection) Or MapCatalog_IsRegionSelection($a_s_Selection)
EndFunc

Func MapCatalog_IsCurrentMapSelection($a_s_Selection)
	Return $a_s_Selection = "" Or $a_s_Selection = "Current Map"
EndFunc
