#include-once

; Active caravan spine. Call CaravanPlan_SetKind before use.
; Farm flags come from the GUI map list; visit list is farm maps plus required
; portal transits, skipping dead-end branches that are not selected.

#include "maps\Caravan_AscalonPlan.au3"
#include "maps\Caravan_MaguumaPlan.au3"
#include "maps\Caravan_EOTNPlan.au3"
#include "maps\Caravan_FactionsPlan.au3"
#include "maps\Caravan_NightfallPlan.au3"

Global Const $GC_I_CARAVAN_FARM_MAX = 40

Global $g_s_CaravanKind = "Ascalon"
Global $g_ab_CaravanFarm[$GC_I_CARAVAN_FARM_MAX]
Global $g_ai_CaravanVisit[$GC_I_CARAVAN_FARM_MAX]
Global $g_i_CaravanVisitCount = 0
Global $g_b_CaravanSkipVanquished = True

Func _CaravanPlan_IsEntryMap(ByRef $a_a_Plan, $a_i_Count, $a_i_MapID, $a_i_Stage)
	If $a_i_Stage < 0 Or $a_i_Stage >= $a_i_Count Then Return False
	If $a_i_MapID = $a_a_Plan[$a_i_Stage][0] Then Return True
	If $a_a_Plan[$a_i_Stage][1] > 0 And $a_i_MapID = $a_a_Plan[$a_i_Stage][1] Then Return True
	If $a_a_Plan[$a_i_Stage][2] > 0 And $a_i_MapID = $a_a_Plan[$a_i_Stage][2] Then Return True
	If $a_a_Plan[$a_i_Stage][3] > 0 And $a_i_MapID = $a_a_Plan[$a_i_Stage][3] Then Return True
	If $a_a_Plan[$a_i_Stage][4] > 0 And $a_i_MapID = $a_a_Plan[$a_i_Stage][4] Then Return True
	Return False
EndFunc

Func _CaravanPlan_StageForCurrentMap(ByRef $a_a_Plan, $a_i_Count)
	Local $iMapID = Number(Map_GetMapID())
	Local $i
	For $i = 0 To $a_i_Count - 1
		If Number($a_a_Plan[$i][0]) = $iMapID Then Return $i
	Next
	For $i = 0 To $a_i_Count - 1
		If $a_a_Plan[$i][2] > 0 And Number($a_a_Plan[$i][2]) = $iMapID Then Return $i
		If $a_a_Plan[$i][3] > 0 And Number($a_a_Plan[$i][3]) = $iMapID Then Return $i
		If $a_a_Plan[$i][4] > 0 And Number($a_a_Plan[$i][4]) = $iMapID Then Return $i
	Next
	For $i = 0 To $a_i_Count - 1
		If $a_a_Plan[$i][1] > 0 And Number($a_a_Plan[$i][1]) = $iMapID Then Return $i
	Next
	Return 0
EndFunc

Func CaravanPlan_SetKind($a_s_Kind)
	Switch $a_s_Kind
		Case "Maguuma"
			$g_s_CaravanKind = "Maguuma"
			_Vanquisher_InitMaguumaCaravanPlan()
		Case "EOTN"
			$g_s_CaravanKind = "EOTN"
			_Vanquisher_InitEOTNCaravanPlan()
		Case "Factions"
			$g_s_CaravanKind = "Factions"
			_Vanquisher_InitFactionsCaravanPlan()
		Case "Nightfall"
			$g_s_CaravanKind = "Nightfall"
			_Vanquisher_InitNightfallCaravanPlan()
		Case Else
			$g_s_CaravanKind = "Ascalon"
			_Vanquisher_InitAscalonCaravanPlan()
	EndSwitch
EndFunc

Func CaravanPlan_Kind()
	Return $g_s_CaravanKind
EndFunc

Func CaravanPlan_Count()
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return $GC_I_MAGUUMA_CARAVAN_MAP_COUNT
		Case "EOTN"
			Return $GC_I_EOTN_CARAVAN_MAP_COUNT
		Case "Factions"
			Return $GC_I_FACTIONS_CARAVAN_MAP_COUNT
		Case "Nightfall"
			Return $GC_I_NIGHTFALL_CARAVAN_MAP_COUNT
	EndSwitch
	Return $GC_I_ASCALON_CARAVAN_MAP_COUNT
