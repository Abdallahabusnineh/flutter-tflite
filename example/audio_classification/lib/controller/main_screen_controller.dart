import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/audio_helper/audio_classification_helper.dart';

class MainScreenController extends GetxController {
  static const platform =
      MethodChannel('org.tensorflow.audio_classification/audio_record');
  final sampleRate = 16000; // 16kHz
  static const expectAudioLength = 975; // milliseconds
  final int requiredInputBuffer = (16000 * (expectAudioLength / 1000)).toInt();
  late AudioClassificationHelper helper;
  List<MapEntry<String, double>> classification = List.empty();
  final List<Color> primaryProgressColorList = [
    const Color(0xFFF44336),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF3F51B5),
    const Color(0xFF2196F3),
    const Color(0xFF00BCD4),
    const Color(0xFF009688),
    const Color(0xFF4CAF50),
    const Color(0xFFFFEB3B),
    const Color(0xFFFFC107),
    const Color(0xFFFF9800)
  ];
  final List<Color> backgroundProgressColorList = [
    const Color(0x44F44336),
    const Color(0x44E91E63),
    const Color(0x449C27B0),
    const Color(0x443F51B5),
    const Color(0x442196F3),
    const Color(0x4400BCD4),
    const Color(0x44009688),
    const Color(0x444CAF50),
    const Color(0x44FFEB3B),
    const Color(0x44FFC107),
    const Color(0x44FF9800)
  ];
  bool showError = false;



  @override
  void onInit() {
    // TODO: implement onInit
    initRecorder();
    super.onInit();
  }




  @override
  void onReady() {
    // TODO: implement onReady

  }

  @override
  void onClose() {
    // TODO: implement onClose
    closeRecorder();
    super.onClose();
  }






  void startRecorder() {
    try {
      print('start record');
      platform.invokeMethod('startRecord');
    } on PlatformException catch (e) {
      log("Failed to start record: '${e.message}'.");
    }
    update();
  }

  Future<bool> requestPermission() async {
    try {
      return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
        "sampleRate": sampleRate,
        "requiredInputBuffer": requiredInputBuffer
      });
    } on Exception catch (e) {
      log("Failed to create recorder: '${e.toString()}'.");
      return false;
    }
  }

  Future<Float32List> getAudioFloatArray() async {
    var audioFloatArray = Float32List(0);
    try {
      final Float32List result =
            await platform.invokeMethod('getAudioFloatArray');
      audioFloatArray = result;
      print('get audio float array');
    } on PlatformException catch (e) {
      log("Failed to get audio array: '${e.message}'.");
    }
    return audioFloatArray;
  }

  Future<void> closeRecorder() async {
    try {
      await platform.invokeMethod('closeRecorder');
      helper.closeInterpreter();
    } on PlatformException {
      log("Failed to close recorder.");
    }
  }

  Future<void> initRecorder() async {
    helper = AudioClassificationHelper();
    await helper.initHelper();
    bool success = await requestPermission();
    print("success abd  ${success}");
    if (success) {
      startRecorder();
      Timer.periodic(const Duration(milliseconds: expectAudioLength), (timer) {
        // classify here
        runInference();
      });
    } else {
      // show error here
      showError = true;
    }
  }

  Future<void> runInference() async {
    Float32List inputArray = await getAudioFloatArray();
    final result =
        await helper.inference(inputArray.sublist(0, requiredInputBuffer));
    // take top 3 classification
    classification = (result.entries.toList()
          ..sort(
            (a, b) => a.value.compareTo(b.value),
          ))
        .reversed
        .take(3)
        .toList();
    update();
    //log(classification());
  }
}
