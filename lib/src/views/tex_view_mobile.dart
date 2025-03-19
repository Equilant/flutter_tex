import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:flutter_tex/src/utils/core_utils.dart';
import 'package:webview_flutter_plus/webview_flutter_plus.dart';

class TeXViewState extends State<TeXView> with AutomaticKeepAliveClientMixin {
  late final WebViewControllerPlus _controller;

  double _height = minHeight;
  String? _lastData;
  bool _pageLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewControllerPlus()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Color(Colors.transparent.value))
      ..loadFlutterAsset(
          "packages/flutter_tex/js/${widget.renderingEngine?.name ?? 'katex'}/index.html")
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: widget.onNavigationRequest,
          onPageFinished: (String url) {
            if (!_pageLoaded) {
              _pageLoaded = true;
              Future.delayed(const Duration(milliseconds: 100), _initTeXView);
            }
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
        double newHeight = double.tryParse(jm.message) ?? minHeight;
        if ((_height - newHeight).abs() > 5) {
          setState(() {
            _height = newHeight + 24;
          });
        }
        final width = await getOptimizedContentWidth();

        widget.onRenderFinished?.call(_height, width);
      });
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

    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pageLoaded
            ? SizedBox(
                height: _height,
                child: WebViewWidget(controller: _controller),
              )
            : Center(
                child: SizedBox(
                  height: 40,
                  width: 40,
                  child: widget.loadingWidgetBuilder?.call(context) ??
                      const SizedBox.shrink(),
                ),
              ));
  }

  @override
  void dispose() {
    _controller.clearCache();
    super.dispose();
  }

  void _initTeXView() {
    if (!_pageLoaded || getRawData(widget) == _lastData) return;

    if (widget.loadingWidgetBuilder != null) {
      setState(() {
        _height = minHeight;
      });
    }

    _controller.runJavaScript("initView(${getRawData(widget)})");
    _lastData = getRawData(widget);
  }
}
