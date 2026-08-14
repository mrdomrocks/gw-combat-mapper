#include-once

; GwAu3 UtilityAI smart casting: Cache_SkillBar must run once per explorable
; before Pathfinder_MoveTo -> UAI_Fight can auto-attack and cast skills.

Global $g_b_SmartCastEnabled = True
Global $g_b_SmartCastWeaponSets = True
Global $g_b_SmartCastReady = False
Global $g_i_SmartCastMapID = 0

Func SmartCast_LoadConfig($a_s_ConfigPath = "")
	If $a_s_ConfigPath = "" Then $a_s_ConfigPath = @ScriptDir & "\config.ini"
	$g_b_SmartCastEnabled = Number(IniRead($a_s_ConfigPath, "Combat", "SmartCast", "1")) <> 0
	$g_b_SmartCastWeaponSets = Number(IniRead($a_s_ConfigPath, "Combat", "SmartCastWeaponSets", "1")) <> 0
EndFunc

Func SmartCast_Invalidate()
	$g_b_SmartCastReady = False
	$g_i_SmartCastMapID = 0
EndFunc

; Cache skill bar for current explorable. Safe to call often (no-ops if already ready for this map).
Func SmartCast_EnsureReady($a_b_Announce = False)
	SmartCast_LoadConfig()
	If Not $g_b_SmartCastEnabled Then Return True

	If Map_GetInstanceInfo("IsLoading") Then
		SmartCast_Invalidate()
		Return False
	EndIf

	If Not Map_GetInstanceInfo("IsExplorable") Then
		SmartCast_Invalidate()
		Return False
	EndIf

	Local $l_i_MapID = Map_GetMapID()
	If $l_i_MapID <= 0 Then Return False

	If $g_b_SmartCastReady And $g_i_SmartCastMapID = $l_i_MapID Then Return True

	$g_b_CacheWeaponSet = $g_b_SmartCastWeaponSets
	If Not Cache_SkillBar() Then
		If $a_b_Announce Then Out("SmartCast: Cache_SkillBar failed on MapID=" & $l_i_MapID)
		SmartCast_Invalidate()
		Return False
	EndIf

	$g_b_SmartCastReady = True
	$g_i_SmartCastMapID = $l_i_MapID
	If $a_b_Announce Then Out("SmartCast ready (skill bar cached) MapID=" & $l_i_MapID)
	Return True
EndFunc
