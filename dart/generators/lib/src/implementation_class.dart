import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:source_gen_helpers/class/class_visitor.dart';
import 'package:source_gen_helpers/class/util.dart';
import 'package:source_gen_helpers/class/output_visitor.dart';
import 'package:source_gen_helpers/class/override_visitor.dart';
import 'visitor.dart';
import 'package:tuple/tuple.dart';
import 'type_list.dart';
import 'package:blackbird_common/member_identifier.dart';
import 'dart:async';

class ImplementationVisitor extends BasicDeviceVisitor<String> {
  static Tuple2<DartType, String> harmonize(Element e) {
    if (e is ExecutableElement) {
      return Tuple2(e.returnType, e.displayName);
    } else if (e is FieldElement) {
      return Tuple2(e.type, e.displayName);
    } else {
      throw new Exception('could not harmonize $e');
    }
  }

  visitClassElement(ClassElement element) async {
    super.visitClassElement(element);
    classDeclarationCompleter.complete(
        'class _\$${element.name}Implementation extends ${element.name}');
    // construction info
    StringBuffer constructionInfo = new StringBuffer();
    constructionInfo.write('''
          if(parameters == null){
            ConstructionInfoException info = new ConstructionInfoException();
    ''');

    List<Element> list = [];
    list.addAll(await runtimeDependencies);
    list.addAll(await modules);
    list.where((e) => !e.isSynthetic).forEach((e) {
      // register dependency

      String types = typeList(harmonize(e).item1).join('","');

      constructionInfo.write('''
        info.dependencies.add(
          new Dependency(
            name: #${harmonize(e).item2}, 
            type: ["$types"], 
            device: this, 
            module: ${isSubModule(e) ? 'delegate.' + harmonize(e).item2 : 'null'},
            isModule: ${isSubModule(e)}));
      ''');
    });
    list.where((e) => !e.isSynthetic).forEach((e) {
      e.metadata.forEach((a) {
        //put annotation to list
        constructionInfo.write('''
            info[#${e.displayName}].annotations.add(
              ${a.toSource().substring(1)}
            );''');
      });
    });
    constructionInfo.write('''
      throw info;
    ''');
    constructionInfo.write('}');

    // assignment of varaibles on construction
    String privateVariables = (await runtimeDependencies)
        .where((e) => !e.isSynthetic)
        .map((e) => harmonize(e))
        .map((e) => '${e.item1} _${e.item2};')
        .join(' \n');

    privateVariables += (await modules)
        .where((e) => !e.isSynthetic)
        .map((e) => harmonize(e))
        .map((e) => '${e.item1} _${e.item2};')
        .join(' \n');

    String assigns = (await runtimeDependencies)
        .where((e) => !e.isSynthetic)
        .map((e) => '_${e.displayName} = parameters[#${e.displayName}];')
        .join('\n');

    assigns += (await modules)
        .where((e) => !e.isSynthetic)
        .map((e) => '_${e.displayName} = parameters[#${e.displayName}];')
        .join('\n');

    assigns += (await properties)
        .where((e) => e is PropertyAccessorElement)
        .map((e) => e as PropertyAccessorElement)
        .where((e) => e.isGetter)
        .where((e) => e.isSynthetic)
        .map((e) => '_${e.displayName} = delegate.${e.displayName};')
        .join('\n');

    String name = await className;
    return '''
      $privateVariables

      _\$${await className}Implementation(${await className} delegate, Map<Symbol, Object> parameters){
          $constructionInfo
        
          $assigns
        }

      Host get host => _host;

      $name implementation(Map<Symbol, Object> dependencies) 
        => throw Exception('this is already an implementation');
      @override
      Object invoke(Invocation invocation) =>
          _\$${name}Invoker.invoke(invocation, this);
      Provision provideRemote(Context context) =>
          _\$${name}Rmi.provideRemote(context, this);
      $name getRemote(Context context, String uuid) =>
        _\$${name}Rmi.getRemote(context, uuid);
      @override
      Map<String, dynamic> serialize() => _\$${name}ToJson(this);
    ''';
  }

  @override
  FutureOr<String> visitConstructorElement(ConstructorElement element) => null;

  @override
  FutureOr<String> visitPropertySetter(PropertyAccessorElement element) =>
      "=> throw new Exception('cannot change device property after implementationconstruction');";
  @override
  FutureOr<String> visitPropertyGetter(PropertyAccessorElement element) {
    if ((element.correspondingGetter ?? element).isSynthetic)
      return "=> _${element.name};";
  }

  @override
  FutureOr<String> visitPropertyField(FieldElement element) {
    if (element.getter.isSynthetic)
      return '''
      ${element.type.name} _${element.displayName};
    ''';
  }

  /// In fact a property method can do anythign and violate the DI concept,
  /// however, some very specific methods are reasonable, eg. a getter and an argument passing a format.
  @override
  FutureOr<String> visitPropertyMethod(MethodElement element) => null;

  @override
  FutureOr<String> visitRuntimeGetter(PropertyAccessorElement element) =>
      "=> _${element.name};";

  @override
  FutureOr<String> visitExecutiveMethod(MethodElement element) => null;
  @override
  FutureOr<String> visitExecutiveSetter(PropertyAccessorElement element) =>
      null;
  @override
  FutureOr<String> visitExecutiveGetter(PropertyAccessorElement element) =>
      null;

  @override
  FutureOr<String> visitModuleGetter(PropertyAccessorElement e) =>
      '=> _${e.displayName};';
  @override
  FutureOr<String> visitModuleSetter(PropertyAccessorElement element) =>
      '=> throw new Exception("cannot change module after implementation construction");';
  @override
  FutureOr<String> visitModuleField(FieldElement element) => null;
}
