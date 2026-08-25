import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gestion_formations/config/theme.dart';
import 'package:gestion_formations/utils/app_logger.dart';

class FormationImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const FormationImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildRawImage();

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: imageWidget,
    );
  }

  Widget _buildRawImage() {
    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return _buildFallbackPlaceholder();
    }

    // Base64 Data URI
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(),
        );
      } catch (e, s) {
        logHandledError('Image base64 illisible', e, s);
        return _buildFallbackPlaceholder();
      }
    }

    // Remote HTTP / HTTPS URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(),
      );
    }

    // Local Asset Path
    final assetPath = url.startsWith('/') ? url.substring(1) : url;
    return Image.asset(
      assetPath.startsWith('images/') ? assetPath : 'images/$assetPath',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(),
    );
  }

  Widget _buildFallbackPlaceholder() {
    return Image.asset(
      'images/Malintic.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
        ),
        child: const Center(
          child: Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}
