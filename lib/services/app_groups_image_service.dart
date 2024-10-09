import 'dart:io';
import 'dart:ui';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:live_activities/models/live_activity_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

const kPictureFolderName = 'LiveActivitiesPictures';

class AppGroupsImageService {
  String? appGroupId;
  final List<String> _assetsCopiedInAppGroups = [];

  Future sendImageToAppGroups(Map<String, dynamic> data) async {
    if (appGroupId == null) {
      throw Exception('appGroupId is null. Please call init() first.');
    }

    for (String key in data.keys) {
      final value = data[key];

      if (value is LiveActivityImage) {
        String? sharedDirectory = await PathProviderFoundation().getContainerPath(
          appGroupIdentifier: appGroupId!,
        );
        Directory appGroupPicture = Directory('${sharedDirectory!}/$kPictureFolderName');
        Directory tempDir = await getTemporaryDirectory();

        // create directory if not exists
        appGroupPicture.createSync();

        late File file;
        late String fileName;
        if (value is LiveActivityImageFromAsset) {
          fileName = (value.path.split('/').last);
        } else if (value is LiveActivityImageFromUrl) {
          fileName = (value.url.split('/').last);
        } else if (value is LiveActivityImageFromMemory) {
          fileName = value.imageName;
        }

        final bytes = await value.loadImage();
        file = await File('${tempDir.path}/$fileName').create();
        file.writeAsBytesSync(bytes);

        if (value.resizeFactor != 1) {
          final buffer = await ImmutableBuffer.fromUint8List(bytes);
          final descriptor = await ImageDescriptor.encoded(buffer);
          final imageWidth = descriptor.width;
          final imageHeight = descriptor.height;

          assert(
            imageWidth > 0,
            'Please make sure you are using an image that is not corrupt or too small',
          );

          final targetWidth = (imageWidth * value.resizeFactor).round();

          final finalDestination = '${appGroupPicture.path}/$fileName';

          await FlutterImageCompress.compressAndGetFile(
            file.path,
            finalDestination,
            minWidth: targetWidth,
            minHeight: (imageHeight * targetWidth / imageWidth).round(),
          );

          file.copySync(finalDestination);

          data[key] = finalDestination;
          _assetsCopiedInAppGroups.add(finalDestination);
        }

        // remove file from temp directory
        file.deleteSync();
      }
    }
  }

  Future<void> removeAllImages() async {
    final sharedDirectory = await PathProviderFoundation().getContainerPath(
      appGroupIdentifier: appGroupId!,
    );
    final laPictureDir = Directory('${sharedDirectory!}/$kPictureFolderName');
    laPictureDir.deleteSync(recursive: true);
  }

  Future<void> removeImagesSession() async {
    for (String filePath in _assetsCopiedInAppGroups) {
      final file = File(filePath);
      await file.delete();
    }
  }
}
