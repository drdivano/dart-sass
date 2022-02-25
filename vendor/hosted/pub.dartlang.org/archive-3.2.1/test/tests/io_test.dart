import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  final testPath = p.join(testDirPath, 'out/test_123.bin');
  final testData = Uint8List(120);
  for (var i = 0; i < testData.length; ++i) {
    testData[i] = i;
  }

  final testFile = File(testPath);
  testFile.createSync(recursive: true);
  testFile.openSync(mode: FileMode.write);
  testFile.writeAsBytesSync(testData);

  group('InputFileStream', () {
    test('length', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      expect(fs.length, testData.length);
    });

    test('readByte', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      for (var i = 0; i < testData.length; ++i) {
        expect(fs.readByte(), testData[i]);
      }
    });

    test('readBytes', () {
      var input = InputFileStream(testPath);
      expect(input.length, equals(120));
      var same = true;
      var ai = 0;
      while (!input.isEOS) {
        var bs = input.readBytes(50);
        var bytes = bs.toUint8List();
        for (var i = 0; i < bytes.length; ++i) {
          same = bytes[i] == ai + i;
          if (!same) {
            expect(same, equals(true));
            return;
          }
        }
        ai += bytes.length;
      }
    });

    test('position', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      fs.position = 50;
      final bs = fs.readBytes(50);
      final b = bs.toUint8List();
      expect(b.length, 50);
      for (var i = 0; i < b.length; ++i) {
        expect(b[i], testData[50 + i]);
      }
    });

    test('skip', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      fs.skip(50);
      final bs = fs.readBytes(50);
      final b = bs.toUint8List();
      expect(b.length, 50);
      for (var i = 0; i < b.length; ++i) {
        expect(b[i], testData[50 + i]);
      }
    });

    test('rewind', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      fs.skip(50);
      fs.rewind(10);
      var bs = fs.readBytes(50);
      var b = bs.toUint8List();
      expect(b.length, 50);
      for (var i = 0; i < b.length; ++i) {
        expect(b[i], testData[40 + i]);
      }
    });

    test('peakBytes', () {
      final fs = InputFileStream(testPath, bufferSize: 2);
      final bs = fs.peekBytes(10);
      final b = bs.toUint8List();
      expect(fs.position, 0);
      expect(b.length, 10);
      for (var i = 0; i < b.length; ++i) {
        expect(b[i], testData[i]);
      }
    });

    test("clone", () {
      final input = InputFileStream(testPath);
      final input2 = InputFileStream.clone(input, position: 6, length: 5);
      final bs = input2.readBytes(5);
      final b = bs.toUint8List();
      expect(b.length, 5);
      for (var i = 0; i < b.length; ++i) {
        expect(b[i], testData[6 + i]);
      }
    });
  });

  test('InputFileStream/OutputFileStream', () {
    var input = InputFileStream(p.join(testDirPath, 'res/cat.jpg'));
    var output = OutputFileStream(p.join(testDirPath, 'out/cat2.jpg'));
    while (!input.isEOS) {
      var bytes = input.readBytes(50);
      output.writeInputStream(bytes);
    }
    input.close();
    output.close();

    var a_bytes = File(p.join(testDirPath, 'res/cat.jpg')).readAsBytesSync();
    var b_bytes = File(p.join(testDirPath, 'out/cat2.jpg')).readAsBytesSync();

    expect(a_bytes.length, equals(b_bytes.length));
    var same = true;
    for (var i = 0; same && i < a_bytes.length; ++i) {
      same = a_bytes[i] == b_bytes[i];
    }
    expect(same, equals(true));
  });

  test('empty file', () {
    var encoder = ZipFileEncoder();
    encoder.create('$testDirPath/out/testEmpty.zip');
    encoder.addFile(File('$testDirPath/res/emptyfile.txt'));
    encoder.close();

    var zipDecoder = ZipDecoder();
    var f = File('$testDirPath/out/testEmpty.zip');
    final archive = zipDecoder.decodeBytes(f.readAsBytesSync(), verify: true);
    expect(archive.length, equals(1));
  });

  test('stream tar decode', () {
    // Decode a tar from disk to memory
    var stream = InputFileStream(p.join(testDirPath, 'res/test2.tar'));
    var tarArchive = TarDecoder();
    tarArchive.decodeBuffer(stream);

    for (final file in tarArchive.files) {
      if (!file.isFile) {
        continue;
      }
      var filename = file.filename;
      try {
        var f = File('$testDirPath/out/$filename');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.content as List<int>);
      } catch (e) {
        print(e);
      }
    }

    expect(tarArchive.files.length, equals(4));
  });

  test('stream zip decode', () {
    // Decode a tar from disk to memory
    var stream = InputFileStream(p.join(testDirPath, 'res/test.zip'));
    var zip = ZipDecoder().decodeBuffer(stream);

    expect(zip.files.length, equals(2));
    expect(zip.files[0].name, equals("a.txt"));
    expect(zip.files[1].name, equals("cat.jpg"));
    expect(zip.files[1].content.length, equals(51662));
  });

  test('stream tar encode', () {
    // Encode a directory from disk to disk, no memory
    final encoder = TarFileEncoder();
    encoder.open('$testDirPath/out/test3.tar');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.close();
  });

  test('stream gzip encode', () {
    final input = InputFileStream(p.join(testDirPath, 'res/cat.jpg'));
    final output = OutputFileStream(p.join(testDirPath, 'out/cat.jpg.gz'));

    final encoder = GZipEncoder();
    encoder.encode(input, output: output);
    output.close();
  });

  test('stream gzip decode', () {
    var input = InputFileStream(p.join(testDirPath, 'out/cat.jpg.gz'));
    var output = OutputFileStream(p.join(testDirPath, 'out/cat.jpg'));

    GZipDecoder().decodeStream(input, output);
    output.close();
  });

  test('stream tgz encode', () {
    // Encode a directory from disk to disk, no memory
    var encoder = TarFileEncoder();
    encoder.create('$testDirPath/out/example2.tar');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.close();

    var input = InputFileStream(p.join(testDirPath, 'out/example2.tar'));
    var output = OutputFileStream(p.join(testDirPath, 'out/example2.tgz'));
    GZipEncoder().encode(input, output: output);
    input.close();
    output.close();
  });

  test('stream zip encode', () {
    var encoder = ZipFileEncoder();
    encoder.create('$testDirPath/out/example2.zip');
    encoder.addDirectory(Directory('$testDirPath/res/test2'));
    encoder.addFile(File('$testDirPath/res/cat.jpg'));
    encoder.addFile(File('$testDirPath/res/tarurls.txt'));
    encoder.close();

    var zipDecoder = ZipDecoder();
    var f = File('$testDirPath/out/example2.zip');
    final archive = zipDecoder.decodeBytes(f.readAsBytesSync(), verify: true);
    expect(archive.length, equals(4));
  });

  test('create_archive_from_directory', () {
    var dir = Directory('$testDirPath/res/test2');
    var archive = createArchiveFromDirectory(dir);
    expect(archive.length, equals(2));
    var encoder = ZipEncoder();

    var bytes = encoder.encode(archive)!;

    var zipDecoder = ZipDecoder();
    var archive2 = zipDecoder.decodeBytes(bytes, verify: true);
    expect(archive2.length, equals(2));
  });

  test('file close', () {
    final testPath = p.join(testDirPath, 'out/test2.bin');
    final testData = Uint8List(120);
    for (var i = 0; i < testData.length; ++i) {
      testData[i] = i;
    }
    final testFile = File(testPath);
    testFile.createSync(recursive: true);
    final fp = testFile.openSync(mode: FileMode.write);
    fp.writeFromSync(testData);
    fp.closeSync();

    final input = InputFileStream(testPath);
    final bs = input.readBytes(50);
    expect(bs.length, 50);
    input.close();

    testFile.deleteSync();
  });

  test('extractFileToDisk tar', () {
    final inPath = '$testDirPath/res/test2.tar';
    final outPath = '$testDirPath/out/extractFileToDisk_tar';
    final dir = Directory(outPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    extractFileToDisk(inPath, outPath);

    final files = dir.listSync(recursive: true);
    expect(files.length, 4);
  });

  test('extractFileToDisk tar.gz', () {
    final inPath = '$testDirPath/res/test2.tar.gz';
    final outPath = '$testDirPath/out/extractFileToDisk_tgz';
    final dir = Directory(outPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    extractFileToDisk(inPath, outPath);

    final files = dir.listSync(recursive: true);
    expect(files.length, 4);
  });

  test('extractFileToDisk tar.tbz', () {
    final inPath = '$testDirPath/res/test2.tar.bz2';
    final outPath = '$testDirPath/out/extractFileToDisk_tbz';
    final dir = Directory(outPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    extractFileToDisk(inPath, outPath);

    final files = dir.listSync(recursive: true);
    expect(files.length, 4);
  });

  test('extractFileToDisk zip', () {
    final inPath = '$testDirPath/res/test.zip';
    final outPath = '$testDirPath/out/extractFileToDisk_zip';
    final dir = Directory(outPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    extractFileToDisk(inPath, outPath);

    final files = dir.listSync(recursive: true);
    expect(files.length, 2);
  });
}
