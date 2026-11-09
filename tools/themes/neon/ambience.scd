// Neon Sprawl ambience: steady rain with droplet patter, the city's low hum and distant traffic,
// one faint siren wailing far off, and the car's electric whine with wet tyre hiss.
// render_fx.scd renders 22 s and make_loop.py crossfades the last 3 s over the first, so
// everything here is steady noise except the siren, which sits in the middle (5 s to 14 s).
~ambience = SynthDef(\ambience, {
	var rainHiss = LPF.ar(HPF.ar(PinkNoise.ar(0.9 ! 2), 1600), 9500) * 0.22;
	var patter = BPF.ar(Decay2.ar(Dust.ar([240, 260]), 0.0004, 0.003) * WhiteNoise.ar(1 ! 2),
		LFNoise1.kr([1.1, 0.9]).range(2600, 5200), 0.7) * 0.9;
	var plinks = Ringz.ar(Dust.ar([7, 6]), LFNoise0.kr([17, 19]).range(1700, 3600), 0.03) * 0.025;
	var hum = (LPF.ar(BrownNoise.ar(0.5 ! 2), 120) * 0.3)
		+ (SinOsc.ar([55, 55.25], 0, 0.016) * LFNoise2.kr(0.2).range(0.6, 1.0))
		+ SinOsc.ar([110.3, 110.1], 0, 0.006);
	var traffic = Mix.fill(3, { |i|
		var swell = LFNoise2.kr(0.11 + (i * 0.04)).range(0, 1).squared;
		Pan2.ar(BPF.ar(BrownNoise.ar(1.6), 260 + (i * 140), 0.9) * swell * 0.07, LFNoise1.kr(0.07 + (i * 0.03)));
	});
	var sirenLevel = EnvGen.kr(Env([0, 0, 1, 1, 0], [5.0, 2.5, 3.5, 3.0], [0, 2, 0, -2]));
	var sirenFreq = LFTri.kr(0.32, 1).range(640, 940);
	var siren = LPF.ar(LFTri.ar(sirenFreq) + (SinOsc.ar(sirenFreq * 2) * 0.25), 1300) * sirenLevel * 0.022;
	var sirenFar = FreeVerb2.ar(siren, siren, 0.75, 0.95, 0.6) * [0.6, 1.0];
	// sclang has no operator precedence, hence the brackets around every product.
	var whine = (SinOsc.ar(1180 + LFNoise1.kr(0.4, 5), 0, 0.0045) + SinOsc.ar(2361, 0, 0.002)
		+ (LPF.ar(LFTri.ar(236 + LFNoise1.kr(0.3, 1.5)), 600) * 0.012)) ! 2;
	var tyres = BPF.ar(WhiteNoise.ar(1 ! 2), LFNoise2.kr(0.25).range(700, 1100), 1.2) * 0.045;
	Out.ar(0, rainHiss + patter + plinks + hum + traffic + sirenFar + whine + tyres);
});