EndFunc

Func CaravanPlan_Title($a_i_Stage)
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return String($g_a_MaguumaCaravanPlan[$a_i_Stage][8])
		Case "EOTN"
			Return String($g_a_EOTNCaravanPlan[$a_i_Stage][8])
		Case "Factions"
			Return String($g_a_FactionsCaravanPlan[$a_i_Stage][8])
		Case "Nightfall"
			Return String($g_a_NightfallCaravanPlan[$a_i_Stage][8])
	EndSwitch
	Return String($g_a_AscalonCaravanPlan[$a_i_Stage][8])
EndFunc

Func CaravanPlan_MapID($a_i_Stage)
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return Number($g_a_MaguumaCaravanPlan[$a_i_Stage][0])
		Case "EOTN"
			Return Number($g_a_EOTNCaravanPlan[$a_i_Stage][0])
		Case "Factions"
			Return Number($g_a_FactionsCaravanPlan[$a_i_Stage][0])
		Case "Nightfall"
			Return Number($g_a_NightfallCaravanPlan[$a_i_Stage][0])
	EndSwitch
	Return Number($g_a_AscalonCaravanPlan[$a_i_Stage][0])
EndFunc

Func CaravanPlan_OutpostID($a_i_Stage)
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return Number($g_a_MaguumaCaravanPlan[$a_i_Stage][1])
		Case "EOTN"
			Return Number($g_a_EOTNCaravanPlan[$a_i_Stage][1])
		Case "Factions"
			Return Number($g_a_FactionsCaravanPlan[$a_i_Stage][1])
		Case "Nightfall"
			Return Number($g_a_NightfallCaravanPlan[$a_i_Stage][1])
	EndSwitch
	Return Number($g_a_AscalonCaravanPlan[$a_i_Stage][1])
EndFunc

Func CaravanPlan_StageIndexByTitle($a_s_Title)
	Local $i
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $l_i_Count - 1
		If CaravanPlan_Title($i) = $a_s_Title Then Return $i
	Next
	Return -1
EndFunc

Func CaravanPlan_StageForCurrentMap()
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return _Vanquisher_MaguumaCaravanStageForCurrentMap()
		Case "EOTN"
			Return _Vanquisher_EOTNCaravanStageForCurrentMap()
		Case "Factions"
			Return _Vanquisher_FactionsCaravanStageForCurrentMap()
		Case "Nightfall"
			Return _Vanquisher_NightfallCaravanStageForCurrentMap()
	EndSwitch
	Return _Vanquisher_AscalonCaravanStageForCurrentMap()
EndFunc

Func CaravanPlan_IsEntryMap($a_i_MapID, $a_i_Stage)
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return _Vanquisher_IsMaguumaCaravanEntryMap($a_i_MapID, $a_i_Stage)
		Case "EOTN"
			Return _Vanquisher_IsEOTNCaravanEntryMap($a_i_MapID, $a_i_Stage)
		Case "Factions"
			Return _Vanquisher_IsFactionsCaravanEntryMap($a_i_MapID, $a_i_Stage)
		Case "Nightfall"
			Return _Vanquisher_IsNightfallCaravanEntryMap($a_i_MapID, $a_i_Stage)
	EndSwitch
	Return _Vanquisher_IsAscalonCaravanEntryMap($a_i_MapID, $a_i_Stage)
EndFunc

Func CaravanPlan_EntryOutpost()
	Local $l_i_First = CaravanPlan_VisitStage(0)
	If $l_i_First < 0 Then Return 0
	Return CaravanPlan_OutpostID($l_i_First)
EndFunc

Func CaravanPlan_ReturnOutpost()
	Switch $g_s_CaravanKind
		Case "EOTN"
			Return $VerdantCascades_Outpost
		Case "Factions"
			Return $SunquaVale_Outpost
		Case "Nightfall"
			Return $PlainsofJarin_Outpost
	EndSwitch
	Return $TheBlackCurtain_Outpost
EndFunc

Func CaravanPlan_ReturnLabel()
	Switch $g_s_CaravanKind
		Case "EOTN"
			Return "Eye of the North"
		Case "Factions"
			Return "Shing Jea Monastery"
		Case "Nightfall"
			Return "Kamadan"
	EndSwitch
	Return "Temple of the Ages"
