#include-once
#include "..\VanquishCheck.au3"

; Nightfall vanquish spine (wiki progression order). Portal hops via Pathfinder.

Global Const $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT = 34

Global Const $GC_AS_NIGHTFALL_CARAVAN_TITLES = "PlainsofJarin|CliffsOfDohjok|ZehlonReach|FahranurTheFirstCity|LahtendaBog|IssnurIsles|MehtaniKeys|SunwardMarches|TuraisProcession|MargaCoast|ArkjokWard|GandaraTheMoonFortress|DejarinEstate|BarbarousShore|JahaiBluffs|TheFloodplainOfMahnkelon|BahdokCaverns|YatendiCanyons|VehtendiValley|ResplendentMakuun|ForumHighlands|VehjinMines|TheMirrorOfLyss|GardenOfSeborhin|WildernessOfBahdza|TheHiddenCityOfAhdashim|HoldingsOfChokhin|TheSulfurousWastes|JokosDomain|TheShatteredRavines|PoisonedOutcrops|TheRupturedHeart|TheAlkaliPan|CrystalOverlook"

; Columns: map id, outpost id, transit, transit2, transit3, GoOut func name, unused, unused, label
Global $g_a_NightfallCaravanPlan[$GC_I_NIGHTFALL_CARAVAN_MAP_COUNT][9]

