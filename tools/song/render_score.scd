// Renders one score to two stems, offline (no audio device, no running server):
//   <outDir>/backing.wav   everything except the melody
//   <outDir>/lead.wav      the melody alone, which the game opens only while the player hits it
//
// Used for every authored song and for MIDI files imported in the game.
// Usage: sclang render_score.scd <score.scd> <outDir> <synthDir>
//   score.scd defines ~duration, ~backingRoom, ~leadRoom, ~backing, ~lead
//   (written by tools/song/songlib.py); events are [time, instrument, midi, seconds, amp, pan].
(
var scorePath = thisProcess.argv[0];
var outDir = thisProcess.argv[1].withoutTrailingSlash ++ "/";
var synthDir = thisProcess.argv[2];
var options = ServerOptions.new.numOutputBusChannels_(2).numWireBufs_(512).maxNodes_(8192).memSize_(65536);
var known, toMsgs, render, room;

~defs = [];
PathName(synthDir).files.select { |f| f.extension == "scd" }.sort { |a, b| a.fileName < b.fileName }.do { |f| f.fullPath.load };
room = SynthDef(\room, { |mix=0.22, size=0.6, slap=0|
	var dry = In.ar(0, 2);
	var wet = FreeVerb2.ar(dry[0], dry[1], mix, size, 0.45);
	var delayed = CombL.ar(dry, 0.3, 0.14, 0.45) * slap;
	// Limiter delays its output by twice this lookahead. At 0.01 the stems sat
	// 20 ms behind the chart, so keep it tiny: 4 ms is well under what a player can feel.
	ReplaceOut.ar(0, Limiter.ar(wet + delayed, 0.95, 0.002));
});
~defs = ~defs ++ [room];
known = ~defs.collect(_.name).collect(_.asSymbol).asSet;
scorePath.load;

toMsgs = { |events|
	events.collect { |e|
		var inst = e[1].asSymbol;
		if(known.includes(inst).not) { ("unknown instrument " ++ inst ++ ", using pick").postln; inst = \pick };
		[e[0], [\s_new, inst, -1, 0, 0, \midi, e[2], \sus, e[3], \amp, e[4], \pan, e[5] ? 0]]
	};
};

render = { |name, events, roomArgs, next|
	var list = ~defs.collect { |d| [0.0, [\d_recv, d.asBytes]] }
		++ [[0.0005, [\s_new, \room, -1, 1, 0, \mix, roomArgs[0], \size, roomArgs[1], \slap, roomArgs[2]]]]
		++ toMsgs.(events)
		++ [[~duration, [\c_set, 0, 0]]];
	list = list.sort { |a, b| a[0] < b[0] };
	Score(list).recordNRT(outDir ++ name ++ ".osc", outDir ++ name ++ ".wav", sampleRate: 44100,
		headerFormat: "WAV", sampleFormat: "int16", options: options, duration: ~duration,
		action: { File.delete(outDir ++ name ++ ".osc"); ("RENDERED " ++ outDir ++ name ++ ".wav").postln; next.value });
};

File.mkdir(outDir);
render.("backing", ~backing, ~backingRoom, {
	render.("lead", ~lead, ~leadRoom, { 0.exit });
});
)
