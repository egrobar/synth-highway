// Io Burn: short sound effects for the world's answers to the player (2026-11-11), mixed under the
// music by ThemeWorld.event_sound(). Rendered offline, one WAV per job, into the region's audio folder:
//   sclang tools/themes/mesa/events.scd game/assets/themes/mesa/audio
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
	// The volcano erupting: a deep boom, a long rumble falling away, rock crackling in it.
	SynthDef(\erupt, { |amp=0.6|
		var boom = SinOsc.ar(XLine.kr(70, 30, 1.4)) * EnvGen.ar(Env.perc(0.005, 1.8));
		var rumble = LPF.ar(BrownNoise.ar, XLine.kr(900, 110, 3.6)) * EnvGen.ar(Env.perc(0.03, 3.8, 1, -3));
		var crk = HPF.ar(Decay2.ar(Dust.ar(XLine.kr(70, 4, 3.2)), 0.001, 0.02) * WhiteNoise.ar, 1500) * EnvGen.ar(Env.perc(0.1, 3.2));
		var env = EnvGen.kr(Env.linen(0, 4.2, 0.2), doneAction: 2);
		Out.ar(0, Limiter.ar(Pan2.ar((boom * 0.9 + (rumble * 1.4) + (crk * 0.4)) * env * amp, 0.35), 0.9));
	}),
	// Choking: a smothered cough of gas and a hiss dying away.
	SynthDef(\choke, { |amp=0.4|
		var cough = LPF.ar(BrownNoise.ar + Saw.ar(36), 380) * EnvGen.ar(Env.perc(0.02, 0.5));
		var hiss = HPF.ar(PinkNoise.ar, 2500) * EnvGen.ar(Env.perc(0.1, 1.4, 1, -2)) * 0.25;
		var env = EnvGen.kr(Env.linen(0, 1.6, 0.1), doneAction: 2);
		Out.ar(0, Pan2.ar((cough + hiss) * env * amp, 0.2));
	}),
];
var jobs = [["event_erupt", [head.(0.001, \erupt)], 4.6], ["event_choke", [head.(0.001, \choke)], 1.8]];
var run = { |i| if(i >= jobs.size) { 0.exit } { render.(defs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
run.(0);
)
