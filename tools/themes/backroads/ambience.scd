// Backroads ambience: crickets in five detuned groups, wind, and the truck's idle.
~ambience = SynthDef(\ambience, {
	var crickets = Mix.fill(5, { |i|
		var carrier = SinOsc.ar(4050 + (i * 170));
		var trill = Lag.kr(LFPulse.kr(15 + (i * 1.3), 0, 0.5), 0.004);
		var phrase = Lag.kr(LFPulse.kr(0.55 + (i * 0.17), i * 0.2, 0.4), 0.05);
		Pan2.ar(carrier * trill * phrase * 0.018, (i / 2) - 1);
	});
	var wind = LPF.ar(BrownNoise.ar(0.22), LFNoise2.kr(0.13).range(180, 520)) ! 2;
	var engine = LPF.ar(Saw.ar(47 + LFNoise1.kr(2.3, 0.4)) + Saw.ar(47.6), 170) * 0.05 ! 2;
	Out.ar(0, crickets + wind + engine);
});
