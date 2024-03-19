// Copyright (C) 2023 Sumo Apps.

// Application implementing native Metal rendering to a
// Flutter texture. Implements simple interactivity between
// the Flutter UI and the backend Metal code.

// Depends on platform specific Flutter Runner implementations
// that create the backend metal texture and render graphics to it.
//
// The Flutter UI implemented here renders that native GPU backend
// drawn texture as a Texture Widget.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Default application background color.
const appBgColor = 0xFF383838;

// Build in animation length in ms.
const buildInAnimLength = 2700;

void main() {
  runApp(const VPTVideoRendererApp());
}

// Displays and runs a triangle rendered with native code, displayed
// inside a Flutter Texture widget.
class VPTVideoRendererApp extends StatelessWidget {
  const VPTVideoRendererApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sumo Cube Render App',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          )),

      // Create the UI and initialize application.
      home: const CubeToTexture(),
    );
  }
}

// Widget for triangle to texture renderer.
class CubeToTexture extends StatefulWidget {
  const CubeToTexture({super.key});

  @override
  State<CubeToTexture> createState() => _CubeToTextureState();
}

// State for the triangle to texture renderer.
//
class _CubeToTextureState extends State<CubeToTexture>
    with TickerProviderStateMixin {
  // Flutter texture id received from the flutter texture registry.
  // Backed up by a native texture.
  int? _flutterTextureId;

  // Dimensions of the texture for render results.
  final int _textureWidth = 720;
  final int _textureHeight = 720;

  // Create the communication channel to the native code.
  static const MethodChannel _channel = MethodChannel('VPTTextureRender');

  // Called after initialization.
  @override
  void initState() {
    // Create the native Metal backed flutter texture.
    createFlutterTexture();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_flutterTextureId != null) {
      // Display triangle in the texture widget.
      return triangleTextureView();
    } else {
      // Display loading screen while creating backend texture.
      return LoadingScreenWidget(onPressed: () => load());
    }
  }

  // Main view widget for displaying a triangle rendered within a flutter texture,
  // with controls and UI elements to support it.
  Widget triangleTextureView() {
    var flutterTextureId = _flutterTextureId;
    return Scaffold(
        backgroundColor: const Color(appBgColor),
        body: Container(
            alignment: Alignment.center,

            // Background gradient.
            decoration: const BoxDecoration(
                gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Color(appBgColor),
              ],
            )),

            // Contain the widgets in a stack for freeform positioning and drawing on top of each other.
            child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                fit: StackFit.loose,
                textDirection: TextDirection.rtl,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 1,
                    child: RepaintBoundary(
                      // Contains the native texture backed Flutter texture.
                      child: SizedBox(
                          width: _textureWidth.toDouble(),
                          height: _textureHeight.toDouble(),
                          child: Container(
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.red, width: 1)),
                              child: Texture(textureId: flutterTextureId!))),
                    ),
                  ),

                  // Text array.

                  Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Animation for moving the text header 1.
                        TweenAnimationBuilder(
                            tween: Tween<double>(begin: -100, end: 0.0),
                            duration: const Duration(
                                milliseconds: buildInAnimLength + 30),
                            builder: (BuildContext context, double tweenValue,
                                Widget? child) {
                              return Transform.translate(
                                  offset: Offset(tweenValue, 0.0),
                                  child: const Align(
                                    alignment: Alignment(0.25, -0.83),
                                    child: Text('VPTVideo',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 39,
                                          fontFamily: "Georgia",
                                        )),
                                  ));
                            }),

                        // Animation for moving the text header 2.
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 150, end: 0.0),
                          duration: const Duration(
                              milliseconds: buildInAnimLength + 30),
                          builder: (BuildContext context, double tweenValue,
                              Widget? child) {
                            return Transform.translate(
                              offset: Offset(tweenValue, 0.0),
                              child: const Align(
                                alignment: Alignment(0.65, -0.72),
                                child: Text('Renderer',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontFamily: "Georgia",
                                    )),
                              ),
                            );
                          },
                        ),
                        Positioned(
                            bottom: 29,
                            child: Row(children: <Widget>[
                              ElevatedButton(
                                  onPressed: () =>
                                      {print("Launching"), load(), start()},
                                  child: const Text('Start')),
                            ])),
                      ]) // Stack.
                ]) // Stack.

            ));
  }

  // Creates a flutter texture and stores the texture id got from the created flutter texture.
  Future<void> createFlutterTexture() async {
    final textureId = await _channel.invokeMethod("createFlutterTexture",
        {"width": _textureWidth, "height": _textureHeight});
    // The flutter texture is backed by a native platform dependent texture, that is registered
    // on the native backend to the flutter texture registry.
    setState(() {
      _flutterTextureId = textureId;
    });
    print("Texture ID: $_flutterTextureId");
  }

  Future<void> load() async {
    print("Calling");
    try {
      await _channel.invokeMethod("load", null);
    } catch (e) {
      print("Error: $e");
    }
    ;
    final data = await _channel.invokeMethod("load", null);

    //await _channel.invokeMethod("start");
    print("Data: $data");
  }

  // Gets the animation velocity parameter from the native side.
  Future<void> start() async {}

  // Gets the animation velocity parameter from the native side.
  Future<void> stop() async {
    await _channel.invokeMethod("stop");
  }
}

// Loading screen view widget for displaying while creating the
// native flutter texture.
class LoadingScreenWidget extends StatelessWidget {
  final void Function()? onPressed;
  const LoadingScreenWidget({
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(appBgColor),

        // Displays empty screen with gradient background.
        body: Stack(
            alignment: Alignment.center,
            fit: StackFit.loose,
            clipBehavior: Clip.hardEdge,
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                  // Background gradient.
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Color(appBgColor),
                ],
              ))),
              ElevatedButton(onPressed: () => onPressed, child: Text("Load"))
            ]));
  }
}
