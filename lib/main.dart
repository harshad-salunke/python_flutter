import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite/tflite.dart';
import 'package:tflite/tflite.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    requestPermission();
  }

  void RunPythoncode(BuildContext context) {
    processPythoncode();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        title: Text(widget.title),
      ),
      body: Center(
    child: Text("No image selected.")

    ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          //run python code function
          RunPythoncode(context);
        },
        tooltip: 'Python',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> processPythoncode() async {
    Directory directory = await getApplicationDocumentsDirectory();
    print("directory path "+directory.path);
    ProcessResult processResult = await Process.run(
      'python',
      [
        'assets/python/my_python_code.py'
      ],
    );

    // Extract the color data from the Python script output
    print(processResult.stdout);

    print(processResult.stderr);

    final colorData = processResult.stdout.toString();

    // Show the color data in a dialog box
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Image Colors'),
        content: Text("python code output ==: "'$colorData'),
      ),
    );
  }



  Future<void> requestPermission() async {
    var status = await Permission.storage.request();
    if (status.isDenied) {
      // Handle denied permission
    } else if (status.isPermanentlyDenied) {
      // Handle permanently denied permission
    }
  }

  void checkTflite() async {
 var d=   StrpDetection("tflite/model.tflite","assets/tflite/dict.txt",0);

  }


}


class StrpDetection {
  Interpreter? _interpreter;
  List? _inputDetails;
  List? _outputDetails;
  List<String>? labels;
  double? threshold;
  bool? initialization;
  var modelPath;
  var dicpath;
  StrpDetection(this. modelPath, this. dicpath, this. threshold) {
    print("in constructor");
    _initialize(modelPath, dicpath, threshold!);
  }

  void _initialize(String modelPath, String dictPath, double threshold) async {
    try {

      _interpreter = await Interpreter.fromAsset(modelPath);
      _interpreter?.allocateTensors();
      _inputDetails = _interpreter?.getInputTensors();
      _outputDetails = _interpreter?.getOutputTensors();
      labels=[];
      labels?.add("background");
      labels?.add("contour");
      labels?.add("strip");
      this.threshold = threshold;
      initialization = true;
      print("all initialized");
    } catch (e) {
      print("INIT FAILED: $e");
      initialization = false;
    }
  }


 Future<List> runFromLocal() async {
   //  print("initialization "+initialization.toString());
   // if (!initialization!) {
   //   return [{"error": "Failed to initialize StripDetection object"}];
   // }
   final bytes = await getImageBytesFromAsset("assets/img.jpeg");
   final image = imglib.decodeImage(bytes.toList())!;
   final rotatedImage = imglib.copyRotate(image, 90);
   final inputImage = imglib.copyRotate(rotatedImage, 90);
   print(_inputDetails![0].shape);// convert to RGB
   final resizedImage = imglib.copyResize(inputImage, width: _inputDetails![0].shape[1], height: _inputDetails![0].shape[2]);
    print(resizedImage);
   List<Map<String, dynamic>> prediction = run(resizedImage);
    List<dynamic> data=cropImagesOnPrediction(resizedImage,prediction);
    print("data is"+ data.toString());
   return data;
 }
 Future<Uint8List> getImageBytesFromAsset(String assetPath) async {
   final data = await rootBundle.load(assetPath);
   return data.buffer.asUint8List();
 }
 // function to crop images on prediction
  List<Map<String, dynamic>> cropImagesOnPrediction(imglib.Image image, List<Map<String, dynamic>> prediction) {
    final imageCandidates = <Map<String, dynamic>>[];

    int stripIndex;
    int counterIndex;

    for (final data in prediction.reversed) {
      final box = data['box'];

      final ymin = (box[0] * image.height).toInt();
      final xmin = (box[1] * image.width).toInt();
      final ymax = (box[2] * image.height).toInt();
      final xmax = (box[3] * image.width).toInt();

      final croppedImage = imglib.copyCrop(image, xmin, ymin, xmax - xmin, ymax - ymin);

      if (data['label'] == 'strip') {
        imageCandidates.add({'label': 'strip', 'image': makeStripVertical(croppedImage)});
        stripIndex = imageCandidates.length - 1;
      }
    }

    return imageCandidates;
  }

  imglib.Image makeStripVertical(imglib.Image image) {
    if (image.width < image.height) {
      return imglib.copyRotate(image, 270);
    } else {
      return image;
    }
  }

  List<Map<String, dynamic>> run(imglib.Image image) {
    _interpreter?.run(_inputDetails![0].index,expandDims(image.data,0));
    final outputLocations = _interpreter?.getOutputTensor(0).data as Float32List;
    final outputLabels = _interpreter?.getOutputTensor(1).data as Float32List;
    final outputScores = _interpreter?.getOutputTensor(2).data as Float32List;

    final predictions = <Map<String, dynamic>>[];

    for (int i = 0; i < outputScores.length; i++) {
      if (outputScores[i] >= threshold!) {
        final labelOffset = (i * (1 + labels!.length));
        final classIndex = 1 + outputLabels[labelOffset].toInt();
        final score = outputScores[i];

        final rectOffset = labelOffset + 1;
        final rect = Float32List.sublistView(outputLocations, rectOffset, rectOffset + 4);

        predictions.add({'box': rect, 'label': labels![classIndex], 'score': score});
      }
    }

    return predictions;
  }

  Uint32List expandDims(Uint32List image, int axis) {
    var expandedImage = <int>[];
    for (var i = 0; i < axis; i++) {
      expandedImage.addAll(image);
    }
    expandedImage.addAll(image);
    for (var i = axis; i < 3; i++) {
      expandedImage.addAll(image);
    }
    return Uint32List.fromList(expandedImage);
  }


}