Func _Vanquisher_InitNightfallCaravanPlan()
	If $g_a_NightfallCaravanPlan[0][0] <> 0 Then Return

	$g_a_NightfallCaravanPlan[0][0] = $PlainsofJarin_Map
	$g_a_NightfallCaravanPlan[0][1] = $PlainsofJarin_Outpost
	$g_a_NightfallCaravanPlan[0][2] = 0
	$g_a_NightfallCaravanPlan[0][3] = 0
	$g_a_NightfallCaravanPlan[0][4] = 0
	$g_a_NightfallCaravanPlan[0][5] = ""
	$g_a_NightfallCaravanPlan[0][8] = "PlainsofJarin"

	$g_a_NightfallCaravanPlan[1][0] = $CliffsOfDohjok_Map
	$g_a_NightfallCaravanPlan[1][1] = $CliffsOfDohjok_Outpost
	$g_a_NightfallCaravanPlan[1][2] = 0
	$g_a_NightfallCaravanPlan[1][3] = 0
	$g_a_NightfallCaravanPlan[1][4] = 0
	$g_a_NightfallCaravanPlan[1][5] = ""
	$g_a_NightfallCaravanPlan[1][8] = "CliffsOfDohjok"

	$g_a_NightfallCaravanPlan[2][0] = $ZehlonReach_Map
	$g_a_NightfallCaravanPlan[2][1] = $ZehlonReach_Outpost
	$g_a_NightfallCaravanPlan[2][2] = 0
	$g_a_NightfallCaravanPlan[2][3] = 0
	$g_a_NightfallCaravanPlan[2][4] = 0
	$g_a_NightfallCaravanPlan[2][5] = ""
	$g_a_NightfallCaravanPlan[2][8] = "ZehlonReach"

	$g_a_NightfallCaravanPlan[3][0] = $FahranurTheFirstCity_Map
	$g_a_NightfallCaravanPlan[3][1] = $FahranurTheFirstCity_Outpost
	$g_a_NightfallCaravanPlan[3][2] = 0
	$g_a_NightfallCaravanPlan[3][3] = 0
	$g_a_NightfallCaravanPlan[3][4] = 0
	$g_a_NightfallCaravanPlan[3][5] = ""
	$g_a_NightfallCaravanPlan[3][8] = "FahranurTheFirstCity"

	$g_a_NightfallCaravanPlan[4][0] = $LahtendaBog_Map
	$g_a_NightfallCaravanPlan[4][1] = $LahtendaBog_Outpost
	$g_a_NightfallCaravanPlan[4][2] = 0
	$g_a_NightfallCaravanPlan[4][3] = 0
	$g_a_NightfallCaravanPlan[4][4] = 0
	$g_a_NightfallCaravanPlan[4][5] = ""
	$g_a_NightfallCaravanPlan[4][8] = "LahtendaBog"

	$g_a_NightfallCaravanPlan[5][0] = $IssnurIsles_Map
	$g_a_NightfallCaravanPlan[5][1] = $IssnurIsles_Outpost
	$g_a_NightfallCaravanPlan[5][2] = 0
	$g_a_NightfallCaravanPlan[5][3] = 0
	$g_a_NightfallCaravanPlan[5][4] = 0
	$g_a_NightfallCaravanPlan[5][5] = ""
	$g_a_NightfallCaravanPlan[5][8] = "IssnurIsles"

	$g_a_NightfallCaravanPlan[6][0] = $MehtaniKeys_Map
	$g_a_NightfallCaravanPlan[6][1] = $MehtaniKeys_Outpost
	$g_a_NightfallCaravanPlan[6][2] = 0
	$g_a_NightfallCaravanPlan[6][3] = 0
	$g_a_NightfallCaravanPlan[6][4] = 0
	$g_a_NightfallCaravanPlan[6][5] = ""
	$g_a_NightfallCaravanPlan[6][8] = "MehtaniKeys"

	$g_a_NightfallCaravanPlan[7][0] = $SunwardMarches_Map
	$g_a_NightfallCaravanPlan[7][1] = $SunwardMarches_Outpost
	$g_a_NightfallCaravanPlan[7][2] = 0
	$g_a_NightfallCaravanPlan[7][3] = 0
	$g_a_NightfallCaravanPlan[7][4] = 0
	$g_a_NightfallCaravanPlan[7][5] = ""
	$g_a_NightfallCaravanPlan[7][8] = "SunwardMarches"

	$g_a_NightfallCaravanPlan[8][0] = $TuraisProcession_Map
	$g_a_NightfallCaravanPlan[8][1] = $TuraisProcession_Outpost
	$g_a_NightfallCaravanPlan[8][2] = 0
	$g_a_NightfallCaravanPlan[8][3] = 0
	$g_a_NightfallCaravanPlan[8][4] = 0
	$g_a_NightfallCaravanPlan[8][5] = ""
	$g_a_NightfallCaravanPlan[8][8] = "TuraisProcession"

	$g_a_NightfallCaravanPlan[9][0] = $MargaCoast_Map
	$g_a_NightfallCaravanPlan[9][1] = $MargaCoast_Outpost
	$g_a_NightfallCaravanPlan[9][2] = 0
	$g_a_NightfallCaravanPlan[9][3] = 0
	$g_a_NightfallCaravanPlan[9][4] = 0
	$g_a_NightfallCaravanPlan[9][5] = ""
	$g_a_NightfallCaravanPlan[9][8] = "MargaCoast"

	$g_a_NightfallCaravanPlan[10][0] = $ArkjokWard_Map
	$g_a_NightfallCaravanPlan[10][1] = $ArkjokWard_Outpost
	$g_a_NightfallCaravanPlan[10][2] = 0
	$g_a_NightfallCaravanPlan[10][3] = 0
	$g_a_NightfallCaravanPlan[10][4] = 0
	$g_a_NightfallCaravanPlan[10][5] = ""
	$g_a_NightfallCaravanPlan[10][8] = "ArkjokWard"

	$g_a_NightfallCaravanPlan[11][0] = $GandaraTheMoonFortress_Map
	$g_a_NightfallCaravanPlan[11][1] = $GandaraTheMoonFortress_Outpost
	$g_a_NightfallCaravanPlan[11][2] = 0
	$g_a_NightfallCaravanPlan[11][3] = 0
	$g_a_NightfallCaravanPlan[11][4] = 0
	$g_a_NightfallCaravanPlan[11][5] = ""
	$g_a_NightfallCaravanPlan[11][8] = "GandaraTheMoonFortress"

	$g_a_NightfallCaravanPlan[12][0] = $DejarinEstate_Map
	$g_a_NightfallCaravanPlan[12][1] = $DejarinEstate_Outpost
	$g_a_NightfallCaravanPlan[12][2] = 0
	$g_a_NightfallCaravanPlan[12][3] = 0
	$g_a_NightfallCaravanPlan[12][4] = 0
	$g_a_NightfallCaravanPlan[12][5] = ""
	$g_a_NightfallCaravanPlan[12][8] = "DejarinEstate"

	$g_a_NightfallCaravanPlan[13][0] = $BarbarousShore_Map
	$g_a_NightfallCaravanPlan[13][1] = $BarbarousShore_Outpost
	$g_a_NightfallCaravanPlan[13][2] = 0
	$g_a_NightfallCaravanPlan[13][3] = 0
	$g_a_NightfallCaravanPlan[13][4] = 0
	$g_a_NightfallCaravanPlan[13][5] = ""
	$g_a_NightfallCaravanPlan[13][8] = "BarbarousShore"

	$g_a_NightfallCaravanPlan[14][0] = $JahaiBluffs_Map
	$g_a_NightfallCaravanPlan[14][1] = $JahaiBluffs_Outpost
	$g_a_NightfallCaravanPlan[14][2] = 0
	$g_a_NightfallCaravanPlan[14][3] = 0
	$g_a_NightfallCaravanPlan[14][4] = 0
	$g_a_NightfallCaravanPlan[14][5] = ""
	$g_a_NightfallCaravanPlan[14][8] = "JahaiBluffs"

	$g_a_NightfallCaravanPlan[15][0] = $TheFloodplainOfMahnkelon_Map
	$g_a_NightfallCaravanPlan[15][1] = $TheFloodplainOfMahnkelon_Outpost
	$g_a_NightfallCaravanPlan[15][2] = 0
	$g_a_NightfallCaravanPlan[15][3] = 0
	$g_a_NightfallCaravanPlan[15][4] = 0
	$g_a_NightfallCaravanPlan[15][5] = ""
	$g_a_NightfallCaravanPlan[15][8] = "TheFloodplainOfMahnkelon"

	$g_a_NightfallCaravanPlan[16][0] = $BahdokCaverns_Map
	$g_a_NightfallCaravanPlan[16][1] = $BahdokCaverns_Outpost
	$g_a_NightfallCaravanPlan[16][2] = 0
	$g_a_NightfallCaravanPlan[16][3] = 0
	$g_a_NightfallCaravanPlan[16][4] = 0
	$g_a_NightfallCaravanPlan[16][5] = ""
	$g_a_NightfallCaravanPlan[16][8] = "BahdokCaverns"

	$g_a_NightfallCaravanPlan[17][0] = $YatendiCanyons_Map
	$g_a_NightfallCaravanPlan[17][1] = $YatendiCanyons_Outpost
	$g_a_NightfallCaravanPlan[17][2] = 0
	$g_a_NightfallCaravanPlan[17][3] = 0
	$g_a_NightfallCaravanPlan[17][4] = 0
	$g_a_NightfallCaravanPlan[17][5] = ""
	$g_a_NightfallCaravanPlan[17][8] = "YatendiCanyons"

	$g_a_NightfallCaravanPlan[18][0] = $VehtendiValley_Map
	$g_a_NightfallCaravanPlan[18][1] = $VehtendiValley_Outpost
	$g_a_NightfallCaravanPlan[18][2] = 0
	$g_a_NightfallCaravanPlan[18][3] = 0
	$g_a_NightfallCaravanPlan[18][4] = 0
	$g_a_NightfallCaravanPlan[18][5] = ""
	$g_a_NightfallCaravanPlan[18][8] = "VehtendiValley"

	$g_a_NightfallCaravanPlan[19][0] = $ResplendentMakuun_Map
	$g_a_NightfallCaravanPlan[19][1] = $ResplendentMakuun_Outpost
	$g_a_NightfallCaravanPlan[19][2] = 0
	$g_a_NightfallCaravanPlan[19][3] = 0
	$g_a_NightfallCaravanPlan[19][4] = 0
	$g_a_NightfallCaravanPlan[19][5] = ""
	$g_a_NightfallCaravanPlan[19][8] = "ResplendentMakuun"

	$g_a_NightfallCaravanPlan[20][0] = $ForumHighlands_Map
	$g_a_NightfallCaravanPlan[20][1] = $ForumHighlands_Outpost
	$g_a_NightfallCaravanPlan[20][2] = 0
	$g_a_NightfallCaravanPlan[20][3] = 0
	$g_a_NightfallCaravanPlan[20][4] = 0
	$g_a_NightfallCaravanPlan[20][5] = ""
	$g_a_NightfallCaravanPlan[20][8] = "ForumHighlands"

	$g_a_NightfallCaravanPlan[21][0] = $VehjinMines_Map
	$g_a_NightfallCaravanPlan[21][1] = $VehjinMines_Outpost
	$g_a_NightfallCaravanPlan[21][2] = 0
	$g_a_NightfallCaravanPlan[21][3] = 0
	$g_a_NightfallCaravanPlan[21][4] = 0
	$g_a_NightfallCaravanPlan[21][5] = ""
	$g_a_NightfallCaravanPlan[21][8] = "VehjinMines"

	$g_a_NightfallCaravanPlan[22][0] = $TheMirrorOfLyss_Map
	$g_a_NightfallCaravanPlan[22][1] = $TheMirrorOfLyss_Outpost
	$g_a_NightfallCaravanPlan[22][2] = 0
	$g_a_NightfallCaravanPlan[22][3] = 0
	$g_a_NightfallCaravanPlan[22][4] = 0
	$g_a_NightfallCaravanPlan[22][5] = ""
	$g_a_NightfallCaravanPlan[22][8] = "TheMirrorOfLyss"

	$g_a_NightfallCaravanPlan[23][0] = $GardenOfSeborhin_Map
	$g_a_NightfallCaravanPlan[23][1] = $GardenOfSeborhin_Outpost
	$g_a_NightfallCaravanPlan[23][2] = 0
	$g_a_NightfallCaravanPlan[23][3] = 0
	$g_a_NightfallCaravanPlan[23][4] = 0
	$g_a_NightfallCaravanPlan[23][5] = ""
	$g_a_NightfallCaravanPlan[23][8] = "GardenOfSeborhin"

	$g_a_NightfallCaravanPlan[24][0] = $WildernessOfBahdza_Map
	$g_a_NightfallCaravanPlan[24][1] = $WildernessOfBahdza_Outpost
	$g_a_NightfallCaravanPlan[24][2] = 0
	$g_a_NightfallCaravanPlan[24][3] = 0
	$g_a_NightfallCaravanPlan[24][4] = 0
	$g_a_NightfallCaravanPlan[24][5] = ""
	$g_a_NightfallCaravanPlan[24][8] = "WildernessOfBahdza"

	$g_a_NightfallCaravanPlan[25][0] = $TheHiddenCityOfAhdashim_Map
	$g_a_NightfallCaravanPlan[25][1] = $TheHiddenCityOfAhdashim_Outpost
	$g_a_NightfallCaravanPlan[25][2] = 0
	$g_a_NightfallCaravanPlan[25][3] = 0
	$g_a_NightfallCaravanPlan[25][4] = 0
	$g_a_NightfallCaravanPlan[25][5] = ""
	$g_a_NightfallCaravanPlan[25][8] = "TheHiddenCityOfAhdashim"

	$g_a_NightfallCaravanPlan[26][0] = $HoldingsOfChokhin_Map
	$g_a_NightfallCaravanPlan[26][1] = $HoldingsOfChokhin_Outpost
	$g_a_NightfallCaravanPlan[26][2] = 0
	$g_a_NightfallCaravanPlan[26][3] = 0
	$g_a_NightfallCaravanPlan[26][4] = 0
	$g_a_NightfallCaravanPlan[26][5] = ""
	$g_a_NightfallCaravanPlan[26][8] = "HoldingsOfChokhin"

	$g_a_NightfallCaravanPlan[27][0] = $TheSulfurousWastes_Map
	$g_a_NightfallCaravanPlan[27][1] = $TheSulfurousWastes_Outpost
	$g_a_NightfallCaravanPlan[27][2] = 0
	$g_a_NightfallCaravanPlan[27][3] = 0
	$g_a_NightfallCaravanPlan[27][4] = 0
	$g_a_NightfallCaravanPlan[27][5] = ""
	$g_a_NightfallCaravanPlan[27][8] = "TheSulfurousWastes"

	$g_a_NightfallCaravanPlan[28][0] = $JokosDomain_Map
	$g_a_NightfallCaravanPlan[28][1] = $JokosDomain_Outpost
	$g_a_NightfallCaravanPlan[28][2] = 0
	$g_a_NightfallCaravanPlan[28][3] = 0
	$g_a_NightfallCaravanPlan[28][4] = 0
	$g_a_NightfallCaravanPlan[28][5] = ""
	$g_a_NightfallCaravanPlan[28][8] = "JokosDomain"

	$g_a_NightfallCaravanPlan[29][0] = $TheShatteredRavines_Map
	$g_a_NightfallCaravanPlan[29][1] = $TheShatteredRavines_Outpost
	$g_a_NightfallCaravanPlan[29][2] = 0
	$g_a_NightfallCaravanPlan[29][3] = 0
	$g_a_NightfallCaravanPlan[29][4] = 0
	$g_a_NightfallCaravanPlan[29][5] = ""
	$g_a_NightfallCaravanPlan[29][8] = "TheShatteredRavines"

	$g_a_NightfallCaravanPlan[30][0] = $PoisonedOutcrops_Map
	$g_a_NightfallCaravanPlan[30][1] = $PoisonedOutcrops_Outpost
	$g_a_NightfallCaravanPlan[30][2] = 0
	$g_a_NightfallCaravanPlan[30][3] = 0
	$g_a_NightfallCaravanPlan[30][4] = 0
	$g_a_NightfallCaravanPlan[30][5] = ""
	$g_a_NightfallCaravanPlan[30][8] = "PoisonedOutcrops"

	$g_a_NightfallCaravanPlan[31][0] = $TheRupturedHeart_Map
	$g_a_NightfallCaravanPlan[31][1] = $TheRupturedHeart_Outpost
	$g_a_NightfallCaravanPlan[31][2] = 0
	$g_a_NightfallCaravanPlan[31][3] = 0
	$g_a_NightfallCaravanPlan[31][4] = 0
	$g_a_NightfallCaravanPlan[31][5] = ""
	$g_a_NightfallCaravanPlan[31][8] = "TheRupturedHeart"

	$g_a_NightfallCaravanPlan[32][0] = $TheAlkaliPan_Map
	$g_a_NightfallCaravanPlan[32][1] = $TheAlkaliPan_Outpost
	$g_a_NightfallCaravanPlan[32][2] = 0
	$g_a_NightfallCaravanPlan[32][3] = 0
	$g_a_NightfallCaravanPlan[32][4] = 0
	$g_a_NightfallCaravanPlan[32][5] = ""
	$g_a_NightfallCaravanPlan[32][8] = "TheAlkaliPan"

	$g_a_NightfallCaravanPlan[33][0] = $CrystalOverlook_Map
	$g_a_NightfallCaravanPlan[33][1] = $CrystalOverlook_Outpost
	$g_a_NightfallCaravanPlan[33][2] = 0
	$g_a_NightfallCaravanPlan[33][3] = 0
	$g_a_NightfallCaravanPlan[33][4] = 0
	$g_a_NightfallCaravanPlan[33][5] = ""
	$g_a_NightfallCaravanPlan[33][8] = "CrystalOverlook"

