import 'dart:async';
import 'dart:io';
import 'package:build_daemon/daemon.dart';
import 'package:build_daemon/src/fakes/fake_builder.dart';
import 'package:build_daemon/src/fakes/fake_change_provider.dart';
import 'package:test/test.dart';

class RaceDirectory implements Directory {
  final Directory delegate;
  final Function(String) onDeleteSync;
  RaceDirectory(this.delegate, this.onDeleteSync);

  // Implement the rest of the interface to avoid analyzer errors and pass execution to the delegate.
  @override String get path => delegate.path;
  @override Uri get uri => delegate.uri;
  @override bool existsSync() => delegate.existsSync();
  @override void createSync({bool recursive = false}) => delegate.createSync(recursive: recursive);

  @override
  void deleteSync({bool recursive = false}) {
    if (path.contains('.dart_tool') && path.contains('daemon')) {
      onDeleteSync(path);
    }
    delegate.deleteSync(recursive: recursive);
  }

  // Need to implement the rest of Directory methods by forwarding to delegate
  @override Future<Directory> create({bool recursive = false}) => delegate.create(recursive: recursive);
  @override Future<Directory> createTemp([String? prefix]) => delegate.createTemp(prefix);
  @override Directory createTempSync([String? prefix]) => delegate.createTempSync(prefix);
  @override Future<FileSystemEntity> delete({bool recursive = false}) => delegate.delete(recursive: recursive);
  @override Future<bool> exists() => delegate.exists();
  @override Directory get absolute => delegate.absolute;
  @override Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) => delegate.list(recursive: recursive, followLinks: followLinks);
  @override List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) => delegate.listSync(recursive: recursive, followLinks: followLinks);
  @override Future<Directory> rename(String newPath) => delegate.rename(newPath);
  @override Directory renameSync(String newPath) => delegate.renameSync(newPath);
  @override Future<String> resolveSymbolicLinks() => delegate.resolveSymbolicLinks();
  @override String resolveSymbolicLinksSync() => delegate.resolveSymbolicLinksSync();
  @override Future<FileStat> stat() => delegate.stat();
  @override FileStat statSync() => delegate.statSync();
  @override Directory get parent => delegate.parent;
  @override bool get isAbsolute => delegate.isAbsolute;
  @override Stream<FileSystemEvent> watch({int events = FileSystemEvent.all, bool recursive = false}) => delegate.watch(events: events, recursive: recursive);
}

void main() {
  test('proves the delete after close lock race', () async {
    final workspace = Directory.systemTemp.createTempSync('build_daemon_test_').path;
    bool deleteFired = false;
    
    await IOOverrides.runZoned(() async {
      final daemon1 = Daemon(workspace, daemonSharedPath: null);
      await daemon1.start(<String>{}, FakeDaemonBuilder(), FakeChangeProvider());

      // Stop daemon1 to trigger cleanUp
      await daemon1.stop();
      await daemon1.onDone;
      
    }, createDirectory: (path) {
       // Escape the current IOOverrides zone by running in the root zone
       final raw = Zone.root.run(() => Directory(path));
       return RaceDirectory(raw, (deletedPath) {
          if (deleteFired) return;
          deleteFired = true;
          print('INTERCEPTED deleteSync on: $deletedPath');
          
          final daemon2 = Daemon(workspace, daemonSharedPath: null);
          print('Daemon 2 created. Checking if its port file is valid...');
          
          final lockFile = File('$deletedPath/.dart_build_lock');
          print('Daemon 2 lock exists: ${lockFile.existsSync()}'); // Should be TRUE here.
          
          // Then when deleteSync continues, it will delete the lock that Daemon 2 just made!
       });
    });
    
    final lockFileAfter = File('$workspace/.dart_tool/build/daemon/.dart_build_lock');
    print('Lock file exists after deleteSync: ${lockFileAfter.existsSync()}'); // Should be FALSE!
    
    // Test assertion!
    expect(deleteFired, isTrue);
    expect(lockFileAfter.existsSync(), isFalse, reason: 'Daemon 2 lock file was deleted by Daemon 1!');
  });
}
