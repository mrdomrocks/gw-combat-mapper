#include-once

; Caravan vanquish route for AscalonFoothills (forward pass from vanquish bot).

Global $aCaravanAscalon_AscalonFoothillsPath = [ _
	[-5785, 1558], _
	[-2684, 2006], _
	[-5544, -1613], _
	[-3428, -5729], _
	[373, -3274], _
	[-3156, -2098], _
	[-1639, 751], _
	[621, -735], _
	[2040, 2078], _
	[240, 5077], _
	[4885, 5096], _
	[5939, 1126], _
	[3321, -3531], _
	[7394, -6932] _
]

Global Const $GC_I_ROUTE_AscalonFoothills_COUNT = 14


Func MapRoute_GetAscalonFoothills(ByRef $a_a_X, ByRef $a_a_Y)
	Return MapRoute_CopyPath1D($aCaravanAscalon_AscalonFoothillsPath, $a_a_X, $a_a_Y)
EndFunc
