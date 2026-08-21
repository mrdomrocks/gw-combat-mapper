#include-once
#include "..\VanquishCheck.au3"

; Factions vanquish spine (wiki progression order). Portal hops via Pathfinder.

Global Const $GC_I_FACTIONS_CARAVAN_MAP_COUNT = 33

Global Const $GC_AS_FACTIONS_CARAVAN_TITLES = "SunquaVale|MinisterChosEstate|KinyaProvince|PanjiangPeninsula|SaoshangTrail|JayaBluffs|HaijuLagoon|ZenDaijun|BukdekByway|WajjunBazaar|XaquangSkyway|ShadowsPassage|NahpuiQuarter|ShenzunTunnels|TahnnakiTemple|SunjiangDistrict|PongmeiValley|Arborstone|Ferndale|MelandrusHope|DrazachThicket|MorostavTrail|TheEternalGrove|MourningVeilFalls|BoreasSeabed|MountQinkai|Archipelagos|MaishangHills|GyalaHatchery|RheasCrater|SilentSurf|UnwakingWaters|RaisuPalace"

; Columns: map id, outpost id, transit, transit2, transit3, GoOut func name, unused, unused, label
Global $g_a_FactionsCaravanPlan[$GC_I_FACTIONS_CARAVAN_MAP_COUNT][9]

