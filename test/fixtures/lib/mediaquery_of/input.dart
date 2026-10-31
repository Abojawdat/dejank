import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as w;

import 'fake_media_query.dart' as fake;

class Sample extends StatelessWidget {
  const Sample({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size; // LINT
    final width = MediaQuery.of(context).size.width; // LINT
    final height = MediaQuery.of(context).size.height; // LINT
    final ratio = MediaQuery.of(context).size.aspectRatio; // LINT
    final top = MediaQuery.of(context).padding.top; // LINT
    final keyboard = MediaQuery.of(context).viewInsets.bottom; // LINT
    final scaler = MediaQuery.of(context).textScaler; // LINT
    final dark = MediaQuery.of(context).platformBrightness == Brightness.dark; // LINT
    final prefixed = w.MediaQuery.of(context).size; // LINT
    final both = MediaQuery.of(context).size.width + MediaQuery.of(context).padding.left; // LINT
    final multiline = MediaQuery.of( // LINT
      context,
    ).orientation;

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
    final otherRule = MediaQuery.of(context).size; // dejank:ignore image-cache-size // LINT

    return Text(
      '$size $width $height $ratio $top $keyboard $scaler $dark $prefixed $both $multiline '
      '$data $copy $maybe $notFlutter $theme',
    );
  }
}
