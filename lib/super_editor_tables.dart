import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const _superEditorBlockType = 'blockType';
const tableRowAttribution = NamedAttribution('table');

class TableRowNode extends DocumentNode
    with ChangeNotifier
    implements TextNode {
  TableRowNode({
    required this.id,
    required this.columns,
    Map<String, dynamic>? metadata,
  }) {
    this.metadata = metadata;
    this.metadata[_superEditorBlockType] = tableRowAttribution;
  }

  @override
  final String id;

  final List<AttributedText> columns;

  @override
  AttributedText get text =>
      columns.reduce((value, element) => value.copyAndAppend(element));

  @override
  set text(AttributedText newText) {
    throw UnimplementedError('set text on row');
  }

  @override
  TextNodePosition get beginningPosition => const TextNodePosition(offset: 0);

  @override
  TextNodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  }) {
    final baseText = base as TextNodePosition;
    final extentText = extent as TextNodePosition;

    return TextNodeSelection(
      baseOffset: baseText.offset,
      extentOffset: extentText.offset,
      affinity: extentText.affinity,
    );
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is TextNodeSelection);
    return (selection as TextNodeSelection).textInside(text.text);
  }

  @override
  TextNodePosition get endPosition => TextNodePosition(
        offset: columns.map((c) => c.text.length).sum,
      );

  @override
  NodePosition selectDownstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    if (position1 is! TextNodePosition) {
      throw Exception(
        'Expected a TextNodePosition for position1 but received a ${position1.runtimeType}',
      );
    }
    if (position2 is! TextNodePosition) {
      throw Exception(
        'Expected a TextNodePosition for position2 but received a ${position2.runtimeType}',
      );
    }

    return position1.offset > position2.offset ? position1 : position2;
  }

  @override
  NodePosition selectUpstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    if (position1 is! TextNodePosition) {
      throw Exception(
        'Expected a TextNodePosition for position1 but received a ${position1.runtimeType}',
      );
    }
    if (position2 is! TextNodePosition) {
      throw Exception(
        'Expected a TextNodePosition for position2 but received a ${position2.runtimeType}',
      );
    }

    return position1.offset < position2.offset ? position1 : position2;
  }

  @override
  DocumentPosition positionAt(int index) {
    return DocumentPosition(
      nodeId: id,
      nodePosition: TextNodePosition(offset: index),
    );
  }

  @override
  DocumentRange rangeBetween(int startIndex, int endIndex) {
    return DocumentRange(
      start: positionAt(startIndex),
      end: positionAt(endIndex),
    );
  }

  @override
  DocumentSelection selectionAt(int collapsedIndex) {
    return DocumentSelection.collapsed(position: positionAt(collapsedIndex));
  }

  @override
  DocumentSelection selectionBetween(int startIndex, int endIndex) {
    return DocumentSelection(
      base: positionAt(startIndex),
      extent: positionAt(endIndex),
    );
  }
}

class TableRowComponentBuilder implements ComponentBuilder {
  const TableRowComponentBuilder();

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TableComponentViewModel) {
      return null;
    }
    return TableRowComponent(
      key: componentContext.componentKey,
      tableStatus: componentViewModel.tableStatus,
      columns: componentViewModel.columns,
      selection: componentViewModel.selection,
      textStyleBuilder: componentViewModel.textStyleBuilder,
    );
  }

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! TableRowNode) {
      return null;
    }
    return TableComponentViewModel(
      nodeId: node.id,
      padding: EdgeInsets.zero,
      maxWidth: 1000,
      columns: node.columns,
      textStyleBuilder: noStyleBuilder,
      tableStatus: TableStatus(
        isFirst: !(document.getNodeBefore(node)?.isTable ?? false),
        isLast: !(document.getNodeAfter(node)?.isTable ?? false),
      ),
    );
  }
}

class TableRowComponent extends StatefulWidget {
  const TableRowComponent({
    super.key,
    required this.tableStatus,
    required this.columns,
    required this.selection,
    required this.textStyleBuilder,
  });

  final TableStatus tableStatus;
  final List<AttributedText> columns;
  final TextNodeSelection? selection;
  final AttributionStyleBuilder textStyleBuilder;

  @override
  State<TableRowComponent> createState() => _TableRowComponentState();
}

