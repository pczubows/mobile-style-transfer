import 'dart:math';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart';

abstract class Model{
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;

  late List<int> _inputShape;
  late List<int> _outputShape;

  late TensorImage _inputImage;
  late TensorBuffer _outputBuffer;

  late TfLiteType _inputType;
  late TfLiteType _outputType;

  String get modelName;

  NormalizeOp get preProcessNormalizeOp;

  Model(){
    _interpreterOptions = InterpreterOptions();
  }

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset(modelName, options: _interpreterOptions);

    _inputShape = interpreter.getInputTensor(0).shape;
    _outputShape = interpreter.getOutputTensor(0).shape;
    _inputType = interpreter.getInputTensor(0).type;
    _outputType = interpreter.getOutputTensor(0).type;

    _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
  }

  TensorImage _preProcess() {
    int cropSize = min(_inputImage.height, _inputImage.width);
    return ImageProcessorBuilder()
        .add(ResizeWithCropOrPadOp(cropSize, cropSize))
        .add(ResizeOp(
        _inputShape[1], _inputShape[2], ResizeMethod.NEAREST_NEIGHBOUR))
        .add(preProcessNormalizeOp)
        .build()
        .process(_inputImage);
  }

  void close(){
    interpreter.close();
  }

}

class StylePredictionModel extends Model{
  static final StylePredictionModel _instance = StylePredictionModel._internal();
  StylePredictionModel._internal() : super();

  factory StylePredictionModel(){
    return _instance;
  }

  @override
  String get modelName => '256_fp16_prediction.tflite';

  @override
  NormalizeOp get preProcessNormalizeOp => NormalizeOp(127.5, 127.5);

  List predict(Image image){
    _inputImage = TensorImage(_inputType);
    _inputImage.loadImage(image);
    _inputImage = _preProcess();

    interpreter.run(_inputImage.buffer, _outputBuffer.getBuffer());

    return _outputBuffer.getDoubleList();
  }
}

class StyleTransferModel extends Model{
  static final StyleTransferModel _instance = StyleTransferModel._internal();
  StyleTransferModel._internal() : super();

  factory StyleTransferModel(){
    return _instance;
  }

  @override
  get modelName => '256_fp16_transfer.tflite';

  @override
  NormalizeOp get preProcessNormalizeOp => NormalizeOp(127.5, 127.5);

  Image? predict(Image image, List style){
    _inputImage = TensorImage(_inputType);
    _inputImage.loadImage(image);
    _inputImage = _preProcess();

    List<Object> inputs = [_inputImage.buffer, style];
    Map<int, ByteBuffer> outputs = {0: _outputBuffer.getBuffer()};

    interpreter.runForMultipleInputs(inputs, outputs);

    print(outputs[0]!.asFloat32List());

    TensorImage outputImage = TensorImage(_outputType);
    outputImage.loadTensorBuffer(_outputBuffer);
    outputImage = ImageProcessorBuilder().add(NormalizeOp(127.5, 127.5)).build().process(outputImage);
    print(outputImage.buffer.asFloat32List());
    return outputImage.image;
  }
}

