// Neon Sprawl: short sound effects for the world's answers to the player (2026-11-11), mixed under the
// music by ThemeWorld.event_sound(). Rendered offline, one WAV per job, into the region's audio folder:
//   sclang tools/themes/neon/events.scd game/assets/themes/neon/audio
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
	// One firework: a thump, the burst's crack, and its stars fizzing out.
	SynthDef(\pop, { |amp=0.4, pan=0|
		var thump = SinOsc.ar(XLine.kr(150, 48, 0.18)) * EnvGen.ar(Env.perc(0.002, 0.3));
		var crack = HPF.ar(WhiteNoise.ar, 800) * EnvGen.ar(Env.perc(0.001, 0.09));
		var fizz = HPF.ar(Dust.ar(XLine.kr(380, 15, 1.4)), 2000) * EnvGen.ar(Env.perc(0.05, 1.5)) * 2;
		var env = EnvGen.kr(Env.linen(0, 1.6, 0.05), doneAction: 2);
		Out.ar(0, Pan2.ar((thump * 0.8 + (crack * 0.5) + (fizz * 0.4)) * env * amp, pan));
	}),
	// A glitch: stuttering, bit-crushed tones.
	SynthDef(\glitch, { |amp=0.28|
		var env = EnvGen.kr(Env.linen(0.005, 0.7, 0.1), doneAction: 2);
		var bits = Latch.ar(SinOsc.ar(LFNoise0.kr(20).range(200, 2000)), Impulse.ar(LFNoise0.kr(15).range(800, 6000)));
		var gate = LFPulse.kr(LFNoise0.kr(12).range(6, 30), 0, 0.6);
		Out.ar(0, Pan2.ar(bits * gate * env * amp, 0.3));
	}),
];
var shells = [[1.15, 0.5], [1.55, -0.4], [1.9, 0.6], [2.3, 0.3], [2.65, -0.5], [3.05, 0.55]];
var jobs = [["event_fireworks", shells.collect { |s| head.(s[0], \pop, \pan, s[1]) }, 4.8],
	["event_glitch", [head.(0.001, \glitch)], 0.9]];
var run = { |i| if(i >= jobs.size) { 0.exit } { render.(defs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
run.(0);
)