EndFunc

Func _Vanquisher_IsNightfallCaravanEntryMap($iMapID, $iStage)
	Return _CaravanPlan_IsEntryMap($g_a_NightfallCaravanPlan, $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT, $iMapID, $iStage)
EndFunc

Func _Vanquisher_IsOnNightfallCaravanSpine($iMapID = -1)
	_Vanquisher_InitNightfallCaravanPlan()
	If $iMapID < 0 Then $iMapID = Map_GetMapID()
	Local $i
	For $i = 0 To $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT - 1
		If _Vanquisher_IsNightfallCaravanEntryMap($iMapID, $i) Then Return True
	Next
	Return False
EndFunc

Func _Vanquisher_NightfallCaravanStageForCurrentMap()
	_Vanquisher_InitNightfallCaravanPlan()
	Return _CaravanPlan_StageForCurrentMap($g_a_NightfallCaravanPlan, $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT)
EndFunc

Func _Vanquisher_NightfallCaravanIsStageHistoricallyVanquished($iStage)
	_Vanquisher_InitNightfallCaravanPlan()
	If $iStage < 0 Or $iStage >= $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT Then Return False
	Return VanquishCheck_IsMapHistoricallyVanquished(Number($g_a_NightfallCaravanPlan[$iStage][0]))
EndFunc
