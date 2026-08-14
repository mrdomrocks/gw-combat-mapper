#include-once

#include "maps\Routes\CaravanAscalon_NorthKrytaProvince.au3"
#include "maps\Routes\CaravanAscalon_ScoundrelsRise.au3"
#include "maps\Routes\CaravanAscalon_GriffonsMouth.au3"
#include "maps\Routes\CaravanAscalon_DeldrimorBowl.au3"
#include "maps\Routes\CaravanAscalon_AnvilRock.au3"
#include "maps\Routes\CaravanAscalon_IronHorseMine.au3"
#include "maps\Routes\CaravanAscalon_TravelersVale.au3"
#include "maps\Routes\CaravanAscalon_AscalonFoothills.au3"
#include "maps\Routes\CaravanAscalon_DiessaLowlands.au3"
#include "maps\Routes\CaravanAscalon_FlameTempleCorridor.au3"
#include "maps\Routes\CaravanAscalon_DragonsGullet.au3"
#include "maps\Routes\CaravanAscalon_TheBreach.au3"
#include "maps\Routes\CaravanAscalon_OldAscalon.au3"
#include "maps\Routes\CaravanAscalon_RegentValley.au3"
#include "maps\Routes\CaravanAscalon_PockmarkFlats.au3"
#include "maps\Routes\CaravanAscalon_EasternFrontier.au3"

Func _MapRoute_Distance($a_f_X1, $a_f_Y1, $a_f_X2, $a_f_Y2)
	Return Sqrt(($a_f_X2 - $a_f_X1) ^ 2 + ($a_f_Y2 - $a_f_Y1) ^ 2)
EndFunc

; Collapse consecutive points closer than $a_f_MinSpacing (default 150).
Func MapRoute_DedupePath1D(ByRef $a_a_X, ByRef $a_a_Y, $a_i_Count, $a_f_MinSpacing = 150)
	If $a_i_Count < 2 Then Return $a_i_Count

	Local $l_a_TempX[$a_i_Count]
	Local $l_a_TempY[$a_i_Count]
	$l_a_TempX[0] = $a_a_X[0]
	$l_a_TempY[0] = $a_a_Y[0]
	Local $l_i_Out = 1

	For $i = 1 To $a_i_Count - 1
		Local $l_f_D = _MapRoute_Distance($l_a_TempX[$l_i_Out - 1], $l_a_TempY[$l_i_Out - 1], $a_a_X[$i], $a_a_Y[$i])
		If $l_f_D < $a_f_MinSpacing Then ContinueLoop
		$l_a_TempX[$l_i_Out] = $a_a_X[$i]
		$l_a_TempY[$l_i_Out] = $a_a_Y[$i]
		$l_i_Out += 1
	Next

	ReDim $a_a_X[$l_i_Out]
	ReDim $a_a_Y[$l_i_Out]
	For $i = 0 To $l_i_Out - 1
		$a_a_X[$i] = $l_a_TempX[$i]
		$a_a_Y[$i] = $l_a_TempY[$i]
	Next
	Return $l_i_Out
EndFunc

; Copy Global path ([n][2] or nested literal) into parallel 1D arrays.
; Drops consecutive points closer than 150 units (duplicates / micro-steps that cause bounce-back).
Func MapRoute_CopyPath1D(ByRef $a_a_Source, ByRef $a_a_X, ByRef $a_a_Y)
	If Not IsArray($a_a_Source) Then Return 0

	Local $l_i_Count = 0
	If UBound($a_a_Source, 0) = 2 Then
		$l_i_Count = UBound($a_a_Source, 1)
	Else
		$l_i_Count = UBound($a_a_Source)
	EndIf
	If $l_i_Count < 1 Then Return 0

	Local $l_a_X[$l_i_Count]
	Local $l_a_Y[$l_i_Count]
	For $i = 0 To $l_i_Count - 1
		$l_a_X[$i] = $a_a_Source[$i][0]
		$l_a_Y[$i] = $a_a_Source[$i][1]
	Next

	Local $l_i_Out = MapRoute_DedupePath1D($l_a_X, $l_a_Y, $l_i_Count)
	If $l_i_Out < 1 Then Return 0
	$a_a_X = $l_a_X
	$a_a_Y = $l_a_Y
	Return $l_i_Out
EndFunc

; Return waypoint count, fills $a_a_X / $a_a_Y parallel arrays. Returns 0 if no route for title.
Func MapRoute_TryLoadForTitle($a_s_Title, ByRef $a_a_X, ByRef $a_a_Y)
	Switch $a_s_Title
		Case "NorthKrytaProvince"
			Return MapRoute_GetNorthKrytaProvince($a_a_X, $a_a_Y)
		Case "ScoundrelsRise"
			Return MapRoute_GetScoundrelsRise($a_a_X, $a_a_Y)
		Case "GriffonsMouth"
			Return MapRoute_GetGriffonsMouth($a_a_X, $a_a_Y)
		Case "DeldrimorBowl"
			Return MapRoute_GetDeldrimorBowl($a_a_X, $a_a_Y)
		Case "AnvilRock"
			Return MapRoute_GetAnvilRock($a_a_X, $a_a_Y)
		Case "IronHorseMine"
			Return MapRoute_GetIronHorseMine($a_a_X, $a_a_Y)
		Case "TravelersVale"
			Return MapRoute_GetTravelersVale($a_a_X, $a_a_Y)
		Case "AscalonFoothills"
			Return MapRoute_GetAscalonFoothills($a_a_X, $a_a_Y)
		Case "DiessaLowlands"
			Return MapRoute_GetDiessaLowlands($a_a_X, $a_a_Y)
		Case "FlameTempleCorridor"
			Return MapRoute_GetFlameTempleCorridor($a_a_X, $a_a_Y)
		Case "DragonsGullet"
			Return MapRoute_GetDragonsGullet($a_a_X, $a_a_Y)
		Case "TheBreach"
			Return MapRoute_GetTheBreach($a_a_X, $a_a_Y)
		Case "OldAscalon"
			Return MapRoute_GetOldAscalon($a_a_X, $a_a_Y)
		Case "RegentValley"
			Return MapRoute_GetRegentValley($a_a_X, $a_a_Y)
		Case "PockmarkFlats"
			Return MapRoute_GetPockmarkFlats($a_a_X, $a_a_Y)
		Case "EasternFrontier"
			Return MapRoute_GetEasternFrontier($a_a_X, $a_a_Y)
	EndSwitch
	Return 0
EndFunc

Func MapRoute_HasRoute($a_s_Title)
	Local $l_a_X, $l_a_Y
	Return MapRoute_TryLoadForTitle($a_s_Title, $l_a_X, $l_a_Y) > 0
EndFunc
