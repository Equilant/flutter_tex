import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_tex/src/utils/core_utils.dart';
import 'package:webview_flutter_plus/webview_flutter_plus.dart';

class TeXViewState extends State<TeXView> with AutomaticKeepAliveClientMixin {
  late WebViewControllerPlus _controller;

  double _height = minHeight;
  String? _lastData;
  bool _pageLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _controller = WebViewControllerPlus()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Color(Colors.transparent.value))
      ..loadFlutterAsset(
          "packages/flutter_tex/js/${widget.renderingEngine?.name ?? 'katex'}/index.html")
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: widget.onNavigationRequest,
          onPageFinished: (String url) {
            _pageLoaded = true;
            _initTeXView();
          },
        ),
      )
      ..setOnConsoleMessage((message) {
        if (kDebugMode) {
          print(message);
        }
      })
      ..addJavaScriptChannel('OnTapCallback', onMessageReceived: (jm) {
        widget.child.onTapCallback(jm.message);
      })
      ..addJavaScriptChannel('TeXViewRenderedCallback',
          onMessageReceived: (jm) async {
        double height = double.parse(jm.message);
        if (_height != height) {
          setState(() {
            _height = height + 24;
          });
        }
        final width = await getOptimizedContentWidth();

        widget.onRenderFinished?.call(height, width);
      });
    super.initState();
  }

  Future<double> getOptimizedContentWidth() async {
    String getContentWidthScript = r"""
      var element = document.body;
      var contentWidth = element.scrollWidth;
      var style = window.getComputedStyle(element);
      var totalMargin = ['left', 'right']
          .map(function (side) {
              return parseInt(style["margin-" + side]);
          })
          .reduce(function (total, side) {
              return total + side;
          }, contentWidth);
      totalMargin;
  """;

    String getMaxWidthScript = r"""
      var elements = document.getElementsByTagName('*');
      var maxWidth = 0;
      for (var i = 0; i < elements.length; i++) {
          maxWidth = Math.max(maxWidth, elements[i].scrollWidth);
      }
      maxWidth;
  """;

    final isAndroid = Platform.isAndroid;
    var totalMargin =
        await _controller.runJavaScriptReturningResult(getContentWidthScript);
    var maxWidth =
        await _controller.runJavaScriptReturningResult(getMaxWidthScript);

    if (isAndroid) {
      totalMargin = totalMargin as int;
      maxWidth = maxWidth as int;
      return totalMargin > maxWidth
          ? totalMargin.toDouble()
          : maxWidth.toDouble();
    } else {
      totalMargin = totalMargin as double;
      maxWidth = maxWidth as double;
      return totalMargin > maxWidth ? totalMargin : maxWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateKeepAlive();
    _initTeXView();
    return IndexedStack(
      index: widget.loadingWidgetBuilder?.call(context) != null
          ? _height == minHeight
              ? 1
              : 0
          : 0,
      children: <Widget>[
        SizedBox(
          height: _height,
          child: WebViewWidget(
            controller: _controller,
          ),
        ),
        widget.loadingWidgetBuilder?.call(context) ?? const SizedBox.shrink()
      ],
    );
  }

  @override
  void dispose() {
    _controller.server.close();
    super.dispose();
  }

  void _initTeXView() {
    if (_pageLoaded && getRawData(widget) != _lastData) {
      if (widget.loadingWidgetBuilder != null) _height = minHeight;
      _controller
          .runJavaScriptReturningResult("initView(${getRawData(widget)})");
      _lastData = getRawData(widget);
    }
  }
}
