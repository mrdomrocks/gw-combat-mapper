#include-once
#include "..\VanquishCheck.au3"

; Eye of the North vanquish spine (wiki progression order). Portal hops via Pathfinder; GoOut routes optional.

Global Const $GC_I_EOTN_CARAVAN_MAP_COUNT = 15

Global Const $GC_AS_EOTN_CARAVAN_TITLES = "BjoraMarches|DrakkarLake|IceCliffChasms|JagaMoraine|NorrhartDomains|VarajarFells|DaladaUplands|GrothmarWardowns|SacnothValley|ArborBay|AlcaziaTangle|MagusStones|RivenEarth|SparkflySwamp|VerdantCascades"

; Columns: map id, outpost id, transit, transit2, transit3, GoOut func name, unused, unused, label
Global $g_a_EOTNCaravanPlan[$GC_I_EOTN_CARAVAN_MAP_COUNT][9]

Func _Vanquisher_InitEOTNCaravanPlan()
	If $g_a_EOTNCaravanPlan[0][0] <> 0 Then Return

	$g_a_EOTNCaravanPlan[0][0] = $BjoraMarches_Map
	$g_a_EOTNCaravanPlan[0][1] = $BjoraMarches_Outpost
	$g_a_EOTNCaravanPlan[0][2] = 0
	$g_a_EOTNCaravanPlan[0][3] = 0
	$g_a_EOTNCaravanPlan[0][4] = 0
	$g_a_EOTNCaravanPlan[0][5] = ""
	$g_a_EOTNCaravanPlan[0][8] = "BjoraMarches"

	$g_a_EOTNCaravanPlan[1][0] = $DrakkarLake_Map
	$g_a_EOTNCaravanPlan[1][1] = $DrakkarLake_Outpost
	$g_a_EOTNCaravanPlan[1][2] = 0
	$g_a_EOTNCaravanPlan[1][3] = 0
	$g_a_EOTNCaravanPlan[1][4] = 0
	$g_a_EOTNCaravanPlan[1][5] = ""
	$g_a_EOTNCaravanPlan[1][8] = "DrakkarLake"

	$g_a_EOTNCaravanPlan[2][0] = $IceCliffChasms_Map
	$g_a_EOTNCaravanPlan[2][1] = $IceCliffChasms_Outpost
	$g_a_EOTNCaravanPlan[2][2] = 0
	$g_a_EOTNCaravanPlan[2][3] = 0
	$g_a_EOTNCaravanPlan[2][4] = 0
	$g_a_EOTNCaravanPlan[2][5] = ""
	$g_a_EOTNCaravanPlan[2][8] = "IceCliffChasms"

	$g_a_EOTNCaravanPlan[3][0] = $JagaMoraine_Map
	$g_a_EOTNCaravanPlan[3][1] = $JagaMoraine_Outpost
	$g_a_EOTNCaravanPlan[3][2] = 0
	$g_a_EOTNCaravanPlan[3][3] = 0
	$g_a_EOTNCaravanPlan[3][4] = 0
	$g_a_EOTNCaravanPlan[3][5] = ""
	$g_a_EOTNCaravanPlan[3][8] = "JagaMoraine"

	$g_a_EOTNCaravanPlan[4][0] = $NorrhartDomains_Map
	$g_a_EOTNCaravanPlan[4][1] = $NorrhartDomains_Outpost
	$g_a_EOTNCaravanPlan[4][2] = 0
	$g_a_EOTNCaravanPlan[4][3] = 0
	$g_a_EOTNCaravanPlan[4][4] = 0
	$g_a_EOTNCaravanPlan[4][5] = ""
	$g_a_EOTNCaravanPlan[4][8] = "NorrhartDomains"

	$g_a_EOTNCaravanPlan[5][0] = $VarajarFells_Map
	$g_a_EOTNCaravanPlan[5][1] = $VarajarFells_Outpost
	$g_a_EOTNCaravanPlan[5][2] = 0
	$g_a_EOTNCaravanPlan[5][3] = 0
	$g_a_EOTNCaravanPlan[5][4] = 0
	$g_a_EOTNCaravanPlan[5][5] = ""
	$g_a_EOTNCaravanPlan[5][8] = "VarajarFells"

	$g_a_EOTNCaravanPlan[6][0] = $DaladaUplands_Map
	$g_a_EOTNCaravanPlan[6][1] = $DaladaUplands_Outpost
	$g_a_EOTNCaravanPlan[6][2] = 0
	$g_a_EOTNCaravanPlan[6][3] = 0
	$g_a_EOTNCaravanPlan[6][4] = 0
	$g_a_EOTNCaravanPlan[6][5] = ""
	$g_a_EOTNCaravanPlan[6][8] = "DaladaUplands"

	$g_a_EOTNCaravanPlan[7][0] = $GrothmarWardowns_Map
	$g_a_EOTNCaravanPlan[7][1] = $GrothmarWardowns_Outpost
	$g_a_EOTNCaravanPlan[7][2] = 0
	$g_a_EOTNCaravanPlan[7][3] = 0
	$g_a_EOTNCaravanPlan[7][4] = 0
	$g_a_EOTNCaravanPlan[7][5] = ""
	$g_a_EOTNCaravanPlan[7][8] = "GrothmarWardowns"

	$g_a_EOTNCaravanPlan[8][0] = $SacnothValley_Map
	$g_a_EOTNCaravanPlan[8][1] = $SacnothValley_Outpost
	$g_a_EOTNCaravanPlan[8][2] = 0
	$g_a_EOTNCaravanPlan[8][3] = 0
	$g_a_EOTNCaravanPlan[8][4] = 0
	$g_a_EOTNCaravanPlan[8][5] = ""
	$g_a_EOTNCaravanPlan[8][8] = "SacnothValley"

	$g_a_EOTNCaravanPlan[9][0] = $ArborBay_Map
	$g_a_EOTNCaravanPlan[9][1] = $ArborBay_Outpost
	$g_a_EOTNCaravanPlan[9][2] = 0
	$g_a_EOTNCaravanPlan[9][3] = 0
	$g_a_EOTNCaravanPlan[9][4] = 0
	$g_a_EOTNCaravanPlan[9][5] = ""
	$g_a_EOTNCaravanPlan[9][8] = "ArborBay"

	$g_a_EOTNCaravanPlan[10][0] = $AlcaziaTangle_Map
	$g_a_EOTNCaravanPlan[10][1] = $AlcaziaTangle_Outpost
	$g_a_EOTNCaravanPlan[10][2] = 0
	$g_a_EOTNCaravanPlan[10][3] = 0
	$g_a_EOTNCaravanPlan[10][4] = 0
	$g_a_EOTNCaravanPlan[10][5] = ""
	$g_a_EOTNCaravanPlan[10][8] = "AlcaziaTangle"

	$g_a_EOTNCaravanPlan[11][0] = $MagusStones_Map
	$g_a_EOTNCaravanPlan[11][1] = $MagusStones_Outpost
	$g_a_EOTNCaravanPlan[11][2] = 0
	$g_a_EOTNCaravanPlan[11][3] = 0
	$g_a_EOTNCaravanPlan[11][4] = 0
	$g_a_EOTNCaravanPlan[11][5] = ""
	$g_a_EOTNCaravanPlan[11][8] = "MagusStones"

	$g_a_EOTNCaravanPlan[12][0] = $RivenEarth_Map
	$g_a_EOTNCaravanPlan[12][1] = $RivenEarth_Outpost
	$g_a_EOTNCaravanPlan[12][2] = 0
	$g_a_EOTNCaravanPlan[12][3] = 0
	$g_a_EOTNCaravanPlan[12][4] = 0
	$g_a_EOTNCaravanPlan[12][5] = ""
	$g_a_EOTNCaravanPlan[12][8] = "RivenEarth"

	$g_a_EOTNCaravanPlan[13][0] = $SparkflySwamp_Map
	$g_a_EOTNCaravanPlan[13][1] = $SparkflySwamp_Outpost
	$g_a_EOTNCaravanPlan[13][2] = 0
	$g_a_EOTNCaravanPlan[13][3] = 0
	$g_a_EOTNCaravanPlan[13][4] = 0
	$g_a_EOTNCaravanPlan[13][5] = ""
	$g_a_EOTNCaravanPlan[13][8] = "SparkflySwamp"

	$g_a_EOTNCaravanPlan[14][0] = $VerdantCascades_Map
	$g_a_EOTNCaravanPlan[14][1] = $VerdantCascades_Outpost
	$g_a_EOTNCaravanPlan[14][2] = 0
	$g_a_EOTNCaravanPlan[14][3] = 0
	$g_a_EOTNCaravanPlan[14][4] = 0
	$g_a_EOTNCaravanPlan[14][5] = ""
	$g_a_EOTNCaravanPlan[14][8] = "VerdantCascades"