EndFunc

Func CaravanPlan_SequenceLabel()
	Switch $g_s_CaravanKind
		Case "Maguuma"
			Return "Maguuma Caravan"
		Case "EOTN"
			Return "EOTN"
		Case "Factions"
			Return "Factions"
		Case "Nightfall"
			Return "Nightfall"
	EndSwitch
	Return "Ascalon Caravan"
EndFunc

Func CaravanPlan_ShouldFarm($a_i_Stage)
	If $a_i_Stage < 0 Or $a_i_Stage >= CaravanPlan_Count() Then Return False
	Return $g_ab_CaravanFarm[$a_i_Stage]
EndFunc

Func CaravanPlan_FarmCount()
	Local $i, $l_i_N = 0
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $l_i_Count - 1
		If $g_ab_CaravanFarm[$i] Then $l_i_N += 1
	Next
	Return $l_i_N
EndFunc

Func CaravanPlan_VisitCount()
	Return $g_i_CaravanVisitCount
EndFunc

Func CaravanPlan_VisitStage($a_i_VisitIdx)
	If $a_i_VisitIdx < 0 Or $a_i_VisitIdx >= $g_i_CaravanVisitCount Then Return -1
	Return $g_ai_CaravanVisit[$a_i_VisitIdx]
EndFunc

Func CaravanPlan_FarmTitlesPipe()
	Local $i, $l_s = ""
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $l_i_Count - 1
		If Not $g_ab_CaravanFarm[$i] Then ContinueLoop
		If $l_s <> "" Then $l_s &= "|"
		$l_s &= CaravanPlan_Title($i)
	Next
	Return $l_s
EndFunc

; $a_s_PipeList empty or "*" => farm every map on the spine.
Func CaravanPlan_SetFarmFromTitles($a_s_PipeList)
	Local $i
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $GC_I_CARAVAN_FARM_MAX - 1
		$g_ab_CaravanFarm[$i] = False
	Next

	Local $l_s = StringStripWS(String($a_s_PipeList), 3)
	If $l_s = "" Or $l_s = "*" Then
		For $i = 0 To $l_i_Count - 1
			$g_ab_CaravanFarm[$i] = True
		Next
		CaravanPlan_BuildVisitList()
		Return
	EndIf

	Local $l_a_Parts = StringSplit($l_s, "|")
	Local $l_i_Set = 0
	For $i = 1 To $l_a_Parts[0]
		Local $l_i_Stage = CaravanPlan_StageIndexByTitle(StringStripWS($l_a_Parts[$i], 3))
		If $l_i_Stage < 0 Then ContinueLoop
		$g_ab_CaravanFarm[$l_i_Stage] = True
		$l_i_Set += 1
	Next
	If $l_i_Set < 1 Then
		For $i = 0 To $l_i_Count - 1
			$g_ab_CaravanFarm[$i] = True
		Next
	EndIf
	CaravanPlan_BuildVisitList()
EndFunc

; Drop already-vanquished maps from the farm set (still used as portal transits).
Func CaravanPlan_DropVanquishedFarms()
	If Not $g_b_CaravanSkipVanquished Then Return
	Local $i
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $l_i_Count - 1
		If Not $g_ab_CaravanFarm[$i] Then ContinueLoop
		If Not VanquishCheck_IsMapHistoricallyVanquished(CaravanPlan_MapID($i)) Then ContinueLoop
		Out("Skip vanquish on " & CaravanPlan_Title($i) & " — already completed.")
		$g_ab_CaravanFarm[$i] = False
	Next
	CaravanPlan_BuildVisitList()
EndFunc

; Side branches that are not required to reach later linear maps (Prophecies caravans only).
Func CaravanPlan_IsSideBranch($a_i_Stage)
	If $g_s_CaravanKind <> "Ascalon" And $g_s_CaravanKind <> "Maguuma" Then Return False
	Local $l_s = CaravanPlan_Title($a_i_Stage)
	If $l_s = "DragonsGullet" Or $l_s = "FlameTempleCorridor" Then Return True
	If $l_s = "TheFalls" Or $l_s = "ReedBog" Then Return True
	Return False
