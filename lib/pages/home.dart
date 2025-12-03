import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:solidart_hooks/solidart_hooks.dart';

import 'package:file_picker/file_picker.dart';
import '/gen/assets.gen.dart';
import '/gen/colors.gen.dart';
import '/utils/app_prefs.dart';
import '/utils/desktop_misc.dart';
import '/utils/file_tra.dart';
import '/utils/file_mp3.dart';
import '/pages/options.dart';
import '/config.dart';
import '/utils/sugar.dart' as sugar;
import '/components/aplayer_wi.dart' as APlayerWi;
import '/components/traview_wi.dart' as TraViewWi;

class TraOrPickWi extends HookWidget {
  const TraOrPickWi({super.key});

  static Future<void> doOpenFile(BuildContext context, Signal<int> isLoading) async {
    final appState = vAppStateProvider.of(context);
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: kIsAndroid ? FileType.any : FileType.custom,
      allowedExtensions: kIsAndroid ? [] : ["tra","mp3"],
      withData: true,
    );
    if (result != null) {
      // File file = File(result.files.single.path!);
      Uint8List bytes;
      final file = result.files.first;
      if (file.bytes != null) {
        // file.size
        isLoading.value = 1;
        bytes = file.bytes!;
        if(file.name.toLowerCase().contains('tra')){
          parseTraWithCallback(bytes, (TraStatus status, TraData? data) {
            isLoading.value = 0;
            if (status != TraStatus.ok){
              appShowAlert(context, context.tr('Warning'), context.tr('Failed to load file'));
              return;
            }
            appState.activeTra = data;
            bumpAppState(appState, true);
          });
          return;
        }
        if(file.name.toLowerCase().contains('mp3')){
          parseMp3WithCallback(file.name, bytes, (TraStatus status, TraData? data) {
            isLoading.value = 0;
            if (status != TraStatus.ok){
              appShowAlert(context, context.tr('Warning'), context.tr('Failed to load file'));
              return;
            }
            appState.activeTra = data;
            bumpAppState(appState, true);
          });
          return;
        }
      }
    }
    // Unknown format / User canceled the picker
    if(context.mounted){
      appShowAlert(context, context.tr('Warning'), context.tr('Please select file'));
    }
  }

  static Future<void> doCloseFile(BuildContext context) async {
    final appState = vAppStateProvider.of(context);
    appState.activeTra = null;
    bumpAppState(appState, true);
  }

  @override
  Widget build(BuildContext context) {
    final appState = vAppStateProvider.of(context);
    final uiTheme = Theme.of(context);
    var uiTextStyle = resolveUiViewerFontMode(context);
    var utx_half = uiTextStyle.copyWith(color: uiTheme.colorScheme.accentForeground.withValues(alpha:0.3));
    final isLoading = useSignal(0);
    final stateChange = Computed(() => appState.stateChange.value);
    return SignalBuilder( builder: (context, child) { 
      stateChange();
      if(isLoading.value > 0 || sugar.unixstamp_ms() < appState.globalAnimationEndExpectancy){
        return Theme(data:uiTheme, child:
          Center(child:Wrap(
            direction: Axis.vertical,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: [
              CircularProgressIndicator(size: 48)
            ])));
      }
      if(appState.activeTra == null){
        final uiBgColor = uiTheme.colorScheme.background;
        return Theme(data:uiTheme, child:
          // Center(child:Column(
          //   mainAxisAlignment: material.MainAxisAlignment.center,
          //   crossAxisAlignment: CrossAxisAlignment.center,
          //   spacing:10,
          //   children: [
          //     Gap(40),
          //     PrimaryButton(
          //       size: ButtonSize.large,
          //       child: Text(context.tr('bt:Open File')),
          //       onPressed: () async {
          //         if(isLoading.value > 0){
          //           return;
          //         }
          //         await doOpenFile(context, isLoading);
          //       },
          //     ),
          //     Gap(20),// SizedBox(height: 20),
          //     Text(context.tr('Pick a file to play'), style: utx_half ),
          //     MaxGap(999),
          //     Text(context.tr('Supported formats: TRA, MP3 with LyricsV3'), style: utx_half ).small(),
          //     Gap(20)
          //   ],
          // ));
          Container(
            color: uiBgColor,
            padding: EdgeInsets.fromLTRB(3,5,3,5),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(0,5,0,9),
                  child: Text(context.tr('No file selected'), style: utx_half )
                ),
                Divider(thickness:2),
                Gap(5),
                Expanded(child: Center(child:
                  PrimaryButton(
                    size: ButtonSize.large,
                    child: Text(context.tr('bt:Open File')),
                    onPressed: () async {
                      if(isLoading.value > 0){
                        return;
                      }
                      await doOpenFile(context, isLoading);
                    },
                  )
                )),
                // MaxGap(999),
                Text(context.tr('Supported formats: {}', args: ["TRA, MP3+LRC/Lyrics"]), style: utx_half ).small(),
                Gap(5),
              ]
            )
          ));
      }
      var aplayer = APlayerWi.g_sys_player;
      return Theme(data:uiTheme, child:
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children:[Expanded(child: TraViewWi(player: aplayer))])),
            Expanded(child: SizedBox(width: double.infinity, child: TraViewWi.TraViewWi(player: aplayer, data: appState.activeTra!))),
            APlayerWi.APlayerWi(player: aplayer, data: appState.activeTra!, key: APlayerWi.g_widget_key),
          ]
        ));
    });
  }
}

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = vAppStateProvider.of(context);
    final uiTheme = Theme.of(context);
    return Theme(data:uiTheme, child:
      Stack(children:[
        TraOrPickWi(),
        Positioned(
          top: 5,
          right: 5,
          child: IconButton.outline(
            key: const Key('options_button'),
            onPressed: () {
                // showDialog(
                //   context: context,
                //   builder: (context) {
                //     final FormController controller = FormController();
                //     return AlertDialog(
                //       title: Text(context.tr('Options')),
                //       content: OptionsPage(),
                //       actions: [
                //         PrimaryButton(
                //           child: Text(context.tr('Close')),
                //           onPressed: () {
                //             Navigator.of(context).pop(controller.values);
                //           },
                //         ),
                //       ],
                //     );
                //   },
                // );
                openSheet(
                  context: context,
                  builder: (context) {
                    // Build the sheet content; keep it small and focused on the form.
                    // pausing player if it is playing already - via widget
                    // var aplayer = APlayerWi.g_sys_player;
                    // aplayer.pause();
                    var playerWi = APlayerWi.g_widget_key.currentState;
                    if(playerWi != null){
                      playerWi.doPause();
                    }
                    final uiTheme = Theme.of(context);
                    return Theme(data:uiTheme, child:
                      Container(
                        padding: const EdgeInsets.all(24),
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(context.tr('Options')).large().medium(),
                                ),
                                TextButton(
                                  density: ButtonDensity.icon,
                                  child: const Icon(Icons.close),
                                  onPressed: () {
                                    // Close the sheet without saving.
                                    closeSheet(context);
                                  },
                                ),
                              ]
                            ),
                            Divider(),
                            const Gap(20),
                            OptionsPage(),
                            const MaxGap(9999),
                            appState.activeTra == null? const Gap(20): Center(child:SecondaryButton(
                              child: Text(context.tr('bt:Close File')),
                              onPressed: () async {
                                if(context.mounted){
                                  await TraOrPickWi.doCloseFile(context);
                                }
                                if(context.mounted){
                                  closeSheet(context);
                                }
                              }))
                          ]
                        )
                      ));
                  },
                  // Slide in from the end (right on LTR).
                  position: OverlayPosition.end,
                );
            },
            size: ButtonSize.small,
            density: ButtonDensity.icon,
            icon: Assets.icons.uiGear.svg(
                colorFilter: const ColorFilter.mode(ColorName.tfgGray, BlendMode.srcIn),
                width: 16.0, height: 16.0
            ),
          )),
      ]));
    }
}