import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

const _superEditorBlockType = 'blockType';
const tableRowAttribution = NamedAttribution('table');

class TableRowNode extends DocumentNode with ChangeNotifier {
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

  AttributedText get text => columns.first;

  @override
  TableRowNodePosition get beginningPosition => TableRowNodePosition(
        index: 0,
        position: const TextNodePosition(offset: 0),
      );

  @override
  TableNodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  }) {
    final baseTable = base as TableRowNodePosition;
    final extentTable = extent as TableRowNodePosition;
    assert(baseTable.index == extentTable.index);

    return TableNodeSelection(
      index: baseTable.index,
      selection: TextNodeSelection(
        baseOffset: baseTable.position.offset,
        extentOffset: extentTable.position.offset,
        affinity: extentTable.position.affinity,
      ),
    );
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is TableNodeSelection);
    return (selection as TableNodeSelection).selection!.textInside(text.text);
  }

  @override
  TableRowNodePosition get endPosition => TableRowNodePosition(
        index: 1,
        position: TextNodePosition(
          offset: columns.last.text.length,
          affinity: TextAffinity.upstream,
        ),
      );

  @override
  NodePosition selectDownstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    if (position1 is! TableRowNodePosition) {
      throw Exception(
        'Expected a TableNodePosition for position1 but received a ${position1.runtimeType}',
      );
    }
    if (position2 is! TableRowNodePosition) {
      throw Exception(
        'Expected a TableNodePosition for position2 but received a ${position2.runtimeType}',
      );
    }

    return position1.position.offset > position2.position.offset
        ? position1
        : position2;
  }

  @override
  NodePosition selectUpstreamPosition(
    NodePosition position1,
    NodePosition position2,
  ) {
    if (position1 is! TableRowNodePosition) {
      throw Exception(
        'Expected a TableNodePosition for position1 but received a ${position1.runtimeType}',
      );
    }
    if (position2 is! TableRowNodePosition) {
      throw Exception(
        'Expected a TableNodePosition for position2 but received a ${position2.runtimeType}',
      );
    }

    return position1.position.offset < position2.position.offset
        ? position1
        : position2;
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
  final TableNodeSelection? selection;
  final AttributionStyleBuilder textStyleBuilder;

  @override
  State<TableRowComponent> createState() => _TableRowComponentState();
}

