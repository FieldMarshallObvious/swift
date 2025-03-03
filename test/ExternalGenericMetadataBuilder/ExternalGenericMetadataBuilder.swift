// RUN: %empty-directory(%t)
// RUN: %target-build-swift -Xfrontend -disable-availability-checking -I %swift-lib-dir -I %swift_src_root/lib/ExternalGenericMetadataBuilder -L%swift-lib-dir -lswiftGenericMetadataBuilder -enable-experimental-feature Extern %s -o %t/ExternalMetadataBuilderTest
// RUN: %target-codesign %t/ExternalMetadataBuilderTest
// RUN: %target-run %t/ExternalMetadataBuilderTest

// REQUIRES: executable_test
// REQUIRES: OS=macosx && CPU=arm64
// REQUIRES: rdar123810110

import ExternalGenericMetadataBuilder
import Foundation
import StdlibUnittest

@_extern(c)
func swift_getRuntimeLibraryPath() -> UnsafePointer<CChar>?

let ExternalGenericMetadataBuilderTests = TestSuite("ExternalGenericMetadataBuilder")

public struct GenericStruct<T, U, V> {
  var t: T
  var u: U
  var v: V
  var str: String
}

public struct GenericField<T, U> {
  var field: GenericStruct<T, U, Double>
  var int: Int
}

// The protocol conformance puts a symbol into __DATA_CONST which the builder
// can use as the base symbol for references to other data.
public protocol PublicProto {}
extension GenericStruct: PublicProto {}

ExternalGenericMetadataBuilderTests.test("JSON output") {
  let builder = swift_externalMetadataBuilder_create(1, "arm64")

  let inputJSON = """
  {
    "metadataNames": [
      {
        "name" : "\(_mangledTypeName(GenericField<Int8, Int16>.self)!)"
      },
      {
        "name" : "\(_mangledTypeName(Array<Array<Double>>.self)!)"
      }
    ]
  }
  """

  let readJSONErrorCStr = swift_externalMetadataBuilder_readNamesJSON(builder, inputJSON);
  let readJSONError = readJSONErrorCStr.map { String(cString: $0) }
  expectNil(readJSONError)

  let swiftCorePathCStr = swift_getRuntimeLibraryPath()
  let swiftCorePath = swiftCorePathCStr.map { String(cString: $0) }
  expectNotNil(swiftCorePath)

  // Add this executable as well, so we can test our own types.
  let executablePath = Bundle.main.executablePath

  for machoPath in [swiftCorePath, executablePath] {
    let url = URL(fileURLWithPath: machoPath!)
    let data = NSData(contentsOf: url)!

    let machHeader = data.bytes.assumingMemoryBound(to: mach_header.self)
    let addDylibErrorCStr =
      swift_externalMetadataBuilder_addDylib(builder,
                                             url.lastPathComponent,
                                             machHeader,
                                             UInt64(data.length));

    let addDylibError = addDylibErrorCStr.map { String(cString: $0) }
    expectNil(addDylibError)
  }

  let buildErrorCStr = swift_externalMetadataBuilder_buildMetadata(builder)
  let buildError = buildErrorCStr.map { String(cString: $0) }
  expectNil(buildError)

  let outputJSONCStr = swift_externalMetadataBuilder_getMetadataJSON(builder)
  let outputJSON = outputJSONCStr.map { String(cString: $0) }
  expectNotNil(outputJSON)

  let outputJSONObject = try! JSONSerialization.jsonObject(with: outputJSON!.data(using: .utf8)!)
  let expectedJSONObject = try! JSONSerialization.jsonObject(with: expectedJSON.data(using: .utf8)!)

  // Before comparing the JSONs, strip out things that might not be consistent
  // from one build to the next. In particular, pointer targets with large
  // addends are things that will depend on the specific layout of data within
  // the binary, because we've ended up referring to an adjacent symbol, so we
  // should replace those with something generic.
  func prepareForComparison(_ value: Any) -> Any {
    if let array = value as? [Any] {
      return array.map(prepareForComparison)
    }

    if let dictionary = value as? [String: Any] {
      // See if this dictionary contains a large addend.
      if let addend = dictionary["addend"] as? Int64 {
        if !(-8...8).contains(addend) {
          // Return a placeholder value that will always match.
          return "Target with large addend removed."
        }
      }

      return dictionary.mapValues(prepareForComparison)
    }
    return value;
  }

  let outputJSONPrepped = prepareForComparison(outputJSONObject)
  let expectedJSONPrepped = prepareForComparison(expectedJSONObject)

  let outputJSONDictionary = outputJSONPrepped as? NSDictionary
  expectNotNil(outputJSONDictionary)
  let expectedJSONDictionary = expectedJSONPrepped as? NSDictionary
  expectNotNil(expectedJSONDictionary)

  // Don't use expectEqual, as it will print the strings on one line with \n
  // escapes, which is unreadable here.
  expectTrue(outputJSONDictionary!.isEqual(expectedJSONDictionary),
             "Output JSON does not match expected:\n\(outputJSONDictionary!)" +
             "\nExpected:\n\(expectedJSONDictionary!)")

  swift_externalMetadataBuilder_destroy(builder)
}

runAllTests()

