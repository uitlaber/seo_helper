import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart' as path_provider;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'SEO HELPER FOR IGOR'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _loading = false;
  late TextEditingController _tagsController;
  late TextEditingController _linksController;
  late TextEditingController _logsController;

  @override
  void dispose() {
    super.dispose();
    _tagsController.dispose();
    _linksController.dispose();
    _logsController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tagsController = TextEditingController();
    _linksController = TextEditingController();
    _logsController = TextEditingController();
  }

  Future<void> _parseLinks() async {
    setState(() {
      _loading = true;
    });

    try {
      LineSplitter ls = const LineSplitter();
      List<String> links = ls.convert(_linksController.value.text.trim());
      List<String> tags = _tagsController.value.text.trim().split(',');
      var data = [];

      for (var i = 0; i < links.length; i++) {
        Map<String, dynamic> dataItem = {};
        dataItem['url'] = links[i];
        final response = await http.get(Uri.parse(links[i]));
        for (var c = 0; c < tags.length; c++) {
          var tag = tags[c].trim();
          if (tag.isNotEmpty) {
            var document = parse(response.body);
            var byAttribute = tag.split('|');
            if (byAttribute.length > 1) {
              var text = document
                  .querySelector(byAttribute[0])
                  ?.attributes[byAttribute[1]];
              if (text == null) {
                _logsController.text +=
                    '\nНе найден тег или атрибут ${byAttribute[0]} по ссылке ${links[i]}';
                continue;
              }
              dataItem[tags[c]] = text;
            } else {
              final text = document.querySelector(tags[c])?.text;
              if (text == null) {
                _logsController.text +=
                    '\nНе найден тег или атрибут ${byAttribute[0]} по ссылке ${links[i]}';
                continue;
              }
              dataItem[tags[c]] = text;
            }
          }
        }
        data.add(dataItem);
      }

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];

      int firstRow = 1;
      const int firstColumn = 1;
      const bool isVertical = false;
      sheet.getRangeByIndex(1, 1, 1, 4).autoFitColumns();

      final List<Object> headers = [];
      headers.add('url');
      for (var c = 0; c < tags.length; c++) {
        headers.add(tags[c]);
      }
      sheet.importList(headers, firstRow, firstColumn, isVertical);
      firstRow++;

      for (var dataItem in data) {
        final List<Object> list = [];
        list.add(dataItem['url']);
        for (var c = 0; c < tags.length; c++) {
          if (dataItem[tags[c]] != null) {
            list.add(dataItem[tags[c]]);
          } else {
            list.add('-');
          }
        }
        sheet.importList(list, firstRow, firstColumn, isVertical);
        firstRow++;
      }

      final List<int>? bytes = workbook.saveAsStream();

      final Directory directory =
          await path_provider.getApplicationSupportDirectory();
      final String path = directory.path;
      var timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final File file = File(Platform.isWindows
          ? '$path\\$timestamp.xlsx'
          : '$path/$timestamp.xlsx');
      await file.writeAsBytes(bytes!, flush: true);
      if (Platform.isWindows) {
        await Process.run('start', <String>['$path\\$timestamp.xlsx'],
            runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', <String>['$path/$timestamp.xlsx'],
            runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', <String>['$path/$timestamp.xlsx'],
            runInShell: true);
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print('Exception: ' + e.toString());
        print('Stacktrace: ' + stacktrace.toString());
      }
      setState(() {
        _loading = false;
      });
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _linksController,
                minLines: 6,
                readOnly: _loading,
                decoration: const InputDecoration(hintText: 'Введите ссылки'),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              TextFormField(
                controller: _tagsController,
                readOnly: _loading,
                decoration: const InputDecoration(
                    hintText: 'Введите теги через запятую'),
              ),
              const SizedBox(
                height: 30,
              ),
              TextFormField(
                controller: _logsController,
                minLines: 6,
                style: const TextStyle(
                  fontSize: 12
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(0),
                  hintText: 'Логи',
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  filled: true,
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 20),
              TextButton(
                style: ButtonStyle(
                  foregroundColor:
                      MaterialStateProperty.all<Color>(Colors.blue),
                ),
                onPressed: () {
                  _logsController.clear();
                },
                child: const Text('Очистить логи'),
              )
            ],
          ),
        ),
        floatingActionButton: !_loading
            ? FloatingActionButton(
                onPressed: _parseLinks,
                tooltip: 'Parse links',
                child: const Icon(Icons.download),
              )
            : FloatingActionButton(
                onPressed: () {},
                tooltip: 'loading',
                backgroundColor: Colors.green,
                child: const Icon(Icons.downloading),
              ) // This trailing comma makes auto-formatting nicer for build methods.
        );
  }

  selectFile() {}
}

@override
Widget build(BuildContext context) {
  // TODO: implement build
  throw UnimplementedError();
}
