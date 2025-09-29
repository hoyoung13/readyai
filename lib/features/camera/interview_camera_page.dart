import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai/features/camera/interview_models.dart';

class InterviewCameraPage extends StatefulWidget {
  const InterviewCameraPage({required this.args, super.key});

  final InterviewCameraArgs args;

  @override
  State<InterviewCameraPage> createState() => _InterviewCameraPageState();
}

class _InterviewCameraPageState extends State<InterviewCameraPage> {
  CameraController? _controller;
  bool _isInitializing = false;
  bool _isRecording = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _permissionDenied = false;
    });

    await _controller?.dispose();
    _controller = null;

    try {
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _errorMessage = '카메라/마이크 권한이 필요합니다.';
          _permissionDenied = true;
        });
        return;
      }

      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }
      frontCamera ??= cameras.isNotEmpty ? cameras.first : null;

      if (frontCamera == null) {
        setState(() {
          _errorMessage = '사용 가능한 카메라를 찾을 수 없습니다.';
        });
        return;
      }

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
      });
    } on CameraException catch (e) {
      setState(() {
        _errorMessage = '카메라 초기화 중 오류가 발생했습니다. (${e.code})';
        _permissionDenied = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '카메라를 준비하는 중 문제가 발생했습니다.';
        _permissionDenied = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<bool> _requestPermissions() async {
    final statuses = await Future.wait([
      Permission.camera.request(),
      Permission.microphone.request(),
    ]);
    return statuses.every((status) => status.isGranted);
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || _isRecording || _isSaving) {
      return;
    }

    try {
      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
      });
    } on CameraException catch (e) {
      _showErrorSnackBar('녹화를 시작할 수 없습니다. (${e.code})');
    } catch (_) {
      _showErrorSnackBar('녹화를 시작하는 중 문제가 발생했습니다.');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_isRecording || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _isSaving = false;
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        InterviewRecordingResult(filePath: file.path),
      );
    } on CameraException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isRecording = false;
      });
      _showErrorSnackBar('녹화 파일을 저장하지 못했습니다. (${e.code})');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _isRecording = false;
      });
      _showErrorSnackBar('녹화 파일을 저장하는 중 문제가 발생했습니다.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final canRecord = controller != null &&
        controller.value.isInitialized &&
        _errorMessage == null;

    return Scaffold(
      appBar: AppBar(
        title:
            Text('${widget.args.category.title} · ${widget.args.mode.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _buildCameraPreview(controller),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isRecording
                        ? '면접이 진행 중입니다. 종료하려면 정지 버튼을 눌러 주세요.'
                        : '전면 카메라로 면접을 준비했어요. 준비가 되면 녹화를 시작해 주세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: canRecord && !_isRecording && !_isSaving
                            ? _startRecording
                            : null,
                        icon: const Icon(Icons.fiber_manual_record,
                            color: Colors.red),
                        label: const Text('녹화 시작'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: canRecord && _isRecording && !_isSaving
                            ? _stopRecording
                            : null,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.stop),
                        label: Text(_isSaving ? '저장 중...' : '녹화 종료'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraController? controller) {
    if (_errorMessage != null) {
      return _ErrorView(
        message: _errorMessage!,
        onRetry: _initializeCamera,
        showSettingsButton: _permissionDenied,
      );
    }

    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return CameraPreview(controller);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.showSettingsButton = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool showSettingsButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
          if (showSettingsButton) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: const Text('설정 열기'),
            ),
          ],
        ],
      ),
    );
  }
}