EndFunc

Func CaravanPlan_SideBranchNeeded($a_i_Stage)
	Local $l_s = CaravanPlan_Title($a_i_Stage)
	If $l_s = "DragonsGullet" Then Return CaravanPlan_ShouldFarm($a_i_Stage)
	If $l_s = "TheFalls" Then Return CaravanPlan_ShouldFarm($a_i_Stage)
	If $l_s = "FlameTempleCorridor" Then
		Return CaravanPlan_ShouldFarm($a_i_Stage) Or _
			CaravanPlan_ShouldFarm(CaravanPlan_StageIndexByTitle("DragonsGullet"))
	EndIf
	If $l_s = "ReedBog" Then
		Return CaravanPlan_ShouldFarm($a_i_Stage) Or _
			CaravanPlan_ShouldFarm(CaravanPlan_StageIndexByTitle("TheFalls"))
	EndIf
	Return True
EndFunc

Func CaravanPlan_BuildVisitList()
	$g_i_CaravanVisitCount = 0
	Local $i, $l_i_LastFarm = -1
	Local $l_i_Count = CaravanPlan_Count()
	For $i = 0 To $l_i_Count - 1
		If $g_ab_CaravanFarm[$i] Then $l_i_LastFarm = $i
	Next
	If $l_i_LastFarm < 0 Then Return

	For $i = 0 To $l_i_LastFarm
		If CaravanPlan_IsSideBranch($i) And Not CaravanPlan_SideBranchNeeded($i) Then ContinueLoop
		$g_ai_CaravanVisit[$g_i_CaravanVisitCount] = $i
		$g_i_CaravanVisitCount += 1
	Next
EndFunc

; Portal hops that skip unselected dead-ends (Falls/Reed, FTC/DG).
Func CaravanPlan_AdvanceToNext($a_s_Here, $a_s_Next)
	If $g_s_CaravanKind = "Maguuma" Then
		If $a_s_Here = "TheFalls" And ($a_s_Next = "DryTop" Or $a_s_Next = "TangleRoot") Then
			Out("Maguuma: leave The Falls via Reed Bog and Ettin's Back (no re-farm).")
			If Not MapTravel_AdvanceToTitle("ReedBog") Then Return False
			If Not MapTravel_AdvanceToTitle("EttinsBack") Then Return False
			If $a_s_Next = "DryTop" Then Return MapTravel_AdvanceToTitle("DryTop")
			If Not MapTravel_AdvanceToTitle("DryTop") Then Return False
			Return MapTravel_AdvanceToTitle($a_s_Next)
		EndIf
		If $a_s_Here = "ReedBog" And ($a_s_Next = "DryTop" Or $a_s_Next = "TangleRoot") Then
			Out("Maguuma: leave Reed Bog via Ettin's Back (no re-farm).")
			If Not MapTravel_AdvanceToTitle("EttinsBack") Then Return False
		EndIf
	EndIf
	Return MapTravel_AdvanceToTitle($a_s_Next)
EndFunc

; Lookup map/outpost id from any caravan spine (for MapCatalog).
Func CaravanPlan_LookupTitle($a_s_Title, ByRef $a_i_MapID, ByRef $a_i_Outpost, ByRef $a_i_Stage)
	$a_i_MapID = 0
	$a_i_Outpost = 0
	$a_i_Stage = -1
	Local $l_s_SavedKind = $g_s_CaravanKind
	Local $l_a_Kinds[5] = ["Ascalon", "Maguuma", "EOTN", "Factions", "Nightfall"]
	Local $k
	For $k = 0 To 4
		CaravanPlan_SetKind($l_a_Kinds[$k])
		Local $l_i_Stage = CaravanPlan_StageIndexByTitle($a_s_Title)
		If $l_i_Stage < 0 Then ContinueLoop
		$a_i_MapID = CaravanPlan_MapID($l_i_Stage)
		$a_i_Outpost = CaravanPlan_OutpostID($l_i_Stage)
		$a_i_Stage = $l_i_Stage
		CaravanPlan_SetKind($l_s_SavedKind)
		Return True
	Next
	CaravanPlan_SetKind($l_s_SavedKind)
	Return False
EndFunc
