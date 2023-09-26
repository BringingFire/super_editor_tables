import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_tables/super_editor_tables.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final MutableDocumentComposer _composer;
  late final MutableDocument _document;
  late final Editor _editor;

  @override
  void initState() {
    _document = MutableDocument(
      nodes: [
        ParagraphNode(id: Editor.createNodeId(), text: AttributedText()),
        TableRowNode(
          id: Editor.createNodeId(),
          columns: [
            AttributedText('foo'),
            AttributedText('bar'),
          ],
        ),
        ParagraphNode(id: Editor.createNodeId(), text: AttributedText()),
      ],
    );
    _composer = SpyComposer(
      initialSelection: DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: _document.nodes.first.id,
          nodePosition: _document.nodes.first.endPosition,
        ),
      ),
    );
    _editor = Editor(
      editables: {
        Editor.documentKey: _document,
        Editor.composerKey: _composer,
      },
      requestHandlers: List.from(defaultRequestHandlers),
      reactionPipeline: List.from([
        ...defaultEditorReactions,
        const TableConversionReaction(),
      ]),
    );
    super.initState();
  }

  @override
  void dispose() {
    _composer.dispose();
    _document.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SuperEditor(
        composer: _composer,
        document: _document,
        editor: _editor,
        inputSource: TextInputSource.ime,
        componentBuilders: [
          ...defaultComponentBuilders,
          const TableRowComponentBuilder(),
        ],
        imeOverrides: _MyImeDecorator(),
      ),
    );
  }
}

class _MyImeDecorator extends DeltaTextInputClientDecorator {
  @override
  void performSelector(String selectorName) {
    print('performSelector($selectorName)');
    super.performSelector(selectorName);
  }
}

class SpyComposer extends MutableDocumentComposer {
  SpyComposer({required super.initialSelection});

  @override
  void setSelectionWithReason(DocumentSelection? newSelection,
      [Object reason = SelectionReason.userInteraction]) {
    print(newSelection);
    super.setSelectionWithReason(newSelection, reason);
  }
}
