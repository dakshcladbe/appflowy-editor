import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cladbe_shared/cladbe_shared.dart' hide Node;
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class ImageBlockKeys {
  const ImageBlockKeys._();

  static const String type = 'image';
  static const String align = 'align';
  static const String appdocument = 'appdocument';
  static const String width = 'width';
  static const String height = 'height';
  static const String fit = 'fit';
}

Node imageNode({
  required dynamic document,
  String align = 'center',
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover, // Changed default to BoxFit.cover
  bool isCover = false, // Add flag for cover images
}) {
  return Node(
    type: ImageBlockKeys.type,
    attributes: {
      ImageBlockKeys.appdocument:
          document is AppDocument ? document.toMap() : document,
      ImageBlockKeys.align:
          isCover ? 'center' : align, // Force center alignment for cover
      if (width != null && !isCover)
        ImageBlockKeys.width: width, // Don't set width for cover
      if (height != null) ImageBlockKeys.height: height,
      ImageBlockKeys.fit:
          fit.toString().split('.').last, // Store as string without 'BoxFit.'
      if (isCover) 'isCover': true, // Add cover flag to attributes
    },
  );
}

// Helper function to create cover image nodes
Node coverImageNode({
  required dynamic document,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return imageNode(
    document: document,
    align: 'center',
    height: height,
    fit: fit,
    isCover: true,
  );
}

typedef ImageBlockComponentMenuBuilder = Widget Function(
  Node node,
  ImageBlockComponentWidgetState state,
);
typedef OnImageSelectedCallback = void Function();
typedef OnImageUploadCallback = Future<String> Function(String filePath);

class ImageBlockComponentBuilder extends BlockComponentBuilder {
  ImageBlockComponentBuilder({
    super.configuration = const BlockComponentConfiguration(
      padding: _customPadding, // Custom padding function
    ),
    this.showMenu = false,
    this.menuBuilder,
    this.onSelectedImage,
  });

  final bool showMenu;
  final ImageBlockComponentMenuBuilder? menuBuilder;
  final OnImageSelectedCallback? onSelectedImage;

  // Custom padding function
  static EdgeInsets _customPadding(Node node) {
    final isFirstNode = node.path.isNotEmpty && node.path.first == 0;
    final isCoverImage = node.attributes['isCover'] == true;

    // Set padding to 0 only for the first node that is a cover image
    if (isFirstNode && isCoverImage) {
      return EdgeInsets.zero;
    }
    return const EdgeInsets.only(bottom: 200);
  }

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ImageBlockComponentWidget(
      key: node.key,
      node: node,
      showActions: showActions(node),
      configuration: configuration,
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
      showMenu: showMenu,
      menuBuilder: menuBuilder,
      onSelectedImage: onSelectedImage,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

class ImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const ImageBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.showMenu = false,
    this.menuBuilder,
    this.onSelectedImage,
  });

  final bool showMenu;
  final ImageBlockComponentMenuBuilder? menuBuilder;
  final OnImageSelectedCallback? onSelectedImage;

  @override
  State<ImageBlockComponentWidget> createState() =>
      ImageBlockComponentWidgetState();
}

