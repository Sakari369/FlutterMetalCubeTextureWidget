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
  runApp(const SumoCubeRenderApp());
}

// Displays and runs a triangle rendered with native code, displayed
// inside a Flutter Texture widget.
class SumoCubeRenderApp extends StatelessWidget {
  const SumoCubeRenderApp({ super.key });

  @override Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Sumo Cube Render App',
      theme: ThemeData(
          primarySwatch: Colors.blue,

          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          )
      ),

      // Create the UI and initialize application.
      home: const CubeToTexture(),
    );
  }
}

// Widget for triangle to texture renderer.
class CubeToTexture extends StatefulWidget {
  const CubeToTexture({ super.key });

  @override State<CubeToTexture> createState() => _CubeToTextureState();
}

// State for the triangle to texture renderer.
//
class _CubeToTextureState extends State<CubeToTexture> with TickerProviderStateMixin {
  // Animation controller for scaling the layer.
  late AnimationController _textureScaleAnimator;

  @override void dispose() {
    _textureScaleAnimator.dispose();
    super.dispose();
  }

  // Flutter texture id received from the flutter texture registry.
  // Backed up by a native texture.
  int? _flutterTextureId;

  // Dimensions of the texture for render results.
  final int _textureWidth = 720;
  final int _textureHeight = 720;

  // Animation velocity slider.
  double _sliderVal = 0.0;

  // Create the communication channel to the native code.
  static const MethodChannel _channel = MethodChannel('Sumo_CubeRenderApp');

  // Called after initialization.
  @override void initState() {
    // Create the native Metal backed flutter texture.
    createFlutterTexture();

    // Start texture scaling animation.
    _textureScaleAnimator = AnimationController(
        duration: const Duration(milliseconds: buildInAnimLength),
        lowerBound: 0.0, upperBound: 1.0,
        vsync: this)
      ..forward();

    super.initState();

    // Read in animation velocity value from the native code.
    getAnimationVelocity();
  }

  @override Widget build(BuildContext context) {
    if (_flutterTextureId != null) {
      // Display triangle in the texture widget.
      return triangleTextureView();
    } else {
      // Display loading screen while creating backend texture.
      return const LoadingScreenWidget();
    }
  }

  // Main view widget for displaying a triangle rendered within a flutter texture,
  // with controls and UI elements to support it.
  Widget triangleTextureView() {
    var flutterTextureId = _flutterTextureId;

    return Scaffold(
        backgroundColor: const Color(appBgColor),

        body:
        Container(
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
                )
            ),

            // Contain the widgets in a stack for freeform positioning and drawing on top of each other.
            child:
            Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                fit: StackFit.loose,
                textDirection: TextDirection.rtl,

                children:
                <Widget> [
                  // Setup animation for scaling the Flutter texture towards the user.
                  AnimatedBuilder(
                    animation: _textureScaleAnimator,

                    builder: (BuildContext context, Widget? child) {

                      return Transform.scale(
                        scale: _textureScaleAnimator.value,
                        child: child,
                      );
                    },

                    // Contain the Flutter texture in a square aspect ratio.
                    child:
                    AspectRatio(
                      aspectRatio: 1,

                      child:
                      RepaintBoundary(

                        // Contains the native texture backed Flutter texture.
                        child:
                        SizedBox(
                            width: _textureWidth.toDouble(),
                            height: _textureHeight.toDouble(),
                            child: Texture(textureId: flutterTextureId!)
                        ),
                      ),
                    ),

                  ),
                  // Text array.

                  Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,

                      children:
                      <Widget>[
                        // Animation for moving the text header 1.
                        TweenAnimationBuilder(
                            tween: Tween<double>(begin: -100, end: 0.0),
                            duration: const Duration(milliseconds: buildInAnimLength + 30),

                            builder:(BuildContext context, double tweenValue, Widget? child) {

                              return Transform.translate(
                                  offset: Offset(tweenValue, 0.0),

                                  child:
                                  const Align(
                                    alignment: Alignment(0.25, -0.83),

                                    child:
                                    Text('SumoRenderer',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 39,
                                          fontFamily: "Georgia",
                                        )
                                    ),
                                  )
                              );

                            }
                        ),

                        // Animation for moving the text header 2.
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 150, end: 0.0),
                          duration: const Duration(milliseconds: buildInAnimLength + 30),

                          builder: (BuildContext context, double tweenValue, Widget? child) {
                            return Transform.translate(
                              offset: Offset(tweenValue, 0.0),

                              child:
                              const Align(
                                alignment: Alignment(0.65, -0.72),

                                child:
                                Text('Cube',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontFamily: "Georgia",
                                    )
                                ),
                              ),

                            );
                          },
                        ),
                        Positioned(
                            bottom: 29,

                            child:
                            Row(
                                children:
                                <Widget> [
                                  const Text(
                                      "velocity",
                                      textAlign: TextAlign.center
                                  ),

                                  Slider(
                                    value: _sliderVal,
                                    label: _sliderVal.toString(),

                                    min: 0.0,
                                    max: 300.0,

                                    onChanged: (double value) {
                                      setState(() {
                                        _sliderVal = value;
                                        setAnimationVelocity(_sliderVal);
                                      });
                                    },
                                  ),

                                  Text(
                                      _sliderVal.round().toString(),
                                      textAlign: TextAlign.center
                                  )

                                ]
                            )
                        ),

                      ]
                  ) // Stack.

                ]
            ) // Stack.

        )
    );
  }

  // Creates a flutter texture and stores the texture id got from the created flutter texture.
  Future<void> createFlutterTexture() async {
    // The flutter texture is backed by a native platform dependent texture, that is registered
    // on the native backend to the flutter texture registry.
    var textureId = await _channel.invokeMethod("createFlutterTexture", {
      "width": _textureWidth,
      "height": _textureHeight
    });

    // Store received texture id from the flutter texture registry.
    setState(() { _flutterTextureId = textureId; });
  }

  // Sets the animation velocity parameter on the native side.
  Future<void> setAnimationVelocity(double velocity) async {
    _channel.invokeMethod("setAnimationVelocity", { "velocity": velocity });
  }

  // Gets the animation velocity parameter from the native side.
  Future<void> getAnimationVelocity() async {
    var velocity = await _channel.invokeMethod("getAnimationVelocity", null);
    // Update slider value from animation velocity.
    setState(() { _sliderVal = velocity; });
  }
}

// Loading screen view widget for displaying while creating the
// native flutter texture.
class LoadingScreenWidget extends StatelessWidget {
  const LoadingScreenWidget({
    Key? key,
  }) : super(key: key);

  @override Widget build(BuildContext context) {

    return Scaffold(
        backgroundColor: const Color(appBgColor),

        // Displays empty screen with gradient background.
        body: Stack(
            alignment: Alignment.center,
            fit: StackFit.loose,
            clipBehavior: Clip.hardEdge,
            textDirection: TextDirection.rtl,

            children:
            <Widget> [

              Container (
                // Background gradient.
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,

                        colors: [
                          Colors.black,
                          Color(appBgColor),
                        ],
                      )
                  )
              ),

            ]
        )
    );

  }
}