EndFunc

Func _Vanquisher_IsEOTNCaravanEntryMap($iMapID, $iStage)
	Return _CaravanPlan_IsEntryMap($g_a_EOTNCaravanPlan, $GC_I_EOTN_CARAVAN_MAP_COUNT, $iMapID, $iStage)
EndFunc

Func _Vanquisher_IsOnEOTNCaravanSpine($iMapID = -1)
	_Vanquisher_InitEOTNCaravanPlan()
	If $iMapID < 0 Then $iMapID = Map_GetMapID()
	Local $i
	For $i = 0 To $GC_I_EOTN_CARAVAN_MAP_COUNT - 1
		If _Vanquisher_IsEOTNCaravanEntryMap($iMapID, $i) Then Return True
	Next
	Return False
EndFunc

Func _Vanquisher_EOTNCaravanStageForCurrentMap()
	_Vanquisher_InitEOTNCaravanPlan()
	Return _CaravanPlan_StageForCurrentMap($g_a_EOTNCaravanPlan, $GC_I_EOTN_CARAVAN_MAP_COUNT)
EndFunc

Func _Vanquisher_EOTNCaravanIsStageHistoricallyVanquished($iStage)
	_Vanquisher_InitEOTNCaravanPlan()
	If $iStage < 0 Or $iStage >= $GC_I_EOTN_CARAVAN_MAP_COUNT Then Return False
	Return VanquishCheck_IsMapHistoricallyVanquished(Number($g_a_EOTNCaravanPlan[$iStage][0]))
EndFunc