Func _Vanquisher_InitFactionsCaravanPlan()
	If $g_a_FactionsCaravanPlan[0][0] <> 0 Then Return

	$g_a_FactionsCaravanPlan[0][0] = $SunquaVale_Map
	$g_a_FactionsCaravanPlan[0][1] = $SunquaVale_Outpost
	$g_a_FactionsCaravanPlan[0][2] = 0
	$g_a_FactionsCaravanPlan[0][3] = 0
	$g_a_FactionsCaravanPlan[0][4] = 0
	$g_a_FactionsCaravanPlan[0][5] = ""
	$g_a_FactionsCaravanPlan[0][8] = "SunquaVale"

	$g_a_FactionsCaravanPlan[1][0] = $MinisterChosEstate_Map
	$g_a_FactionsCaravanPlan[1][1] = $MinisterChosEstate_Outpost
	$g_a_FactionsCaravanPlan[1][2] = 0
	$g_a_FactionsCaravanPlan[1][3] = 0
	$g_a_FactionsCaravanPlan[1][4] = 0
	$g_a_FactionsCaravanPlan[1][5] = ""
	$g_a_FactionsCaravanPlan[1][8] = "MinisterChosEstate"

	$g_a_FactionsCaravanPlan[2][0] = $KinyaProvince_Map
	$g_a_FactionsCaravanPlan[2][1] = $KinyaProvince_Outpost
	$g_a_FactionsCaravanPlan[2][2] = 0
	$g_a_FactionsCaravanPlan[2][3] = 0
	$g_a_FactionsCaravanPlan[2][4] = 0
	$g_a_FactionsCaravanPlan[2][5] = ""
	$g_a_FactionsCaravanPlan[2][8] = "KinyaProvince"

	$g_a_FactionsCaravanPlan[3][0] = $PanjiangPeninsula_Map
	$g_a_FactionsCaravanPlan[3][1] = $PanjiangPeninsula_Outpost
	$g_a_FactionsCaravanPlan[3][2] = 0
	$g_a_FactionsCaravanPlan[3][3] = 0
	$g_a_FactionsCaravanPlan[3][4] = 0
	$g_a_FactionsCaravanPlan[3][5] = ""
	$g_a_FactionsCaravanPlan[3][8] = "PanjiangPeninsula"

	$g_a_FactionsCaravanPlan[4][0] = $SaoshangTrail_Map
	$g_a_FactionsCaravanPlan[4][1] = $SaoshangTrail_Outpost
	$g_a_FactionsCaravanPlan[4][2] = 0
	$g_a_FactionsCaravanPlan[4][3] = 0
	$g_a_FactionsCaravanPlan[4][4] = 0
	$g_a_FactionsCaravanPlan[4][5] = ""
	$g_a_FactionsCaravanPlan[4][8] = "SaoshangTrail"

	$g_a_FactionsCaravanPlan[5][0] = $JayaBluffs_Map
	$g_a_FactionsCaravanPlan[5][1] = $JayaBluffs_Outpost
	$g_a_FactionsCaravanPlan[5][2] = 0
	$g_a_FactionsCaravanPlan[5][3] = 0
	$g_a_FactionsCaravanPlan[5][4] = 0
	$g_a_FactionsCaravanPlan[5][5] = ""
	$g_a_FactionsCaravanPlan[5][8] = "JayaBluffs"

	$g_a_FactionsCaravanPlan[6][0] = $HaijuLagoon_Map
	$g_a_FactionsCaravanPlan[6][1] = $HaijuLagoon_Outpost
	$g_a_FactionsCaravanPlan[6][2] = 0
	$g_a_FactionsCaravanPlan[6][3] = 0
	$g_a_FactionsCaravanPlan[6][4] = 0
	$g_a_FactionsCaravanPlan[6][5] = ""
	$g_a_FactionsCaravanPlan[6][8] = "HaijuLagoon"

	$g_a_FactionsCaravanPlan[7][0] = $ZenDaijun_Map
	$g_a_FactionsCaravanPlan[7][1] = $ZenDaijun_Outpost
	$g_a_FactionsCaravanPlan[7][2] = 0
	$g_a_FactionsCaravanPlan[7][3] = 0
	$g_a_FactionsCaravanPlan[7][4] = 0
	$g_a_FactionsCaravanPlan[7][5] = ""
	$g_a_FactionsCaravanPlan[7][8] = "ZenDaijun"

	$g_a_FactionsCaravanPlan[8][0] = $BukdekByway_Map
	$g_a_FactionsCaravanPlan[8][1] = $BukdekByway_Outpost
	$g_a_FactionsCaravanPlan[8][2] = 0
	$g_a_FactionsCaravanPlan[8][3] = 0
	$g_a_FactionsCaravanPlan[8][4] = 0
	$g_a_FactionsCaravanPlan[8][5] = ""
	$g_a_FactionsCaravanPlan[8][8] = "BukdekByway"

	$g_a_FactionsCaravanPlan[9][0] = $WajjunBazaar_Map
	$g_a_FactionsCaravanPlan[9][1] = $WajjunBazaar_Outpost
	$g_a_FactionsCaravanPlan[9][2] = 0
	$g_a_FactionsCaravanPlan[9][3] = 0
	$g_a_FactionsCaravanPlan[9][4] = 0
	$g_a_FactionsCaravanPlan[9][5] = ""
	$g_a_FactionsCaravanPlan[9][8] = "WajjunBazaar"

	$g_a_FactionsCaravanPlan[10][0] = $XaquangSkyway_Map
	$g_a_FactionsCaravanPlan[10][1] = $XaquangSkyway_Outpost
	$g_a_FactionsCaravanPlan[10][2] = 0
	$g_a_FactionsCaravanPlan[10][3] = 0
	$g_a_FactionsCaravanPlan[10][4] = 0
	$g_a_FactionsCaravanPlan[10][5] = ""
	$g_a_FactionsCaravanPlan[10][8] = "XaquangSkyway"

	$g_a_FactionsCaravanPlan[11][0] = $ShadowsPassage_Map
	$g_a_FactionsCaravanPlan[11][1] = $ShadowsPassage_Outpost
	$g_a_FactionsCaravanPlan[11][2] = 0
	$g_a_FactionsCaravanPlan[11][3] = 0
	$g_a_FactionsCaravanPlan[11][4] = 0
	$g_a_FactionsCaravanPlan[11][5] = ""
	$g_a_FactionsCaravanPlan[11][8] = "ShadowsPassage"

	$g_a_FactionsCaravanPlan[12][0] = $NahpuiQuarter_Map
	$g_a_FactionsCaravanPlan[12][1] = $NahpuiQuarter_Outpost
	$g_a_FactionsCaravanPlan[12][2] = 0
	$g_a_FactionsCaravanPlan[12][3] = 0
	$g_a_FactionsCaravanPlan[12][4] = 0
	$g_a_FactionsCaravanPlan[12][5] = ""
	$g_a_FactionsCaravanPlan[12][8] = "NahpuiQuarter"

	$g_a_FactionsCaravanPlan[13][0] = $ShenzunTunnels_Map
	$g_a_FactionsCaravanPlan[13][1] = $ShenzunTunnels_Outpost
	$g_a_FactionsCaravanPlan[13][2] = 0
	$g_a_FactionsCaravanPlan[13][3] = 0
	$g_a_FactionsCaravanPlan[13][4] = 0
	$g_a_FactionsCaravanPlan[13][5] = ""
	$g_a_FactionsCaravanPlan[13][8] = "ShenzunTunnels"

	$g_a_FactionsCaravanPlan[14][0] = $TahnnakiTemple_Map
	$g_a_FactionsCaravanPlan[14][1] = $TahnnakiTemple_Outpost
	$g_a_FactionsCaravanPlan[14][2] = 0
	$g_a_FactionsCaravanPlan[14][3] = 0
	$g_a_FactionsCaravanPlan[14][4] = 0
	$g_a_FactionsCaravanPlan[14][5] = ""
	$g_a_FactionsCaravanPlan[14][8] = "TahnnakiTemple"

	$g_a_FactionsCaravanPlan[15][0] = $SunjiangDistrict_Map
	$g_a_FactionsCaravanPlan[15][1] = $SunjiangDistrict_Outpost
	$g_a_FactionsCaravanPlan[15][2] = 0
	$g_a_FactionsCaravanPlan[15][3] = 0
	$g_a_FactionsCaravanPlan[15][4] = 0
	$g_a_FactionsCaravanPlan[15][5] = ""
	$g_a_FactionsCaravanPlan[15][8] = "SunjiangDistrict"

	$g_a_FactionsCaravanPlan[16][0] = $PongmeiValley_Map
	$g_a_FactionsCaravanPlan[16][1] = $PongmeiValley_Outpost
	$g_a_FactionsCaravanPlan[16][2] = 0
	$g_a_FactionsCaravanPlan[16][3] = 0
	$g_a_FactionsCaravanPlan[16][4] = 0
	$g_a_FactionsCaravanPlan[16][5] = ""
	$g_a_FactionsCaravanPlan[16][8] = "PongmeiValley"

	$g_a_FactionsCaravanPlan[17][0] = $Arborstone_Map
	$g_a_FactionsCaravanPlan[17][1] = $Arborstone_Outpost
	$g_a_FactionsCaravanPlan[17][2] = 0
	$g_a_FactionsCaravanPlan[17][3] = 0
	$g_a_FactionsCaravanPlan[17][4] = 0
	$g_a_FactionsCaravanPlan[17][5] = ""
	$g_a_FactionsCaravanPlan[17][8] = "Arborstone"

	$g_a_FactionsCaravanPlan[18][0] = $Ferndale_Map
	$g_a_FactionsCaravanPlan[18][1] = $Ferndale_Outpost
	$g_a_FactionsCaravanPlan[18][2] = 0
	$g_a_FactionsCaravanPlan[18][3] = 0
	$g_a_FactionsCaravanPlan[18][4] = 0
	$g_a_FactionsCaravanPlan[18][5] = ""
	$g_a_FactionsCaravanPlan[18][8] = "Ferndale"

	$g_a_FactionsCaravanPlan[19][0] = $MelandrusHope_Map
	$g_a_FactionsCaravanPlan[19][1] = $MelandrusHope_Outpost
	$g_a_FactionsCaravanPlan[19][2] = 0
	$g_a_FactionsCaravanPlan[19][3] = 0
	$g_a_FactionsCaravanPlan[19][4] = 0
	$g_a_FactionsCaravanPlan[19][5] = ""
	$g_a_FactionsCaravanPlan[19][8] = "MelandrusHope"

	$g_a_FactionsCaravanPlan[20][0] = $DrazachThicket_Map
	$g_a_FactionsCaravanPlan[20][1] = $DrazachThicket_Outpost
	$g_a_FactionsCaravanPlan[20][2] = 0
	$g_a_FactionsCaravanPlan[20][3] = 0
	$g_a_FactionsCaravanPlan[20][4] = 0
	$g_a_FactionsCaravanPlan[20][5] = ""
	$g_a_FactionsCaravanPlan[20][8] = "DrazachThicket"

	$g_a_FactionsCaravanPlan[21][0] = $MorostavTrail_Map
	$g_a_FactionsCaravanPlan[21][1] = $MorostavTrail_Outpost
	$g_a_FactionsCaravanPlan[21][2] = 0
	$g_a_FactionsCaravanPlan[21][3] = 0
	$g_a_FactionsCaravanPlan[21][4] = 0
	$g_a_FactionsCaravanPlan[21][5] = ""
	$g_a_FactionsCaravanPlan[21][8] = "MorostavTrail"

	$g_a_FactionsCaravanPlan[22][0] = $TheEternalGrove_Map
	$g_a_FactionsCaravanPlan[22][1] = $TheEternalGrove_Outpost
	$g_a_FactionsCaravanPlan[22][2] = 0
	$g_a_FactionsCaravanPlan[22][3] = 0
	$g_a_FactionsCaravanPlan[22][4] = 0
	$g_a_FactionsCaravanPlan[22][5] = ""
	$g_a_FactionsCaravanPlan[22][8] = "TheEternalGrove"

	$g_a_FactionsCaravanPlan[23][0] = $MourningVeilFalls_Map
	$g_a_FactionsCaravanPlan[23][1] = $MourningVeilFalls_Outpost
	$g_a_FactionsCaravanPlan[23][2] = 0
	$g_a_FactionsCaravanPlan[23][3] = 0
	$g_a_FactionsCaravanPlan[23][4] = 0
	$g_a_FactionsCaravanPlan[23][5] = ""
	$g_a_FactionsCaravanPlan[23][8] = "MourningVeilFalls"

	$g_a_FactionsCaravanPlan[24][0] = $BoreasSeabed_Map
	$g_a_FactionsCaravanPlan[24][1] = $BoreasSeabed_Outpost
	$g_a_FactionsCaravanPlan[24][2] = 0
	$g_a_FactionsCaravanPlan[24][3] = 0
	$g_a_FactionsCaravanPlan[24][4] = 0
	$g_a_FactionsCaravanPlan[24][5] = ""
	$g_a_FactionsCaravanPlan[24][8] = "BoreasSeabed"

	$g_a_FactionsCaravanPlan[25][0] = $MountQinkai_Map
	$g_a_FactionsCaravanPlan[25][1] = $MountQinkai_Outpost
	$g_a_FactionsCaravanPlan[25][2] = 0
	$g_a_FactionsCaravanPlan[25][3] = 0
	$g_a_FactionsCaravanPlan[25][4] = 0
	$g_a_FactionsCaravanPlan[25][5] = ""
	$g_a_FactionsCaravanPlan[25][8] = "MountQinkai"

	$g_a_FactionsCaravanPlan[26][0] = $Archipelagos_Map
	$g_a_FactionsCaravanPlan[26][1] = $Archipelagos_Outpost
	$g_a_FactionsCaravanPlan[26][2] = 0
	$g_a_FactionsCaravanPlan[26][3] = 0
	$g_a_FactionsCaravanPlan[26][4] = 0
	$g_a_FactionsCaravanPlan[26][5] = ""
	$g_a_FactionsCaravanPlan[26][8] = "Archipelagos"

	$g_a_FactionsCaravanPlan[27][0] = $MaishangHills_Map
	$g_a_FactionsCaravanPlan[27][1] = $MaishangHills_Outpost
	$g_a_FactionsCaravanPlan[27][2] = 0
	$g_a_FactionsCaravanPlan[27][3] = 0
	$g_a_FactionsCaravanPlan[27][4] = 0
	$g_a_FactionsCaravanPlan[27][5] = ""
	$g_a_FactionsCaravanPlan[27][8] = "MaishangHills"

	$g_a_FactionsCaravanPlan[28][0] = $GyalaHatchery_Map
	$g_a_FactionsCaravanPlan[28][1] = $GyalaHatchery_Outpost
	$g_a_FactionsCaravanPlan[28][2] = 0
	$g_a_FactionsCaravanPlan[28][3] = 0
	$g_a_FactionsCaravanPlan[28][4] = 0
	$g_a_FactionsCaravanPlan[28][5] = ""
	$g_a_FactionsCaravanPlan[28][8] = "GyalaHatchery"

	$g_a_FactionsCaravanPlan[29][0] = $RheasCrater_Map
	$g_a_FactionsCaravanPlan[29][1] = $RheasCrater_Outpost
	$g_a_FactionsCaravanPlan[29][2] = 0
	$g_a_FactionsCaravanPlan[29][3] = 0
	$g_a_FactionsCaravanPlan[29][4] = 0
	$g_a_FactionsCaravanPlan[29][5] = ""
	$g_a_FactionsCaravanPlan[29][8] = "RheasCrater"

	$g_a_FactionsCaravanPlan[30][0] = $SilentSurf_Map
	$g_a_FactionsCaravanPlan[30][1] = $SilentSurf_Outpost
	$g_a_FactionsCaravanPlan[30][2] = 0
	$g_a_FactionsCaravanPlan[30][3] = 0
	$g_a_FactionsCaravanPlan[30][4] = 0
	$g_a_FactionsCaravanPlan[30][5] = ""
	$g_a_FactionsCaravanPlan[30][8] = "SilentSurf"

	$g_a_FactionsCaravanPlan[31][0] = $UnwakingWaters_Map
	$g_a_FactionsCaravanPlan[31][1] = $UnwakingWaters_Outpost
	$g_a_FactionsCaravanPlan[31][2] = 0
	$g_a_FactionsCaravanPlan[31][3] = 0
	$g_a_FactionsCaravanPlan[31][4] = 0
	$g_a_FactionsCaravanPlan[31][5] = ""
	$g_a_FactionsCaravanPlan[31][8] = "UnwakingWaters"

	$g_a_FactionsCaravanPlan[32][0] = $RaisuPalace_Map
	$g_a_FactionsCaravanPlan[32][1] = $RaisuPalace_Outpost
	$g_a_FactionsCaravanPlan[32][2] = 0
	$g_a_FactionsCaravanPlan[32][3] = 0
	$g_a_FactionsCaravanPlan[32][4] = 0
	$g_a_FactionsCaravanPlan[32][5] = ""
	$g_a_FactionsCaravanPlan[32][8] = "RaisuPalace"