// Put the expected JSON at the end so it doesn't get in the way of the rest of
// the test code. Make it a computed property so we don't fall afoul of weird
// global initialization problems with top-level code.
var expectedJSON: String {
"""
{
    "version": 1,
    "platform": 1,
    "platformVersion": "1.0",
    "arch": "arm64",
    "installName": "/usr/lib/libswiftPrespecialized.dylib",
    "atoms": [
        {
            "name": "_$s27ExternalMetadataBuilderTest12GenericFieldVys4Int8Vs5Int16VG",
            "contentType": "constData",
            "contents": [
                "0000000000000000",
                {
                    "self": true,
                    "target": "___unnamed_atom_1",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "0002000000000000",
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMn",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$ss4Int8VN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$ss5Int16VN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "0000000020000000"
            ]
        },
        {
            "name": "_$s27ExternalMetadataBuilderTest13GenericStructVys4Int8Vs5Int16VSdG",
            "contentType": "constData",
            "contents": [
                "0000000000000000",
                {
                    "self": true,
                    "target": "___unnamed_atom_0",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "0002000000000000",
                {
                    "target": "_$s27ExternalMetadataBuilderTest13GenericStructVMn",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$ss4Int8VN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$ss5Int16VN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$sSdN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "00000000020000000800000010000000"
            ]
        },
        {
            "name": "___unnamed_atom_0",
            "contentType": "constData",
            "contents": [
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 432,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 776,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 936,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 1168,
                    "kind": "ptr64"
                },
                {
                    "target": "__swift_pod_copy",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 1600,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 1820,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 2264,
                    "kind": "ptr64"
                },
                "2000000000000000200000000000000007000300FFFFFF7F"
            ]
        },
        {
            "name": "___unnamed_atom_1",
            "contentType": "constData",
            "contents": [
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 2920,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 3292,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 3452,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 3712,
                    "kind": "ptr64"
                },
                {
                    "target": "__swift_pod_copy",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 4196,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 4444,
                    "kind": "ptr64"
                },
                {
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa",
                    "addend": 4560,
                    "kind": "ptr64"
                },
                "2800000000000000280000000000000007000300FFFFFF7F"
            ]
        },
        {
            "name": "_$sSaySdG",
            "contentType": "constData",
            "contents": [
                "0000000000000000",
                {
                    "target": "_$sBbWV",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "0002000000000000",
                {
                    "target": "_$sSaMn",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "target": "_$sSdN",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "00000000000000000000000000000000"
            ]
        },
        {
            "name": "_$sSaySaySdGG",
            "contentType": "constData",
            "contents": [
                "0000000000000000",
                {
                    "target": "_$sBbWV",
                    "addend": 0,
                    "kind": "ptr64"
                },
                "0002000000000000",
                {
                    "target": "_$sSaMn",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "_$sSaySdG",
                    "addend": 16,
                    "kind": "ptr64"
                },
                "00000000000000000000000000000000"
            ]
        },
        {
            "name": "__swift_prespecializedMetadataMap",
            "contentType": "constData",
            "contents": [
                "0500000000000000",
                {
                    "self": true,
                    "target": "__cstring_$s27ExternalMetadataBuilderTest13GenericStructVys4Int8Vs5Int16VSdG",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "_$s27ExternalMetadataBuilderTest13GenericStructVys4Int8Vs5Int16VSdG",
                    "addend": 16,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "__cstring_$sSaySdG",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "_$sSaySdG",
                    "addend": 16,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "__cstring_$s27ExternalMetadataBuilderTest12GenericFieldVys4Int8Vs5Int16VG",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "_$s27ExternalMetadataBuilderTest12GenericFieldVys4Int8Vs5Int16VG",
                    "addend": 16,
                    "kind": "ptr64"
                },
                "00000000000000000000000000000000",
                {
                    "self": true,
                    "target": "__cstring_$sSaySaySdGG",
                    "addend": 0,
                    "kind": "ptr64"
                },
                {
                    "self": true,
                    "target": "_$sSaySaySdGG",
                    "addend": 16,
                    "kind": "ptr64"
                }
            ]
        },
        {
            "name": "__cstring_$s27ExternalMetadataBuilderTest12GenericFieldVys4Int8Vs5Int16VG",
            "contentType": "constData",
            "contents": [
                "2473323745787465726E616C4D657461646174614275696C64657254657374313247656E657269634669656C6456797334496E7438567335496E743136564700"
            ]
        },
        {
            "name": "__cstring_$s27ExternalMetadataBuilderTest13GenericStructVys4Int8Vs5Int16VSdG",
            "contentType": "constData",
            "contents": [
                "2473323745787465726E616C4D657461646174614275696C64657254657374313347656E6572696353747275637456797334496E7438567335496E7431365653644700"
            ]
        },
        {
            "name": "__cstring_$sSaySaySdGG",
            "contentType": "constData",
            "contents": [
                "24735361795361795364474700"
            ]
        },
        {
            "name": "__cstring_$sSaySdG",
            "contentType": "constData",
            "contents": [
                "247353617953644700"
            ]
        },
        {
            "name": "__swift_prespecializationsData",
            "contentType": "constData",
            "contents": [
                "0100000001000000",
                {
                    "self": true,
                    "target": "__swift_prespecializedMetadataMap",
                    "addend": 0,
                    "kind": "ptr64"
                }
            ]
        }
    ],
    "dylibs": [
        {
            "installName": "/usr/lib/swift/libswiftCore.dylib",
            "exports": [
                {
                    "name": "_$sSaMn"
                },
                {
                    "name": "_$ss4Int8VN"
                },
                {
                    "name": "_$sSdN"
                },
                {
                    "name": "_$sBbWV"
                },
                {
                    "name": "__swift_pod_copy"
                },
                {
                    "name": "_$ss5Int16VN"
                }
            ]
        },
        {
            "installName": "ExternalMetadataBuilderTest",
            "exports": [
                {
                    "name": "_$s27ExternalMetadataBuilderTest12GenericFieldVMa"
                },
                {
                    "name": "_$s27ExternalMetadataBuilderTest13GenericStructVMn"
                },
                {
                    "name": "_$s27ExternalMetadataBuilderTest12GenericFieldVMn"
                }
            ]
        }
    ]
}
"""
}
