// Red Frontier ambience (region id `backroads`): thin Martian wind with a fine dust hiss and
// grains ticking on the hull, the homestead's habitat hum, a soft radio beacon ping, two distant
// servo whirrs, and the rover's electric drive with regolith crunching under the wheels.
// render_fx.scd renders 22 s and make_loop.py crossfades the last 3 s over the first, so the loop
// is 19 s long. The steady tones complete whole cycles in 19 s (60 Hz, and 60 + 2/19 for the beat),
// so the crossfade never cancels them; the beacon pings every 4.75 s, four times a loop, landing on
// the seam; the servo whirrs are one-off events between 5 s and 15 s, clear of the crossfade.
// sclang has no operator precedence, hence the brackets around every product.
~ambience = SynthDef(\ambience, {
	var gust = LFNoise2.kr([0.11, 0.13]).range(0.4, 1.0);
	var wind = BPF.ar(PinkNoise.ar(1 ! 2), LFNoise2.kr([0.17, 0.19]).range(650, 1400), 0.7) * gust * 0.2;
	var whistle = BPF.ar(WhiteNoise.ar(1 ! 2), LFNoise2.kr([0.23, 0.2]).range(1900, 2700), 0.03) * gust.squared * 0.35;
	var hiss = HPF.ar(WhiteNoise.ar(1 ! 2), 6500) * (0.014 * gust);
	var grains = BPF.ar(Decay2.ar(Dust.ar([26, 31] * gust), 0.0003, 0.002) * WhiteNoise.ar(1 ! 2), 4200, 1.0) * 0.16;

	var humLevel = LFNoise2.kr(0.1).range(0.8, 1.0);
	var hum = (SinOsc.ar([60, 60 + (2 / 19)], 0, 0.014) + SinOsc.ar(120, 0, 0.006 ! 2)
		+ SinOsc.ar(180, 0, 0.0025 ! 2)) * humLevel;
	var humAir = LPF.ar(BrownNoise.ar(0.2 ! 2), 140) * 0.18;

	var pingEnv = EnvGen.ar(Env.perc(0.004, 1.1, 1, -6), Impulse.kr(1 / 4.75));
	var pingTone = (SinOsc.ar(1568) * pingEnv * 0.06) + (SinOsc.ar(2352) * pingEnv.squared * 0.02);
	var ping = FreeVerb2.ar(pingTone * 0.8, pingTone, 0.45, 0.8, 0.4);

	var servo1Level = EnvGen.kr(Env([0, 0, 1, 1, 0], [5.5, 0.25, 1.7, 0.4], [0, 2, 0, -2]));
	var servo1Freq = EnvGen.kr(Env([260, 260, 520, 440], [5.5, 0.9, 1.4], \sin));
	var servo1 = BPF.ar(Saw.ar(servo1Freq) + (Saw.ar(servo1Freq * 2.01) * 0.5), servo1Freq * 3, 0.5) * servo1Level * 0.12;
	var servo2Level = EnvGen.kr(Env([0, 0, 1, 1, 0, 0, 1, 1, 0],
		[11.5, 0.2, 0.7, 0.15, 0.35, 0.15, 0.9, 0.3], [0, 2, 0, -2, 0, 2, 0, -2]));
	var servo2Freq = EnvGen.kr(Env([480, 480, 360, 360, 300], [11.5, 0.9, 0.6, 1.1], \sin));
	var servo2 = BPF.ar(Pulse.ar(servo2Freq, 0.3) + Saw.ar(servo2Freq * 1.5), servo2Freq * 2.5, 0.6) * servo2Level * 0.09;
	var clunk = Ringz.ar(EnvGen.ar(Env([0, 0, 1, 0], [14.35, 0.001, 0.03])) * WhiteNoise.ar(1), 170, 0.18) * 0.03;
	// Servo one on the left, servo two on the right, both far off in the reverb.
	var servos = FreeVerb2.ar(LPF.ar(servo1, 2600) + clunk, LPF.ar(servo2, 2600) + clunk, 0.5, 0.9, 0.5);

	var whine = (SinOsc.ar(760 + LFNoise1.kr(0.3, 3), 0, 0.006) + SinOsc.ar(1520, 0, 0.002)
		+ SinOsc.ar(3040 + LFNoise1.kr(0.4, 6), 0, 0.0012)) ! 2;
	var motor = LPF.ar(Saw.ar([38, 38 + (10 / 19)]) + Saw.ar(57), 160) * 0.035;
	var roll = LPF.ar(BrownNoise.ar(1 ! 2), 320) * 0.06;
	var crunch = BPF.ar(Decay2.ar(Dust.ar([90, 105]), 0.0005, 0.006) * PinkNoise.ar(1 ! 2), 900, 1.2) * 0.3;

	// Doubled (+6 dB) to sit at about the other regions' loudness (around -21 dBFS RMS).
	Out.ar(0, (wind + whistle + hiss + grains + hum + humAir + ping + servos + whine + motor + roll + crunch) * 2);
});
