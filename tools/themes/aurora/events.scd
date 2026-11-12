// Ring Road: short sound effects for the world's answers to the player (2026-11-11), mixed under the
// music by ThemeWorld.event_sound(). Rendered offline, one WAV per job, into the region's audio folder:
//   sclang tools/themes/aurora/events.scd game/assets/themes/aurora/audio
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
	// A ship leaving: a soft undocking thrum, then its engines lighting and the whoosh of it going.
	SynthDef(\shiplaunch, { |amp=0.4|
		var env = EnvGen.kr(Env.new([0, 0.3, 1, 0], [1.25, 0.3, 3.2], [1, 2, -3]), doneAction: 2);
		var tone = (Saw.ar(XLine.kr(80, 220, 4.5) * [1, 1.005]).sum * 0.3) + SinOsc.ar(XLine.kr(55, 110, 4.5));
		var whoosh = BPF.ar(PinkNoise.ar, XLine.kr(400, 3000, 4.5), 0.8) * 1.5;
		Out.ar(0, Pan2.ar(LPF.ar(tone + whoosh, 4000) * env * amp, Line.kr(0.4, 0.1, 4.5)));
	}),
	// The station's lights flickering: a buzzing supply cutting in and out, with sparks.
	SynthDef(\flicker, { |amp=0.25|
		var env = EnvGen.kr(Env.linen(0.01, 0.8, 0.2), doneAction: 2);
		var buzz = LPF.ar(Pulse.ar(100, 0.3) + Pulse.ar(150.5, 0.2), 1500) * LFPulse.kr(LFNoise0.kr(14).range(4, 18), 0, 0.5);
		var spark = HPF.ar(Dust.ar(30), 3000) * 3;
		Out.ar(0, Pan2.ar((buzz * 0.5 + (spark * 0.3)) * env * amp, -0.4));
	}),
];
var jobs = [["event_launch", [head.(0.001, \shiplaunch)], 5.0], ["event_flicker", [head.(0.001, \flicker)], 1.2]];
var run = { |i| if(i >= jobs.size) { 0.exit } { render.(defs, jobs[i][1], jobs[i][2], dir ++ jobs[i][0] ++ ".wav", { run.(i + 1) }) } };
run.(0);
)
