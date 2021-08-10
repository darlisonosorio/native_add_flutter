
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart:ffi'; // For FFI
import 'dart:io'; // For Platform.isX
import 'package:ffi/ffi.dart';
import 'package:native_add/read-forever.dart';
import 'package:path_provider/path_provider.dart' as pathProvider;
import 'package:process_run/cmd_run.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/shell.dart';
import 'package:package_info/package_info.dart';
import 'package:path/path.dart';

final DynamicLibrary lib = Platform.isAndroid
    ? DynamicLibrary.open("libnative_add.so")
    : DynamicLibrary.process();

final int Function(int x, int y) nativeAdd = lib
    .lookup<NativeFunction<Int32 Function(Int32, Int32)>>("native_add")
    .asFunction();


final int Function(int argc, Pointer<Pointer<Uint8>> argv) nativeMain = lib
    .lookup<NativeFunction<Int32 Function(Int32, Pointer<Pointer<Uint8>>)>>("main")
    .asFunction();

final int Function() nativeMain2 = lib
    .lookup<NativeFunction<Int32 Function()>>("main")
    .asFunction();

final void Function(Pointer<Utf8>, Pointer<Utf8>) nativeRedirectStreams = lib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>>("redirect_streams")
    .asFunction();

final void Function() nativeRestoreStreams = lib
    .lookup<NativeFunction<Void Function()>>("restore_streams")
    .asFunction();

final void Function(Pointer<Utf8> key, Pointer<Utf8> value) nativeSetEnvVar = lib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>, Pointer<Utf8>)>>("set_env_var")
    .asFunction();

class IperfCommandData {
  String command;
  Function onMessage;
  Function onComplete;

  IperfCommandData({
    required this.command,
    required this.onMessage,
    required this.onComplete
  });
}

class NativeCode {

  static Future<Process> runIperf({
    required String command,
    required Function onMessage,
    required Function onComplete
  }) async {
    const MethodChannel _channel = MethodChannel("br.fpf.tva/iperf");
    var nativeLibDir = await _channel.invokeMethod("getNativeLibraryDir");

    Directory? temp = Platform.isAndroid
        ? await pathProvider.getExternalStorageDirectory() //FOR ANDROID
        : await pathProvider.getApplicationSupportDirectory(); //FOR iOS

    var params = command.split(" ");
    params.insert(0, temp?.absolute.path ?? "");
    params.add("--forceflush");

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    var process = await Process.start("$nativeLibDir/libiperf_bundle.so", params);
    process.stdout.transform(utf8.decoder).forEach((foo) {
      // print("STDOUT: $foo");
      onMessage(foo, false);
    });
    process.stderr.transform(utf8.decoder).forEach((foo) {
      // print("STDERR: $foo");
      onMessage(foo, true);
    });
    process.exitCode.then((value) {
      print("Process finished with $exitCode");
      onComplete();
    });

    return process;
  }

  static Pointer<Uint8> toNat(String foo) {
    return foo.toNativeUtf8().cast();
  }

  static Pointer<Utf8> toNat2(String foo) {
    return foo.toNativeUtf8().cast();
  }

  static _runIperf2(Map data) async {
    print("isolate called with ${data['command']}");

    var cwd = data['temp'];
    var params = data['command'].split(" ");
    params.insert(0, cwd);
    params.add("--forceflush");

    final argv = calloc<Pointer<Uint8>>(params.length);
    for (var i = 0; i < params.length; i++) {
      // argv.elementAt(i).value = params[i].toNativeUtf8().cast();
      argv.elementAt(i).value = toNat(params[i]);
    }

    var nativeOut = File(join(cwd, "stdout.txt"));
    var nativeErr = File(join(cwd, "stderr.txt"));

    var tempVarName = toNat2("TMPDIR");
    var tempDir = toNat2(cwd);
    var stdoutPath = toNat2(nativeOut.absolute.path);
    var stderrPath = toNat2(nativeErr.absolute.path);

    nativeSetEnvVar(tempVarName, tempDir);
    nativeRedirectStreams(stdoutPath, stderrPath);

    var outReader = InfiniteFileReader(nativeOut.absolute.path);
    outReader.addStringDataListener((text) {
      print("STDOUT| $text");
      data['message'].send(text);
    });
    await outReader.startReading();

    // .transform(utf8.decoder)
    // nativeOut.openRead()
    // .listen((msg) {
    //   print("STDOUTz: $msg");
    //   data['message'].send(msg);
    //   // commandData.onMessage(msg, false);
    //   // data['receiver']
    // });

    // nativeErr.openRead().transform(utf8.decoder).listen((msg) {
    //   print("STDERR: $msg");
    //   data['message'].send(msg);
    //   // commandData.onMessage(msg, true);
    // });

    final ret = nativeMain(params.length, argv);
    nativeRestoreStreams();

    outReader.stopReading();
    // commandData.onComplete();
    data['complete'].send(null);


    calloc.free(tempVarName);
    calloc.free(tempDir);
    calloc.free(stdoutPath);
    calloc.free(stderrPath);
    calloc.free(argv);

    print("function return: $ret");
    // print(foo);

    // await kek;
    // await foo;
    return ret;
  }


