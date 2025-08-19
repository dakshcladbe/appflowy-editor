import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:cladbe_shared/cladbe_shared.dart' hide Node;

class MarkdownImageParserV2 extends CustomMarkdownParser {
  const MarkdownImageParserV2();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }

    if (element.attributes['src'] != null) {
      return [
        imageNode(
          document: AppDocument(
            name: "name",
            documentPath: "documentPath",
            bucketProvider: "bucketProvider",
            hashingCode: "hashingCode",
          ),
        ),
      ];
    }

    if (element.children?.length != 1 ||
        element.children?.first is! md.Element) {
      return [];
    }

    final ec = element.children?.first as md.Element;
    if (ec.tag != 'img' || ec.attributes['src'] == null) {
      return [];
    }

    return [
      imageNode(
        document: AppDocument(
          name: "name",
          documentPath: "documentPath",
          bucketProvider: "bucketProvider",
          hashingCode: "hashingCode",
        ),
      ),
    ];
  }
}
