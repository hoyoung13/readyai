import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class InterviewVideoPageArgs {
  const InterviewVideoPageArgs({
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;
}

class InterviewVideoPage extends StatefulWidget {
  const InterviewVideoPage({super.key, required this.args});

  final InterviewVideoPageArgs args;

  @override
  State<InterviewVideoPage> createState() => _InterviewVideoPageState();
}

class _InterviewVideoPageState extends State<InterviewVideoPage> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.args.videoUrl));
      await controller.initialize();
      controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _isInitializing = false;
        _errorMessage = '영상을 불러오지 못했습니다. 다시 시도해 주세요.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isInitializing
              ? const CircularProgressIndicator()
              : _errorMessage != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeController,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    )
                  : controller != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: controller.value.aspectRatio == 0
                                  ? 16 / 9
                                  : controller.value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (!controller.value.isPlaying) {
                                      controller.play();
                                    } else {
                                      controller.pause();
                                    }
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    controller.value.isPlaying
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                  ),
                                  label: Text(
                                    controller.value.isPlaying ? '일시정지' : '재생',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    controller.seekTo(Duration.zero);
                                    controller.play();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.replay),
                                  label: const Text('처음부터'),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