  static Future<dynamic> runIperf2(IperfCommandData commandData) async {

    Directory? temp = Platform.isAndroid
        ? await pathProvider.getExternalStorageDirectory() //FOR ANDROID
        : await pathProvider.getApplicationSupportDirectory(); //FOR iOS

    ReceivePort receiver1 = ReceivePort();
    receiver1.listen((message) {
      print("GOT ERROR: $message");
    });

    ReceivePort receiver2 = ReceivePort();
    receiver2.listen((message) {
      print("GOT EXIT: $message");
      commandData.onComplete();
    });

    ReceivePort receiver3 = ReceivePort();
    receiver3.listen((message) {
      print("GOT MESSAGE: $message");
      commandData.onMessage(message, false);
    });

    var data = Map();
    data["command"] = commandData.command;
    data["message"] = receiver3.sendPort;
    data["complete"] = receiver2.sendPort;
    data["temp"] = temp?.absolute.path;

    var foo = await Isolate.spawn(_runIperf2, data);
    // var foo = await compute(_runIperf2, data);
    foo.addErrorListener(receiver1.sendPort);
    foo.addOnExitListener(receiver2.sendPort);
    return foo;
    // print("isolate called with $commandData.command");
    //
    // Directory temp = Platform.isAndroid
    //     ? await pathProvider.getExternalStorageDirectory() //FOR ANDROID
    //     : await pathProvider.getApplicationSupportDirectory(); //FOR iOS
    //
    // var cwd = temp.absolute.path;
    // var params = command.split(" ");
    // params.insert(0, cwd);
    // params.add("--forceflush");
    //
    // final argv = calloc<Pointer<Uint8>>(params.length);
    // for (var i = 0; i < params.length; i++) {
    //   argv.elementAt(i).value = params[i].toNativeUtf8().cast();
    // }
    //
    // var nativeOut = File(join(cwd, "stdout.txt"));
    // var nativeErr = File(join(cwd, "stderr.txt"));
    //
    // var tempVarName = "TMPDIR".toNativeUtf8();
    // var tempDir = cwd.toNativeUtf8();
    // var stdoutPath = nativeOut.absolute.path.toNativeUtf8();
    // var stderrPath = nativeErr.absolute.path.toNativeUtf8();
    //
    // nativeSetEnvVar(tempVarName, tempDir);
    // nativeRedirectStreams(stdoutPath, stderrPath);
    //
    // var kek = nativeOut.openRead().transform(utf8.decoder).forEach((data) {
    //   print("STDOUT: $data");
    //   onMessage(data, false);
    // });
    //
    // var foo = nativeErr.openRead().transform(utf8.decoder).forEach((data) {
    //   print("STDERR: $data");
    //   onMessage(data, true);
    // });
    //
    // final ret = nativeMain(params.length, argv);
    // nativeRestoreStreams();
    // onComplete();
    //
    //
    // calloc.free(tempVarName);
    // calloc.free(tempDir);
    // calloc.free(stdoutPath);
    // calloc.free(stderrPath);
    // calloc.free(argv);
    //
    // print("function return: $ret");
    // print(foo);
    //
    // await kek;
    // await foo;
  }
}