class _TableRowComponentState extends State<TableRowComponent>
    with DocumentComponent {
  final _childKeys = <GlobalKey<_TableColumnState>>[];

  String getAllText() => widget.columns.first.text;

  int get fullLength => widget.columns.map((c) => c.length).sum;

  GlobalKey<_TableColumnState> columnAt(int index) => _childKeys[index];

  @override
  void initState() {
    super.initState();
    _allocateColumns();
  }

  @override
  void didUpdateWidget(covariant TableRowComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) {
      _allocateColumns();
    }
  }

  void _allocateColumns() {
    if (widget.columns.length != 2) {
      throw UnimplementedError('Only 2 column tables are currently suppoted');
    }
    if (_childKeys.length == widget.columns.length) return;
    if (_childKeys.length < widget.columns.length) {
      final existingChildKeys = _childKeys.length;
      for (var i = 0; i < widget.columns.length - existingChildKeys; i++) {
        _childKeys.add(GlobalKey(debugLabel: 'Column ${_childKeys.length}'));
      }
    }
    if (_childKeys.length > widget.columns.length) {
      throw UnimplementedError('Child deallocation not yet implemented');
    }
  }

  @override
  TextNodePosition? getPositionAtOffset(Offset localOffset) {
    final (_, childKey) =
        localOffset.dx < 400 ? (0, columnAt(0)) : (1, columnAt(1));
    final textPosition =
        childKey.currentState!.getPositionAtOffset(localOffset);
    return textPosition! as TextNodePosition;
  }

  @override
  TextNodePosition getBeginningPosition() {
    return const TextNodePosition(offset: 0);
  }

  @override
  TextNodePosition getBeginningPositionNearX(double x) {
    return columnAt(0).currentState!.getBeginningPositionNearX(x)
        as TextNodePosition;
  }

  @override
  TextNodeSelection getCollapsedSelectionAt(NodePosition position) {
    if (position is! TextNodePosition) {
      throw Exception(
        'The given node position ($position) is not compatible with TableRowComponent',
      );
    }

    return TextNodeSelection.collapsed(
      offset: position.offset,
    );
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    final index = localOffset.dx < 200 ? 0 : 1;
    return columnAt(index).currentState!.getDesiredCursorAtOffset(localOffset);
  }

  @override
  TextNodePosition getEndPosition() {
    return TextNodePosition(
      offset: widget.columns.map((c) => c.length).sum,
      affinity: TextAffinity.upstream,
    );
  }

  @override
  TextNodePosition getEndPositionNearX(double x) {
    final offset =
        widget.columns.take(widget.columns.length - 1).map((c) => c.length).sum;
    final childPosition = _childKeys.last.currentState!.getEndPositionNearX(x)
        as TextNodePosition;
    return childPosition.copyWith(offset: childPosition.offset + offset);
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TextNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $nodePosition',
      );
    }
    final column = _columnFromOffset(nodePosition.offset);
    final childKey = columnAt(column);
    final baseOffset = _offsetForColumn(column);
    final adjustedPosition =
        nodePosition.copyWith(offset: nodePosition.offset - baseOffset);
    return childKey.currentState!.getOffsetForPosition(adjustedPosition);
  }

  (int, TextNodePosition) _childWithPosition(TextNodePosition position) {
    final column = _columnFromOffset(position.offset);
    final baseOffset = _offsetForColumn(column);
    final childPosition = position.copyWith(
      offset: position.offset - baseOffset,
    );
    return (column, childPosition);
  }

  int _columnFromOffset(int offset) {
    var remainingChars = offset;
    for (var i = 0; i < widget.columns.length; i++) {
      remainingChars -= widget.columns[i].length;
      if (remainingChars < 1) return i;
    }
    return widget.columns.length - 1;
  }

  int _offsetForColumn(int column) {
    return widget.columns.indexed
        .takeWhile((v) => v.$1 < column)
        .map((v) => v.$2.length)
        .sum;
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! TextNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $nodePosition',
      );
    }
    final column = _columnFromOffset(nodePosition.offset);
    final childKey = columnAt(column);
    final childPosition = childKey.currentState!.getRectForPosition(
      TextNodePosition(
        offset: nodePosition.offset - _offsetForColumn(column),
      ),
    );
    final myBox = context.findRenderObject()! as RenderBox;
    final childBox = childKey.currentContext!.findRenderObject()! as RenderBox;
    final childOffset = childBox.localToGlobal(Offset.zero, ancestor: myBox);
    return childPosition.shift(childOffset);
  }

  @override
  Rect getRectForSelection(
    dynamic baseNodePosition,
    dynamic extentNodePosition,
  ) {
    // TODO: implement cross-node selection
    if (baseNodePosition is! TextNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $baseNodePosition',
      );
    }
    if (extentNodePosition is! TextNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $extentNodePosition',
      );
    }
    final baseColumn = _columnFromOffset(baseNodePosition.offset);
    final extentColumn = _columnFromOffset(extentNodePosition.offset);
    assert(baseColumn == extentColumn);

    final childKey = columnAt(baseColumn);
    return childKey.currentState!.getRectForSelection(
      baseNodePosition.copyWith(
        offset: baseNodePosition.offset - _offsetForColumn(baseColumn),
      ),
      extentNodePosition.copyWith(
        offset: extentNodePosition.offset - _offsetForColumn(extentColumn),
      ),
    );
  }

  @override
  TextNodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    if (basePosition is! TextNodePosition) {
      throw Exception(
        'Expected a basePosition of type TableNodePosition but received: $basePosition',
      );
    }
    if (extentPosition is! TextNodePosition) {
      throw Exception(
        'Expected an extentPosition of type TableNodePosition but received: $extentPosition',
      );
    }
    final baseColumn = _columnFromOffset(basePosition.offset);
    final extentColumn = _columnFromOffset(extentPosition.offset);
    assert(baseColumn == extentColumn);

    return TextNodeSelection(
      baseOffset: basePosition.offset,
      extentOffset: extentPosition.offset,
      affinity: extentPosition.affinity,
    );
  }

  @override
  TextNodeSelection getSelectionInRange(
    Offset localBaseOffset,
    Offset localExtentOffset,
  ) {
    throw UnimplementedError();
  }

  @override
  TextNodeSelection getSelectionOfEverything() {
    return TextNodeSelection(
      baseOffset: 0,
      extentOffset: widget.columns.map((c) => c.length).sum,
    );
  }

  TextNodePosition? getPositionOneLineDown(NodePosition position) {
    if (position is! TextNodePosition) {
      throw Exception(
        'Expected position of type TableNodePosition but received ${position.runtimeType}',
      );
    }
    final (column, childPosition) = _childWithPosition(position);
    final lineDownPos =
        columnAt(column).currentState!.getPositionOneLineDown(childPosition);
    return lineDownPos;
  }

  @override
  TextNodePosition? movePositionDown(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > fullLength) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineDown = getPositionOneLineDown(textNodePosition);
    return positionOneLineDown;
  }

  TextNodePosition getPositionAtStartOfLine(
    TextNodePosition position,
  ) {
    final (column, childPosition) = _childWithPosition(position);
    final childKey = columnAt(column);
    final baseOffset = _offsetForColumn(column);
    final result =
        childKey.currentState!.getPositionAtStartOfLine(childPosition);
    return result.copyWith(offset: result.offset + baseOffset);
  }

  @override
  TextNodePosition? movePositionLeft(
    NodePosition position, [
    MovementModifier? movementModifier,
  ]) {
    if (position is! TextNodePosition) {
      return null;
    }

    final (column, childPosition) = _childWithPosition(position);
    final childKey = columnAt(column);
    final newPosition = childKey.currentState!.movePositionLeft(
      childPosition,
      movementModifier,
    ) as TextNodePosition?;
    if (newPosition == null && column > 0) {
      final newIndex = column - 1;
      final endPosition =
          columnAt(newIndex).currentState!.getEndPosition() as TextNodePosition;
      return endPosition.copyWith(
        offset: endPosition.offset + _offsetForColumn(newIndex),
      );
    }
    return newPosition == null ? null : newPosition + _offsetForColumn(column);
  }

  TextNodePosition getPositionAtEndOfLine(TextNodePosition position) {
    final (column, childPosition) = _childWithPosition(position);
    final childKey = columnAt(column);
    final newPosition =
        childKey.currentState!.getPositionAtEndOfLine(childPosition);
    return newPosition + _offsetForColumn(column);
  }

  @override
  TextNodePosition? movePositionRight(
    NodePosition position, [
    MovementModifier? movementModifier,
  ]) {
    if (position is! TextNodePosition) {
      return null;
    }

    final (column, childPosition) = _childWithPosition(position);
    final childKey = columnAt(column);
    final newPosition = childKey.currentState!.movePositionRight(
      childPosition,
      movementModifier,
    ) as TextNodePosition?;
    if (newPosition == null && column < widget.columns.length - 1) {
      return TextNodePosition(offset: _offsetForColumn(column + 1) + 1);
    }
    return newPosition == null ? null : newPosition + _offsetForColumn(column);
  }

  TextNodePosition? getPositionOneLineUp(NodePosition position) {
    if (position is! TextNodePosition) {
      throw Exception(
        'Expected position of type TableNodePosition but received ${position.runtimeType}',
      );
    }
    final (column, childPosition) = _childWithPosition(position);
    final childKey = columnAt(column);
    final newPosition =
        childKey.currentState!.getPositionOneLineUp(childPosition);
    if (newPosition == null) return null;
    return newPosition + _offsetForColumn(column);
  }

  @override
  TextNodePosition? movePositionUp(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > fullLength) {
      // This text position does not represent a position within our text.
      return null;
    }

    return getPositionOneLineUp(textNodePosition);
  }

  @override
  Widget build(BuildContext context) {
    final childSelection = switch (widget.selection) {
      final sel? => _childWithPosition(sel.base),
      _ => null,
    };
    return Row(
      children: [
        for (final (index, text) in widget.columns.indexed)
          TableColumn(
            key: _childKeys[index],
            isFirst: widget.tableStatus.isFirst,
            text: text,
            textStyleBuilder: widget.textStyleBuilder,
            selection: childSelection?.$1 == index
                ? TextSelection.collapsed(offset: childSelection!.$2.offset)
                : null,
          ),
      ],
    );
  }
}

