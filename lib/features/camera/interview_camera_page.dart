import 'dart:io';
import 'dart:async';
import 'package:ai/features/camera/interview_evaluation_service.dart';
import 'package:ai/features/camera/interview_models.dart';
import 'package:ai/features/camera/interview_stt_service.dart';
import 'package:ai/features/camera/services/azure_face_service.dart';
import 'package:ai/features/camera/services/google_cloud_stt_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  late final AzureFaceAnalysisService _faceAnalysisService;
  late final List<String> _questions;
  int _currentQuestionIndex = 0;
  FlutterTts? _tts;
  String? _ttsInitializationError;
  final Set<int> _spokenQuestions = {};

  @override
  void initState() {
    super.initState();
    _evaluationService = InterviewEvaluationService();
    _faceAnalysisService = AzureFaceAnalysisService();
    _questions = List<String>.from(widget.args.questions);
    _initializeCamera();
    _initSttService();
    _initTts();

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
    _tts?.stop();
    _controller?.dispose();
    super.dispose();
  }
  Future<void> _initTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('ko-KR');
      await tts.setSpeechRate(0.92);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      if (!mounted) {
        await tts.stop();
        return;
      }
      setState(() {
        _tts = tts;
        _ttsInitializationError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ttsInitializationError = '질문 음성 안내를 사용할 수 없습니다.';
      });
    }
  }

  Future<void> _speakCurrentQuestion({bool force = false}) async {
    if (_questions.isEmpty) {
      return;
    }
    final tts = _tts;
    if (tts == null) {
      return;
    }
    final index = _currentQuestionIndex;
    if (!force && _spokenQuestions.contains(index)) {
      return;
    }
    final text = _questions[index];
    try {
      await tts.stop();
      await tts.speak(text);
      _spokenQuestions.add(index);
    } catch (_) {}
  }

  void _goToNextQuestion() {
    if (_questions.isEmpty) {
      return;
    }
    if (_currentQuestionIndex >= _questions.length - 1) {
      return;
    }
    setState(() {
      _currentQuestionIndex++;
    });
    _spokenQuestions.remove(_currentQuestionIndex);
    unawaited(_speakCurrentQuestion(force: true));
  }

  void _goToPreviousQuestion() {
    if (_questions.isEmpty) {
      return;
    }
    if (_currentQuestionIndex <= 0) {
      return;
    }
    setState(() {
      _currentQuestionIndex--;
    });
    _spokenQuestions.remove(_currentQuestionIndex);
    unawaited(_speakCurrentQuestion(force: true));
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
      _spokenQuestions.remove(_currentQuestionIndex);
      unawaited(_speakCurrentQuestion());
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
      FaceAnalysisResult? faceAnalysis;
      String? faceAnalysisError;
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

      // 3) 얼굴 시선/표정 분석
      setState(() {
        _savingStatusMessage = '시선과 표정을 분석하는 중...';
      });

      try {
        faceAnalysis = await _faceAnalysisService.analyzeVideo(recordedFilePath);
      } on FaceAnalysisException catch (e) {
        faceAnalysisError = e.message;
      } catch (e, st) {
        faceAnalysisError = '영상 분석 중 알 수 없는 오류가 발생했습니다.';
        print('Face analysis error: $e\n$st');
      }

      if (!mounted) return;

      // 4) 평가
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
          faceAnalysis: faceAnalysis,
          faceAnalysisError: faceAnalysisError,
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
child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCameraPreview(controller),
                    if (_questions.isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _buildQuestionOverlay(context),
                      ),
                  ],
                ),
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
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
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
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: canRecord &&
                                  _isRecording &&
                                  !_isSaving &&
                                  !_isTranscribing
                              ? _stopRecording
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSaving)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.stop),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isSaving
                                      ? (_savingStatusMessage ?? '저장 중...')
                                      : '녹화 종료',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
   Widget _buildQuestionOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final total = _questions.length;
    final question = _questions[_currentQuestionIndex];
    final canGoPrev = _currentQuestionIndex > 0;
    final canGoNext = _currentQuestionIndex < total - 1;

    return _QuestionOverlay(
      question: question,
      index: _currentQuestionIndex,
      total: total,
      onReplay: _tts != null ? () => _speakCurrentQuestion(force: true) : null,
      onNext: canGoNext ? _goToNextQuestion : null,
      onPrevious: canGoPrev ? _goToPreviousQuestion : null,
      ttsError: _ttsInitializationError,
      theme: theme,
    );
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
class _QuestionOverlay extends StatelessWidget {
  const _QuestionOverlay({
    required this.question,
    required this.index,
    required this.total,
    required this.theme,
    this.onReplay,
    this.onNext,
    this.onPrevious,
    this.ttsError,
  });

  final String question;
  final int index;
  final int total;
  final VoidCallback? onReplay;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final String? ttsError;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: Colors.white70,
      fontWeight: FontWeight.w600,
    );
    final questionStyle = theme.textTheme.titleMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      height: 1.4,
    );

    final buttons = <Widget>[
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        ),
        onPressed: onReplay,
        icon: const Icon(Icons.volume_up_outlined),
        label: const Text('질문 다시 듣기'),
      ),
      if (onPrevious != null)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
          ),
          onPressed: onPrevious,
          icon: const Icon(Icons.navigate_before),
          label: const Text('이전 질문'),
        ),
      if (onNext != null)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
          onPressed: onNext,
          icon: const Icon(Icons.navigate_next),
          label: const Text('다음 질문'),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('질문 ${index + 1}/$total', style: labelStyle),
          const SizedBox(height: 8),
          Text(question, style: questionStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buttons,
          ),
          if (ttsError != null) ...[
            const SizedBox(height: 8),
            Text(
              ttsError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade200,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
