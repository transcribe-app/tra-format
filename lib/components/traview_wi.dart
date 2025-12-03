// Uses https://pub.dev/packages/super_editor
// ALSO: https://github.com/AppFlowy-IO/appflowy-editor
import 'dart:math';
import 'dart:async';

import '/utils/app_log.dart';
import '/utils/sugar.dart' as sugar;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;

import '/gen/assets.gen.dart';
import '/gen/colors.gen.dart';

import '/config.dart';
import '/utils/app_prefs.dart';
import '/utils/file_tra.dart';

import 'package:g_json/g_json.dart';
import 'package:super_editor/super_editor.dart';
import 'package:audioplayers/audioplayers.dart';

bool prepareDocumentNodes(TraData data){
  // debugPrint("- prepareDocumentNodes");
  List<DocumentNode> nodes = [];
  data.enodes = nodes;
  List<JSON> deltaContent = data.deltaContent;
  // Detecting max speaker number
  // Filling fedaults for ts/te
  var maxSpeaker = 0;
  var lst_wr_ts = data.duration.toDouble();
  for(var deltaLine in deltaContent.reversed){
    if(deltaLine["ph"].integerValue > 0){
      maxSpeaker = max(maxSpeaker, deltaLine["sp"].integerValue);
    }
    if(deltaLine["wr"].string != null){
      if(deltaLine["te"].ddouble == null){
        // ts of next word
        deltaLine["te"] = lst_wr_ts;
      }
      if(deltaLine["ts"].ddouble != null){
        lst_wr_ts = deltaLine["ts"].ddoubleValue;
      }
    }
  }
  var tsWordLvl = true;
  if(data.deltaHeader["tm"].stringValue == "char"){
    tsWordLvl = false;
  }
  JSON ph_init = JSON({});
  var ph_init_ts = -1.0;
  var ph_init_te = -1.0;
  var ph_text = "";
  AttributedSpans ph_text_spans = AttributedSpans();
  void pushLastParagraph() {
    if(ph_text.isNotEmpty){
      var line_ph = "";
      if(maxSpeaker > 0){
        var line_sp = ph_init["sp"].integerValue;
        line_ph = "Speaker: ${line_sp}";// Not working in isolation: tr("Speaker: {}", args:[line_sp.toString()]);
      }
      if(ph_init["he"].string != null){
        line_ph = ph_init["he"].stringValue;
      }
      var line_ts = ph_init["ts"].ddouble ?? ph_init_ts;
      var line_te = ph_init["te"].ddouble ?? ph_init_te;
      AttributedSpans line_spans = AttributedSpans();
      // debugPrint(//- ph ${sugar.strFromSec(ph_init_ts.toInt())}-${sugar.strFromSec(ph_init_te.toInt())} ${line_ph}");
      line_spans.addAttribution(newAttribution: TimeAttribution(ts:line_ts, te:line_te), start: 0, end: line_ph.length-1);
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(line_ph, line_spans),
        metadata: {
          NodeMetadata.blockType: header1Attribution
        },
      ));
      // debugPrint("// wr ${sugar.strFromSec((ph_text_spans.markers.toList()[0].attribution as TimeAttribution).ts.toInt())} ${ph_text}");
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(ph_text, ph_text_spans)
      ));
    }
    ph_init = JSON({});
    ph_init_ts = -1;
    ph_init_te = -1;
    ph_text = "";
    ph_text_spans = AttributedSpans();
  }
  for(var deltaLine in deltaContent){
    if(deltaLine["doc"].string != null){
      continue;
    }
    if(deltaLine["ph"].integerValue > 0){
      pushLastParagraph();
      ph_init = deltaLine;
      continue;
    }
    var line_wr = deltaLine["wr"].stringValue;
    if(line_wr.isNotEmpty){
      var line_ts = deltaLine["ts"].ddoubleValue;
      var line_te = deltaLine["te"].ddoubleValue;
      if(ph_init_ts < 0){
        ph_init_ts = max(ph_init_ts,line_ts);
      }
      ph_init_te = max(ph_init_te,line_te);
      var len_pre = ph_text.length;
      if(tsWordLvl){
        line_wr = line_wr.trim();
        // Extra space if there is no space/new lines in line_wr
        if(len_pre > 0){
          ph_text = ph_text+" ";
        }
      }
      ph_text = ph_text+line_wr;
      var len_post = ph_text.length-1;
      // debugPrint("// span ${line_wr} ${line_ts}:${line_te}");
      ph_text_spans.addAttribution(newAttribution: TimeAttribution(ts:line_ts, te:line_te), start: len_pre, end: len_post);
    }
  }
  pushLastParagraph();
  return true;
}

class TimeAttribution implements Attribution {
  final double ts;
  final double te;

