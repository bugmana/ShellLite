import 'dart:async';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// An [SSHSocket] implementation that communicates over a WebSocket channel
/// for Flutter Web browser environments.
class WebSocketSSHSocket implements SSHSocket {
  final WebSocketChannel _channel;
  final StreamController<Uint8List> _streamController = StreamController<Uint8List>.broadcast();
  final StreamController<List<int>> _sinkController = StreamController<List<int>>();
  late final StreamSubscription _wsSub;
  late final StreamSubscription _sinkSub;

  WebSocketSSHSocket(this._channel) {
    _wsSub = _channel.stream.listen(
      (data) {
        if (data is Uint8List) {
          _streamController.add(data);
        } else if (data is List<int>) {
          _streamController.add(Uint8List.fromList(data));
        } else if (data is ByteBuffer) {
          _streamController.add(data.asUint8List());
        }
      },
      onError: (e, st) {
        if (!_streamController.isClosed) {
          _streamController.addError(e, st);
        }
      },
      onDone: () {
        if (!_streamController.isClosed) {
          _streamController.close();
        }
      },
      cancelOnError: false,
    );

    _sinkSub = _sinkController.stream.listen(
      (data) {
        _channel.sink.add(Uint8List.fromList(data));
      },
      onDone: () {
        _channel.sink.close();
      },
    );
  }

  static Future<SSHSocket> connect(Uri wsUri) async {
    final channel = WebSocketChannel.connect(wsUri);
    await channel.ready;
    return WebSocketSSHSocket(channel);
  }

  @override
  Stream<Uint8List> get stream => _streamController.stream;

  @override
  StreamSink<List<int>> get sink => _sinkController.sink;

  @override
  Future<void> get done => _streamController.done;

  @override
  Future<void> close() async {
    try {
      await _sinkController.close();
      await _sinkSub.cancel();
      await _wsSub.cancel();
      await _channel.sink.close();
      await _streamController.close();
    } catch (_) {}
  }

  @override
  Future<void> flush() async {}

  @override
  void destroy() {
    close();
  }
}
