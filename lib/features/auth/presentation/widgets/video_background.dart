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
        } else {
           _controller.play();
        }
      });
      
    _controller.addListener(() {
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