class _TableRowComponentState extends State<TableRowComponent>
    with DocumentComponent {
  final _childKeys = <GlobalKey<_TableColumnState>>[];

  String getAllText() => widget.columns.first.text;

  String get text => widget.columns.first.text;

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
  TableRowNodePosition? getPositionAtOffset(Offset localOffset) {
    final (index, childKey) =
        localOffset.dx < 400 ? (0, columnAt(0)) : (1, columnAt(1));
    final textPosition =
        childKey.currentState!.getPositionAtOffset(localOffset);
    return TableRowNodePosition.fromTextPosition(
      index,
      textPosition! as TextNodePosition,
    );
  }

  @override
  TableRowNodePosition getBeginningPosition() {
    return TableRowNodePosition(
      index: 0,
      position: const TextNodePosition(offset: 0),
    );
  }

  @override
  TableRowNodePosition getBeginningPositionNearX(double x) {
    return TableRowNodePosition.fromTextPosition(
      0,
      TextNodePosition.fromTextPosition(
        columnAt(0).currentState!.getBeginningPositionNearX(x)
            as TextNodePosition,
      ),
    );
  }

  @override
  TableNodeSelection getCollapsedSelectionAt(NodePosition position) {
    if (position is! TableRowNodePosition) {
      throw Exception(
        'The given node position ($position) is not compatible with TableRowComponent',
      );
    }

    return TableNodeSelection.collapsed(
      index: position.index,
      offset: position.position.offset,
    );
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    final index = localOffset.dx < 200 ? 0 : 1;
    return columnAt(index).currentState!.getDesiredCursorAtOffset(localOffset);
  }

  @override
  TableRowNodePosition getEndPosition() {
    return TableRowNodePosition(
      index: 1,
      position: TextNodePosition(offset: widget.columns.last.text.length),
    );
  }

  @override
  TableRowNodePosition getEndPositionNearX(double x) {
    return TableRowNodePosition(
      index: 1,
      position: _childKeys.last.currentState!.getEndPositionNearX(x)
          as TextNodePosition,
    );
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TableRowNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $nodePosition',
      );
    }
    final childKey = columnAt(nodePosition.index);
    return childKey.currentState!.getOffsetForPosition(nodePosition.position);
  }

  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    if (nodePosition is! TableRowNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $nodePosition',
      );
    }
    final childKey = columnAt(nodePosition.index);
    final childPosition =
        childKey.currentState!.getRectForPosition(nodePosition.position);
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
    if (baseNodePosition is! TableRowNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $baseNodePosition',
      );
    }
    if (extentNodePosition is! TableRowNodePosition) {
      throw Exception(
        'Expected nodePosition of type TableNodePosition but received: $extentNodePosition',
      );
    }
    assert(baseNodePosition.index == extentNodePosition.index);

    final childKey = columnAt(extentNodePosition.index);
    return childKey.currentState!.getRectForSelection(
      baseNodePosition.position,
      extentNodePosition.position,
    );
  }

  @override
  TableNodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    if (basePosition is! TableRowNodePosition) {
      throw Exception(
        'Expected a basePosition of type TableNodePosition but received: $basePosition',
      );
    }
    if (extentPosition is! TableRowNodePosition) {
      throw Exception(
        'Expected an extentPosition of type TableNodePosition but received: $extentPosition',
      );
    }
    assert(basePosition.index == extentPosition.index);
    return TableNodeSelection(
      index: basePosition.index,
      selection: TextNodeSelection(
        baseOffset: basePosition.position.offset,
        extentOffset: extentPosition.position.offset,
        affinity: extentPosition.position.affinity,
      ),
    );
  }

  @override
  TableNodeSelection getSelectionInRange(
    Offset localBaseOffset,
    Offset localExtentOffset,
  ) {
    throw UnimplementedError();
  }

  @override
  TableNodeSelection getSelectionOfEverything() {
    final selection = TextNodeSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    return TableNodeSelection(
      index: 0,
      selection: selection,
    );
  }

  TableRowNodePosition? getPositionOneLineDown(NodePosition position) {
    if (position is! TableRowNodePosition) {
      throw Exception(
        'Expected position of type TableNodePosition but received ${position.runtimeType}',
      );
    }
    final lineDownPos = columnAt(position.index)
        .currentState!
        .getPositionOneLineDown(position.position);
    if (lineDownPos == null) return null;
    return TableRowNodePosition(
      index: position.index,
      position: lineDownPos,
    );
  }

  @override
  TableRowNodePosition? movePositionDown(NodePosition textNodePosition) {
    if (textNodePosition is! TableRowNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.position.offset < 0 ||
        textNodePosition.position.offset > text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineDown = getPositionOneLineDown(textNodePosition);
    if (positionOneLineDown == null) {
      return null;
    }
    return TableRowNodePosition.fromTextPosition(
      positionOneLineDown.index,
      positionOneLineDown.position,
    );
  }

  TableRowNodePosition getPositionAtStartOfLine(
    TableRowNodePosition position,
  ) {
    final childKey = columnAt(position.index);
    return TableRowNodePosition(
      index: position.index,
      position:
          childKey.currentState!.getPositionAtStartOfLine(position.position),
    );
  }

  @override
  TableRowNodePosition? movePositionLeft(
    NodePosition position, [
    MovementModifier? movementModifier,
  ]) {
    if (position is! TableRowNodePosition) {
      return null;
    }

    final childKey = columnAt(position.index);
    final newPosition = childKey.currentState!.movePositionLeft(
      position.position,
      movementModifier,
    ) as TextNodePosition?;
    if (newPosition == null && position.index > 0) {
      final newIndex = position.index - 1;
      final endPosition =
          columnAt(newIndex).currentState!.getEndPosition() as TextNodePosition;
      return TableRowNodePosition(
        index: newIndex,
        position: endPosition,
      );
    }
    return newPosition == null
        ? null
        : TableRowNodePosition(index: position.index, position: newPosition);
  }

  TableRowNodePosition getPositionAtEndOfLine(TableRowNodePosition position) {
    final childKey = columnAt(position.index);
    return TableRowNodePosition(
      index: position.index,
      position: TextNodePosition.fromTextPosition(
        childKey.currentState!.getPositionAtEndOfLine(position.position),
      ),
    );
  }

  @override
  TableRowNodePosition? movePositionRight(
    NodePosition position, [
    MovementModifier? movementModifier,
  ]) {
    if (position is! TableRowNodePosition) {
      return null;
    }

    final childKey = columnAt(position.index);
    final newPosition = childKey.currentState!.movePositionRight(
      position.position,
      movementModifier,
    ) as TextNodePosition?;
    if (newPosition == null && position.index < 1) {
      return TableRowNodePosition(
        index: 1,
        position: const TextNodePosition(offset: 0),
      );
    }
    return newPosition == null
        ? null
        : TableRowNodePosition(index: position.index, position: newPosition);
  }

  TableRowNodePosition? getPositionOneLineUp(NodePosition position) {
    if (position is! TableRowNodePosition) {
      throw Exception(
        'Expected position of type TableNodePosition but received ${position.runtimeType}',
      );
    }
    final childKey = columnAt(position.index);
    final newPosition =
        childKey.currentState!.getPositionOneLineUp(position.position);
    if (newPosition == null) return null;
    return TableRowNodePosition(index: position.index, position: newPosition);
  }

  @override
  TableRowNodePosition? movePositionUp(NodePosition textNodePosition) {
    if (textNodePosition is! TableRowNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.position.offset < 0 ||
        textNodePosition.position.offset > text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    return getPositionOneLineUp(textNodePosition);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, text) in widget.columns.indexed)
          TableColumn(
            key: _childKeys[index],
            isFirst: widget.tableStatus.isFirst,
            text: text,
            textStyleBuilder: widget.textStyleBuilder,
            selection: widget.selection?.index == index
                ? widget.selection!.selection
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
        textStyleBuilder: widget.textStyleBuilder,
        textSelection: widget.selection,
        showDebugPaint: false,
      ),
    );
  }
}

class TableRowNodePosition extends NodePosition {
  TableRowNodePosition({required this.index, required this.position});

  final int index;
  final TextNodePosition position;

  static TableRowNodePosition fromTextPosition(
      int index, TextPosition position) {
    return TableRowNodePosition(
      index: index,
      position: TextNodePosition.fromTextPosition(position),
    );
  }
}

class TableNodeSelection extends NodeSelection {
  TableNodeSelection({
    required this.index,
    required this.selection,
  });

  final int index;
  final TextNodeSelection? selection;

  static TableNodeSelection fromTextSelection(
    int index,
    TextSelection textSelection,
  ) =>
      TableNodeSelection(
        index: index,
        selection: TextNodeSelection.fromTextSelection(textSelection),
      );

  static TableNodeSelection collapsed({
    required int index,
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) =>
      TableNodeSelection(
        index: index,
        selection: TextNodeSelection.collapsed(
          offset: offset,
          affinity: affinity,
        ),
      );
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
  TableNodeSelection? selection;
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
