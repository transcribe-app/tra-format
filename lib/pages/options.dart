import '/utils/app_log.dart';
import '/utils/sugar.dart' as sugar;
import 'package:easy_localization/easy_localization.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import 'package:solidart_hooks/solidart_hooks.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import '/utils/app_prefs.dart';
import '/config.dart';

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  OptionsPageState createState() => OptionsPageState();

}

class OptionsPageState extends State<OptionsPage> {

  @override 
  dynamic deactivate() {
    // final appState = vAppStateProvider.of(context);
    // unawaited(saveAppStateToPrefs(appState));
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final appState = vAppStateProvider.of(context);
    final stateChange = Computed(() => appState.stateChange.value);
    return SignalBuilder( builder: (context, child) { 
      stateChange();
      return LayoutGrid(
        areas: '''
          op_lng_t op_lng_v
          op_thm_t op_thm_v
          op_fzs_t op_fzs_v
          op_apl_t op_apl_v
        ''',
        columnSizes: [1.fr, 150.px],
        rowSizes: [
          48.px,
          48.px,
          48.px,
          48.px
        ],
        columnGap: 6,
        rowGap: 6,
        children: [

          Align(alignment: Alignment.centerLeft, child: Text(context.tr('opt:Interface Language')))
          .inGridArea('op_lng_t'),
          Align(alignment: Alignment.center, child: SizedBox(width: double.infinity, child:Select<Locale>(
            value: appState.uiLang,
            itemBuilder: (BuildContext context, Locale item) { return Text(context.tr("lng:"+item.languageCode)); },
            popupWidthConstraint: PopoverConstraint.anchorFixedSize,
            onChanged: (value) {
              if (value != null) {
                appState.uiLang = value;
                context.setLocale(appState.uiLang);
                bumpAppState(appState, true);
              }
            },
            popup: SelectPopup(
                items: SelectItemList(children: [
                  for (var item in AppConfig.supportedLocales)
                    SelectItemButton(
                      value: item,
                      child: Text(context.tr("lng:"+item.languageCode)),
                    ),
                ])),
          )))
          .inGridArea('op_lng_v'),

          Align(alignment: Alignment.centerLeft, child:Text(context.tr('opt:Color Theme')))
          .inGridArea('op_thm_t'),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: double.infinity, child:Select<int>(
            value: appState.uiTheme,
            itemBuilder: (BuildContext context, int item_id) { var item=AppConfig.supportedThemes[item_id]; return Text(context.tr("opt:thm:${item[0]}")); },
            popupWidthConstraint: PopoverConstraint.anchorFixedSize,
            onChanged: (item_id) {
              if (item_id != null) {
                appState.uiTheme = item_id;
                bumpAppState(appState, true, expectAnimMs:1000);
              }
            },
            popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final (item_id, item) in sugar.enumerate(AppConfig.supportedThemes))
                    SelectItemButton(
                      value: item_id,
                      child: Text(context.tr("opt:thm:${item[0]}")),
                    ),
                ])),
          )))
          .inGridArea('op_thm_v'),
          
          Align(alignment: Alignment.centerLeft, child:Text(context.tr('opt:Viewer Font Size')))
          .inGridArea('op_fzs_t'),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: double.infinity, child:Select<int>(
            value: appState.uiViewerFontMode,
            itemBuilder: (BuildContext context, int item_id) { var item=AppConfig.supportedFontModes[item_id]; return Text(context.tr("opt:fzs:${item[0]}")); },
            popupWidthConstraint: PopoverConstraint.anchorFixedSize,
            onChanged: (item_id) {
              if (item_id != null) {
                appState.uiViewerFontMode = item_id;
                bumpAppState(appState, true, expectAnimMs:1000);
              }
            },
            popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final (item_id, item) in sugar.enumerate(AppConfig.supportedFontModes))
                    SelectItemButton(
                      value: item_id,
                      child: Text(context.tr("opt:fzs:${item[0]}")),
                    ),
                ])),
          )))
          .inGridArea('op_fzs_v'),

          Align(alignment: Alignment.centerLeft, child: Text(context.tr('opt:Application Logs')))
          .inGridArea('op_apl_t'),
          Align(alignment: Alignment.centerRight, child: SecondaryButton(
            child: const Text('Save'),
            onPressed: () {
              sendLogsWithEmail();
            },
          ))
          .inGridArea('op_apl_v'),

          // Container(color: Colors.red)
          // .inGridArea('o_btm')

        ]
      );
    });
  }
  // );}
}