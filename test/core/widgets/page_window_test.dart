import 'package:app_finnegans/core/widgets/page_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Una página intermedia va de start a end', () {
    expect(pageWindow(page: 1, pageSize: 8, total: 20), (
      page: 1,
      pageCount: 3,
      start: 8,
      end: 16,
    ));
  });

  test('La última página puede quedar incompleta', () {
    expect(pageWindow(page: 2, pageSize: 8, total: 20), (
      page: 2,
      pageCount: 3,
      start: 16,
      end: 20,
    ));
  });

  test('Una página fuera de rango se acota a la última', () {
    expect(pageWindow(page: 7, pageSize: 8, total: 20), (
      page: 2,
      pageCount: 3,
      start: 16,
      end: 20,
    ));
    expect(pageWindow(page: -1, pageSize: 8, total: 20).page, 0);
  });

  test('Si la lista se achica, la página vuelve a la que existe', () {
    expect(pageWindow(page: 2, pageSize: 8, total: 5), (
      page: 0,
      pageCount: 1,
      start: 0,
      end: 5,
    ));
  });

  test('Sin elementos hay una sola página vacía', () {
    expect(pageWindow(page: 3, pageSize: 8, total: 0), (
      page: 0,
      pageCount: 1,
      start: 0,
      end: 0,
    ));
  });
}