  TimeAttribution({
    required this.ts,
    required this.te,
  });

  @override
  String get id => 'wts';

  @override
  bool canMergeWith(Attribution other) {
    return this == other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || 
      (other is TimeAttribution && runtimeType == other.runtimeType
      && sugar.sameFloat(this.ts, other.ts) && sugar.sameFloat(this.te, other.te));

  @override
  int get hashCode => (ts*1000).toInt()+(te*10000).toInt();
}

class ParagraphHeaderComponentBuilder implements ComponentBuilder {
  const ParagraphHeaderComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    // This component builder can work with the standard paragraph view model.
    // We'll defer to the standard paragraph component builder to create it.
    return null;
  }

  @override
  Widget? createComponent(SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel) {
    if (componentViewModel is! ParagraphComponentViewModel) {
      return null;
    }

    final blockAttribution = componentViewModel.blockType;
    if (!(const [header1Attribution, header2Attribution, header3Attribution]).contains(blockAttribution)) {
      return null;
    }
    var headerText = componentViewModel.text.toPlainText();
    var headerTime = "";
    var headerSpans = componentViewModel.text.spans.markers.toList();
    if(headerSpans.isNotEmpty && headerSpans[0].attribution is TimeAttribution){
      var spm = headerSpans[0].attribution as TimeAttribution;
      var spm_ts = spm.ts.toInt();
      if(spm_ts >= 0) {
        headerTime = sugar.strFromSec(spm_ts);
      }
    }
    return BoxComponent(
      key: componentContext.componentKey,
      isVisuallySelectable: false,
      opacity: 0.7,
      child:Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.fromLTRB(5,30,5,5),
              child: Row(children:[
                (headerTime.isNotEmpty?Text(headerTime).muted().large():Gap(0)),
                (headerTime.isNotEmpty?Gap(5):Gap(0)),
                Text(headerText).large()
              ]),
            ),
            Divider(),
            Gap(5)
          ]
    ));
  }
}

class TraViewWi extends StatefulHookWidget {
  final AudioPlayer player;
  final TraData data;
  const TraViewWi({
    required this.player,
    required this.data,
    super.key
  });

  @override
  TraViewWiState createState() => TraViewWiState();
}

class TraViewWiState extends State<TraViewWi> {
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  SuperReader? _superreader;
  late ScrollController _scrollController;
  final GlobalKey _docLayoutKey = GlobalKey();
  final GlobalKey _editorKey = GlobalKey();
  StreamSubscription? _positionSubscription;
  final whitespace_cn = ["\n".codeUnitAt(0)," ".codeUnitAt(0)];
  var lastAutoScrollTimeStamp = 0;
  void highligtWordAt(double p_sec){
    // Simulating selection change
    // Other options: LeaderLink/LayerLink/positioned rect
    // https://pub.dev/packages/follow_the_leader - LeaderLink
    // https://github.com/Flutter-Bounty-Hunters/super_editor/blob/8de15834fbc1237bb31c4d81a377dff6dd74f9ea/super_editor/example/lib/demos/in_the_lab/feature_stable_tags.dart
    if(widget.data.enodes == null || widget.player.state == PlayerState.stopped || widget.player.state == PlayerState.completed){
      _composer.clearSelection();
      _composer.setComposingRegion(null);
      return;
    }
    var enodes = widget.data.enodes!;
    DocumentNode? target_node;
    SpanMarker? target_span_f;
    SpanMarker? target_span_e;
    for(var dn in enodes){
      if(dn is ParagraphNode){
        if(dn.metadata[NodeMetadata.blockType] == header1Attribution){
          continue;
        }
        var dnSpans = dn.text.spans.markers.toList();
        if(dnSpans.isNotEmpty && dnSpans[0].attribution is TimeAttribution){
          for(var spn in dnSpans){
            var spn_ta = spn.attribution as TimeAttribution;
            if(p_sec >= spn_ta.ts && p_sec < spn_ta.te){
              target_node = dn;
              if(spn.isStart){
                target_span_f = spn;
              }
              if(spn.isEnd){
                target_span_e = spn;
              }
            }
          }
          if(target_span_f != null && target_span_e != null){
            // debugPrint("// span ${p_sec} ${target_span_f.offset}-${target_span_e.offset}");
            break;
          }
        }
      }
    }
    // var headerSpans = componentViewModel.text.spans.markers.toList();
    // if(headerSpans.isNotEmpty && headerSpans[0].attribution is TimeAttribution){
    //   var spm = headerSpans[0].attribution as TimeAttribution;
    //   var spm_ts = spm.ts.toInt();
    //   if(spm_ts >= 0) {
    //     headerTime = sugar.strFromSec(spm_ts);
    //   }
    // }
    if(target_node == null || target_span_f == null || target_span_e == null){
      _composer.clearSelection();
      _composer.setComposingRegion(null);
      return;
    }
    // Adjusting to avoid selecting newlines at start etc
    var pt_f = target_span_f.offset;
    var pt_f_check = true;
    var pt_e = target_span_e.offset;
    var pt_e_check = true;
    var pt_text = target_node.asTextNode.text.toPlainText();
    for(var i=0;i <= pt_e-pt_f;i++){
      if(pt_f_check && !whitespace_cn.contains(pt_text.codeUnitAt(pt_f+i))){
        pt_f = pt_f+i;
        pt_f_check = false;
      }
      if(pt_e_check && !whitespace_cn.contains(pt_text.codeUnitAt(pt_e-i))){
        pt_e = pt_e-i;
        pt_e_check = false;
      }
      if(!pt_f_check && !pt_e_check){
        break;
      }
    }
    _composer.setSelectionWithReason(DocumentSelection(base: DocumentPosition(nodeId: target_node.id, nodePosition: TextNodePosition(offset: pt_f)), extent: DocumentPosition(nodeId: target_node.id, nodePosition: TextNodePosition(offset: pt_e+1))));
    _composer.setComposingRegion(null);
    if(sugar.unixstamp() - lastAutoScrollTimeStamp > 3){
      lastAutoScrollTimeStamp = sugar.unixstamp();
      scrollToNode(target_node.id);
    }
  }

