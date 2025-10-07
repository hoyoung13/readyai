import 'dart:io';
import 'package:ai/features/camera/interview_evaluation_service.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_stt_service.dart';
import 'package:ai/features/camera/services/google_cloud_stt_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isTranscribing = false;

  String? _savingStatusMessage;
  String? _errorMessage;
  bool _permissionDenied = false;
  InterviewSttService? _sttService;
  bool _isSttInitializing = false;
  String? _sttInitializationError;
  late final InterviewEvaluationService _evaluationService;

  @override
  void initState() {
    super.initState();
    _evaluationService = InterviewEvaluationService();
    _initializeCamera();
    _initSttService();
  }

  Future<void> _initSttService() async {
    setState(() {
      _isSttInitializing = true;
      _sttInitializationError = null;
    });

    try {
      String? serviceAccountJson;
      try {
        serviceAccountJson = await rootBundle.loadString(
          'assets/keys/service-account.json',
        );
        if (serviceAccountJson.trim().isEmpty) {
          serviceAccountJson = null;
        }
      } on FlutterError {
        serviceAccountJson = null;
      }

      final googleService = GoogleCloudSttService(
        credentialsProvider: GoogleCloudCredentialsProvider(
          serviceAccountJson: serviceAccountJson,
          allowApplicationDefault: !Platform.isAndroid,
        ),
        languageCode: 'ko-KR',
        enableAutomaticPunctuation: true,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _sttService = InterviewSttService(
          googleCloudSttService: googleService,
        );
        _isSttInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSttInitializing = false;
        _sttInitializationError = '음성 인식 서비스를 초기화할 수 없습니다. 다시 시도해 주세요.';
      });
      // ignore: avoid_print
      print('Failed to initialize STT service: $error');
    }
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

  Future<bool> _waitFileReady(
    String path, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final f = File(path);
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0) return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return false;
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
    if (controller == null || _isRecording || _isSaving) return;

    try {
      if (!controller.value.isInitialized) {
        _showErrorSnackBar('카메라가 아직 준비되지 않았습니다.');
        return;
      }
      if (controller.value.isRecordingVideo) {
        _showErrorSnackBar('이미 녹화 중입니다.');
        return;
      }

      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _savingStatusMessage = null;
      });
    } on CameraException catch (e, st) {
      _showErrorSnackBar(
        '녹화를 시작할 수 없습니다. (${e.code}) ${e.description ?? ""}'.trim(),
      );
      // ignore: avoid_print
      print('CameraException at start: ${e.code} ${e.description}\n$st');
    } catch (e, st) {
      _showErrorSnackBar('녹화를 시작하는 중 문제가 발생했습니다.');
      // ignore: avoid_print
      print('Unexpected error at start: $e\n$st');
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || _isSaving) return;

    // 실제 녹화 중인지 안전 체크 (내 상태변수 대신 컨트롤러 상태 기준)
    if (!controller.value.isRecordingVideo) {
      _showErrorSnackBar('이미 녹화가 종료되었습니다.');
      setState(() {
        _isRecording = false;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _isTranscribing = false;
      _savingStatusMessage = '녹화 파일을 정리하는 중...';
    });

    try {
      // 1) 녹화 종료
      final XFile file = await controller.stopVideoRecording();
      final recordedFilePath = file.path;

      final ok = await _waitFileReady(recordedFilePath);
      if (!ok) {
        setState(() {
          _isSaving = false;
          _isRecording = false;
          _savingStatusMessage = null;
        });
        _showErrorSnackBar('녹화 파일이 준비되지 않았습니다.');
        return;
      }
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _savingStatusMessage = '전사를 준비하는 중...';
      });

      // 2) 전사
      String? transcript;
      double? transcriptConfidence;
      String? transcriptionError;
      try {
        final transcription = await _transcribeRecording(recordedFilePath);
        transcript = transcription.text;
        transcriptConfidence = transcription.confidence;
      } on InterviewSttException catch (error) {
        transcriptionError = error.message;
      } catch (e, st) {
        transcriptionError = 'STT 실패: ${e.toString()}';
        // 개발 로그
        // ignore: avoid_print
        print('STT unexpected error: $e\n$st');
      }

      if (!mounted) return;

      if (transcriptionError != null) {
        setState(() {
          _isSaving = false;
          _savingStatusMessage = null;
        });
        _showErrorSnackBar(transcriptionError);

        // pop 이후에는 setState 호출 금지
        Navigator.of(context).pop(
          InterviewRecordingResult(
            filePath: recordedFilePath,
            transcript: transcript,
            transcriptConfidence: transcriptConfidence,
            transcriptionError: transcriptionError,
          ),
        );
        return;
      }

      // 3) 평가
      setState(() {
        _savingStatusMessage = '답변을 평가하는 중...';
      });

      InterviewScore? score;
      String? evaluationError;
      try {
        score = await _evaluationService.evaluateInterview(
          transcript: transcript ?? '',
          args: widget.args,
        );
      } on InterviewEvaluationException catch (e) {
        evaluationError = e.message;
      } catch (e, st) {
        evaluationError = '답변을 평가하는 중 문제가 발생했습니다.';
        // ignore: avoid_print
        print('Evaluation error: $e\n$st');
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _savingStatusMessage = null;
      });

      if (evaluationError != null) {
        _showErrorSnackBar(evaluationError);
      }

      // pop 이후에는 더 이상 setState 호출하지 않기
      Navigator.of(context).pop(
        InterviewRecordingResult(
          filePath: recordedFilePath,
          transcript: transcript,
          transcriptConfidence: transcriptConfidence,
          score: score,
          evaluationError: evaluationError,
        ),
      );
    } on CameraException catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isRecording = false;
        _savingStatusMessage = null;
      });
      // 오류 원인을 그대로 보여주면 원인 파악이 쉬움
      _showErrorSnackBar(
        '녹화를 종료/저장할 수 없습니다. (${e.code}) ${e.description ?? ""}'.trim(),
      );
      // ignore: avoid_print
      print('CameraException at stop: ${e.code} ${e.description}\n$st');
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isRecording = false;
        _savingStatusMessage = null;
      });
      _showErrorSnackBar('녹화 파일을 저장하는 중 문제가 발생했습니다.'); // 기존 메시지
      // 개발용 로그
      // ignore: avoid_print
      print('Unexpected error at stop: $e\n$st');
    }
  }

  Future<InterviewTranscription> _transcribeRecording(String filePath) async {
    if (!mounted) {
      throw InterviewSttException('화면이 닫혀 전사를 중단했습니다.');
    }
    final sttService = _sttService;
    if (sttService == null) {
      throw InterviewSttException('음성 인식 서비스가 아직 준비되지 않았습니다.');
    }
    setState(() {
      _isTranscribing = true;
    });
    try {
      return await sttService.transcribeVideo(
        videoPath: filePath,
        onProgress: (message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _savingStatusMessage = message;
          });
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
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
        _errorMessage == null &&
        !_isSttInitializing &&
        _sttService != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.args.category.title} · ${widget.args.mode.title}',
        ),
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
                    _sttInitializationError != null
                        ? _sttInitializationError!
                        : _isRecording
                            ? '면접이 진행 중입니다. 종료하려면 정지 버튼을 눌러 주세요.'
                            : _isSttInitializing
                                ? '음성 인식 서비스를 준비하고 있어요. 잠시만 기다려 주세요.'
                                : '전면 카메라로 면접을 준비했어요. 준비가 되면 녹화를 시작해 주세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: canRecord &&
                                !_isRecording &&
                                !_isSaving &&
                                !_isTranscribing
                            ? _startRecording
                            : null,
                        icon: const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.red,
                        ),
                        label: const Text('녹화 시작'),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: canRecord &&
                                _isRecording &&
                                !_isSaving &&
                                !_isTranscribing
                            ? _stopRecording
                            : null,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.stop),
                        label: Text(
                          _isSaving
                              ? (_savingStatusMessage ?? '저장 중...')
                              : '녹화 종료',
                        ),
                      ),
                    ],
                  ),
                  if (_isSaving && _savingStatusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _savingStatusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSaving || _isTranscribing
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
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
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
