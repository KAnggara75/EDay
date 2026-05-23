import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eday/features/gallery/gallery_controller.dart';
import 'package:eday/features/gallery/gallery_model.dart';

class MockGalleryModel extends Mock implements GalleryModel {}
class MockFile extends Mock implements File {}

void main() {
  late MockGalleryModel mockModel;
  late GalleryController controller;

  setUp(() {
    mockModel = MockGalleryModel();
    controller = GalleryController(mockModel);
  });

  group('GalleryController Tests', () {
    test('initial states are correct', () {
      expect(controller.images, isEmpty);
      expect(controller.isLoading, true);
      expect(controller.isSyncing, false);
      expect(controller.syncTotal, 0);
      expect(controller.syncCurrent, 0);
    });

    test('loadImages populates images and updates loading state', () async {
      final mockFiles = [MockFile(), MockFile()];
      when(() => mockModel.getLocalImages()).thenAnswer((_) async => mockFiles);

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      final future = controller.loadImages();
      expect(controller.isLoading, true);

      await future;

      expect(controller.isLoading, false);
      expect(controller.images, mockFiles);
      expect(notified, true);
    });

    test('syncToGithub handles error when token is null or empty', () async {
      final mockFiles = [MockFile()];
      when(() => mockModel.getLocalImages()).thenAnswer((_) async => mockFiles);
      await controller.loadImages();

      String? receivedError;
      await controller.syncToGithub(
        token: null,
        owner: 'owner',
        repo: 'repo',
        onComplete: () {},
        onError: (err) {
          receivedError = err;
        },
      );

      expect(receivedError, 'GITHUB_PAT not found in .env');
      expect(controller.isSyncing, false);
    });
   group('syncToGithub with files', () {
      test('syncToGithub handles success flow', () async {
        final mockFiles = [MockFile()];
        when(() => mockModel.getLocalImages()).thenAnswer((_) async => mockFiles);
        when(() => mockModel.syncImages(
              any(),
              token: any(named: 'token'),
              owner: any(named: 'owner'),
              repo: any(named: 'repo'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async {});

        await controller.loadImages();
        expect(controller.images, hasLength(1));

        bool completeCalled = false;
        await controller.syncToGithub(
          token: 'token',
          owner: 'owner',
          repo: 'repo',
          onComplete: () {
            completeCalled = true;
          },
          onError: (_) {},
        );

        expect(completeCalled, true);
        expect(controller.isSyncing, false);
      });
    });
  });
}