  void scrollToNode(String nodeId) {
    // https://github.com/Flutter-Bounty-Hunters/super_editor/issues/2371
    // https://stackoverflow.com/questions/78900243/how-do-i-scroll-to-a-documentnode-or-get-its-vertical-offset-in-flutter-super-e
    final node = _document.getNodeById(nodeId);
    final documentLayout = _docLayoutKey.currentState as DocumentLayout?;
    final RenderBox? renderBox = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    double docHeight = 0;
    if (renderBox != null) {
      docHeight = renderBox.size.height;
    }

    if (node != null) {
      final rect = documentLayout?.getRectForPosition(
        DocumentPosition(nodeId: nodeId, nodePosition: node.beginningPosition),
      );
      // Scroll to the node.
      if (rect != null) {
        double scrollToHeight = rect.top-rect.height*0.5-docHeight*0.5;
        if(scrollToHeight > docHeight*0.1){
          _scrollController.animateTo(
            scrollToHeight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if(widget.data.enodes == null){
      prepareDocumentNodes(widget.data);
    }
    List<DocumentNode> nodes = widget.data.enodes ?? [];

    _document = MutableDocument(nodes: nodes);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _document, composer: _composer);
    _scrollController = ScrollController();
    _positionSubscription = widget.player.onPositionChanged.listen((p) {
      highligtWordAt(p.inMilliseconds/1000.0);
    });
  }

  @override
  void dispose() {
    _superreader = null;
    _positionSubscription?.cancel();
    _scrollController.dispose();
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiTheme = Theme.of(context);
    // final uiBgColor = ColorName.tbgWhite; //ColorName.tfgGray,
    final uiBgColor = uiTheme.colorScheme.background;
    var traTitle = widget.data.title;
    if(_superreader == null)
    {
      // Avoiding recreations on theme/etc rebuilds
      // SuperReader construction can be lengthy on long documents
      SelectionStyles uiSelSt = SelectionStyles(selectionColor: uiTheme.colorScheme.mutedForeground);
      var uiTextStyle = resolveUiViewerFontMode(context);
      final Stylesheet traStylesheet = defaultStylesheet.copyWith(
        documentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 40),
        rules: [
          StyleRule(
            BlockSelector.all, // Matches all nodes
            (document, node) { 
              return {
                Styles.textStyle: TextStyle(color: uiTextStyle.color, fontSize: uiTextStyle.fontSize, fontFamily: uiTextStyle.fontFamily),
              };
            },
          )
        ]
      );
      _superreader = SuperReader(
        editor: _editor,
        scrollController: _scrollController,
        documentLayoutKey: _docLayoutKey,
        stylesheet: traStylesheet,
        selectionStyle: uiSelSt,
        // overlayController: _overlayController,
        componentBuilders: [
          ParagraphHeaderComponentBuilder(),
          ...defaultComponentBuilders,
        ],
      );
    }
    return 
      Container(
        color: uiBgColor,
        padding: EdgeInsets.fromLTRB(3,5,3,0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(0,5,0,9),
              child: Text(traTitle).large().medium(),
            ),
            Divider(thickness:2),
            Expanded(
              key: _editorKey,
              child: _superreader!
            )
          ]
        )
      );
  }
}