class ImageBlockComponentWidgetState extends State<ImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final imageKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  final showActionsNotifier = ValueNotifier<bool>(false);
  final showCoverActionsNotifier = ValueNotifier<bool>(false);

  bool alwaysShowMenu = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final attributes = node.attributes;
    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );

    // Check if this is the first node or cover image
    final isFirstNode = node.path.isNotEmpty && node.path.first == 0;
    final isCoverImage = attributes['isCover'] == true;

    // Get padding from configuration
    final padding = configuration.padding(node);
    final horizontalPadding = padding.horizontal;

    // Calculate width based on whether it's the first cover image
    final width = (isFirstNode && isCoverImage)
        ? MediaQuery.of(context).size.width
        : (attributes[ImageBlockKeys.width]?.toDouble() ??
            (MediaQuery.of(context).size.width - horizontalPadding));
    final height = attributes[ImageBlockKeys.height]?.toDouble();

    // Improved BoxFit parsing
    final fitString = attributes[ImageBlockKeys.fit] as String? ?? 'cover';
    BoxFit fit = _parseBoxFit(fitString);

    // Reconstruct AppDocument from serialized map
    final appDocumentMap =
        attributes[ImageBlockKeys.appdocument] as Map<String, dynamic>?;
    final appDocument =
        appDocumentMap != null ? AppDocument.fromMap(appDocumentMap) : null;

    Widget child = appDocument != null
        ? _isPdf(appDocument)
            ? GestureDetector(
                onTap: () {
                  _showPdfPopup(context, node, appDocument);
                },
                child: SizedBox(
                  height: 500,
                  width: 500,
                  child: FileDisplay(
                    document: appDocument,
                    preview: true,
                  ),
                ),
              )
            : _isVideo(appDocument)
                ? Container(
                    // Only constrain videos to prevent infinite height
                    constraints: BoxConstraints(
                      maxWidth: width,
                      maxHeight:
                          height ?? MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: ResizableImage(
                      document: appDocument,
                      width: width,
                      height: height,
                      isCover: isCoverImage,
                      fit: fit,
                      alignment: alignment,
                      editable: editorState.editable &&
                          !(isFirstNode && isCoverImage),
                      onResize: (newWidth) {
                        final transaction = editorState.transaction
                          ..updateNode(node, {
                            ImageBlockKeys.width: newWidth,
                          });
                        editorState.apply(transaction);
                      },
                      onTap: () {
                        _showPdfPopup(context, node, appDocument);
                      },
                    ),
                  )
                : ResizableImage(
                    // Regular images without height constraints
                    document: appDocument,
                    width: width,
                    height: height,
                    isCover: isCoverImage,
                    fit: fit,
                    alignment: alignment,
                    editable:
                        editorState.editable && !(isFirstNode && isCoverImage),
                    onResize: (newWidth) {
                      final transaction = editorState.transaction
                        ..updateNode(node, {
                          ImageBlockKeys.width: newWidth,
                        });
                      editorState.apply(transaction);
                    },
                    onTap: () {
                      _showPdfPopup(context, node, appDocument);
                    },
                  )
        : const Center(child: Text('No image available'));

    // Add "Uploading..." overlay if the image is being uploaded
    if (attributes['isUploading'] == true) {
      child = Stack(
        alignment: Alignment.center,
        children: [
          child,
          Container(
            width: width,
            height: height ?? 300,
            color: Colors.black.withOpacity(0.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Uploading...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Add cover image overlay for hover actions
    if ((isFirstNode && isCoverImage) && editorState.editable) {
      child = _buildCoverImageWithOverlay(child);
    }

    // Apply padding from configuration
    child = Padding(
      key: imageKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    if (widget.showMenu && widget.menuBuilder != null) {
      child = MouseRegion(
        onEnter: (_) => showActionsNotifier.value = true,
        onExit: (_) {
          if (!alwaysShowMenu) {
            showActionsNotifier.value = false;
          }
        },
        hitTestBehavior: HitTestBehavior.opaque,
        opaque: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: showActionsNotifier,
          builder: (context, value, child) {
            return Stack(
              children: [
                BlockSelectionContainer(
                  node: node,
                  delegate: this,
                  listenable: editorState.selectionNotifier,
                  remoteSelection: editorState.remoteSelections,
                  cursorColor: editorState.editorStyle.cursorColor,
                  selectionColor: editorState.editorStyle.selectionColor,
                  child: child!,
                ),
                if (value) widget.menuBuilder!(widget.node, this),
              ],
            );
          },
          child: child,
        ),
      );
    }

    return child;
  }

  // Helper method to check if the document is a PDF
  bool _isPdf(AppDocument document) {
    final filePath = document.getFileExtension;
    if (filePath == 'pdf') {
      return true;
    }
    return false;
  } // Helper method to check if the document is a video

  bool _isVideo(AppDocument document) {
    final extension = document.getFileExtension.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp']
        .contains(extension);
  }

  // Method to show the PDF popup
  void _showPdfPopup(BuildContext context, Node node, AppDocument document) {
    final noteData =
        _getNoteDataFromNode(node); // Assume this retrieves note data
    var popup = Popup(
      id: '1',
      onDismiss: () {
        Provider.of<PopupProvider>(context, listen: false).popPopupStack();
      },
      element: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            width: MediaQuery.of(context).size.width * 0.32,
            child: FileDisplay(
              document: document,
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width - 200,
              preview: false,
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
    Provider.of<PopupProvider>(context, listen: false).pushPopupStack = popup;
  }

  // Placeholder method to get note data from node (implement based on your data model)
  dynamic _getNoteDataFromNode(Node node) {
    // This is a placeholder. Replace with actual logic to get noteData from node or context
    return null; // Example, implement based on your data structure
  }

  // Rest of the methods remain unchanged
  BoxFit _parseBoxFit(String fitString) {
    switch (fitString.toLowerCase()) {
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      case 'cover':
        return BoxFit.cover;
      case 'fitheight':
        return BoxFit.fitHeight;
      case 'fitwidth':
        return BoxFit.fitWidth;
      case 'none':
        return BoxFit.none;
      case 'scaledown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  Widget _buildCoverImageWithOverlay(Widget imageChild) {
    return Stack(
      children: [
        imageChild,
        Positioned.fill(
          child: MouseRegion(
            onEnter: (_) {
              print('Cover image hover ENTER');
              showCoverActionsNotifier.value = true;
            },
            onExit: (_) {
              print('Cover image hover EXIT');
              showCoverActionsNotifier.value = false;
            },
            child: ValueListenableBuilder<bool>(
              valueListenable: showCoverActionsNotifier,
              builder: (context, showActions, _) {
                return Container(
                  color: showActions
                      ? Colors.black.withOpacity(0.2)
                      : Colors.transparent,
                  child: showActions
                      ? Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCoverButton(
                                icon: EvilIcons.image,
                                label: 'Change Cover',
                                onTap: _onChangeCover,
                              ),
                              const SizedBox(width: 16),
                              _buildCoverButton(
                                icon: Icons.delete,
                                label: 'Delete',
                                onTap: _onDeleteCover,
                                isDestructive: true,
                              ),
                            ],
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.8)
                : AppDefault.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: !isDestructive ? 18 : 16,
                color: isDestructive ? Colors.white : AppDefault.iconGreyColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.white : AppDefault.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onChangeCover() {
    if (widget.onSelectedImage != null) {
      widget.onSelectedImage!();
    }
    print('Change cover image requested');
  }

  void _onDeleteCover() {
    final transaction = editorState.transaction..deleteNode(widget.node);
    editorState.apply(transaction);
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);
  @override
  Position end() => Position(path: widget.node.path, offset: 1);
  @override
  Position getPositionInOffset(Offset start) => end();
  @override
  bool get shouldCursorBlink => false;
  @override
  CursorStyle get cursorStyle => CursorStyle.cover;
  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (imageBox is RenderBox) {
      return Offset.zero & imageBox.size;
    }
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) {
      return null;
    }
    final size = _renderBox!.size;
    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) {
      return [];
    }
    final parentBox = context.findRenderObject();
    final imageBox = imageKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && imageBox is RenderBox) {
      return [
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );
  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);
}

extension AlignmentExtension on Alignment {
  static Alignment fromString(String name) {
    switch (name) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }
}