class TableColumn extends StatefulWidget {
  const TableColumn({
    super.key,
    required this.isFirst,
    required this.text,
    required this.selection,
    required this.textStyleBuilder,
  });

  final bool isFirst;
  final AttributedText text;
  final TextSelection? selection;
  final AttributionStyleBuilder textStyleBuilder;

  @override
  State<TableColumn> createState() => _TableColumnState();
}

class _TableColumnState extends State<TableColumn>
    with ProxyDocumentComponent<TableColumn>, ProxyTextComposable {
  final _childTextComponentKey = GlobalKey<TextComponentState>();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey =>
      _childTextComponentKey;

  @override
  TextComposable get childTextComposable =>
      _childTextComponentKey.currentState!;

  @override
  Widget build(BuildContext context) {
    const border = BorderSide(color: Color(0xff000000), width: 1);
    return Container(
      width: 200,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        border: Border(
          left: border,
          right: border,
          bottom: border,
          top: widget.isFirst ? border : BorderSide.none,
        ),
      ),
      child: TextComponent(
        key: _childTextComponentKey,
        text: widget.text,
        textStyleBuilder: (attrs) => widget.textStyleBuilder(attrs).copyWith(
              color: Colors.red,
              fontSize: 24,
            ),
        textSelection: widget.selection,
        showDebugPaint: false,
      ),
    );
  }
}

