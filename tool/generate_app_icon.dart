import 'dart:io';
import 'package:image/image.dart' as img;

bool _isNearWhite(int r, int g, int b, {int threshold = 245}) {
  return r >= threshold && g >= threshold && b >= threshold;
}

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'assets/icons/app_icon.png';
  final outputPath =
      args.length >= 2 ? args[1] : 'assets/icons/app_icon_cropped.png';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input icon not found: $inputPath');
    exit(1);
  }

  final bytes = inputFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exit(1);
  }

  final width = decoded.width;
  final height = decoded.height;

  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = decoded.getPixel(x, y);
      final a = p.a.toInt();
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      // Treat transparent OR near-white pixels as "background".
      if (a == 0 || _isNearWhite(r, g, b)) continue;

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  // If we couldn't find any non-background pixels, just copy/resize the input.
  if (maxX < 0 || maxY < 0) {
    final resized = img.copyResize(
      decoded,
      width: 1024,
      height: 1024,
      interpolation: img.Interpolation.cubic,
    );
    File(outputPath).writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('Wrote icon: $outputPath (no crop detected)');
    return;
  }

  final boxW = (maxX - minX + 1);
  final boxH = (maxY - minY + 1);
  final boxMax = boxW > boxH ? boxW : boxH;
  final margin = (boxMax * 0.06).round(); // small margin to avoid touching edges

  final cropX = (minX - margin).clamp(0, width - 1);
  final cropY = (minY - margin).clamp(0, height - 1);
  final cropW = (boxW + margin * 2).clamp(1, width - cropX);
  final cropH = (boxH + margin * 2).clamp(1, height - cropY);

  final cropped = img.copyCrop(
    decoded,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );

  // Center on a square canvas, then upscale to 1024x1024.
  final side = cropped.width > cropped.height ? cropped.width : cropped.height;
  final canvas = img.Image(width: side, height: side, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final dx = ((side - cropped.width) / 2).round();
  final dy = ((side - cropped.height) / 2).round();
  img.compositeImage(canvas, cropped, dstX: dx, dstY: dy);

  final out = img.copyResize(
    canvas,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );

  File(outputPath).writeAsBytesSync(img.encodePng(out));
  stdout.writeln('Wrote icon: $outputPath');
}

