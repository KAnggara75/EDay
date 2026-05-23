import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eday/features/camera/camera_controller.dart';
import 'package:eday/features/camera/camera_model.dart';

class MockCameraModel extends Mock implements CameraModel {}

void main() {
  late MockCameraModel mockModel;
  late CameraControllerHolder controllerHolder;

  setUp(() {
    mockModel = MockCameraModel();
    controllerHolder = CameraControllerHolder(mockModel);
  });

  group('CameraControllerHolder Tests', () {
    test('initial states are correct', () {
      expect(controllerHolder.isInit, false);
      expect(controllerHolder.isProcessing, false);
      expect(controllerHolder.showGuideline, true);
      expect(controllerHolder.previewImagePath, null);
      expect(controllerHolder.guidelineBytes, null);
      expect(controllerHolder.isLoadingGuideline, false);
      expect(controllerHolder.controller, null);
    });

    test('toggleGuideline changes state and notifies listeners', () {
      bool notified = false;
      controllerHolder.addListener(() {
        notified = true;
      });

      controllerHolder.toggleGuideline();
      expect(controllerHolder.showGuideline, false);
      expect(notified, true);

      controllerHolder.toggleGuideline();
      expect(controllerHolder.showGuideline, true);
    });
  });
}