class TableComponentViewModel extends SingleColumnLayoutComponentViewModel {
  TableComponentViewModel({
    required super.nodeId,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    this.blockType,
    required this.columns,
    this.selection,
    required this.tableStatus,
    required this.textStyleBuilder,
  });

  TableStatus tableStatus;
  Attribution? blockType;
  List<AttributedText> columns;
  TextNodeSelection? selection;
  AttributionStyleBuilder textStyleBuilder;

  @override
  TableComponentViewModel copy() {
    return TableComponentViewModel(
      nodeId: nodeId,
      maxWidth: maxWidth,
      padding: padding,
      blockType: blockType,
      columns: columns,
      selection: selection,
      tableStatus: tableStatus,
      textStyleBuilder: textStyleBuilder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TableComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          blockType == other.blockType &&
          columns == other.columns &&
          selection == other.selection;

  @override
  int get hashCode =>
      super.hashCode ^
      nodeId.hashCode ^
      blockType.hashCode ^
      columns.hashCode ^
      selection.hashCode;
}

class TableStatus {
  TableStatus({
    required this.isFirst,
    required this.isLast,
  });

  final bool isFirst;
  final bool isLast;
}

extension TableBlockNodeExtensions on DocumentNode {
  bool get isTable => runtimeType == TableRowNode;
}

class TableConversionReaction extends ParagraphPrefixConversionReaction {
  const TableConversionReaction();

  static final _tablePattern = RegExp(r'^\s*\|\s+$');

  @override
  RegExp get pattern => _tablePattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: TableRowNode(
          id: paragraph.id,
          columns: [AttributedText(''), AttributedText('')],
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

extension _ModifyOffset on TextNodePosition {
  operator +(int mod) => copyWith(
        offset: offset + mod,
        affinity: TextAffinity.downstream,
      );
  operator -(int mod) => copyWith(
        offset: offset - mod,
        affinity: TextAffinity.upstream,
      );
}
