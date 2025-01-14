// RUN: %empty-directory(%t)

// RUN: %target-swift-frontend -swift-version 5 -enable-library-evolution -module-name isolated_any -emit-module -o %t/isolated_any.swiftmodule -emit-module-interface-path -  -enable-experimental-feature IsolatedAny %s | %FileCheck %s

// CHECK:      #if compiler(>=5.3) && $IsolatedAny
// CHECK-NEXT: {{^}}public func test1(fn: @isolated(any) () -> ())
// CHECK-NEXT: #endif
public func test1(fn: @isolated(any) () -> ()) {}

// CHECK-NEXT: #if compiler(>=5.3) && $IsolatedAny
// CHECK-NEXT: {{^}}public func test2(fn: @isolated(any) () -> ())
// CHECK-NEXT: #endif
@_allowFeatureSuppression(XXX)
public func test2(fn: @isolated(any) () -> ()) {}

// CHECK-NEXT: #if compiler(>=5.3) && $IsolatedAny
// CHECK-NEXT: {{^}}public func test3(fn: @isolated(any) () -> ())
// CHECK-NEXT: #else
// CHECK-NEXT: {{^}}public func test3(fn: () -> ())
// CHECK-NEXT: #endif
@_allowFeatureSuppression(IsolatedAny)
public func test3(fn: @isolated(any) () -> ()) {}
