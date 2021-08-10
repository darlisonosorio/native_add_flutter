import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

class InParams {
  String path;
  SendPort configPort;
  SendPort dataPort;
  int bufferSize;
  int pollingInterval;

  InParams({
    required this.path,
    required this.configPort,
    required this.dataPort,
    required this.bufferSize,
    required this.pollingInterval
  });
}

void performRead (InParams params) {
  var cancelled = false;
  ReceivePort inPort = ReceivePort();
  inPort.listen((message) {
    cancelled = true;
  });
  params.configPort.send(inPort.sendPort);

  var file = File(params.path);
  file.open().asStream().forEach((ramFile) async { 
    Timer.periodic(
      Duration(milliseconds: params.pollingInterval),
      (timer) async {
        if(cancelled) { 
          timer.cancel();
          return;
        }

        var bytes = await ramFile.read(params.bufferSize);
        if(bytes.length > 0) {
          params.dataPort.send(bytes);
          // stderr.write(utf8.decode(bytes));
        } else {
          // await Future.delayed(Duration.zero);
        }
      }
    );
    // while(true) {
    //   var byte = ramFile.readByteSync();
    //   // if(byte > 0) {
    //   //   params.dataPort.send([byte]);
    //   // } else {
    //   //   continue;
    //   // }
    //   if(byte > 0) {
    //     stderr.write(utf8.decode([byte]));
    //     // params.dataPort.send([byte]);
    //   } else {
    //     // stderr.write('.');
    //   }
    // }
  });
}

class InfiniteFileReader {
  String path;
  int bufferSize;
  int pollingInterval;
  SendPort? _inPort;
  Isolate? _isolate;
  Function(Uint8List bytes)? rawDataCallback;
  Function(String text)? stringDataCallback;

  InfiniteFileReader(this.path, {
    this.bufferSize: 500,
    this.pollingInterval: 100,
    this.rawDataCallback,
    this.stringDataCallback
  });

  void addRawDataListener(Function(Uint8List bytes) callback) {
    this.rawDataCallback = callback;
  }

  void addStringDataListener(Function(String text) callback) {
    this.stringDataCallback = callback;
  }

  Future<void> startReading() async {
    ReceivePort configPort = ReceivePort();
    ReceivePort dataPort = ReceivePort();
    configPort.listen((message) {
      _inPort = message;
    });
    dataPort.listen((bytes) {
      stderr.writeln("got data");
      rawDataCallback?.call(bytes);
      stringDataCallback?.call(utf8.decode(bytes));
    });
    var inParams = InParams(
      path: this.path,
      configPort: configPort.sendPort,
      dataPort: dataPort.sendPort,
      bufferSize: bufferSize,
      pollingInterval: pollingInterval
    );
    _isolate = await Isolate.spawn(performRead, inParams);
  }

  void stopReading() {
    this._inPort?.send(true);
    this._isolate?.kill();
  }
}