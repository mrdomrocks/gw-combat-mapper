#include-once

; Caravan vanquish route for AscalonFoothills (forward pass from vanquish bot).

Global $aCaravanAscalon_AscalonFoothillsPath = [ _
	[-5785, 1558], _
	[-2684, 2006], _
	[-5760, 1440], _ ; auto
	[-7084.8, 192], _ ; auto
	[-5544, -1613], _
	[-6576, -3936], _ ; auto
	[-5518.0466, -5664], _ ; auto
	[-3428, -5729], _
	[-840, -4992], _ ; auto
	[373, -3274], _
	[183.9626, -3456], _ ; auto
	[-1376, -3456], _ ; auto
	[-3156, -2098], _
	[-1996.2048, 304], _ ; auto
	[-1639, 751], _
	[-542.5877, 384], _ ; auto
	[621, -735], _
	[2249.5831, 2016], _ ; auto
	[2040, 2078], _
	[300, 3505], _ ; auto
	[240, 5077], _
	[816.9821, 5796], _ ; auto
	[1776, 6048], _ ; auto
	[2176, 6816], _ ; auto
	[3360, 6816], _ ; auto
	[5799.5, 5171], _ ; auto
	[4885, 5096], _
	[5939, 1126], _
	[3321, -3531], _
	[5489.9106, -4896], _ ; auto
	[7321.25, -5205], _ ; auto
	[7394, -6932] _
]

Global Const $GC_I_ROUTE_AscalonFoothills_COUNT = 32


Func MapRoute_GetAscalonFoothills(ByRef $a_a_X, ByRef $a_a_Y)
	Return MapRoute_CopyPath1D($aCaravanAscalon_AscalonFoothillsPath, $a_a_X, $a_a_Y)
EndFunc
