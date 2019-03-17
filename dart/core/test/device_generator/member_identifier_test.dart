import 'dart:async';
import 'package:test/test.dart';

import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:blackbird/blackbird.dart';
import 'package:blackbird_common/member_identifier.dart';
import 'dart:io';

String source = '''
import 'package:blackbird/blackbird.dart';
abstract class SimpleDevice implements Device {
  int aProperty;

  Device otherDevice;

  int get aRuntimeDependency;
  
  void executiveMethod() {}
  int get executiveGetter {}
  set executiveSetter(int value) {}

  void abstractExecutiveMethod();

  @Property()
  int get annotationProperty => aProperty + 1;
  @Runtime()
  int get annotationRuntimeDependency;
  @Executive()
  int get annotationExecutive;
  @Ignore()
  int get annotationIgnored{return 2;}
}
''';

main() async {
  await generate(source);
  ClassElement simpleDevice = classElements['SimpleDevice'];
  check(String name, DeviceMemberType expected) {
    List elements = [];
    elements.addAll(simpleDevice.fields);
    elements.addAll(simpleDevice.accessors);
    elements.addAll(simpleDevice.methods);
    elements
        .where((e) => e.name == name)
        .map((e) => identify(e))
        .forEach((e) => expect(e, expected));
  }

  group('properties', () {
    test('simple', () {
      check('aProperty', DeviceMemberType.property);
    });
    test('annotation', () {
      check('annotationProperty', DeviceMemberType.property);
    });
  });
  group('runtime', () {
    test('simple', () {
      check('aRuntimeDependency', DeviceMemberType.runtime);
    });
    test('annotation', () {
      check('annotationRuntimeDependency', DeviceMemberType.runtime);
    });
  });
  group('executive', () {
    test('simple', () {
      check('executiveMethod', DeviceMemberType.executive);
      check('execuitiveGetter', DeviceMemberType.executive);
      check('executiveSetter', DeviceMemberType.executive);
    });
    test('annotation', () {
      check('annotationExecutive', DeviceMemberType.executive);
    });
  });
  group('submodule', () {
    test('simple', () {
      check('otherDevice', DeviceMemberType.submodule);
    });
  });
  group('ignored', () {
    test('annotation', () {
      check('annotationIgnored', DeviceMemberType.ignored);
    });
  });
}

final Builder builder =
    new PartBuilder([new ClassElementProvder()], '.g.test.dart');

Map<String, ClassElement> classElements = {};

class ClassElementProvder extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    library.classElements.forEach((e) {
      classElements.putIfAbsent(e.name, () => e);
    });
    return "";
  }
}

final String pkgName = 'pkg';

generate(String source) async {
  final srcs = <String, String>{
    '$pkgName|lib/sometestfile.dart': source,
    'blackbird|lib/blackbird.dart':
        await new File('lib/blackbird.dart').readAsString(),
    'blackbird|lib/src/device.dart':
        await new File('lib/src/device.dart').readAsString(),
  };

  final writer = new InMemoryAssetWriter();
  await testBuilder(builder, srcs, rootPackage: pkgName, writer: writer);
}
