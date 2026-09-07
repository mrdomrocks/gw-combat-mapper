#include-once

; Copy example configs next to the launcher when live files are missing.

Func EnsureConfig_CopyIfMissing()
	Local $l_s_Config = @ScriptDir & "\config.ini"
	Local $l_s_ConfigEx = @ScriptDir & "\config.ini.example"
	If Not FileExists($l_s_Config) And FileExists($l_s_ConfigEx) Then
		FileCopy($l_s_ConfigEx, $l_s_Config)
	EndIf
	Local $l_s_Hero = @ScriptDir & "\vanquish_config.ini"
	Local $l_s_HeroEx = @ScriptDir & "\vanquish_config.ini.example"
	If Not FileExists($l_s_Hero) And FileExists($l_s_HeroEx) Then
		FileCopy($l_s_HeroEx, $l_s_Hero)
	EndIf
EndFunc
