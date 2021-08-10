import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:native_add/native_add.dart';
import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform.isX
import 'package:process_run/shell.dart';

enum LineType {
  COMMAND, STDOUT, STDERR
}

class LineData {
  String text;
  LineType type;
  LineData({
    required this.text,
    required this.type
  });
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<LineData> logLines = [];
  final _listController = ScrollController();
  var _isRunning = false;
  Process? currentProcess;
  var _inputController1 = TextEditingController(
    text: '-c 192.168.10.100'
  );
  var _inputController2 = TextEditingController(
    text: '-t10 -P2 -i1'
  );

  @override
  void initState() {
    super.initState();
  }

  callIperf() async {
    setState(() {
      logLines.clear();
      _isRunning = true;
    });

    var command = _inputController1.text + " " + _inputController2.text;

    logLines.add(LineData(
        text: 'iperf3 $command --force-flush',
        type: LineType.COMMAND
    ));

    // currentProcess = await NativeCode.runIperf(
    //   command: command,
    //   onMessage: (String text, bool error) {
    //     setState(() {
    //       var lines = text.split("\n");
    //       lines.forEach((line) {
    //         logLines.add(LineData(
    //             text: line,
    //             type: error ? LineType.STDERR : LineType.STDOUT
    //         ));
    //       });
    //
    //     });
    //
    //     Timer(Duration(milliseconds: 300),
    //       () => _listController.jumpTo(_listController.position.maxScrollExtent),
    //     );
    //   },
    //   onComplete: () {
    //     setState(() {
    //       _isRunning = false;
    //     });
    //   }
    // );

    IperfCommandData commandData = IperfCommandData(
        command: command,
        onMessage: (String text, bool error) {
          setState(() {
            var lines = text.split("\n");
            lines.forEach((line) {
              logLines.add(LineData(
                  text: line,
                  type: error ? LineType.STDERR : LineType.STDOUT
              ));
            });

          });

          Timer(Duration(milliseconds: 300),
                () => _listController.jumpTo(_listController.position.maxScrollExtent),
          );
        },
        onComplete: () {
          setState(() {
            _isRunning = false;
          });
        }
    );

    await NativeCode.runIperf2(commandData);
  }

  void cancelRunning() {
    currentProcess?.kill(ProcessSignal.sigint);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TVA Iperf Test'),
        ),
        body: Container(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inputController1,
                  decoration: InputDecoration(
                    labelText: 'Command part 1',
                  ),
                ),
                TextField(
                  controller: _inputController2,
                  decoration: InputDecoration(
                    labelText: 'Command part 2',
                  ),
                ),
                ElevatedButton(
                  onPressed: _isRunning ? cancelRunning : callIperf,
                  child: Text(_isRunning ? 'Cancel' : 'Run'),
                  style: ElevatedButton.styleFrom(
                      primary: _isRunning ? Colors.deepOrange : Theme.of(context).primaryColor
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.grey.withOpacity(0.2),
                    child: ListView.builder(
                      controller: _listController,
                      padding: EdgeInsets.zero,
                      itemCount: logLines.length,
                      itemBuilder: (context, index) {
                        var data = logLines[index];
                        return Text(
                          '${data.text}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            color: getLineColor(data)
                          ),
                        );
                      },
                    ),
                  ),
                )
                //
              ],
            ),
          ),
        ),
      ),
    );
  }

  getLineColor(LineData data) {
    switch(data.type) {
      case LineType.COMMAND:
        return Colors.blue;
      case LineType.STDERR:
        return Colors.red;
      case LineType.STDOUT:
      default:
        return Colors.black;
    }
  }
}
