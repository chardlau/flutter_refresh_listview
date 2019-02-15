import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

/// Callback of RefreshListView for header/footer loadding
typedef RefreshCallback = Future<dynamic> Function();

/// RefreshListView
///
/// RefreshListView is a ListView that allow you to refresh or load more.
class RefreshListView extends StatefulWidget {
  // Threshold of offset for trigger refresh
  final int _threshold = 60;

  final int itemCount;

  final IndexedWidgetBuilder itemBuilder;

  final RefreshCallback onFooterRefresh;

  final RefreshCallback onHeaderRefresh;


  RefreshListView({
    Key key,
    this.itemCount,
    this.itemBuilder,
    this.onHeaderRefresh,
    this.onFooterRefresh,
  }) : super(key: key) {
    assert(itemCount != null, "itemCount can't not be null");
    assert(itemCount >= 0, "itemCount should be positive integer");
    assert(
    itemBuilder is IndexedWidgetBuilder,
    "itemBuilder is a function as bellow: \n"
        "Widget fun(BuildContext context, int index) {\n"
        "  ...\n"
        "}"
    );
    assert(
    onHeaderRefresh is RefreshCallback,
    "onHeaderRefresh is a function as bellow: \n"
        "Future<dynamic> function() async { \n"
        " await doAsyncThings(); \n"
        " // if ok \n"
        " return Future<null>; \n"
        " // if error happens \n"
        " // return Future<'Error'>; \n"
        "}"
    );
    assert(
    onFooterRefresh is RefreshCallback,
    "onFooterRefresh is a function as bellow: \n"
        "Future<dynamic> function() async { \n"
        " await doAsyncThings(); \n"
        " // if ok \n"
        " return Future<null>; \n"
        " // if error happens \n"
        " // return Future<'Error'>; \n"
        "}"
    );
  }

  @override
  _RefreshListViewState createState() => _RefreshListViewState();
}

/// State of Header/Footer
///
/// IDLE -> DRAG
///
/// DRAG -> READY
///
/// READY -> LOADING
///
/// LOADING -> ERROR
///
/// all -> IDLE
///
enum LoadingState {
  IDLE,
  DRAG,
  READY,
  LOADING,
  ERROR
}

class _RefreshListViewState extends State<RefreshListView> {
  ScrollController _controller = ScrollController();
  double _headerHeight = 0.0;
  LoadingState _headerState = LoadingState.IDLE;
  double _footerHeight = 0.0;
  LoadingState _footerState = LoadingState.IDLE;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget list = Positioned(
      left: 0,
      right: 0,
      top: _headerState == LoadingState.LOADING || _headerState == LoadingState.ERROR ? 60 : 0,
      bottom: _footerState == LoadingState.LOADING || _footerState == LoadingState.ERROR ? 60 : 0,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleNotification,
        child: ListView.builder(
            physics: new AlwaysScrollableScrollPhysics(),
            controller: _controller,
            itemCount: widget.itemCount ?? 0,
            itemBuilder: widget.itemBuilder
        ),
      ),
    );
    var children = <Widget> [
      list,
      HeaderView(state: _headerState, height: _headerHeight),
      FooterView(state: _footerState, height: _footerHeight, callback: _triggerFooterCallback)
    ];
    return Stack(children: children);
  }

  bool _handleNotification (ScrollNotification notification) {
    if (notification.depth > 0) return false;

    ScrollMetrics metrics = notification.metrics;

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) { // User is touching the screen
        double headerOffset = math.min(metrics.pixels, 0.0).abs();
        double footerOffset = math.min(metrics.maxScrollExtent - metrics.pixels, 0.0).abs();
        if (_isHeaderDraggable(headerOffset)) { // Update header state
          setState(() {
            if (headerOffset >= widget._threshold) {
              _headerState = LoadingState.READY;
            } else {
              _headerState = LoadingState.DRAG;
            }
            _headerHeight = headerOffset;
            if (headerOffset > widget._threshold / 2) {
              _footerState = LoadingState.IDLE;
              _footerHeight = 0;
            }
          });
        }
        if (_isFooterDraggable(footerOffset)) {  // Update footer state
          setState(() {
            if (footerOffset >= widget._threshold) {
              _footerState = LoadingState.READY;
            } else {
              _footerState = LoadingState.DRAG;
            }
            _footerHeight = footerOffset;
          });
        }
      } else { // User is not touching the screen
        if (_headerState == LoadingState.DRAG || _headerState == LoadingState.READY) {
          if (_headerState == LoadingState.READY) {
            _triggerHeaderCallback();
          } else {
            setState(() {
              _headerState = LoadingState.IDLE;
              _headerHeight = 0;
            });
          }
        }
        if (_footerState == LoadingState.DRAG || _footerState == LoadingState.READY) {
          if (_footerState == LoadingState.READY) {
            _triggerFooterCallback();
          } else {
            setState(() {
              _footerState = LoadingState.IDLE;
              _footerHeight = 0;
            });
          }
        }
      }
    }
    return false;
  }

  void _triggerHeaderCallback () async {
    setState(() {
      _headerState = LoadingState.LOADING;
    });
    var error = await widget.onHeaderRefresh();
    print('onHeaderRefresh returns error: $error');
    setState(() {
      _headerState = error == null ? LoadingState.IDLE : LoadingState.ERROR;
      if (error == null) {
        _headerHeight = 0;
      }
    });
  }

  void _triggerFooterCallback () async {
    setState(() {
      _footerState = LoadingState.LOADING;
    });
    var error = await widget.onFooterRefresh();
    print('onFooterRefresh returns error: $error');
    setState(() {
      _footerState = error == null ? LoadingState.IDLE : LoadingState.ERROR;
      if (error == null) {
        _footerHeight = 0;
      }
    });
  }

  // Check whether header is draggable or not
  bool _isFooterDraggable(footerOffset) {
    return (
        footerOffset > 0 &&
            widget.itemCount > 0 &&
            _footerState != LoadingState.LOADING &&
            _footerState != LoadingState.ERROR
    ) && (
        _headerState == LoadingState.IDLE ||
            _headerState == LoadingState.ERROR
    );
  }

  // Check whether footer is draggable or not
  bool _isHeaderDraggable(headerOffset) {
    return (
        headerOffset > 0 &&
            _headerState != LoadingState.LOADING
    ) && (
        _footerState == LoadingState.IDLE ||
            _footerState == LoadingState.ERROR
    );
  }
}

