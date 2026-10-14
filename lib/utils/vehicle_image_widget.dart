import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/colorcode.dart';

/// Reusable thumbnail widget and viewer dialog for vehicle images in booking lists.
class VehicleImageThumbnail extends StatelessWidget {
  final List<String> images;
  final String vehicleNumber;
  final double size;
  final EdgeInsetsGeometry? margin;

  const VehicleImageThumbnail({
    super.key,
    required this.images,
    required this.vehicleNumber,
    this.size = 52.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final validImages = images
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (validImages.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstImage = validImages.first;

    return GestureDetector(
      onTap: () => showVehicleImageDialog(context, validImages, vehicleNumber),
      child: Container(
        width: size,
        height: size,
        margin: margin ?? const EdgeInsets.only(right: 8.0, left: 4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: ColorUtils.primarycolor(),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6.5),
              child: _buildThumbnail(firstImage),
            ),
            // Zoom indicator badge
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: ColorUtils.primarycolor(),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
            // Multi-image count badge
            if (validImages.length > 1)
              Positioned(
                left: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '+${validImages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorUtils.primarycolor(),
                  ),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.camera_alt,
              size: 20,
              color: ColorUtils.primarycolor().withOpacity(0.6),
            ),
          );
        },
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return Container(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.camera_alt,
          size: 20,
          color: ColorUtils.primarycolor().withOpacity(0.6),
        ),
      );
    }
  }
}

/// Opens a full-screen or dialog viewer for vehicle photos with interactive pinch-to-zoom.
void showVehicleImageDialog(
  BuildContext context,
  List<String> images,
  String vehicleNumber,
) {
  final validImages = images
      .map((e) => e.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (validImages.isEmpty) return;

  showDialog(
    context: context,
    builder: (ctx) {
      int activeIndex = 0;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: ColorUtils.primarycolor(),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              vehicleNumber.isNotEmpty ? vehicleNumber : 'Vehicle Photo',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Image viewer with InteractiveViewer (pinch-to-zoom)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Container(
                      color: Colors.black,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                        minHeight: 220,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (validImages.length == 1)
                            InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: Center(
                                child: _buildDialogImage(validImages.first),
                              ),
                            )
                          else ...[
                            PageView.builder(
                              itemCount: validImages.length,
                              onPageChanged: (idx) {
                                setDialogState(() {
                                  activeIndex = idx;
                                });
                              },
                              itemBuilder: (context, index) {
                                return InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.0,
                                  child: Center(
                                    child: _buildDialogImage(validImages[index]),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${activeIndex + 1} / ${validImages.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildDialogImage(String imageUrl) {
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 40, color: Colors.white54),
                SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      },
    );
  } else {
    final file = File(imageUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }
    return const SizedBox(
      height: 220,
      child: Center(
        child: Icon(Icons.broken_image, size: 40, color: Colors.white54),
      ),
    );
  }
}
