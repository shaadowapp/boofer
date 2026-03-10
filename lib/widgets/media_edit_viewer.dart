import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Result returned when the user presses "Send"
class MediaEditResult {
  final File file;
  final bool isVideo;
  final Duration? trimStart;
  final Duration? trimEnd;

  const MediaEditResult({
    required this.file,
    required this.isVideo,
    this.trimStart,
    this.trimEnd,
  });
}

/// Full-screen media editor shown immediately after picking a file.
/// - Images: displays the image, allows basic quality selection, then compress → send
/// - Videos: shows video with duration trimmer sliders, then send
class MediaEditViewer extends StatefulWidget {
  final File file;
  final bool isVideo;
  final String recipientName;

  const MediaEditViewer({
    super.key,
    required this.file,
    required this.isVideo,
    required this.recipientName,
  });

  @override
  State<MediaEditViewer> createState() => _MediaEditViewerState();
}

class _MediaEditViewerState extends State<MediaEditViewer> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  final bool _isProcessing = false;
  bool _isEditing = false;
  File? _editedFile;

  // Video trim state
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = const Duration(seconds: 999);
  Duration _videoDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(widget.file);
    await _videoController!.initialize();
    if (mounted) {
      setState(() {
        _videoInitialized = true;
        _videoDuration = _videoController!.value.duration;
        _trimEnd = _videoDuration;
      });
      _videoController!.play();
      _videoController!.setLooping(true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    HapticFeedback.mediumImpact();

    final result = MediaEditResult(
      file: _editedFile ?? widget.file,
      isVideo: widget.isVideo,
      trimStart: widget.isVideo ? _trimStart : null,
      trimEnd: widget.isVideo ? _trimEnd : null,
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _openImageEditor() async {
    setState(() => _isEditing = true);

    // Use the Navigator from the current context before the async gap
    final navigator = Navigator.of(context);

    try {
      final File? result = await navigator.push<File>(
        MaterialPageRoute(
          builder: (_) => ProImageEditor.file(
            _editedFile ?? widget.file,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List bytes) async {
                try {
                  final tempDir = await getTemporaryDirectory();
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final fileName = 'edited_$timestamp.jpg';
                  final file = File(p.join(tempDir.path, fileName));
                  await file.writeAsBytes(bytes);

                  // Return the file back to the viewer immediately
                  if (navigator.canPop()) {
                    navigator.pop(file);
                  }
                } catch (e) {
                  debugPrint('Error saving image: $e');
                  if (navigator.canPop()) navigator.pop();
                }
              },
              onCloseEditor: (dynamic mode) {
                if (navigator.canPop()) navigator.pop();
              },
            ),
            configs: const ProImageEditorConfigs(
              designMode: ImageEditorDesignMode.material,
              imageGeneration: ImageGenerationConfigs(
                outputFormat: OutputFormat.jpg,
              ),
            ),
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _editedFile = result;
          _isEditing = false;
        });

        // Automatically trigger send after editing is complete
        _onSend();
      } else if (mounted) {
        setState(() => _isEditing = false);
      }
    } catch (e) {
      debugPrint('Error launching editor: $e');
      if (mounted) setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // ── Media Preview (fills screen) ──────────────────────────
            Positioned.fill(
              child: _isEditing
                  ? Container(color: Colors.black)
                  : (widget.isVideo
                      ? _buildVideoPreview()
                      : _buildImagePreview()),
            ),

            // ── Top Bar ───────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 4,
                  right: 16,
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                    const Spacer(),
                    if (!widget.isVideo)
                      IconButton(
                        icon:
                            const Icon(Icons.edit_rounded, color: Colors.white),
                        tooltip: 'Edit Image',
                        onPressed: _openImageEditor,
                      ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Send to',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          widget.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Controls + Send ─────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isVideo && _videoInitialized)
                      _buildVideoTrimmer(),
                    const SizedBox(height: 16),
                    _buildSendRow(),
                  ],
                ),
              ),
            ),

            // ── Processing Overlay ─────────────────────────────────────
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                        SizedBox(height: 16),
                        Text(
                          'Processing…',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          _editedFile ?? widget.file,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_videoInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _videoController!.value.isPlaying
              ? _videoController!.pause()
              : _videoController!.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          if (!_videoController!.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 48),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoTrimmer() {
    final totalSecs = _videoDuration.inSeconds.toDouble();
    if (totalSecs <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trim: ${_formatDuration(_trimStart)} – ${_formatDuration(_trimEnd)}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              'Duration: ${_formatDuration(_trimEnd - _trimStart)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Start slider
        _TrimSlider(
          label: 'Start',
          value: _trimStart.inSeconds.toDouble(),
          max: _trimEnd.inSeconds.toDouble() - 1,
          onChanged: (v) {
            setState(() => _trimStart = Duration(seconds: v.round()));
            _videoController?.seekTo(_trimStart);
          },
        ),
        const SizedBox(height: 4),
        // End slider
        _TrimSlider(
          label: 'End',
          value: _trimEnd.inSeconds.toDouble(),
          min: _trimStart.inSeconds.toDouble() + 1,
          max: totalSecs,
          onChanged: (v) {
            setState(() => _trimEnd = Duration(seconds: v.round()));
          },
        ),
      ],
    );
  }

  Widget _buildSendRow() {
    return Row(
      children: [
        // File size hint
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<int>(
                future: widget.file.length(),
                builder: (context, snap) {
                  final size = snap.data ?? 0;
                  return Text(
                    _formatSize(size),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  );
                },
              ),
              Text(
                widget.isVideo
                    ? 'Video'
                    : (_editedFile != null ? 'Image (Edited)' : 'Image'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        // Send button
        GestureDetector(
          onTap: _isProcessing ? null : _onSend,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0072FF).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Send',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _TrimSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _TrimSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
        overlayColor: Colors.white12,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}