class HeaderView extends StatelessWidget {

  final LoadingState state;

  final double height;

  HeaderView ({ Key key, this.state, this.height }) : super (key: key);

  @override
  Widget build(BuildContext context) {
    var children;
    if (state == LoadingState.LOADING) {
      children =<Widget>[
        Container(
          width: 20,
          height: 20,
          margin: EdgeInsets.only(right: 12),
          child: CircularProgressIndicator(),
        ),
        Text('Loading...'),
      ];
    } else if (state == LoadingState.READY) {
      children =<Widget>[
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(Icons.arrow_upward),
        ),
        Text('送开刷新'),
      ];
    } else {
      children =<Widget>[
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(Icons.arrow_downward),
        ),
        Text('下拉将触发刷新'),
      ];
    }
    double top = state == LoadingState.IDLE ? -60 :
    (state == LoadingState.LOADING ? 0 : this.height - 60);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Container(
          height: 60,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children
          )
      ),
    );
  }
}

class FooterView extends StatelessWidget {

  final LoadingState state;

  final double height;

  final GestureTapCallback callback;

  FooterView ({ Key key, this.state, this.height, this.callback }) : super (key: key);

  @override
  Widget build(BuildContext context) {
    var children;
    if (state == LoadingState.LOADING) {
      children = <Widget>[
        Container(
          width: 20,
          height: 20,
          margin: EdgeInsets.only(right: 12),
          child: CircularProgressIndicator(),
        ),
        Text('Loading...'),
      ];
    } else if (state == LoadingState.ERROR) {
      children = <Widget>[
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(Icons.error_outline),
        ),
        GestureDetector(
          child: Text('加载失败，点击重新加载'),
          onTap: callback,
        )
      ];
    } else if (state == LoadingState.READY) {
      children =<Widget>[
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(Icons.arrow_downward),
        ),
        Text('松开加载更多'),
      ];
    } else {
      children =<Widget>[
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(Icons.arrow_upward),
        ),
        Text('上拉加载更多'),
      ];
    }
    double bottom = state == LoadingState.IDLE ? -60 :
    (state == LoadingState.LOADING || state == LoadingState.ERROR ? 0 : this.height - 60);
    return Positioned(
      bottom: bottom,
      left: 0,
      right: 0,
      child: Container(
          height: 60,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children
          )
      ),
    );
  }
}
