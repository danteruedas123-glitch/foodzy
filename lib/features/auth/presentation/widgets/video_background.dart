import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatefulWidget {
  final String assetPath;
  final VoidCallback? onVideoFinished;
  final Duration? stopAtDuration;
  final Duration? startAtDuration;
  final bool loop;
  final Duration? loopStart;
  final Duration? loopEnd;
  
  const VideoBackground({
    super.key, 
    required this.assetPath, 
    this.onVideoFinished, 
    this.stopAtDuration,
    this.startAtDuration,
    this.loop = false,
    this.loopStart,
    this.loopEnd,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        // Si la persona ya salió de la pantalla, no hay nada que mostrar.
        if (!mounted) return;
        setState(() {});
        _controller.setVolume(0);
        // Si usamos loop personalizado, desactivamos el loop nativo
        _controller.setLooping(widget.loop && widget.loopEnd == null); 
        
        if (widget.startAtDuration != null) {
          _controller.seekTo(widget.startAtDuration!);
        }
        
        if (widget.startAtDuration != null && widget.startAtDuration == widget.stopAtDuration) {
           _controller.pause();
           _hasFinished = true;
           widget.onVideoFinished?.call();
        } else if (_tapado) {
           _pausadoPorTapado = true; // arrancará al volver a verse
        } else {
           _controller.play();
        }
      }).catchError((Object _) {
        // Si el video no se puede reproducir, no bloqueamos la pantalla.
        if (!_hasFinished) {
          _hasFinished = true;
          widget.onVideoFinished?.call();
        }
      });

    _controller.addListener(() {
      if (_controller.value.hasError && !_hasFinished) {
        _hasFinished = true;
        widget.onVideoFinished?.call();
        return;
      }
      if (!_controller.value.isInitialized) return;
      
      final currentPosition = _controller.value.position;
      
      // Lógica para detenerse de una vez
      if (widget.stopAtDuration != null && !_hasFinished) {
        if (currentPosition >= widget.stopAtDuration!) {
          _hasFinished = true;
          _controller.pause();
          widget.onVideoFinished?.call();
          return;
        }
      }
      
      // Lógica para bucle personalizado
      if (widget.loop) {
        final endTarget = widget.loopEnd ?? _controller.value.duration;
        if (currentPosition >= endTarget) {
          final startTarget = widget.loopStart ?? Duration.zero;
          _controller.seekTo(startTarget);
          _controller.play();
        }
      } else if (!_hasFinished && currentPosition >= _controller.value.duration) {
        _hasFinished = true;
        widget.onVideoFinished?.call();
      }
    });
  }

  bool _tapado = false;
  bool _pausadoPorTapado = false;

  /// Cuando otra pantalla tapa esta (por ejemplo, el registro encima del
  /// login), el video se pausa: así no hay dos videos decodificándose a la
  /// vez. Al volver, sigue donde iba.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tapado = !TickerMode.valuesOf(context).enabled;
    final v = _controller.value;
    if (_tapado && v.isInitialized && v.isPlaying) {
      _pausadoPorTapado = true;
      _controller.pause();
    } else if (!_tapado && _pausadoPorTapado) {
      _pausadoPorTapado = false;
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}
