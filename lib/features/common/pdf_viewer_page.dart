import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:ai/features/tabs/tabs_shared.dart';

class PdfViewerArgs {
  const PdfViewerArgs({required this.title, required this.pdfUrl});

  final String title;
  final String pdfUrl;
}

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({required this.title, required this.pdfUrl, super.key});

  final String title;
  final String pdfUrl;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfControllerPinch? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(widget.pdfUrl);
      final response = await http.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('파일을 불러오지 못했습니다.');
      }

      final document = PdfDocument.openData(response.bodyBytes);
      _controller?.dispose();
      _controller = PdfControllerPinch(document: document);
    } catch (_) {
      _errorMessage = '파일을 불러오지 못했습니다';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? '파일을 불러오지 못했습니다',
              style: const TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadPdf,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return PdfViewPinch(
      controller: _controller!,
      backgroundDecoration: const BoxDecoration(color: Colors.white),
    );
  }
}
