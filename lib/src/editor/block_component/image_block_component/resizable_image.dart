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
    required this.fit,
    required this.isCover,
  });

  final AppDocument document;
  final double width;
  final double? height;
  final Alignment alignment;
  final bool editable;
  final bool preview;
  final void Function(double width) onResize;
  final BoxFit fit;
  final bool isCover;

  @override
  State<ResizableImage> createState() => _ResizableImageState();
}

const _kImageBlockComponentMinWidth = 90.0;

class _ResizableImageState extends State<ResizableImage> {
  late double currentWidth;
  bool isDragging = false;

  @visibleForTesting
  bool onFocus = false;

  @override
  void initState() {
    super.initState();
    currentWidth = widget.width;
  }

  @override
  void didUpdateWidget(ResizableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isDragging) {
      currentWidth = widget.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: SizedBox(
        width: max(_kImageBlockComponentMinWidth, currentWidth),
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
    final displayWidth = max(_kImageBlockComponentMinWidth, currentWidth);

    final child = FileDisplay(
      document: widget.document,
      fit: widget.fit,
      alignment: widget.alignment,
      width: displayWidth,
      height: widget.height,
      preview: widget.preview,
    );

    if (!widget.editable) {
      return child;
    }

    return Stack(
      children: [
        // Main image
        Container(
          margin: EdgeInsets.symmetric(horizontal: 150),
          child: SizedBox(
            width: displayWidth,
            height: widget.height,
            child: child,
          ),
        ),

        // Left resize handle
        if (widget.alignment != Alignment.centerRight)
          Positioned(
            top: 0,
            left: 150, // Align with the left edge of the SizedBox
            bottom: 0,
            child: _buildResizeHandle(
              isLeft: true,
              onUpdate: (newWidth) {
                setState(() {
                  currentWidth = max(_kImageBlockComponentMinWidth, newWidth);
                });
              },
              onEnd: () {
                widget.onResize(currentWidth);
              },
            ),
          ),

        // Right resize handle
        if (widget.alignment != Alignment.centerLeft)
          Positioned(
            top: 0,
            right: 150, // Align with the right edge of the SizedBox
            bottom: 0,
            child: _buildResizeHandle(
              isLeft: false,
              onUpdate: (newWidth) {
                setState(() {
                  currentWidth = max(_kImageBlockComponentMinWidth, newWidth);
                });
              },
              onEnd: () {
                widget.onResize(currentWidth);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildResizeHandle({
    required bool isLeft,
    required void Function(double newWidth) onUpdate,
    required VoidCallback onEnd,
  }) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        isDragging = true;
      },
      onHorizontalDragUpdate: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.globalPosition);

        double newWidth;

        if (widget.alignment == Alignment.center) {
          // For center alignment, calculate from center
          final centerX = renderBox.size.width / 2;
          final distanceFromCenter = (localPosition.dx - centerX).abs();
          newWidth = distanceFromCenter * 2;
        } else if (isLeft) {
          // For left handle, width is from current position to right edge
          newWidth = renderBox.size.width -
              localPosition.dx +
              currentWidth -
              renderBox.size.width;
        } else {
          // For right handle, width is from left edge to current position
          newWidth = localPosition.dx;
        }

        newWidth = max(_kImageBlockComponentMinWidth, newWidth);
        onUpdate(newWidth);
      },
      onHorizontalDragEnd: (details) {
        isDragging = false;
        onEnd();
      },
      child: SizedBox(
        width: 10,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: onFocus
              ? Center(
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(2.0),
                      ),
                      border: Border.all(width: 1, color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  width: 10,
                  color: Colors.transparent,
                ),
        ),
      ),
    );
  }
}
