// Tidewater: short sound effects for the world's answers to the player (2026-11-11), mixed under the
// music by ThemeWorld.event_sound(). Rendered offline, one WAV per job, into the region's audio folder:
//   sclang tools/themes/coast/events.scd game/assets/themes/coast/audio
// (through ~/Desktop/siege-pc/tools/heavy.sh, like every SuperCollider build).
(
var dir = thisProcess.argv[0].withoutTrailingSlash ++ "/";
var options = ServerOptions.new.numOutputBusChannels_(2).numWireBufs_(512).memSize_(65536);
var head = { |t, def ... args| [t, [\s_new, def, -1, 0, 0] ++ args] };
var render = { |defs, events, dur, path, next|
	var list = defs.collect { |d| [0.0, [\d_recv, d.asBytes]] } ++ events ++ [[dur, [\c_set, 0, 0]]];
	Score(list.sort { |a, b| a[0] < b[0] }).recordNRT(path ++ ".osc", path, sampleRate: 44100, headerFormat: "WAV",
		sampleFormat: "int16", options: options, duration: dur,
		action: { File.delete(path ++ ".osc"); ("RENDERED " ++ path).postln; next.value });
};
var defs = [
	// A cryo-geyser: a burst of steam hissing out and dying down.
	SynthDef(\geyser, { |amp=0.4, pan=(-0.4)|
		var env = EnvGen.kr(Env.new([0, 1, 0.6, 0], [0.12, 1.1, 1.3], [2, -1, -3]), doneAction: 2);
		var hiss = BPF.ar(WhiteNoise.ar, XLine.kr(1800, 800, 2.5), 0.6) + (HPF.ar(PinkNoise.ar, 4000) * 0.4);
		Out.ar(0, Pan2.ar(hiss * env * amp, pan));
	}),
	// An ice cliff calving: cracks, a groan as the spire goes, and the splash as it hits (at 2 s).
	SynthDef(\calve, { |amp=0.55|
		var crack = (HPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env.perc(0.001, 0.2)))
			+ (Decay2.ar(Dust.ar(40) * EnvGen.ar(Env.perc(0.001, 0.8)), 0.001, 0.01) * WhiteNoise.ar);
		var groan = LPF.ar(Saw.ar(XLine.kr(90, 42, 1.9)), 400) * EnvGen.ar(Env.new([0, 0.6, 0], [0.5, 1.4]));
		var splash = DelayN.ar(LPF.ar(WhiteNoise.ar + BrownNoise.ar, XLine.kr(4000, 300, 2.5)) * EnvGen.ar(Env.perc(0.01, 2.5)), 2.2, 2.0);
		var boom = DelayN.ar(SinOsc.ar(XLine.kr(60, 30, 1)) * EnvGen.ar(Env.perc(0.005, 1.2)), 2.2, 2.0);
		var env = EnvGen.kr(Env.linen(0, 4.6, 0.1), doneAction: 2);
		Out.ar(0, Pan2.ar((crack * 0.5 + (groan * 0.5) + (splash * 0.9) + (boom * 0.8)) * env * amp, 0.4));
	}),
	// The ice cracking beside the road.
	SynthDef(\icecrack, { |amp=0.4|
		var env = EnvGen.kr(Env.linen(0, 1.0, 0.1), doneAction: 2);
		var pops = Decay2.ar(Dust.ar(XLine.kr(120, 8, 0.9)), 0.0005, 0.012) * (WhiteNoise.ar + SinOsc.ar(3000));
		var ring = Ringz.ar(Decay.ar(Impulse.ar(0), 0.01) * WhiteNoise.ar, [1800, 2650, 3400], 0.3).sum * 0.05;
		Out.ar(0, Pan2.ar(HPF.ar(pops + ring, 500) * env * amp, -0.4));
	}),
];
var jobs = [["event_geysers", [0.0, 0.35, 0.7, 1.05].collect { |t, i| head.(t + 0.001, \geyser, \amp, 0.32, \pan, -0.6 + (i * 0.1)) }, 4.0],
	["event_calve", [head.(0.001, \calve)], 4.9], ["event_crack", [head.(0.001, \icecrack)], 1.2]];
var run = { |i| if(i >= jobs.size) { 0.exit } { render.(defs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
run.(0);
)
