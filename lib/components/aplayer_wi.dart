import 'dart:async';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import 'package:audioplayers/audioplayers.dart';
import '/utils/file_tra.dart';
import '/utils/sugar.dart' as sugar;

final GlobalKey<_APlayerWiState> g_widget_key = GlobalKey<_APlayerWiState>();
final g_sys_player = AudioPlayer(playerId:"asing");

class APlayerWi extends material.StatefulWidget {
  final AudioPlayer player;
  final TraData data;
  const APlayerWi({
    required this.player,
    required this.data,
    super.key,
  });

  @override
  material.State<material.StatefulWidget> createState() {
    return _APlayerWiState();
  }
}

class _APlayerWiState extends material.State<APlayerWi> {
  PlayerState? _playerState;
  Duration? _duration;
  Duration? _position;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  bool get _isPaused => _playerState == PlayerState.paused;

  String get _durationText => sugar.strFromDuration(_duration);

  String get _positionText => sugar.strFromDuration(_position);

  AudioPlayer get player => widget.player;

  @override
  void initState() {
    super.initState();
    // Use initial values from player
    _playerState = player.state;
    player.getDuration().then(
          (value) => setState(() {
            _duration = value;
          }),
        );
    player.getCurrentPosition().then(
          (value) => setState(() {
            _position = value;
          }),
        );
    _initStreams();
    doPlay();
  }

  @override
  void setState(VoidCallback fn) {
    // Subscriptions only can be closed asynchronously,
    // therefore events can occur after widget has been disposed.
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
    doStop();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiTheme = Theme.of(context);
    final uiFgColor = uiTheme.colorScheme.foreground;
    material.IconButton? multi_button = null;
    if(!_isPlaying){
      multi_button = material.IconButton(
        key: const Key('play_button'),
        onPressed: doPlay,
        iconSize: 48.0,
        icon: const Icon(Icons.play_arrow),
        color: uiFgColor,
      );
    }else{
      multi_button = material.IconButton(
        key: const Key('pause_button'),
        onPressed: doPause,
        iconSize: 48.0,
        icon: const Icon(Icons.pause),
        color: uiFgColor,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Divider(thickness:2),
        Gap(5),
        multi_button,
        // Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     material.IconButton(
        //       key: const Key('play_button'),
        //       onPressed: _isPlaying ? null : doPlay,
        //       iconSize: 48.0,
        //       icon: const Icon(Icons.play_arrow),
        //       color: uiFgColor,
        //     ),
        //     material.IconButton(
        //       key: const Key('pause_button'),
        //       onPressed: _isPlaying ? doPause : null,
        //       iconSize: 48.0,
        //       icon: const Icon(Icons.pause),
        //       color: uiFgColor,
        //     ),
        //     material.IconButton(
        //       key: const Key('stop_button'),
        //       onPressed: _isPlaying || _isPaused ? doStop : null,
        //       iconSize: 48.0,
        //       icon: const Icon(Icons.stop),
        //       color: uiFgColor,
        //     ),
        //   ],
        // ),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: material.Slider(
                activeColor: uiFgColor,
                onChanged: (value) {
                  final duration = _duration;
                  if (duration != null) {
                    final position = value * duration.inMilliseconds;
                    player.seek(Duration(milliseconds: position.round()));
                  }
                },
                value: (_position != null &&
                        _duration != null &&
                        _position!.inMilliseconds > 0 &&
                        _position!.inMilliseconds < _duration!.inMilliseconds)
                    ? _position!.inMilliseconds / _duration!.inMilliseconds
                    : 0.0,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right:16.0),
              child: Text('$_positionText / $_durationText',
                style: const TextStyle(fontSize: 16.0),
              ),
            ),
          ]
        ),
        Gap(2),
      ],
    );
  }

  void _initStreams() {
    _durationSubscription = player.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _positionSubscription = player.onPositionChanged.listen(
      (p) => setState(() => _position = p),
    );

    _playerCompleteSubscription = player.onPlayerComplete.listen((event) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    });

    _playerStateChangeSubscription = player.onPlayerStateChanged.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
  }

  Future<void> doPlay() async {
    if(_playerState != PlayerState.paused){
      if(widget.data.audioPath.isNotEmpty){
        await widget.player.play(DeviceFileSource(widget.data.audioPath));
      }
    }else{
      await player.resume();
    }
    setState(() => _playerState = PlayerState.playing);
  }

  Future<void> doPause() async {
    await player.pause();
    setState(() => _playerState = PlayerState.paused);
  }

  Future<void> doStop() async {
    await player.stop();
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  }
}