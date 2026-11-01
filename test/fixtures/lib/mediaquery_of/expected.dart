import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as w;

import 'fake_media_query.dart' as fake;

class Sample extends StatelessWidget {
  const Sample({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context); // LINT
    final width = MediaQuery.widthOf(context); // LINT
    final height = MediaQuery.heightOf(context); // LINT
    final ratio = MediaQuery.sizeOf(context).aspectRatio; // LINT
    final top = MediaQuery.paddingOf(context).top; // LINT
    final keyboard = MediaQuery.viewInsetsOf(context).bottom; // LINT
    final scaler = MediaQuery.textScalerOf(context); // LINT
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark; // LINT
    final prefixed = w.MediaQuery.sizeOf(context); // LINT
    final both = MediaQuery.widthOf(context) + MediaQuery.paddingOf(context).left; // LINT
    final multiline = MediaQuery.orientationOf( // LINT
      context,
    );

    // Saved in a variable, and only its fields are read.
    final fromVariable = MediaQuery.widthOf(context) + MediaQuery.paddingOf(context).top;
    // Read later in a callback: suggest only.
    final later = MediaQuery.of(context); // LINT
    void onTap() => debugPrint('${later.size}');

    // Must not change: whole MediaQueryData is used, or it's not Flutter's MediaQuery.
    final data = MediaQuery.of(context);
    final copy = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
    final maybe = MediaQuery.maybeOf(context)?.size;
    final notFlutter = fake.MediaQuery.of(context).size;
    final theme = Theme.of(context).colorScheme;
    // Silenced with an ignore comment, on the line or the line above.
    final ignored = MediaQuery.of(context).size; // dejank:ignore mediaquery-of
    // dejank:ignore
    final ignoredAll = MediaQuery.of(context).padding;
    final otherRule = MediaQuery.sizeOf(context); // dejank:ignore image-cache-size // LINT

    return Text(
      '$size $width $height $ratio $top $keyboard $scaler $dark $prefixed $both $multiline '
      '$data $copy $maybe $notFlutter $theme $fromVariable ${onTap.hashCode}',
    );
  }
}