EndFunc

Func _Vanquisher_IsFactionsCaravanEntryMap($iMapID, $iStage)
	Return _CaravanPlan_IsEntryMap($g_a_FactionsCaravanPlan, $GC_I_FACTIONS_CARAVAN_MAP_COUNT, $iMapID, $iStage)
EndFunc

Func _Vanquisher_IsOnFactionsCaravanSpine($iMapID = -1)
	_Vanquisher_InitFactionsCaravanPlan()
	If $iMapID < 0 Then $iMapID = Map_GetMapID()
	Local $i
	For $i = 0 To $GC_I_FACTIONS_CARAVAN_MAP_COUNT - 1
		If _Vanquisher_IsFactionsCaravanEntryMap($iMapID, $i) Then Return True
	Next
	Return False
EndFunc

Func _Vanquisher_FactionsCaravanStageForCurrentMap()
	_Vanquisher_InitFactionsCaravanPlan()
	Return _CaravanPlan_StageForCurrentMap($g_a_FactionsCaravanPlan, $GC_I_FACTIONS_CARAVAN_MAP_COUNT)
EndFunc

Func _Vanquisher_FactionsCaravanIsStageHistoricallyVanquished($iStage)
	_Vanquisher_InitFactionsCaravanPlan()
	If $iStage < 0 Or $iStage >= $GC_I_FACTIONS_CARAVAN_MAP_COUNT Then Return False
	Return VanquishCheck_IsMapHistoricallyVanquished(Number($g_a_FactionsCaravanPlan[$iStage][0]))
EndFunc
