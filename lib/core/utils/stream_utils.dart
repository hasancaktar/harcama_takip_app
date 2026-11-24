import 'dart:async';

/// Ek paket gerektirmeden birden çok akışın en son değerlerini birleştirir.
///
/// Tüm akışlar en az bir değer yayınladıktan sonra, herhangi biri her değiştiğinde
/// güncel değerlerin listesini yayınlar. Akışlardan biri hata verirse hata iletilir.
Stream<List<T>> combineLatestAll<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) return Stream.value(<T>[]);
  if (streams.length == 1) return streams.first.map((v) => <T>[v]);

  // Akış dinleyicisi iptal edildiğinde onCancel içinde kapatılır.
  // ignore: close_sinks
  late StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<T>>[];
  final values = List<T?>.filled(streams.length, null);
  final hasValue = List<bool>.filled(streams.length, false);

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(
          streams[i].listen((value) {
            values[i] = value;
            hasValue[i] = true;
            if (hasValue.every((h) => h)) {
              controller.add(List<T>.from(values));
            }
          }, onError: controller.addError),
        );
      }
    },
    onPause: () {
      for (final s in subscriptions) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subscriptions) {
        s.resume();
      }
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
      subscriptions.clear();
      await controller.close();
    },
  );
  return controller.stream;
}

/// Liste akışlarını birleştirip kimliğe göre tekilleştirir.
Stream<List<T>> mergeListStreams<T>(
  List<Stream<List<T>>> streams, {
  required String Function(T) idOf,
}) {
  return combineLatestAll(streams).map((lists) {
    final byId = <String, T>{};
    for (final list in lists) {
      for (final item in list) {
        byId[idOf(item)] = item;
      }
    }
    return byId.values.toList();
  });
}

/// [fetch]'i hemen ve ardından her [interval]'da bir çağırır; son başarılı
/// değeri yayınlar (henüz yoksa `null`). Hatalar bilerek yok sayılır — dış
/// servislerden gelen bilgiler yalnızca yardımcıdır. Dönen [cancel] zamanlayıcıyı
/// durdurup akışı kapatır.
({Stream<T?> stream, void Function() cancel}) pollLatest<T>(
  Future<T> Function() fetch,
  Duration interval,
) {
  final controller = StreamController<T?>();
  T? last;
  var busy = false;
  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    try {
      last = await fetch();
    } catch (_) {
      // Yok sayılır; son başarılı değer korunur.
    } finally {
      busy = false;
    }
    if (!controller.isClosed) controller.add(last);
  }

  refresh();
  final timer = Timer.periodic(interval, (_) => refresh());
  return (
    stream: controller.stream,
    cancel: () {
      timer.cancel();
      controller.close();
    },
  );
}
