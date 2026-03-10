import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/message_model.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

/// Media viewer for displaying images and videos in full screen with premium feel
class MediaViewer extends StatefulWidget {
  final Message message;
  final String currentUserId;
  final List<Message> messages;
  final int initialIndex;

  const MediaViewer({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.messages,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late List<Message> _mediaMessages;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _showControls = true;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _mediaMessages = widget.messages.where((m) {
      return m.type == MessageType.image || m.type == MessageType.video;
    }).toList();
    _pageController = PageController(initialPage: _currentIndex);

    // Set status bar to transparent/dark for full screen feel
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _loadCurrentMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMedia() async {
    final message = _mediaMessages[_currentIndex];
    final mediaData = message.metadata?['media'] as Map<String, dynamic>?;
    String? localPath = mediaData?['local_media_path'] as String?;

    if (localPath == null) {
      setState(() {
        _isLoading = true;
      });

      // Try to download and decrypt the media
      try {
        debugPrint('⬇️ MediaViewer: Local path missing, starting download...');
        final downloadedPath =
            await SupabaseService.instance.decryptMediaMessage(
          message,
          widget.currentUserId,
        );

        if (downloadedPath != null && mounted) {
          debugPrint('✅ MediaViewer: Download complete: $downloadedPath');
          setState(() {
            localPath = downloadedPath;
            // Update the message object in our list so the gallery builder sees it
            final updatedMetadata =
                Map<String, dynamic>.from(message.metadata ?? {});
            final media = Map<String, dynamic>.from(
                updatedMetadata['media'] as Map? ?? {});
            media['local_media_path'] = downloadedPath;
            updatedMetadata['media'] = media;
            _mediaMessages[_currentIndex] =
                message.copyWith(metadata: updatedMetadata);
          });
        }
      } catch (e) {
        debugPrint('❌ MediaViewer: Download failed: $e');
      }
    }

    if (message.type == MessageType.video && localPath != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(localPath!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _videoController?.play();
            _videoController?.setLooping(true);
          }
        });
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _loadCurrentMedia();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentMessage = _mediaMessages[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTap: _toggleControls,
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.delta.dy;
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset.abs() > 150) {
              Navigator.pop(context);
            } else {
              setState(() {
                _dragOffset = 0;
              });
            }
          },
          child: Stack(
            children: [
              // Main Content (Gallery/Video)
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Opacity(
                  opacity: (1 - (_dragOffset.abs() / 500)).clamp(0.0, 1.0),
                  child: PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      final message = _mediaMessages[index];
                      final mediaData =
                          message.metadata?['media'] as Map<String, dynamic>?;
                      final localPath =
                          mediaData?['local_media_path'] as String?;
                      final isVideo = message.type == MessageType.video;

                      if (isVideo &&
                          index == _currentIndex &&
                          _videoController?.value.isInitialized == true) {
                        return PhotoViewGalleryPageOptions.customChild(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                          initialScale: PhotoViewComputedScale.contained,
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2,
                        );
                      }

                      return PhotoViewGalleryPageOptions(
                        imageProvider: localPath != null
                            ? FileImage(File(localPath))
                            : const AssetImage('assets/placeholder.png')
                                as ImageProvider,
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        heroAttributes:
                            PhotoViewHeroAttributes(tag: message.id),
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded,
                                  color: Colors.white24, size: 64),
                              SizedBox(height: 16),
                              Text('Media unavailable',
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      );
                    },
                    itemCount: _mediaMessages.length,
                    loadingBuilder: (context, event) => const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                    pageController: _pageController,
                    onPageChanged: _onPageChanged,
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                  ),
                ),
              ),

              // Top Bar Controls
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentMessage.senderId == widget.currentUserId
                                  ? 'You'
                                  : 'Friend',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d, h:mm a')
                                  .format(currentMessage.timestamp),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: Colors.white, size: 22),
                        onPressed: () {
                          // TODO: Implement share
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () {
                          // More options
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Video Controls
              if (currentMessage.type == MessageType.video &&
                  _videoController?.value.isInitialized == true)
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: VideoControlsOverlay(controller: _videoController!),
                  ),
                ),

              // Page Indicator
              if (_mediaMessages.length > 1 && _showControls)
                Positioned(
                  bottom: currentMessage.type == MessageType.video ? 100 : 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_mediaMessages.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControlsOverlay({super.key, required this.controller});

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            widget.controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.blueAccent,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  widget.controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  widget.controller.value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                },
              ),
              Text(
                '${_formatDuration(widget.controller.value.position)} / ${_formatDuration(widget.controller.value.duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              IconButton(
                icon: Icon(
                  widget.controller.value.volume > 0
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  widget.controller
                      .setVolume(widget.controller.value.volume > 0 ? 0 : 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
