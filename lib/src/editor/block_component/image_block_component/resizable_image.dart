import 'dart:io';
import 'dart:math';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:cladbe_shared/cladbe_shared.dart';
import 'package:string_validator/string_validator.dart';

class ResizableImage extends StatefulWidget {
  const ResizableImage({
    super.key,
    required this.document,
    required this.alignment,
    required this.editable,
    required this.onResize,
    required this.width,
    this.height,
    this.preview = false,
  });

  final AppDocument document;
  final double width;
  final double? height;
  final Alignment alignment;
  final bool editable;
  final bool preview;
  final void Function(double width) onResize;

  @override
  State<ResizableImage> createState() => _ResizableImageState();
}

const _kImageBlockComponentMinWidth = 30.0;

class _ResizableImageState extends State<ResizableImage> {
  late double imageWidth;
  double initialOffset = 0;
  double moveDistance = 0;

  @visibleForTesting
  bool onFocus = false;

  @override
  void initState() {
    super.initState();
    imageWidth = widget.width;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: SizedBox(
        width: max(_kImageBlockComponentMinWidth, imageWidth - moveDistance),
        height: widget.height,
        child: MouseRegion(
          onEnter: (event) => setState(() {
            onFocus = true;
          }),
          onExit: (event) => setState(() {
            onFocus = false;
          }),
          child: _buildResizableImage(context),
        ),
      ),
    );
  }

  Widget _buildResizableImage(BuildContext context) {
    // Delegate rendering to FileDisplay
    final child = FileDisplay(
      document: widget.document,
      fit: BoxFit.contain,
      alignment: widget.alignment,
      width: max(_kImageBlockComponentMinWidth, imageWidth - moveDistance),
      height: widget.height,
      preview: widget.preview,
    );

    return Stack(
      children: [
        child,
        if (widget.editable) ...[
          _buildEdgeGesture(
            context,
            top: 0,
            left: 5,
            bottom: 0,
            width: 5,
            onUpdate: (distance) {
              setState(() {
                moveDistance = distance;
              });
            },
          ),
          _buildEdgeGesture(
            context,
            top: 0,
            right: 5,
            bottom: 0,
            width: 5,
            onUpdate: (distance) {
              setState(() {
                moveDistance = -distance;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEdgeGesture(
    BuildContext context, {
    double? top,
    double? left,
    double? right,
    double? bottom,
    double? width,
    void Function(double distance)? onUpdate,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      width: width,
      child: GestureDetector(
        onHorizontalDragStart: (details) {
          initialOffset = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          if (onUpdate != null) {
            var offset = (details.globalPosition.dx - initialOffset);
            if (widget.alignment == Alignment.center) {
              offset *= 2.0;
            }
            onUpdate(offset);
          }
        },
        onHorizontalDragEnd: (details) {
          imageWidth =
              max(_kImageBlockComponentMinWidth, imageWidth - moveDistance);
          initialOffset = 0;
          moveDistance = 0;
          widget.onResize(imageWidth);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: onFocus
              ? Center(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(5.0),
                      ),
                      border: Border.all(width: 1, color: Colors.white),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
